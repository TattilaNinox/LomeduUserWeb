const { onCall, onRequest } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const crypto = require('crypto');

// Konfiguráció forrása: 1) Firebase Functions config (firebase functions:config:set smtp.*),
// 2) környezeti változók, 3) ha emulátor fut, próbáljon meg helyi SMTP-t (opcionális).

admin.initializeApp();

// Globális beállítások – régió, erőforrások
setGlobalOptions({ region: 'europe-west1', cpu: 1 });

const db = admin.firestore();

// SimplePay konfiguráció
const SIMPLEPAY_CONFIG = {
  merchantId: process.env.SIMPLEPAY_MERCHANT_ID || '',
  secretKey: process.env.SIMPLEPAY_SECRET_KEY || '',
  baseUrl: process.env.NODE_ENV === 'production' 
    ? 'https://secure.simplepay.hu/payment/v2/' 
    : 'https://sandbox.simplepay.hu/payment/v2/',
};

// Fizetési csomagok
const PAYMENT_PLANS = {
  monthly_web: {
    name: 'Havi előfizetés',
    price: 2990,
    description: 'Teljes hozzáférés minden funkcióhoz',
    subscriptionDays: 30,
  },
};

// SMTP transport - STARTTLS módszerrel
const transport = nodemailer.createTransport({
  host: 'mail.lomedu.hu',
  port: 587,
  secure: false, // STARTTLS
  requireTLS: true,
  auth: {
    user: 'info@lomedu.hu',
    pass: 'SoliDeoGloria55!!',
  },
});
const auth = admin.auth();

exports.requestDeviceChange = onCall(async (request) => {
  const data = request.data || {};
  const email = (data.email || '').toString().trim().toLowerCase();
  if (!email) {
    throw new Error('invalid-argument: Email szükséges');
  }

  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = Date.now() + 15 * 60 * 1000; // 15 perc
  
  const snap = await db.collection('users').where('email', '==', email).limit(1).get();
  if (snap.empty) {
    throw new Error('not-found: Nem található felhasználó ezzel az email címmel.');
  }

  const userDoc = snap.docs[0];
  await userDoc.ref.set({
    deviceChange: {
      code,
      expiresAt,
      requestedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  }, { merge: true });

  // E-mail küldés
  try {
    await transport.sendMail({
      from: 'Lomedu <info@lomedu.hu>',
      to: email,
      subject: 'Eszközváltási kód',
      text: `Az új eszköz jóváhagyásához adja meg a következő kódot: ${code} (15 percig érvényes)`,
      html: `<p>Az új eszköz jóváhagyásához adja meg a következő kódot:</p><h2>${code}</h2><p>A kód 15 percig érvényes.</p>`,
    });
    console.log('Device change email sent to', email);
  } catch (mailErr) {
    console.error('Email sending failed:', mailErr);
  }

  return { ok: true };
});

exports.verifyAndChangeDevice = onCall(async (request) => {
  const data = request.data || {};
  const email = (data.email || '').toString().trim().toLowerCase();
  const code = (data.code || '').toString().trim();
  const newFingerprint = (data.fingerprint || '').toString().trim();

  if (!email || !code || !newFingerprint) {
    throw new Error('invalid-argument: Hiányzó mezők');
  }

  const snap = await db.collection('users').where('email', '==', email).limit(1).get();
  if (snap.empty) {
    throw new Error('not-found: Nem található felhasználó ezzel az email címmel.');
  }

  const userDoc = snap.docs[0];
  const dc = userDoc.data().deviceChange || {};
  if (!dc.code || !dc.expiresAt || dc.code !== code || Date.now() > Number(dc.expiresAt)) {
    throw new Error('failed-precondition: Érvénytelen vagy lejárt kód');
  }

  try {
    // A Firebase Auth UID-t használjuk a dokumentum ID-ként
    const userData = userDoc.data();
    const firebaseAuthUid = userData.firebaseAuthUid || userDoc.id;
    
    console.log(`Found user with email ${email}, Firestore ID: ${userDoc.id}, Firebase Auth UID: ${firebaseAuthUid}`);
    
    // A Firebase Auth UID-val frissítjük a dokumentumot
    const targetDoc = db.collection('users').doc(firebaseAuthUid);
    
    // Először frissítjük a fingerprint-et
    await targetDoc.set({
      authorizedDeviceFingerprint: newFingerprint,
      deviceChangeDate: admin.firestore.FieldValue.serverTimestamp(),
      deviceChange: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    
    console.log(`Device changed for user ${firebaseAuthUid}, new fingerprint: ${newFingerprint}`);
    
    // Majd invalidáljuk a tokeneket - Firebase Auth user ID-t használunk
    try {
      // A Firestore user dokumentumban keressük a Firebase Auth UID-t
      const userData = userDoc.data();
      const firebaseAuthUid = userData.firebaseAuthUid || userDoc.id; // Fallback a Firestore ID-re
      
      console.log(`Attempting to revoke tokens for Firebase Auth UID: ${firebaseAuthUid}`);
      await admin.auth().revokeRefreshTokens(firebaseAuthUid);
      console.log(`Refresh tokens revoked for user ${firebaseAuthUid}`);
    } catch (revokeError) {
      console.error('Failed to revoke refresh tokens:', revokeError);
      // Folytatjuk, még ha a token invalidálás sikertelen is
    }
    
    return { ok: true };
  } catch (error) {
    console.error('Error in verifyAndChangeDevice:', error);
    throw error;
  }
});

// ============================================================================
// WEBES FIZETÉSI FUNKCIÓK - OTP SIMPLEPAY v2 INTEGRÁCIÓ
// ============================================================================

/**
 * Webes fizetés indítása SimplePay v2 API-val
 */
exports.initiateWebPayment = onCall(async (request) => {
  try {
    const { planId, userId } = request.data || {};
    
    if (!planId || !userId) {
      throw new Error('invalid-argument: planId és userId szükséges');
    }
    
    // Plan validálás
    const plan = PAYMENT_PLANS[planId];
    if (!plan) {
      throw new Error('invalid-argument: Érvénytelen csomag');
    }
    
    // Konfiguráció ellenőrzése
    if (!SIMPLEPAY_CONFIG.merchantId || !SIMPLEPAY_CONFIG.secretKey) {
      throw new Error('internal: SimplePay konfiguráció hiányzik');
    }
    
    // Felhasználó adatok lekérése
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new Error('not-found: Felhasználó nem található');
    }
    
    const userData = userDoc.data();
    const email = userData.email;
    const name = userData.firstName && userData.lastName 
      ? `${userData.firstName} ${userData.lastName}`.trim()
      : userData.displayName;
    
    if (!email) {
      throw new Error('invalid-argument: Email cím szükséges');
    }
    
    // Egyedi rendelés azonosító generálása (userId-t tartalmazza)
    const orderRef = `WEB_${userId}_${Date.now()}_${Math.random().toString(36).substr(2, 8)}`;
    
    // SimplePay v2 API kérés összeállítása
    const simplePayRequest = {
      merchant: SIMPLEPAY_CONFIG.merchantId,
      orderRef: orderRef,
      customerEmail: email,
      customerName: name || undefined,
      language: 'HU',
      currency: 'HUF',
      total: plan.price,
      items: [{
        ref: planId,
        title: plan.name,
        description: plan.description,
        amount: plan.price,
        price: plan.price,
        quantity: 1,
      }],
      methods: ['CARD'],
      url: `${process.env.NEXTAUTH_URL || 'https://lomedu-user-web.web.app'}/api/webhook/simplepay`,
      timeout: new Date(Date.now() + 30 * 60 * 1000).toISOString(), // 30 perc
      invoice: '1',
      redirectUrl: `${process.env.NEXTAUTH_URL || 'https://lomedu-user-web.web.app'}/subscription?success=true`,
    };
    
    // SimplePay API hívás
    const response = await fetch(`${SIMPLEPAY_CONFIG.baseUrl}start`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SIMPLEPAY_CONFIG.secretKey}`,
        'User-Agent': 'Lomedu-Cloud-Functions/1.0',
      },
      body: JSON.stringify(simplePayRequest),
    });
    
    if (!response.ok) {
      const errorData = await response.text();
      console.error('SimplePay API error:', errorData);
      throw new Error('internal: Fizetési folyamat indítása sikertelen');
    }
    
    const paymentData = await response.json();
    
    // Fizetési rekord mentése
    await db.collection('web_payments').doc(orderRef).set({
      userId: userId,
      planId: planId,
      orderRef: orderRef,
      amount: plan.price,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return {
      success: true,
      paymentUrl: paymentData.paymentUrl,
      orderRef: orderRef,
      amount: plan.price,
    };
    
  } catch (error) {
    console.error('initiateWebPayment error:', error);
    throw error;
  }
});

/**
 * SimplePay webhook feldolgozás
 */
exports.processWebPaymentWebhook = onCall(async (request) => {
  try {
    const webhookData = request.data || {};
    
    // Webhook adatok validálása
    const { orderRef, transactionId, orderId, status, total, items } = webhookData;
    
    if (!orderRef || !transactionId || !status) {
      throw new Error('invalid-argument: Hiányzó webhook adatok');
    }
    
    // Csak sikeres fizetéseket dolgozunk fel
    if (status !== 'SUCCESS') {
      console.log('Payment not successful, ignoring webhook:', status);
      return { success: true };
    }
    
    // Felhasználó azonosítása az orderRef-ből
    // Formátum: WEB_userId_timestamp_random
    const orderRefParts = orderRef.split('_');
    if (orderRefParts.length < 3 || orderRefParts[0] !== 'WEB') {
      throw new Error('invalid-argument: Érvénytelen orderRef formátum');
    }
    
    const userId = orderRefParts[1];
    
    // Fizetési rekord frissítése
    const paymentRef = db.collection('web_payments').doc(orderRef);
    const paymentDoc = await paymentRef.get();
    
    if (!paymentDoc.exists) {
      throw new Error('not-found: Fizetési rekord nem található');
    }
    
    const paymentData = paymentDoc.data();
    const planId = paymentData.planId;
    const plan = PAYMENT_PLANS[planId];
    
    if (!plan) {
      throw new Error('invalid-argument: Érvénytelen csomag');
    }
    
    // Előfizetés aktiválása
    const now = new Date();
    const expiryDate = new Date(now.getTime() + (plan.subscriptionDays * 24 * 60 * 60 * 1000));
    
    const subscriptionData = {
      // Kompatibilitási mezők (a mobilalkalmazás ezeket használja)
      isSubscriptionActive: true,
      subscriptionStatus: 'premium',
      subscriptionEndDate: admin.firestore.Timestamp.fromDate(expiryDate),
      
      // Részletes adatok
      subscription: {
        status: 'ACTIVE',
        productId: planId,
        purchaseToken: transactionId,
        orderId: orderId,
        endTime: expiryDate.toISOString(),
        lastUpdateTime: now.toISOString(),
        source: 'otp_simplepay',
      },
      
      // Meta adatok
      lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    // Felhasználói dokumentum frissítése
    await db.collection('users').doc(userId).set(subscriptionData, { merge: true });
    
    // Fizetési rekord frissítése
    await paymentRef.update({
      status: 'completed',
      transactionId: transactionId,
      orderId: orderId,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`Successfully processed web payment for user ${userId}, orderRef: ${orderRef}`);
    
    return { success: true };
    
  } catch (error) {
    console.error('processWebPaymentWebhook error:', error);
    throw error;
  }
});

/**
 * HTTP webhook endpoint SimplePay számára
 */
exports.simplepayWebhook = onRequest(async (req, res) => {
  try {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, x-simplepay-signature');
    
    if (req.method === 'OPTIONS') {
      res.status(200).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }
    
    const body = req.body;
    const signature = req.headers['x-simplepay-signature'];
    
    if (!signature) {
      console.error('Missing signature in webhook request');
      res.status(400).send('Missing signature');
      return;
    }
    
    // Aláírás ellenőrzése
    if (!SIMPLEPAY_CONFIG.secretKey) {
      console.error('SimplePay secret key not configured');
      res.status(500).send('Configuration error');
      return;
    }
    
    const expectedSignature = crypto
      .createHmac('sha256', SIMPLEPAY_CONFIG.secretKey)
      .update(JSON.stringify(body))
      .digest('hex');
    
    if (!crypto.timingSafeEqual(
      Buffer.from(signature, 'hex'),
      Buffer.from(expectedSignature, 'hex')
    )) {
      console.error('Invalid signature in webhook request');
      res.status(401).send('Invalid signature');
      return;
    }
    
    console.log('SimplePay webhook received:', body);
    
    // Csak sikeres fizetéseket dolgozunk fel
    if (body.status !== 'SUCCESS') {
      console.log('Payment not successful, ignoring webhook');
      res.status(200).send('OK');
      return;
    }
    
    const { orderRef, transactionId, orderId, total, items } = body;
    
    // Felhasználó azonosítása az orderRef-ből
    const orderRefParts = orderRef.split('_');
    if (orderRefParts.length < 3 || orderRefParts[0] !== 'WEB') {
      console.error('Invalid orderRef format:', orderRef);
      res.status(400).send('Invalid order reference');
      return;
    }
    
    const userId = orderRefParts[1];
    
    // Fizetési rekord lekérése
    const paymentRef = db.collection('web_payments').doc(orderRef);
    const paymentDoc = await paymentRef.get();
    
    if (!paymentDoc.exists) {
      console.error('Payment record not found:', orderRef);
      res.status(404).send('Payment record not found');
      return;
    }
    
    const paymentData = paymentDoc.data();
    const planId = paymentData.planId;
    const plan = PAYMENT_PLANS[planId];
    
    if (!plan) {
      console.error('Invalid plan:', planId);
      res.status(400).send('Invalid plan');
      return;
    }
    
    // Előfizetés aktiválása
    const now = new Date();
    const expiryDate = new Date(now.getTime() + (plan.subscriptionDays * 24 * 60 * 60 * 1000));
    
    const subscriptionData = {
      isSubscriptionActive: true,
      subscriptionStatus: 'premium',
      subscriptionEndDate: admin.firestore.Timestamp.fromDate(expiryDate),
      subscription: {
        status: 'ACTIVE',
        productId: planId,
        purchaseToken: transactionId,
        orderId: orderId,
        endTime: expiryDate.toISOString(),
        lastUpdateTime: now.toISOString(),
        source: 'otp_simplepay',
      },
      lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    // Felhasználói dokumentum frissítése
    await db.collection('users').doc(userId).set(subscriptionData, { merge: true });
    
    // Fizetési rekord frissítése
    await paymentRef.update({
      status: 'completed',
      transactionId: transactionId,
      orderId: orderId,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`Successfully processed web payment for user ${userId}, orderRef: ${orderRef}`);
    
    res.status(200).send('OK');
    
  } catch (error) {
    console.error('SimplePay webhook error:', error);
    res.status(500).send('Internal server error');
  }
});

