'use client';

import { useState, useEffect } from 'react';
import { useAuthState } from 'react-firebase-hooks/auth';
import { doc, onSnapshot } from 'firebase/firestore';
import { auth, db } from '../../lib/firebase';
import SubscriptionStatusCard from '../components/SubscriptionStatusCard';
import PaymentPlans from '../components/PaymentPlans';
import PaymentHistory from '../components/PaymentHistory';

interface UserData {
  email: string;
  displayName?: string;
  subscriptionStatus: 'free' | 'premium' | 'expired';
  isSubscriptionActive: boolean;
  subscriptionEndDate?: any;
  subscription?: {
    status: string;
    productId?: string;
    endTime?: string;
    source?: string;
  };
  lastPaymentDate?: any;
  createdAt?: any;
}

export default function SubscriptionPage() {
  const [user, loading, error] = useAuthState(auth);
  const [userData, setUserData] = useState<UserData | null>(null);
  const [loadingUserData, setLoadingUserData] = useState(true);

  useEffect(() => {
    if (user) {
      const userRef = doc(db, 'users', user.uid);
      const unsubscribe = onSnapshot(userRef, (doc) => {
        if (doc.exists()) {
          setUserData(doc.data() as UserData);
        }
        setLoadingUserData(false);
      });

      return () => unsubscribe();
    } else {
      setLoadingUserData(false);
    }
  }, [user]);

  if (loading || loadingUserData) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Betöltés...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="text-red-600 text-xl mb-4">⚠️</div>
          <p className="text-red-600">Hiba történt a betöltés során</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="text-blue-600 text-xl mb-4">🔒</div>
          <p className="text-gray-600">Kérjük, jelentkezzen be a folytatáshoz</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Előfizetés kezelése</h1>
          <p className="mt-2 text-gray-600">
            Kezelje előfizetését és fizetési adatait egy helyen
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Előfizetési státusz */}
          <div className="lg:col-span-2">
            <SubscriptionStatusCard userData={userData} />
          </div>

          {/* Fizetési csomagok */}
          <div className="lg:col-span-1">
            <PaymentPlans userData={userData} />
          </div>
        </div>

        {/* Fizetési előzmények */}
        <div className="mt-8">
          <PaymentHistory userData={userData} />
        </div>
      </div>
    </div>
  );
}






