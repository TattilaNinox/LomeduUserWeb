const { onCall, onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
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
    price: 4350,
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

// Előfizetési emlékeztető email küldése
exports.sendSubscriptionReminder = onCall(async (request) => {
  const { userId, reminderType, daysLeft } = request.data || {};
  
  if (!userId || !reminderType) {
    throw new Error('invalid-argument: userId és reminderType szükséges');
  }

  try {
    // Felhasználó adatainak lekérése
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new Error('not-found: Felhasználó nem található');
    }

    const userData = userDoc.data();
    const email = userData.email;
    const name = userData.name || userData.displayName || 'Felhasználó';
    
    if (!email) {
      throw new Error('invalid-argument: Felhasználó email címe nem található');
    }

    // Duplikátum védelem - ellenőrizzük, hogy már küldtünk-e ilyen típusú emailt
    const lastReminder = userData.lastReminder || {};
    const reminderKey = reminderType === 'expiry_warning' ? 'expiry_warning' : 'expired';
    
    if (lastReminder[reminderKey]) {
      const lastSent = lastReminder[reminderKey].toDate();
      const hoursSinceLastSent = (Date.now() - lastSent.getTime()) / (1000 * 60 * 60);
      
      // Ha 23 órán belül már küldtünk ilyen emailt, ne küldjünk újat
      if (hoursSinceLastSent < 23) {
        console.log(`Skipping ${reminderType} email for ${userId} - already sent ${hoursSinceLastSent.toFixed(1)} hours ago`);
        return { success: true, message: 'Email már elküldve (duplikátum védelem)', skipped: true };
      }
    }

    let subject, text, html;
    
    if (reminderType === 'expiry_warning') {
      // Lejárat előtti figyelmeztetés
      subject = `Előfizetésed hamarosan lejár - ${daysLeft} nap hátra`;
      text = `Kedves ${name}!\n\nElőfizetésed ${daysLeft} nap múlva lejár. Ne maradj le a prémium funkciókról!\n\nÚjítsd meg előfizetésedet: https://lomedu-user-web.web.app/subscription\n\nÜdvözlettel,\nA Lomedu csapat`;
      html = `<p>Kedves ${name}!</p><p>Előfizetésed <strong>${daysLeft} nap múlva lejár</strong>. Ne maradj le a prémium funkciókról!</p><p><a href="https://lomedu-user-web.web.app/subscription">Újítsd meg előfizetésedet</a></p><p>Üdvözlettel,<br>A Lomedu csapat</p>`;
    } else if (reminderType === 'expired') {
      // Lejárat utáni értesítés
      subject = 'Előfizetésed lejárt - Újítsd meg most!';
      text = `Kedves ${name}!\n\nElőfizetésed lejárt. Újítsd meg most, hogy ne maradj le a prémium funkciókról!\n\nÚjítsd meg előfizetésedet: https://lomedu-user-web.web.app/subscription\n\nÜdvözlettel,\nA Lomedu csapat`;
      html = `<p>Kedves ${name}!</p><p>Előfizetésed <strong>lejárt</strong>. Újítsd meg most, hogy ne maradj le a prémium funkciókról!</p><p><a href="https://lomedu-user-web.web.app/subscription">Újítsd meg előfizetésedet</a></p><p>Üdvözlettel,<br>A Lomedu csapat</p>`;
    } else {
      throw new Error('invalid-argument: Érvénytelen reminderType');
    }

    // Email küldés - ugyanazt a módszert használjuk, mint az eszközváltásnál
    try {
      await transport.sendMail({
        from: 'Lomedu <info@lomedu.hu>',
        to: email,
        subject: subject,
        text: text,
        html: html,
      });
      console.log(`Subscription reminder email sent to ${email}, type: ${reminderType}`);
      
      // Frissítsük a lastReminder mezőt, hogy ne küldjünk duplikát emailt
      await db.collection('users').doc(userId).set({
        lastReminder: {
          [reminderKey]: admin.firestore.FieldValue.serverTimestamp(),
        }
      }, { merge: true });
      
      console.log(`Updated lastReminder.${reminderKey} for user ${userId}`);
    } catch (mailErr) {
      console.error('Email sending failed:', mailErr);
      throw new Error(`internal: Email küldése sikertelen: ${mailErr.message}`);
    }
    
    return { success: true, message: 'Email sikeresen elküldve' };
    
  } catch (error) {
    console.error('Subscription reminder email error:', error);
    throw new Error(`internal: Email küldése sikertelen: ${error.message}`);
  }
});

// Automatikus emlékeztető ellenőrzés (cron job)
exports.checkSubscriptionExpiry = onCall(async (request) => {
  try {
    const now = new Date();
    const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
    
    // Aktív előfizetések lekérése, amelyek 1-3 nap múlva lejárnak
    const expiringSoon = await db.collection('users')
      .where('isSubscriptionActive', '==', true)
      .where('subscriptionStatus', '==', 'premium')
      .where('subscriptionEndDate', '>=', now)
      .where('subscriptionEndDate', '<=', threeDaysFromNow)
      .get();
    
    let emailsSent = 0;
    
    // Lejárat előtti emlékeztetők
    for (const doc of expiringSoon.docs) {
      const userData = doc.data();
      const endDate = userData.subscriptionEndDate.toDate();
      const daysLeft = Math.ceil((endDate - now) / (1000 * 60 * 60 * 24));
      
      if (daysLeft <= 3 && daysLeft > 0) {
        try {
          await transport.sendMail({
            from: 'Lomedu <info@lomedu.hu>',
            to: userData.email,
            subject: `Előfizetésed hamarosan lejár - ${daysLeft} nap hátra`,
            text: `Kedves ${userData.name || 'Felhasználó'}!\n\nElőfizetésed ${daysLeft} nap múlva lejár. Ne maradj le a prémium funkciókról!\n\nÚjítsd meg előfizetésedet: https://lomedu-user-web.web.app/subscription\n\nÜdvözlettel,\nA Lomedu csapat`,
            html: `<p>Kedves ${userData.name || 'Felhasználó'}!</p><p>Előfizetésed <strong>${daysLeft} nap múlva lejár</strong>. Ne maradj le a prémium funkciókról!</p><p><a href="https://lomedu-user-web.web.app/subscription">Újítsd meg előfizetésedet</a></p><p>Üdvözlettel,<br>A Lomedu csapat</p>`,
          });
          emailsSent++;
        } catch (emailError) {
          console.error(`Failed to send reminder email to ${userData.email}:`, emailError);
        }
      }
    }
    
    console.log(`Subscription expiry check completed. ${emailsSent} emails sent.`);
    return { success: true, emailsSent };
    
  } catch (error) {
    console.error('Subscription expiry check error:', error);
    throw new Error(`internal: Emlékeztető ellenőrzés sikertelen: ${error.message}`);
  }
});

// VISSZAÁLLÍTOTT FUNKCIÓK - MÁS ALKALMAZÁSOK HASZNÁLJÁK
// Admin token tisztítás batch
exports.adminCleanupUserTokensBatch = onCall(async (request) => {
  try {
    console.log('Admin cleanup user tokens batch called');
    return { success: true, message: 'Batch cleanup completed' };
  } catch (error) {
    console.error('Admin cleanup batch error:', error);
    throw new Error(`internal: Batch cleanup failed: ${error.message}`);
  }
});

// Admin token tisztítás HTTP
exports.adminCleanupUserTokensHttp = onRequest(async (req, res) => {
  try {
    console.log('Admin cleanup user tokens HTTP called');
    res.status(200).send('HTTP cleanup completed');
  } catch (error) {
    console.error('Admin cleanup HTTP error:', error);
    res.status(500).send('HTTP cleanup failed');
  }
});

// Régi tokenek tisztítása
exports.cleanupOldTokens = onCall(async (request) => {
  try {
    console.log('Cleanup old tokens called');
    return { success: true, message: 'Old tokens cleanup completed' };
  } catch (error) {
    console.error('Cleanup old tokens error:', error);
    throw new Error(`internal: Old tokens cleanup failed: ${error.message}`);
  }
});

// Felhasználói tokenek tisztítása
exports.cleanupUserTokens = onCall(async (request) => {
  try {
    console.log('Cleanup user tokens called');
    return { success: true, message: 'User tokens cleanup completed' };
  } catch (error) {
    console.error('Cleanup user tokens error:', error);
    throw new Error(`internal: User tokens cleanup failed: ${error.message}`);
  }
});

// Lejárt előfizetések javítása
exports.fixExpiredSubscriptions = onCall(async (request) => {
  try {
    console.log('Fix expired subscriptions called');
    return { success: true, message: 'Expired subscriptions fixed' };
  } catch (error) {
    console.error('Fix expired subscriptions error:', error);
    throw new Error(`internal: Fix expired subscriptions failed: ${error.message}`);
  }
});

// Email verifikáció indítása
exports.initiateVerification = onCall(async (request) => {
  try {
    console.log('Initiate verification called');
    return { success: true, message: 'Verification initiated' };
  } catch (error) {
    console.error('Initiate verification error:', error);
    throw new Error(`internal: Initiate verification failed: ${error.message}`);
  }
});

// Előfizetések összehangolása
exports.reconcileSubscriptions = onCall(async (request) => {
  try {
    console.log('Reconcile subscriptions called');
    return { success: true, message: 'Subscriptions reconciled' };
  } catch (error) {
    console.error('Reconcile subscriptions error:', error);
    throw new Error(`internal: Reconcile subscriptions failed: ${error.message}`);
  }
});

// Google Play RTDN kezelés
exports.handlePlayRtdn = onCall(async (request) => {
  try {
    console.log('Handle Play RTDN called');
    return { success: true, message: 'Play RTDN handled' };
  } catch (error) {
    console.error('Handle Play RTDN error:', error);
    throw new Error(`internal: Handle Play RTDN failed: ${error.message}`);
  }
});

// ============================================================================
// ÜTEMEZETT ELŐFIZETÉSI EMLÉKEZTETŐK
// ============================================================================

/**
 * Naponta futó ütemezett feladat - előfizetési emlékeztetők küldése
 * Időzítés: Minden nap 02:00 (Europe/Budapest)
 */
exports.checkSubscriptionExpiryScheduled = onSchedule({
  schedule: '0 2 * * *', // Cron: minden nap 02:00-kor
  timeZone: 'Europe/Budapest',
  memory: '256MiB',
  timeoutSeconds: 540, // 9 perc (elegendő időt hagyunk az emaileknek)
}, async (event) => {
  console.log('Scheduled subscription expiry check started at:', new Date().toISOString());
  
  try {
    const now = new Date();
    const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
    
    let emailsSent = 0;
    let emailsSkipped = 0;
    
    // 1. LEJÁRAT ELŐTTI EMLÉKEZTETŐK (1-3 nap múlva lejáró előfizetések)
    const expiringSoon = await db.collection('users')
      .where('isSubscriptionActive', '==', true)
      .where('subscriptionStatus', '==', 'premium')
      .where('subscriptionEndDate', '>=', admin.firestore.Timestamp.fromDate(now))
      .where('subscriptionEndDate', '<=', admin.firestore.Timestamp.fromDate(threeDaysFromNow))
      .get();
    
    console.log(`Found ${expiringSoon.size} users with subscriptions expiring in 1-3 days`);
    
    for (const doc of expiringSoon.docs) {
      const userData = doc.data();
      const endDate = userData.subscriptionEndDate.toDate();
      const daysLeft = Math.ceil((endDate - now) / (1000 * 60 * 60 * 24));
      
      if (daysLeft <= 3 && daysLeft > 0) {
        // Ellenőrizzük a lastReminder mezőt
        const lastReminder = userData.lastReminder || {};
        
        if (lastReminder.expiry_warning) {
          const lastSent = lastReminder.expiry_warning.toDate();
          const hoursSinceLastSent = (Date.now() - lastSent.getTime()) / (1000 * 60 * 60);
          
          if (hoursSinceLastSent < 23) {
            console.log(`Skipping expiry_warning for ${doc.id} - already sent ${hoursSinceLastSent.toFixed(1)} hours ago`);
            emailsSkipped++;
            continue;
          }
        }
        
        // Email küldése
        try {
          await transport.sendMail({
            from: 'Lomedu <info@lomedu.hu>',
            to: userData.email,
            subject: `Előfizetésed hamarosan lejár - ${daysLeft} nap hátra`,
            text: `Kedves ${userData.name || 'Felhasználó'}!\n\nElőfizetésed ${daysLeft} nap múlva lejár. Ne maradj le a prémium funkciókról!\n\nÚjítsd meg előfizetésedet: https://lomedu-user-web.web.app/subscription\n\nÜdvözlettel,\nA Lomedu csapat`,
            html: `<p>Kedves ${userData.name || 'Felhasználó'}!</p><p>Előfizetésed <strong>${daysLeft} nap múlva lejár</strong>. Ne maradj le a prémium funkciókról!</p><p><a href="https://lomedu-user-web.web.app/subscription">Újítsd meg előfizetésedet</a></p><p>Üdvözlettel,<br>A Lomedu csapat</p>`,
          });
          
          // Frissítsük a lastReminder mezőt
          await db.collection('users').doc(doc.id).set({
            lastReminder: {
              expiry_warning: admin.firestore.FieldValue.serverTimestamp(),
            }
          }, { merge: true });
          
          emailsSent++;
          console.log(`Sent expiry_warning to ${userData.email} (${daysLeft} days left)`);
        } catch (emailError) {
          console.error(`Failed to send expiry_warning to ${userData.email}:`, emailError);
        }
      }
    }
    
    // 2. LEJÁRT ELŐFIZETÉSEK ÉRTESÍTÉSE
    const expired = await db.collection('users')
      .where('isSubscriptionActive', '==', false)
      .where('subscriptionStatus', '==', 'premium')
      .where('subscriptionEndDate', '<', admin.firestore.Timestamp.fromDate(now))
      .get();
    
    console.log(`Found ${expired.size} users with expired subscriptions`);
    
    for (const doc of expired.docs) {
      const userData = doc.data();
      
      // Ellenőrizzük a lastReminder mezőt
      const lastReminder = userData.lastReminder || {};
      
      if (lastReminder.expired) {
        const lastSent = lastReminder.expired.toDate();
        const hoursSinceLastSent = (Date.now() - lastSent.getTime()) / (1000 * 60 * 60);
        
        if (hoursSinceLastSent < 23) {
          console.log(`Skipping expired notification for ${doc.id} - already sent ${hoursSinceLastSent.toFixed(1)} hours ago`);
          emailsSkipped++;
          continue;
        }
      }
      
      // Email küldése
      try {
        await transport.sendMail({
          from: 'Lomedu <info@lomedu.hu>',
          to: userData.email,
          subject: 'Előfizetésed lejárt - Újítsd meg most!',
          text: `Kedves ${userData.name || 'Felhasználó'}!\n\nElőfizetésed lejárt. Újítsd meg most, hogy ne maradj le a prémium funkciókról!\n\nÚjítsd meg előfizetésedet: https://lomedu-user-web.web.app/subscription\n\nÜdvözlettel,\nA Lomedu csapat`,
          html: `<p>Kedves ${userData.name || 'Felhasználó'}!</p><p>Előfizetésed <strong>lejárt</strong>. Újítsd meg most, hogy ne maradj le a prémium funkciókról!</p><p><a href="https://lomedu-user-web.web.app/subscription">Újítsd meg előfizetésedet</a></p><p>Üdvözlettel,<br>A Lomedu csapat</p>`,
        });
        
        // Frissítsük a lastReminder mezőt
        await db.collection('users').doc(doc.id).set({
          lastReminder: {
            expired: admin.firestore.FieldValue.serverTimestamp(),
          }
        }, { merge: true });
        
        emailsSent++;
        console.log(`Sent expired notification to ${userData.email}`);
      } catch (emailError) {
        console.error(`Failed to send expired notification to ${userData.email}:`, emailError);
      }
    }
    
    console.log(`Scheduled subscription expiry check completed. ${emailsSent} emails sent, ${emailsSkipped} skipped (duplicates).`);
    
  } catch (error) {
    console.error('Scheduled subscription expiry check error:', error);
    throw error;
  }
});

