"use client";
import { useEffect, useState } from 'react';
import { getFirebase } from '@/lib/firebase';
import { useRouter } from 'next/navigation';
import { doc, getDoc } from 'firebase/firestore';
import { getWebDeviceFingerprint } from '@/lib/deviceFingerprint';

export default function CategoriesPage() {
  const { auth, db } = getFirebase();
  const router = useRouter();
  const [status, setStatus] = useState<string>('Betöltés...');

  const checkDevice = async () => {
    const u = auth.currentUser;
    if (!u) return;

    try {
      const fingerprint = getWebDeviceFingerprint();
      console.log('Manual check - Current fingerprint:', fingerprint);
      
      const userDoc = await getDoc(doc(db, 'users', u.uid));
      if (!userDoc.exists()) {
        console.log('User document not found');
        return;
      }
      
      const data = userDoc.data();
      const allowed = data?.authorizedDeviceFingerprint;
      console.log('Manual check - Allowed fingerprint:', allowed);
      
      if (allowed && allowed !== fingerprint) {
        console.log('MANUAL CHECK: Device mismatch! Logging out...');
        await auth.signOut();
        router.replace('/login');
      } else {
        console.log('MANUAL CHECK: Device OK');
      }
    } catch (error) {
      console.error('Manual check error:', error);
    }
  };

  useEffect(() => {
    const u = auth.currentUser;
    if (!u) {
      router.replace('/login');
      return;
    }
    setStatus('Kategóriák');
    
    // Automatikus ellenőrzés 5 másodpercenként
    const interval = setInterval(checkDevice, 5000);
    return () => clearInterval(interval);
  }, [auth, router]);

  return (
    <main className="mx-auto max-w-3xl p-6">
      <h1 className="text-2xl font-semibold mb-4">{status}</h1>
      <p className="text-sm text-gray-600">Itt fognak megjelenni a kategóriák.</p>
      <div className="mt-4 space-y-2">
        <button 
          onClick={checkDevice}
          className="bg-blue-500 text-white px-4 py-2 rounded mr-2"
        >
          Manuális eszköz ellenőrzés
        </button>
        <button 
          onClick={() => {
            console.log('Current user:', auth.currentUser?.uid);
            console.log('Current fingerprint:', getWebDeviceFingerprint());
          }}
          className="bg-green-500 text-white px-4 py-2 rounded"
        >
          Debug info
        </button>
      </div>
    </main>
  );
}


