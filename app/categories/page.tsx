"use client";
import { useEffect, useMemo, useRef, useState } from 'react';
import { getFirebase } from '@/lib/firebase';
import { doc, onSnapshot } from 'firebase/firestore';
import { useRouter } from 'next/navigation';
import { getWebDeviceFingerprint } from '@/lib/deviceFingerprint';

export default function CategoriesPage() {
  const { auth, db } = getFirebase();
  const router = useRouter();
  const [status, setStatus] = useState<string>('Betöltés...');
  const fingerprint = useMemo(() => getWebDeviceFingerprint(), []);

  useEffect(() => {
    const u = auth.currentUser;
    if (!u) {
      router.replace('/login');
      return;
    }
    const unsub = onSnapshot(doc(db, 'users', u.uid), (snap) => {
      const data = snap.data() as any;
      if (!data) return;
      const allowed = data.authorizedDeviceFingerprint;
      if (allowed && allowed !== fingerprint) {
        auth.signOut().finally(() => router.replace('/login'));
      } else {
        setStatus('Kategóriák');
      }
    });
    return () => unsub();
  }, [auth, db, fingerprint, router]);

  return (
    <main className="mx-auto max-w-3xl p-6">
      <h1 className="text-2xl font-semibold mb-4">{status}</h1>
      <p className="text-sm text-gray-600">Itt fognak megjelenni a kategóriák.</p>
    </main>
  );
}


