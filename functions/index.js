const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Engedélyezett IP címek listája
const ALLOWED_IPS = [
  '192.168.1.1', // Példa IP - cseréld le a valós IP címedre
  '10.0.0.1',    // Másik engedélyezett IP
];

exports.checkAdminAccess = functions.https.onRequest((req, res) => {
  const clientIp = req.headers['x-forwarded-for'] || req.connection.remoteAddress;
  
  if (!ALLOWED_IPS.includes(clientIp)) {
    res.status(403).send('Access denied');
    return;
  }
  
  res.status(200).send('Access granted');
});

