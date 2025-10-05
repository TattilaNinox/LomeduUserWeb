"use client";
import { useCallback, useEffect, useRef, useState } from 'react';
import { getFirebase } from '@/lib/firebase';
import { sendEmailVerification } from 'firebase/auth';
import { useRouter } from 'next/navigation';

export default function VerifyEmailPage() {
  const { auth } = getFirebase();
  const router = useRouter();
  const [cooldown, setCooldown] = useState(0);
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    timerRef.current = setInterval(async () => {
      const u = auth.currentUser;
      if (!u) return;
      await u.reload();
      if (u.emailVerified) {
        router.replace('/categories');
      }
    }, 5000);
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [auth, router]);

  useEffect(() => {
    if (cooldown <= 0) return;
    const t = setTimeout(() => setCooldown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [cooldown]);

  const resend = useCallback(async () => {
    if (cooldown > 0) return;
    const u = auth.currentUser;
    if (!u) return;
    await sendEmailVerification(u);
    setCooldown(30);
  }, [auth, cooldown]);

  return (
    <main className="mx-auto max-w-md p-6">
      <h1 className="text-2xl font-semibold mb-4">E-mail megerősítés</h1>
      <p className="mb-4 text-sm">Kérjük, erősítse meg az e-mail címét. Az oldal 5 mp-enként ellenőrzi az állapotot.</p>
      <button onClick={resend} disabled={cooldown > 0} className="bg-black text-white rounded px-4 py-2">
        {cooldown > 0 ? `Újraküldés ${cooldown}s` : 'Megerősítő e-mail újraküldése'}
      </button>
    </main>
  );
}


