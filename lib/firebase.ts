import { initializeApp, getApps, FirebaseApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, type Auth } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, type Firestore } from 'firebase/firestore';
import { getFunctions, connectFunctionsEmulator, type Functions } from 'firebase/functions';

let app: FirebaseApp | null = null;
let auth: Auth | null = null;
let db: Firestore | null = null;
let functions: Functions | null = null;

export function initFirebase(): { app: FirebaseApp; auth: Auth; db: Firestore; functions: Functions } {
  if (!app) {
    app = initializeApp({
      apiKey: 'AIzaSyCWkH2x7ujj3xc8M1fhJAMphWo7pLBhV_k',
      authDomain: 'orlomed-f8f9f.firebaseapp.com',
      projectId: 'orlomed-f8f9f',
      storageBucket: 'orlomed-f8f9f.firebasestorage.app',
      messagingSenderId: '673799768268',
      appId: '1:673799768268:web:2313db56d5226e17c6da69',
    });
  }

  if (!auth) auth = getAuth(app);
  if (!db) db = getFirestore(app);
  if (!functions) functions = getFunctions(app, 'europe-west1');

  // Emulátorok opcionális csatlakoztatása fejlesztéshez
  if (typeof window !== 'undefined' && (window as any).__USE_FIREBASE_EMULATORS__) {
    try {
      connectAuthEmulator(auth, 'http://localhost:9099', { disableWarnings: true });
      connectFirestoreEmulator(db, 'localhost', 8080);
      connectFunctionsEmulator(functions, 'localhost', 5001);
    } catch (_) {}
  }

  return { app, auth, db, functions } as { app: FirebaseApp; auth: Auth; db: Firestore; functions: Functions };
}

export function getFirebase() {
  if (!app || !auth || !db || !functions) {
    return initFirebase();
  }
  return { app, auth, db, functions } as { app: FirebaseApp; auth: Auth; db: Firestore; functions: Functions };
}


