"use client";
import { useCallback, useState } from 'react';
import { getFirebase } from '@/lib/firebase';
import { getFunctions, httpsCallable } from 'firebase/functions';
import { getWebDeviceFingerprint } from '@/lib/deviceFingerprint';

export default function DeviceChangePage() {
  const { app } = getFirebase();
  const functions = getFunctions(app, 'europe-west1');
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [msg, setMsg] = useState<string | null>(null);

  const request = useCallback(async () => {
    setMsg(null);
    try {
      await httpsCallable(functions, 'requestDeviceChange')({ email: email.trim() });
      setMsg('Kód elküldve az email címre (15 percig érvényes).');
    } catch (e: any) {
      setMsg(e?.message || 'Hiba történt.');
    }
  }, [email, functions]);

  const verify = useCallback(async () => {
    setMsg(null);
    try {
      const fingerprint = getWebDeviceFingerprint();
      await httpsCallable(functions, 'verifyAndChangeDevice')({ email: email.trim(), code: code.trim(), fingerprint });
      setMsg('Eszköz sikeresen frissítve. Mostantól ez az eszköz jogosult.');
    } catch (e: any) {
      setMsg(e?.message || 'Hiba történt.');
    }
  }, [code, email, functions]);

  return (
    <main className="mx-auto max-w-md p-6">
      <h1 className="text-2xl font-semibold mb-4">Eszközváltás</h1>
      {msg && <div className="mb-3 text-sm">{msg}</div>}
      <div className="space-y-3">
        <input className="w-full border rounded px-3 py-2" placeholder="E-mail" value={email} onChange={(e) => setEmail(e.target.value)} />
        <div className="flex gap-2">
          <button onClick={request} className="flex-1 bg-black text-white rounded py-2">Kód igénylése</button>
          <input className="w-36 border rounded px-3 py-2" placeholder="6 jegyű kód" value={code} onChange={(e) => setCode(e.target.value)} />
          <button onClick={verify} className="flex-1 bg-black text-white rounded py-2">Váltás</button>
        </div>
      </div>
    </main>
  );
}


