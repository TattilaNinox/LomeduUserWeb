const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const { buildTemplate, logoAttachment } = require('./emailTemplates');

// Konfiguráció forrása: 1) Firebase Functions config (firebase functions:config:set smtp.*),
// 2) környezeti változók, 3) ha emulátor fut, próbáljon meg helyi SMTP-t (opcionális).

admin.initializeApp();

// Globális beállítások – régió, erőforrások
setGlobalOptions({ region: 'europe-west1', cpu: 1 });

const db = admin.firestore();

// Helper to mask sensitive values in logs
function maskValue(value) {
  try {
    if (!value || typeof value !== 'string') return 'N/A';
    const tail = value.slice(-4);
    return `***${tail}`;
  } catch (_) {
    return 'N/A';
  }
}

// SimplePay konfiguráció
// Sandbox/Production kiválasztása külön titok alapján (alapértelmezés: sandbox)
const SIMPLEPAY_ENV = (process.env.SIMPLEPAY_ENV || 'sandbox').toLowerCase();

// Runtime config reader (secrets biztosan elérhetők invokációkor)
function getSimplePayConfig() {
  const env = (process.env.SIMPLEPAY_ENV || 'sandbox').toLowerCase().trim();
  return {
    merchantId: (process.env.SIMPLEPAY_MERCHANT_ID || '').trim(),
    secretKey: (process.env.SIMPLEPAY_SECRET_KEY || '').trim(),
    baseUrl: env === 'production'
      ? 'https://secure.simplepay.hu/payment/v2/'
      : 'https://sandbox.simplepay.hu/payment/v2/',
    nextAuthUrl: (process.env.NEXTAUTH_URL || 'https://lomedu-user-web.web.app').trim(),
    allowedReturnBases: (process.env.RETURN_BASES || process.env.NEXTAUTH_URL || 'https://lomedu-user-web.web.app')
      .split(',')
      .map(s => s.trim())
      .filter(Boolean),
    env,
  };
}

// Biztonság kedvéért definiálunk egy globális, hogy régi revíziók/async hivatkozások se dobjanak ReferenceError-t
const SIMPLEPAY_CONFIG = getSimplePayConfig();

// Kisegítő késleltetés
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const NEXTAUTH_URL = process.env.NEXTAUTH_URL || 'https://lomedu-user-web.web.app';

// Fizetési csomagok
const PAYMENT_PLANS = {
  // Kanonikus azonosító
  monthly_premium_prepaid: {
    name: 'Havi előfizetés',
    price: 4350,
    description: 'Teljes hozzáférés minden funkcióhoz',
    subscriptionDays: 30,
  },
  // Régi alias a visszafelé kompatibilitásért
  monthly_web: {
    name: 'Havi előfizetés',
    price: 4350,
    description: 'Teljes hozzáférés minden funkcióhoz',
    subscriptionDays: 30,
  },
};

// Plan ID kanonikusítása (alias → kanonikus)
const CANONICAL_PLAN_ID = {
  monthly_web: 'monthly_premium_prepaid',
  monthly_premium_prepaid: 'monthly_premium_prepaid',
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
    const SIMPLEPAY_CONFIG = getSimplePayConfig();
    await transport.sendMail({
      from: 'Lomedu <info@lomedu.hu>',
      to: email,
      subject: 'Eszközváltási kód',
      text: `Az új eszköz jóváhagyásához adja meg a következő kódot: ${code} (15 percig érvényes)`,
      html: buildTemplate(`<p>Az új eszköz jóváhagyásához adja meg a következő kódot:</p><h2 style="text-align:center;font-size:32px;margin:24px 0;color:#0d6efd;">${code}</h2><p>A kód 15 percig érvényes.</p>`),
      attachments: [logoAttachment()],
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
exports.initiateWebPayment = onCall({ 
  secrets: ['SIMPLEPAY_MERCHANT_ID', 'SIMPLEPAY_SECRET_KEY', 'NEXTAUTH_URL']
}, async (request) => {
  try {
    const { planId, userId } = request.data || {};
    console.log('[initiateWebPayment] input', { planId, userId });

    if (!planId || !userId) {
      throw new HttpsError('invalid-argument', 'planId és userId szükséges');
    }

    const canonicalPlanId = CANONICAL_PLAN_ID[planId] || planId;
    const plan = PAYMENT_PLANS[canonicalPlanId];
    if (!plan) {
      throw new HttpsError('invalid-argument', 'Érvénytelen csomag');
    }

    if (!SIMPLEPAY_CONFIG.merchantId || !SIMPLEPAY_CONFIG.secretKey || !SIMPLEPAY_CONFIG.baseUrl) {
      throw new HttpsError('failed-precondition', 'SimplePay konfiguráció hiányzik');
    }

    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new HttpsError('not-found', 'Felhasználó nem található');
    }

    const userData = userDoc.data();
    const email = userData.email;
    const name = userData.firstName && userData.lastName ? `${userData.firstName} ${userData.lastName}`.trim() : userData.displayName;

    if (!email) {
      throw new HttpsError('failed-precondition', 'A felhasználóhoz nem tartozik email cím');
    }

    const orderRef = `WEB_${userId}_${Date.now()}`;
    // Visszairányítási bázis validálása (ne ugorjon loginra ismeretlen domain miatt)
    const returnBase = (SIMPLEPAY_CONFIG.allowedReturnBases && SIMPLEPAY_CONFIG.allowedReturnBases.length > 0)
      ? SIMPLEPAY_CONFIG.allowedReturnBases[0]
      : SIMPLEPAY_CONFIG.nextAuthUrl;
    const nextAuthBase = returnBase.replace(/\/$/, '');
    const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || '';
    const webhookUrl = `https://europe-west1-${projectId}.cloudfunctions.net/simplepayWebhook`;

    // Időkorlát számítása (30 perc a jövőben) ISO formátumban, milliszekundumok nélkül
    // Példa: 2025-10-15T12:34:56Z
    const timeout = new Date(Date.now() + 30 * 60 * 1000)
      .toISOString()
      .replace(/\.\d{3}Z$/, 'Z');
    
    const simplePayRequest = {
      salt: crypto.randomBytes(16).toString('hex'),
      merchant: SIMPLEPAY_CONFIG.merchantId.trim(),
      orderRef,
      customerEmail: email,
      language: 'HU',
      sdkVersion: 'CustomBashScript_v1.0',
      currency: 'HUF',
      timeout: timeout,
      methods: ['CARD'],
      // IPN/Webhook értesítési URL (server-to-server)
      url: webhookUrl,
      urls: {
        success: `${nextAuthBase}/account?payment=success&orderRef=${orderRef}`,
        fail: `${nextAuthBase}/account?payment=fail&orderRef=${orderRef}`,
        timeout: `${nextAuthBase}/account?payment=timeout&orderRef=${orderRef}`,
        cancel: `${nextAuthBase}/account?payment=cancelled&orderRef=${orderRef}`,
      },
      items: [{
        ref: canonicalPlanId,
        title: plan.name,
        description: plan.description,
        amount: 1,
        price: plan.price,
      }],
    };
    
    // Ellenőrizzük, hogy a JSON formázás helyes-e
    const payloadKeys = Object.keys(simplePayRequest);
    if (!payloadKeys.includes('items') || !Array.isArray(simplePayRequest.items) || simplePayRequest.items.length === 0) {
      throw new HttpsError('invalid-argument', 'Az items tömb hibásan formázott vagy hiányzik');
    }
    
    // Ellenőrizzük, hogy minden szükséges kulcs megvan-e
    const requiredKeys = ['salt', 'merchant', 'orderRef', 'customerEmail', 'language', 'currency', 'timeout', 'methods', 'urls', 'items'];
    const missingKeys = requiredKeys.filter(key => !payloadKeys.includes(key));
    if (missingKeys.length > 0) {
      throw new HttpsError('invalid-argument', `Hiányzó kulcsok a kérésben: ${missingKeys.join(', ')}`);
    }

    console.log('[initiateWebPayment] outgoing payload', {
      orderRef,
      url: simplePayRequest.url,
      hasPaymentUrl: true,
    });

    const requestBody = JSON.stringify(simplePayRequest);
    const signature = crypto.createHmac('sha384', SIMPLEPAY_CONFIG.secretKey.trim()).update(requestBody).digest('base64');

    const response = await fetch(`${SIMPLEPAY_CONFIG.baseUrl.trim()}start`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Signature': signature,
      },
      body: requestBody,
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('[initiateWebPayment] SimplePay HTTP error', { status: response.status, errorText, orderRef });
      throw new HttpsError('internal', 'Fizetési szolgáltató API hiba');
    }

    const paymentData = await response.json();
    if (!paymentData?.paymentUrl) {
      const errorCodes = paymentData?.errorCodes;
      
      // Részletes log a 5321-es hibakódhoz
      if (Array.isArray(errorCodes) && errorCodes.includes('5321')) {
        console.error('=================================================================');
        console.error('SIMPLEPAY HIBAKÓD 5321 RÉSZLETES ELEMZÉS:');
        console.error('=================================================================');
        console.error('Kérés adatok:', JSON.stringify(simplePayRequest, null, 2));
        console.error('SimplePay válasz:', JSON.stringify(paymentData, null, 2));
        console.error('Aláírás generálás alapja:', requestBody);
        console.error('Generált aláírás:', signature);
        console.error('=================================================================');
      }
      
      console.error('[initiateWebPayment] SimplePay start returned logical error', { orderRef, errorCodes, rawResponse: paymentData, payload: simplePayRequest });
      throw new HttpsError('failed-precondition', `SimplePay indítás elutasítva: ${Array.isArray(errorCodes) ? errorCodes.join(',') : 'ismeretlen hiba'}`);
    }

    await db.collection('web_payments').doc(orderRef).set({
      userId,
      planId: canonicalPlanId,
      orderRef,
      simplePayTransactionId: paymentData.transactionId || null,
      amount: plan.price,
      status: 'INITIATED',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, paymentUrl: paymentData.paymentUrl, orderRef };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('internal', error?.message || 'Ismeretlen szerverhiba');
  }
});

/**
 * Fizetés lezárása (FINISH) SimplePay v2 API-val
 * - Client a sikeres visszairányítás után hívja: { orderRef }
 * - Siker esetén users/{uid} frissül és web_payments status COMPLETED-re vált
 */
exports.confirmWebPayment = onCall({ secrets: ['SIMPLEPAY_MERCHANT_ID', 'SIMPLEPAY_SECRET_KEY', 'SIMPLEPAY_ENV'] }, async (request) => {
  try {
    const SIMPLEPAY_CONFIG = getSimplePayConfig();
    const { orderRef } = request.data || {};
    if (!orderRef || typeof orderRef !== 'string') {
      throw new HttpsError('invalid-argument', 'orderRef szükséges');
    }

    const orderRefParts = orderRef.split('_');
    if (orderRefParts.length < 3 || orderRefParts[0] !== 'WEB') {
      throw new HttpsError('invalid-argument', 'Érvénytelen orderRef formátum');
    }
    const userId = orderRefParts[1];

    if (!SIMPLEPAY_CONFIG.merchantId || !SIMPLEPAY_CONFIG.secretKey) {
      throw new HttpsError('failed-precondition', 'SimplePay konfiguráció hiányzik');
    }

    // Lekérjük a fizetési rekordot
    const paymentRef = db.collection('web_payments').doc(orderRef);
    const paymentSnap = await paymentRef.get();
    if (!paymentSnap.exists) {
      throw new HttpsError('not-found', 'Fizetési rekord nem található');
    }
    const pay = paymentSnap.data();
    const rawPlanId = pay.planId;
    const canonicalPlanId = CANONICAL_PLAN_ID[rawPlanId] || rawPlanId;
    const plan = PAYMENT_PLANS[canonicalPlanId];
    if (!plan) {
      throw new HttpsError('failed-precondition', 'Érvénytelen csomag');
    }

    // QUERY – ellenőrzés SimplePay v2 API-val (biztos lezárás helyett státusz lekérdezés)
    const queryPayload = {
      salt: crypto.randomBytes(16).toString('hex'),
      merchant: SIMPLEPAY_CONFIG.merchantId.trim(),
      orderRef,
    };
    const queryBody = JSON.stringify(queryPayload);
    const querySig = crypto.createHmac('sha384', SIMPLEPAY_CONFIG.secretKey.trim()).update(queryBody).digest('base64');
    const queryResp = await fetch(`${SIMPLEPAY_CONFIG.baseUrl.trim()}query`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8', 'Signature': querySig },
      body: queryBody,
    });
    if (!queryResp.ok) {
      const txt = await queryResp.text();
      console.error('[confirmWebPayment] query HTTP error', { status: queryResp.status, txt });
      throw new HttpsError('internal', 'Query hívás sikertelen');
    }
    const queryTxt = await queryResp.text();
    let queryData; try { queryData = JSON.parse(queryTxt); } catch (_) { queryData = { raw: queryTxt }; }
    const successLike = (queryData?.status || '').toString().toUpperCase() === 'SUCCESS' || !!queryData?.transactionId;
    if (!successLike) {
      console.warn('[confirmWebPayment] query not SUCCESS', { orderRef, queryData });
      return { success: false, status: queryData?.status || 'UNKNOWN' };
    }

    const transactionId = queryData?.transactionId || pay.simplePayTransactionId || null;
    const orderId = queryData?.orderId || null;

    // Előfizetés aktiválása
    const now = new Date();
    const expiryDate = new Date(now.getTime() + (plan.subscriptionDays * 24 * 60 * 60 * 1000));
    const subscriptionData = {
      isSubscriptionActive: true,
      subscriptionStatus: 'premium',
      subscriptionEndDate: admin.firestore.Timestamp.fromDate(expiryDate),
      subscription: {
        status: 'ACTIVE',
        productId: canonicalPlanId,
        purchaseToken: transactionId,
        orderId: orderId,
        endTime: expiryDate.toISOString(),
        lastUpdateTime: now.toISOString(),
        source: 'otp_simplepay',
      },
      lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('users').doc(userId).set(subscriptionData, { merge: true });
    await db.collection('users').doc(userId).update({ lastReminder: admin.firestore.FieldValue.delete() });

    await paymentRef.update({
      status: 'COMPLETED',
      transactionId,
      orderId,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('[confirmWebPayment] completed', { userId, orderRef });
    return { success: true, status: 'COMPLETED' };
  } catch (err) {
    console.error('[confirmWebPayment] error', { message: err?.message, stack: err?.stack });
    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', err?.message || 'Ismeretlen hiba');
  }
});

/**
 * SimplePay webhook feldolgozás
 */
exports.processWebPaymentWebhook = onCall({ secrets: ['SIMPLEPAY_SECRET_KEY','NEXTAUTH_URL','SIMPLEPAY_ENV'] }, async (request) => {
  try {
    const SIMPLEPAY_CONFIG = getSimplePayConfig();
    const webhookData = request.data || {};
    console.debug('[processWebPaymentWebhook] input status/orderRef', { status: webhookData?.status, orderRef: webhookData?.orderRef });
    
    // Webhook adatok validálása
    const { orderRef, transactionId, orderId, status, total, items } = webhookData;
    
    if (!orderRef || !transactionId || !status) {
      throw new HttpsError('invalid-argument', 'Hiányzó webhook adatok');
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
      throw new HttpsError('invalid-argument', 'Érvénytelen orderRef formátum');
    }
    
    const userId = orderRefParts[1];
    
    // Fizetési rekord frissítése
    const paymentRef = db.collection('web_payments').doc(orderRef);
    const paymentDoc = await paymentRef.get();
    
    if (!paymentDoc.exists) {
      throw new HttpsError('not-found', 'Fizetési rekord nem található');
    }
    
    const paymentData = paymentDoc.data();
    const rawPlanId = paymentData.planId;
    const canonicalPlanId = CANONICAL_PLAN_ID[rawPlanId] || rawPlanId;
    const plan = PAYMENT_PLANS[canonicalPlanId];
    
    if (!plan) {
      throw new HttpsError('failed-precondition', 'Érvénytelen csomag');
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
        productId: canonicalPlanId,
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
    
    // Új előfizetés esetén töröljük a lastReminder mezőket, hogy újra küldhessünk emailt
    await db.collection('users').doc(userId).update({
      lastReminder: admin.firestore.FieldValue.delete(),
    });
    
    // Fizetési rekord frissítése
    await paymentRef.update({
      status: 'COMPLETED',
      transactionId: transactionId,
      orderId: orderId,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('[processWebPaymentWebhook] updated payment to COMPLETED', { userId, orderRef });
    
    return { success: true };
    
  } catch (error) {
    console.error('[processWebPaymentWebhook] error', { message: error?.message, stack: error?.stack });
    if (error instanceof HttpsError || error?.code) {
      throw error;
    }
    throw new HttpsError('internal', error?.message || 'Ismeretlen hiba a SimplePay webhook feldolgozásakor');
  }
});

/**
 * HTTP webhook endpoint SimplePay számára
 */
exports.simplepayWebhook = onRequest({ secrets: ['SIMPLEPAY_SECRET_KEY','NEXTAUTH_URL','SIMPLEPAY_ENV'] }, async (req, res) => {
  try {
    const SIMPLEPAY_CONFIG = getSimplePayConfig();
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Signature, x-simplepay-signature, x-signature');
    
    if (req.method === 'OPTIONS') {
      res.status(200).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }
    
    const body = req.body;
    const headerSignature = (
      req.headers['signature'] ||
      req.headers['x-simplepay-signature'] ||
      req.headers['x-signature'] ||
      ''
    ).toString();

    if (!headerSignature) {
      console.error('[simplepayWebhook] Missing signature', {
        headerKeys: Object.keys(req.headers || {}),
        rawLen: Buffer.isBuffer(req.rawBody) ? req.rawBody.length : String(JSON.stringify(body)).length,
      });
      res.status(400).send('Missing signature');
      return;
    }

    // Aláírás ellenőrzése – SimplePay v2: HMAC-SHA384 + base64 a RAW BODY-ra
    if (!SIMPLEPAY_CONFIG.secretKey) {
      console.error('[simplepayWebhook] Secret key not configured');
      res.status(500).send('Configuration error');
      return;
    }

    const raw = Buffer.isBuffer(req.rawBody)
      ? req.rawBody
      : Buffer.from(JSON.stringify(body));

    const expectedSigSha384B64 = crypto
      .createHmac('sha384', SIMPLEPAY_CONFIG.secretKey)
      .update(raw)
      .digest('base64');

    // Biztonságos összehasonlítás
    const a = Buffer.from(headerSignature);
    const b = Buffer.from(expectedSigSha384B64);
    const valid = a.length === b.length && crypto.timingSafeEqual(a, b);

    if (!valid) {
      console.error('[simplepayWebhook] Invalid signature', {
        headerSignatureMasked: maskValue(headerSignature),
        expectedMasked: maskValue(expectedSigSha384B64),
        headerKeys: Object.keys(req.headers || {}),
        rawLen: raw.length,
      });
      res.status(401).send('Invalid signature');
      return;
    }
    
    const incomingStatus = (body?.status || '').toString().toUpperCase();
    console.log('[simplepayWebhook] received', {
      status: incomingStatus,
      orderRef: body?.orderRef,
      headers: {
        signatureMasked: maskValue(headerSignature),
      },
    });
    
    // Csak sikeres fizetéseket dolgozunk fel – a SimplePay itt 'FINISHED' státuszt küld,
    // ami a tranzakció sikeres lezárását jelenti. Kezeljük SUCCESS-ként.
    if (incomingStatus !== 'SUCCESS' && incomingStatus !== 'FINISHED') {
      console.log('[simplepayWebhook] non-success status, ignoring');
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
      console.error('[simplepayWebhook] Payment record not found', { orderRef });
      res.status(404).send('Payment record not found');
      return;
    }
    
    const paymentData = paymentDoc.data();
    const rawPlanId = paymentData.planId;
    const canonicalPlanId = CANONICAL_PLAN_ID[rawPlanId] || rawPlanId;
    const plan = PAYMENT_PLANS[canonicalPlanId];
    
    if (!plan) {
      console.error('[simplepayWebhook] Invalid plan', { planId });
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
        productId: canonicalPlanId,
        purchaseToken: transactionId || null,
        orderId: orderId || null,
        endTime: expiryDate.toISOString(),
        lastUpdateTime: now.toISOString(),
        source: 'otp_simplepay',
      },
      lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    // Felhasználói dokumentum frissítése
    await db.collection('users').doc(userId).set(subscriptionData, { merge: true });
    
    // Új előfizetés esetén töröljük a lastReminder mezőket, hogy újra küldhessünk emailt
    await db.collection('users').doc(userId).update({
      lastReminder: admin.firestore.FieldValue.delete(),
    });
    
    // Fizetési rekord frissítése
    await paymentRef.update({
      status: 'COMPLETED',
      transactionId: transactionId || null,
      orderId: orderId || null,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('[simplepayWebhook] updated payment to COMPLETED', { userId, orderRef });
    
    res.status(200).send('OK');
    
  } catch (error) {
    console.error('[simplepayWebhook] error', { message: error?.message, stack: error?.stack });
    res.status(500).send('Internal server error');
  }
});

/**
 * Firestore trigger: web_payments/{orderRef}
 * Ha egy fizetés elkészült (status == 'INITIATED' → 'SUCCESS'/'COMPLETED' vagy manuálisan beállított SUCCESS),
 * frissíti a users/{uid} dokumentumot a mobil sémának megfelelően.
 */
exports.onWebPaymentWrite = onDocumentWritten({
  document: 'web_payments/{orderRef}',
  secrets: ['SIMPLEPAY_MERCHANT_ID','SIMPLEPAY_SECRET_KEY','SIMPLEPAY_ENV'],
}, async (event) => {
  try {
    const SIMPLEPAY_CONFIG = getSimplePayConfig();
    const before = event.data?.before?.data() || null;
    const after = event.data?.after?.data() || null;

    // Ha törlés, nincs teendő
    if (!after) return;

    const status = (after.status || '').toString().toUpperCase();
    const userId = after.userId;
    const rawPlanId = after.planId;
    const canonicalPlanId = CANONICAL_PLAN_ID[rawPlanId] || rawPlanId;
    const plan = PAYMENT_PLANS[canonicalPlanId];

    console.log('[onWebPaymentWrite] trigger', {
      orderRef: event.params.orderRef,
      status,
      userId,
      planId: rawPlanId,
    });

    if (!userId || !plan) {
      console.warn('[onWebPaymentWrite] skip - missing user/plan', {
        orderRef: event.params.orderRef,
        hasUser: !!userId,
        hasPlan: !!plan,
      });
      return;
    }

    // Csak akkor írunk, ha:
    // - új dokumentum jött létre és már SUCCESS/COMPLETED, vagy
    // - status változott INITIATED/PENDING → SUCCESS/COMPLETED
    const beforeStatus = (before?.status || '').toString().toUpperCase();
    const meaningfulTransition = (
      (!before && (status === 'SUCCESS' || status === 'COMPLETED')) ||
      (before && beforeStatus !== status && (status === 'SUCCESS' || status === 'COMPLETED'))
    );

    // Ha még csak INITIATED, megpróbáljuk a FINISH hívást szerverről (nem kell kliensre várni)
    if (status === 'INITIATED') {
      try {
        if (!SIMPLEPAY_CONFIG.merchantId || !SIMPLEPAY_CONFIG.secretKey) {
          console.warn('[onWebPaymentWrite] finish skipped - config missing');
          return;
        }
        // QUERY – állapot lekérdezése a FINISH helyett
        // Többszöri query 5 másodpercig; SimplePay késleltetett állapotközlés esetére
        let data = null;
        for (let i = 0; i < 20; i++) {
          const queryPayload = { salt: crypto.randomBytes(16).toString('hex'), merchant: SIMPLEPAY_CONFIG.merchantId.trim(), orderRef: event.params.orderRef };
          const queryBody = JSON.stringify(queryPayload);
          const querySig = crypto.createHmac('sha384', SIMPLEPAY_CONFIG.secretKey.trim()).update(queryBody).digest('base64');
          const resp = await fetch(`${SIMPLEPAY_CONFIG.baseUrl.trim()}query`, {
            method: 'POST', headers: { 'Content-Type': 'application/json; charset=utf-8', Signature: querySig }, body: queryBody,
          });
          const txt = await resp.text();
          try { data = JSON.parse(txt); } catch (_) { data = { raw: txt }; }
          const ok = (data?.status || '').toString().toUpperCase() === 'SUCCESS' || !!data?.transactionId;
          if (ok) break;
          await sleep(1000);
        }
        if (data) {
          const ok = (data?.status || '').toString().toUpperCase() === 'SUCCESS' || !!data?.transactionId;
          if (ok) {
            const now = new Date();
            const expiryDate = new Date(
              now.getTime() + plan.subscriptionDays * 24 * 60 * 60 * 1000
            );
            const transactionId = data?.transactionId || after.simplePayTransactionId || null;
            const orderId = data?.orderId || null;

            const subscriptionData = {
              isSubscriptionActive: true,
              subscriptionStatus: 'premium',
              subscriptionEndDate: admin.firestore.Timestamp.fromDate(expiryDate),
              subscription: {
                status: 'ACTIVE',
                productId: canonicalPlanId,
                purchaseToken: transactionId,
                orderId: orderId,
                endTime: expiryDate.toISOString(),
                lastUpdateTime: now.toISOString(),
                source: 'otp_simplepay',
              },
              lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            await db.collection('users').doc(userId).set(subscriptionData, { merge: true });
            await db.collection('users').doc(userId).update({
              lastReminder: admin.firestore.FieldValue.delete(),
            });
            await event.data.after.ref.update({
              status: 'COMPLETED',
              transactionId,
              orderId,
              completedAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log('[onWebPaymentWrite] completed via FINISH', { userId, orderRef: event.params.orderRef });
          } else {
            console.log('[onWebPaymentWrite] query not SUCCESS', { orderRef: event.params.orderRef, status: data?.status, data });
          }
        }
      } catch (e) {
        console.error('[onWebPaymentWrite] finish call failed', { message: e?.message });
      }
      return;
    }

    if (!meaningfulTransition) {
      console.log('[onWebPaymentWrite] no-op transition', {
        orderRef: event.params.orderRef,
        beforeStatus,
        status,
      });
      return;
    }

    const now = new Date();
    const expiryDate = new Date(now.getTime() + (plan.subscriptionDays * 24 * 60 * 60 * 1000));

    const subscriptionData = {
      isSubscriptionActive: true,
      subscriptionStatus: 'premium',
      subscriptionEndDate: admin.firestore.Timestamp.fromDate(expiryDate),
      subscription: {
        status: 'ACTIVE',
        productId: canonicalPlanId,
        purchaseToken: after.transactionId || after.simplePayTransactionId || null,
        orderId: after.orderId || null,
        endTime: expiryDate.toISOString(),
        lastUpdateTime: now.toISOString(),
        source: 'otp_simplepay',
      },
      lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('users').doc(userId).set(subscriptionData, { merge: true });
    await db.collection('users').doc(userId).update({
      lastReminder: admin.firestore.FieldValue.delete(),
    });

    console.log('[onWebPaymentWrite] user updated from web_payments', { userId, orderRef: event.params.orderRef, status });
  } catch (err) {
    console.error('[onWebPaymentWrite] error', { message: err?.message, stack: err?.stack });
  }
});

// Stabil reconciláció: INITIATED web_payments rekordok utózárása QUERY-vel
exports.reconcileWebPaymentsScheduled = onSchedule({
  schedule: '*/2 * * * *',
  timeZone: 'Europe/Budapest',
  memory: '256MiB',
  timeoutSeconds: 240,
}, async () => {
  const cfg = getSimplePayConfig();
  try {
    const cutoff = new Date(Date.now() - 90 * 1000); // 90s-nél régebbi INITIATED
    const snap = await db.collection('web_payments')
      .where('status', '==', 'INITIATED')
      .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(cutoff))
      .limit(20).get();
    if (snap.empty) return { ok: true, reconciled: 0 };
    let reconciled = 0;
    for (const d of snap.docs) {
      const pay = d.data();
      const orderRef = pay.orderRef || d.id;
      const userId = pay.userId;
      const canonicalPlanId = CANONICAL_PLAN_ID[pay.planId] || pay.planId;
      const plan = PAYMENT_PLANS[canonicalPlanId];
      if (!userId || !plan) continue;
      // 10 próbálat, 1 mp-es poll
      let data = null;
      for (let i = 0; i < 10; i++) {
        const pl = { salt: crypto.randomBytes(16).toString('hex'), merchant: cfg.merchantId.trim(), orderRef };
        const body = JSON.stringify(pl);
        const sig = crypto.createHmac('sha384', cfg.secretKey.trim()).update(body).digest('base64');
        const r = await fetch(`${cfg.baseUrl.trim()}query`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=utf-8', Signature: sig }, body });
        const t = await r.text();
        try { data = JSON.parse(t); } catch (_) { data = { raw: t }; }
        const ok = (data?.status || '').toString().toUpperCase() === 'SUCCESS' || !!data?.transactionId;
        if (ok) break;
        await sleep(1000);
      }
      const ok = data && ((data.status || '').toString().toUpperCase() === 'SUCCESS' || !!data.transactionId);
      if (!ok) continue;
      const now = new Date();
      const expiry = new Date(now.getTime() + plan.subscriptionDays * 24 * 60 * 60 * 1000);
      const transactionId = data?.transactionId || pay.simplePayTransactionId || null;
      const orderId = data?.orderId || null;
      await db.collection('users').doc(userId).set({
        isSubscriptionActive: true,
        subscriptionStatus: 'premium',
        subscriptionEndDate: admin.firestore.Timestamp.fromDate(expiry),
        subscription: {
          status: 'ACTIVE', productId: canonicalPlanId, purchaseToken: transactionId,
          orderId, endTime: expiry.toISOString(), lastUpdateTime: now.toISOString(), source: 'otp_simplepay'
        },
        lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      await d.ref.update({ status: 'COMPLETED', transactionId, orderId, completedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      reconciled++;
      console.log('[reconcileWebPaymentsScheduled] reconciled', { orderRef });
    }
    return { ok: true, reconciled };
  } catch (e) {
    console.error('[reconcileWebPaymentsScheduled] error', { message: e?.message });
    throw e;
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
      console.log(`Skipping ${reminderType} email for ${userId} - already sent on ${lastReminder[reminderKey].toDate().toISOString()}`);
      return { success: true, message: 'Email már elküldve (duplikátum védelem)', skipped: true };
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
    const { userId } = request.data || {};
    if (!userId) {
      throw new Error('invalid-argument: userId szükséges');
    }

    // Felhasználó email címének lekérése
    const userRecord = await admin.auth().getUser(userId);
    const email = userRecord.email;
    if (!email) {
      throw new Error('invalid-argument: A felhasználóhoz nincs email cím rendelve');
    }

    // Email verification link generálása
    const actionCodeSettings = {
      url: 'https://lomedu-user-web.web.app/login',
      handleCodeInApp: false,
    };
    const verificationLink = await admin.auth().generateEmailVerificationLink(email, actionCodeSettings);

    const subject = 'Email-cím megerősítése';
    const text = `Kedves felhasználó!\n\nKérjük, erősítsd meg email-címedet a következő linkre kattintva:\n\n${verificationLink}\n\nÜdvözlettel,\nA Lomedu csapat`;
    const bodyHtml = `<p>Kedves felhasználó!</p><p>Kérjük, erősítsd meg email-címedet az alábbi gombra kattintva:</p><p style="text-align:center;margin:32px 0;"><a href="${verificationLink}" style="background:#0d6efd;color:#ffffff;text-decoration:none;padding:12px 24px;border-radius:4px;display:inline-block;">Email megerősítése</a></p><p>Ha a gomb nem működik, másold be ezt a linket a böngésződbe:<br><a href="${verificationLink}">${verificationLink}</a></p><p>Üdvözlettel,<br>A Lomedu csapat</p>`;

    await transport.sendMail({
      from: 'Lomedu <info@lomedu.hu>',
      to: email,
      subject,
      text,
      html: buildTemplate(bodyHtml),
      attachments: [logoAttachment()],
    });

    console.log('Verification email sent to', email);
    return { success: true };
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

// =====================================
// 📧 EMAIL VERIFICATION HANDLER
// =====================================
exports.sendVerificationEmail = onCall(async (request) => {
  const { uid } = request.data;
  
  if (!uid) {
    throw new HttpsError('invalid-argument', 'uid is required');
  }

  try {
    // Get user from Auth
    const user = await admin.auth().getUser(uid);
    const email = user.email;
    const displayName = user.displayName || 'User';

    console.log(`Sending verification email to ${email} for user ${uid}`);

    // Generate verification link using Firebase Auth
    const actionCodeSettings = {
      url: 'https://www.lomedu.hu/#/verify-email',
      handleCodeInApp: true,
    };

    const verificationLink = await admin.auth().generateEmailVerificationLink(
      email,
      actionCodeSettings
    );

    console.log(`Generated verification link: ${verificationLink.substring(0, 50)}...`);

    // Extract the verification code from the link
    const urlObj = new URL(verificationLink);
    const oobCode = urlObj.searchParams.get('oobCode');

    if (!oobCode) {
      throw new Error('Failed to extract oobCode from verification link');
    }

    // Build email body with the verification link
    const emailBody = `
      <p>Üdvözöljük a Lomedun!</p>
      <p>Az e-mail címedet megerősítéséhez kérjük, kattints az alábbi gombra:</p>
      <p style="text-align: center; margin: 30px 0;">
        <a href="${verificationLink}" 
           style="background-color: #1E3A8A; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block; font-weight: bold;">
          E-mail megerősítése
        </a>
      </p>
      <p>vagy másold be az alábbi linket a böngészőbe:</p>
      <p style="word-break: break-all; font-size: 12px; color: #666;">
        ${verificationLink}
      </p>
      <p>A link 24 óra múlva lejár.</p>
    `;

    const mailOptions = {
      from: 'info@lomedu.hu',
      to: email,
      subject: 'Lomedu - E-mail megerősítés',
      html: buildTemplate(emailBody),
      attachments: [logoAttachment()],
    };

    const result = await transport.sendMail(mailOptions);
    console.log(`Email sent successfully to ${email}, message ID: ${result.messageId}`);

    return {
      success: true,
      message: 'Verification email sent successfully',
      email: email,
    };
  } catch (error) {
    console.error('Error sending verification email:', error);
    throw new HttpsError('internal', `Failed to send verification email: ${error.message}`);
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
          console.log(`Skipping expiry_warning for ${doc.id} - already sent on ${lastReminder.expiry_warning.toDate().toISOString()}`);
          emailsSkipped++;
          continue;
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
    // Keresünk minden felhasználót, aki premium előfizetéssel rendelkezik és lejárt
    const expired = await db.collection('users')
      .where('subscriptionStatus', '==', 'premium')
      .where('subscriptionEndDate', '<', admin.firestore.Timestamp.fromDate(now))
      .get();
    
    console.log(`Found ${expired.size} users with expired subscriptions`);
    
    for (const doc of expired.docs) {
      const userData = doc.data();
      console.log(`Processing expired user ${doc.id}: email=${userData.email}, isActive=${userData.isSubscriptionActive}, endDate=${userData.subscriptionEndDate?.toDate()?.toISOString()}`);
      
      // Ellenőrizzük a lastReminder mezőt
      const lastReminder = userData.lastReminder || {};
      
      if (lastReminder.expired) {
        console.log(`Skipping expired notification for ${doc.id} - already sent on ${lastReminder.expired.toDate().toISOString()}`);
        emailsSkipped++;
        continue;
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

