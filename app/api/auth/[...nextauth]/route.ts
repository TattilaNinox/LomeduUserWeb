import NextAuth from 'next-auth';
import GoogleProvider from 'next-auth/providers/google';
import { FirestoreAdapter } from '@next-auth/firebase-adapter';
import { getFirestore } from 'firebase-admin/firestore';
import { initializeApp, getApps, cert } from 'firebase-admin/app';

// Firebase Admin inicializálás
if (!getApps().length) {
  initializeApp({
    credential: cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

const db = getFirestore();

export const authOptions = {
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
  ],
  adapter: FirestoreAdapter(db),
  callbacks: {
    async session({ session, user }) {
      if (session?.user) {
        session.user.id = user.id;
      }
      return session;
    },
    async signIn({ user, account, profile }) {
      // Felhasználói dokumentum létrehozása/ellenőrzése
      if (user.email) {
        try {
          const userRef = db.collection('users').doc(user.id);
          const userDoc = await userRef.get();
          
          if (!userDoc.exists) {
            // Új felhasználó - 7 napos próbaidőszak beállítása
            const now = new Date();
            const trialEndDate = new Date(now.getTime() + (7 * 24 * 60 * 60 * 1000));
            
            await userRef.set({
              email: user.email,
              displayName: user.name || 'Felhasználó',
              createdAt: now,
              userType: 'user',
              
              // Próbaidőszak beállítása
              isSubscriptionActive: true,
              subscriptionStatus: 'premium', // A próbaidőszak alatt prémium hozzáférést kap
              subscriptionEndDate: trialEndDate,
              
              // Részletes adatok
              subscription: {
                status: 'TRIAL',
                endTime: trialEndDate.toISOString(),
                lastUpdateTime: now.toISOString(),
                source: 'registration_trial'
              }
            });
          }
        } catch (error) {
          console.error('Error creating user document:', error);
        }
      }
      
      return true;
    },
  },
  pages: {
    signIn: '/auth/login',
    error: '/auth/error',
  },
};

const handler = NextAuth(authOptions);

export { handler as GET, handler as POST };






