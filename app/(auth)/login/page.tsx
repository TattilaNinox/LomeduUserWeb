"use client";
import { useCallback, useEffect, useMemo, useState } from 'react';
import { getFirebase } from '@/lib/firebase';
import { signInWithEmailAndPassword, sendPasswordResetEmail } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { ensureUserDocument } from '@/lib/ensureUserDocument';
import { getWebDeviceFingerprint } from '@/lib/deviceFingerprint';

function isValidEmail(email: string) {
  return /^(?:[a-zA-Z0-9_'^&/+-])+(?:\.(?:[a-zA-Z0-9_'^&/+-])+)*@(?:(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,})$/.test(email);
}

export default function LoginPage() {
  const { auth, db } = getFirebase();
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSignIn = useCallback(async () => {
    setError(null);
    if (!isValidEmail(email)) {
      setError('Kérjük, adjon meg egy érvényes email címet.');
      return;
    }
    if (!password) {
      setError('Kérjük, adja meg a jelszavát.');
      return;
    }
    setLoading(true);
    try {
      const cred = await signInWithEmailAndPassword(auth, email.trim(), password.trim());
      const user = cred.user;
      await user.reload();
      if (!user.emailVerified) {
        setError('Az email cím nincs megerősítve. Küldtünk új megerősítő emailt.');
        await (user as any).sendEmailVerification();
        return;
      }
      const userRef = doc(db, 'users', user.uid);
      const snap = await getDoc(userRef);
      const isActive = (snap.data()?.isActive as boolean | undefined) ?? true;
      if (!isActive) {
        setError('A fiók inaktív. Kérjük, lépjen kapcsolatba az adminnal.');
        await auth.signOut();
        router.replace('/login');
        return;
      }
      await ensureUserDocument(user);
      router.replace('/');
    } catch (e: any) {
      const code = e?.code as string | undefined;
      switch (code) {
        case 'auth/user-not-found':
          setError('Nem található felhasználó ezzel az email címmel.');
          break;
        case 'auth/wrong-password':
        case 'auth/invalid-credential':
          setError('Hibás email cím vagy jelszó. Próbálja újra!');
          break;
        case 'auth/invalid-email':
          setError('Kérjük, adjon meg egy érvényes email címet.');
          break;
        case 'auth/too-many-requests':
          setError('Túl sok próbálkozás. Próbálja később!');
          break;
        default:
          setError('Ismeretlen hiba történt. Próbálja újra!');
      }
    } finally {
      setLoading(false);
    }
  }, [auth, db, email, password, router]);

  const handleReset = useCallback(async () => {
    setError(null);
    if (!isValidEmail(email)) {
      setError('Kérjük, adjon meg egy érvényes email címet.');
      return;
    }
    try {
      await sendPasswordResetEmail(auth, email.trim());
      setError('Jelszó-visszaállító email elküldve.');
    } catch (_) {
      setError('Hiba történt. Próbálja újra!');
    }
  }, [auth, email]);

  const checkDevice = async () => {
    const u = auth.currentUser;
    if (!u) {
      console.log('No user logged in');
      return;
    }

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

  return (
    <main className="mx-auto max-w-md p-6">
      <h1 className="text-2xl font-semibold mb-4">Bejelentkezés</h1>
      {error && <div className="mb-3 text-sm text-red-600">{error}</div>}
      <div className="space-y-3">
        <input
          type="email"
          placeholder="E-mail"
          className="w-full border rounded px-3 py-2"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
        <input
          type="password"
          placeholder="Jelszó"
          className="w-full border rounded px-3 py-2"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <button disabled={loading} onClick={handleSignIn} className="w-full bg-black text-white rounded py-2">
          {loading ? 'Bejelentkezés...' : 'Belépés'}
        </button>
        <button type="button" onClick={handleReset} className="text-sm text-blue-700 underline">
          Elfelejtett jelszó
        </button>
        <div className="text-sm">
          Nincs fiókja? <Link href="/register" className="text-blue-700 underline">Regisztráció</Link>
        </div>
        <button 
          onClick={checkDevice}
          className="w-full bg-blue-500 text-white px-4 py-2 rounded mt-2"
        >
          Eszköz ellenőrzés (Debug)
        </button>
      </div>
    </main>
  );
}


