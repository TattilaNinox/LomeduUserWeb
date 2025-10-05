const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

// Régió: europe-west1
exports.requestDeviceChange = functions.region('europe-west1').https.onCall(async (data, context) => {
  const email = (data && data.email || '').toString().trim().toLowerCase();
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email szükséges');
  }
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = Date.now() + 15 * 60 * 1000; // 15 perc

  const snap = await db.collection('users').where('email', '==', email).limit(1).get();
  if (snap.empty) {
    throw new functions.https.HttpsError('not-found', 'Nem található felhasználó ezzel az email címmel.');
  }
  const userDoc = snap.docs[0];
  await userDoc.ref.set({ deviceChange: { code, expiresAt, requestedAt: admin.firestore.FieldValue.serverTimestamp() } }, { merge: true });

  // Itt normál esetben email küldés történne (pl. nodemailer / SendGrid)
  console.log(`Device change code for ${email}: ${code}`);
  return { ok: true };
});

exports.verifyAndChangeDevice = functions.region('europe-west1').https.onCall(async (data, context) => {
  const email = (data && data.email || '').toString().trim().toLowerCase();
  const code = (data && data.code || '').toString().trim();
  const newFingerprint = (data && data.fingerprint || '').toString().trim();
  if (!email || !code || !newFingerprint) {
    throw new functions.https.HttpsError('invalid-argument', 'Hiányzó mezők');
  }
  const snap = await db.collection('users').where('email', '==', email).limit(1).get();
  if (snap.empty) {
    throw new functions.https.HttpsError('not-found', 'Nem található felhasználó ezzel az email címmel.');
  }
  const userDoc = snap.docs[0];
  const dc = (userDoc.data().deviceChange) || {};
  if (!dc.code || !dc.expiresAt || dc.code !== code || Date.now() > Number(dc.expiresAt)) {
    throw new functions.https.HttpsError('failed-precondition', 'Érvénytelen vagy lejárt kód');
  }
  await userDoc.ref.set({
    authorizedDeviceFingerprint: newFingerprint,
    deviceChangeDate: admin.firestore.FieldValue.serverTimestamp(),
    deviceChange: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  return { ok: true };
});

