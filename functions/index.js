const { onCall } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

// Konfiguráció forrása: 1) Firebase Functions config (firebase functions:config:set smtp.*),
// 2) környezeti változók, 3) ha emulátor fut, próbáljon meg helyi SMTP-t (opcionális).

admin.initializeApp();

// Globális beállítások – régió, erőforrások
setGlobalOptions({ region: 'europe-west1', cpu: 1 });

const db = admin.firestore();

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

