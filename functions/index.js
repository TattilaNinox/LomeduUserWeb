const { onCall } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();

// Globális beállítások – régió, erőforrások
setGlobalOptions({ region: 'europe-west1', cpu: 1 });

const db = admin.firestore();

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

  // Itt normál esetben email küldés
  console.log(`Device change code for ${email}: ${code}`);
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

  await userDoc.ref.set({
    authorizedDeviceFingerprint: newFingerprint,
    deviceChangeDate: admin.firestore.FieldValue.serverTimestamp(),
    deviceChange: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // Invalidate refresh tokens
  await admin.auth().revokeRefreshTokens(userDoc.id);
  return { ok: true };
});

