/*
 * Egyszeri bulk frissítés: minden notes dokumentumhoz hozzáadja a
 * science: "Alap" mezőt, ha még nincs beállítva.
 * 
 * Futtatás előtt:
 * 1) Hozz létre egy Firebase service-account JSON-t (Projekt beállítások → Szolgáltatási fiókok → Új privát kulcs).
 * 2) Mentsd el a repo gyökerébe serviceAccount.json néven (vagy módosítsd lent a path-ot).
 * 3) Telepítsd a függőséget:  npm install firebase-admin
 * 4) node tools/bulk_add_science.js
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import fs from 'fs';

const serviceAccountPath = './serviceAccount.json';
if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌  serviceAccount.json nem található (repo gyökér).');
  process.exit(1);
}

initializeApp({ credential: cert(serviceAccountPath) });
const db = getFirestore();

(async () => {
  const snap = await db.collection('notes').where('science', '==', null).get();
  console.log(`Frissítendő dokumentumok: ${snap.size}`);
  const batch = db.batch();
  snap.docs.forEach((doc) => {
    batch.update(doc.ref, { science: 'Alap' });
  });
  await batch.commit();
  console.log('✅  Kész: minden érintett dokumentum frissítve.');
})();
