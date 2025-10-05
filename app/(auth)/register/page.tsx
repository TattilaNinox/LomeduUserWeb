"use client";
import { useCallback, useState } from 'react';
import { getFirebase } from '@/lib/firebase';
import { createUserWithEmailAndPassword, sendEmailVerification } from 'firebase/auth';
import { ensureUserDocument } from '@/lib/ensureUserDocument';
import { useRouter } from 'next/navigation';

function isValidEmail(email: string) {
  return /^(?:[a-zA-Z0-9_'^&/+-])+(?:\.(?:[a-zA-Z0-9_'^&/+-])+)*@(?:(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,})$/.test(email);
}

export default function RegisterPage() {
  const { auth } = getFirebase();
  const router = useRouter();
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleRegister = useCallback(async () => {
    setError(null);
    if (!lastName.trim()) return setError('Vezetéknév kötelező.');
    if (!firstName.trim()) return setError('Keresztnév kötelező.');
    if (!isValidEmail(email)) return setError('Kérjük, adjon meg egy érvényes email címet.');
    if (!password) return setError('Jelszó kötelező.');
    if (password !== confirm) return setError('A jelszavak nem egyeznek.');
    setLoading(true);
    try {
      const cred = await createUserWithEmailAndPassword(auth, email.trim(), password.trim());
      await ensureUserDocument(cred.user, { firstName: firstName.trim(), lastName: lastName.trim() });
      await sendEmailVerification(cred.user);
      router.replace('/verify-email');
    } catch (e: any) {
      const code = e?.code as string | undefined;
      switch (code) {
        case 'auth/email-already-in-use':
          setError('Ez az email cím már használatban van.');
          break;
        case 'auth/invalid-email':
          setError('Kérjük, adjon meg egy érvényes email címet.');
          break;
        case 'auth/weak-password':
          setError('A jelszó túl gyenge.');
          break;
        default:
          setError('Ismeretlen hiba történt. Próbálja újra!');
      }
    } finally {
      setLoading(false);
    }
  }, [auth, confirm, email, firstName, lastName, password, router]);

  return (
    <main className="mx-auto max-w-md p-6">
      <h1 className="text-2xl font-semibold mb-4">Regisztráció</h1>
      {error && <div className="mb-3 text-sm text-red-600">{error}</div>}
      <div className="space-y-3">
        <input className="w-full border rounded px-3 py-2" placeholder="Vezetéknév" value={lastName} onChange={(e) => setLastName(e.target.value)} />
        <input className="w-full border rounded px-3 py-2" placeholder="Keresztnév" value={firstName} onChange={(e) => setFirstName(e.target.value)} />
        <input className="w-full border rounded px-3 py-2" placeholder="E-mail" type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
        <input className="w-full border rounded px-3 py-2" placeholder="Jelszó" type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
        <input className="w-full border rounded px-3 py-2" placeholder="Jelszó megerősítése" type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)} />
        <button disabled={loading} onClick={handleRegister} className="w-full bg-black text-white rounded py-2">{loading ? 'Folyamatban…' : 'Regisztráció'}</button>
      </div>
    </main>
  );
}


