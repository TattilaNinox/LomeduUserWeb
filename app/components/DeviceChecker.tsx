"use client";
import { useEffect, useMemo, useState } from 'react';
import { getFirebase } from '@/lib/firebase';
import { doc, getDoc } from 'firebase/firestore';
import { useRouter, usePathname } from 'next/navigation';
import { getWebDeviceFingerprint } from '@/lib/deviceFingerprint';

export default function DeviceChecker() {
  const { auth, db } = getFirebase();
  const router = useRouter();
  const pathname = usePathname();
  const fingerprint = useMemo(() => getWebDeviceFingerprint(), []);
  const [isInitialized, setIsInitialized] = useState(false);

  useEffect(() => {
    // Csak a bejelentkezési oldalakon kívül működjön
    if (pathname?.startsWith('/login') || pathname?.startsWith('/register') || pathname?.startsWith('/verify-email') || pathname?.startsWith('/device-change')) {
      return;
    }

    const u = auth.currentUser;
    if (!u) {
      setIsInitialized(true);
      return;
    }

    console.log('DeviceChecker: Checking device for user', u.uid, 'fingerprint:', fingerprint);

    // Egyszerű getDoc használata onSnapshot helyett
    const checkDevice = async () => {
      try {
        const userDoc = await getDoc(doc(db, 'users', u.uid));
        if (!userDoc.exists()) {
          console.log('DeviceChecker: User document not found');
          return;
        }
        
        const data = userDoc.data();
        const allowed = data?.authorizedDeviceFingerprint;
        console.log('DeviceChecker: Current fingerprint:', fingerprint, 'Allowed:', allowed);
        
        if (allowed && allowed !== fingerprint) {
          console.log('Device fingerprint mismatch, logging out user');
          await auth.signOut();
          router.replace('/login');
        }
      } catch (error) {
        console.error('DeviceChecker: Error checking device:', error);
      }
    };

    checkDevice();
    
    // Időzítő - 5 másodpercenként ellenőrzi
    const interval = setInterval(checkDevice, 5000);
    
    setIsInitialized(true);
    
    return () => clearInterval(interval);
  }, [auth, db, fingerprint, router, pathname]);

  return null;
}
