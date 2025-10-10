'use client';

import { useState, useEffect } from 'react';
import { useAuthState } from 'react-firebase-hooks/auth';
import { doc, onSnapshot } from 'firebase/firestore';
import { auth, db } from '../../../lib/firebase';
import { useRouter } from 'next/navigation';

interface UserData {
  email: string;
  displayName?: string;
  subscriptionStatus: 'free' | 'premium' | 'expired';
  isSubscriptionActive: boolean;
  subscriptionEndDate?: any;
  subscription?: {
    status: string;
    productId?: string;
    source?: string;
  };
}

interface Plan {
  id: string;
  name: string;
  price: number;
  period: string;
  features: string[];
  popular?: boolean;
  description: string;
  originalPrice?: number;
  discount?: string;
}

const plans: Plan[] = [
  {
    id: 'monthly',
    name: 'Havi előfizetés',
    price: 2990,
    period: 'hó',
    description: 'Teljes hozzáférés minden funkcióhoz',
    features: [
      'Korlátlan jegyzet hozzáférés',
      'Interaktív kvízek',
      'Flashcard csomagok',
      'Audio tartalmak',
      'Offline letöltés',
      'Elsődleges támogatás'
    ]
  },
  {
    id: 'yearly',
    name: 'Éves előfizetés',
    price: 29900,
    period: 'év',
    description: '2 hónap ingyen a havi árhoz képest',
    originalPrice: 35880, // 12 * 2990
    discount: '17%',
    popular: true,
    features: [
      'Korlátlan jegyzet hozzáférés',
      'Interaktív kvízek',
      'Flashcard csomagok',
      'Audio tartalmak',
      'Offline letöltés',
      'Elsődleges támogatás',
      'Korai hozzáférés új funkciókhoz',
      'Exkluzív tartalmak'
    ]
  }
];

export default function UpgradePage() {
  const [user, loading, error] = useAuthState(auth);
  const [userData, setUserData] = useState<UserData | null>(null);
  const [loadingUserData, setLoadingUserData] = useState(true);
  const [selectedPlan, setSelectedPlan] = useState<string | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const router = useRouter();

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

  const handleSelectPlan = async (planId: string) => {
    if (isProcessing) return;
    
    setIsProcessing(true);
    setSelectedPlan(planId);

    try {
      const response = await fetch('/api/payment/create', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          planId: planId,
          userId: user?.uid,
        }),
      });

      if (response.ok) {
        const { paymentUrl } = await response.json();
        // Átirányítás a SimplePay fizetési oldalra
        window.location.href = paymentUrl;
      } else {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Fizetési folyamat indítása sikertelen');
      }
    } catch (error) {
      console.error('Payment error:', error);
      alert(`Hiba történt a fizetés indítása során: ${error.message}`);
    } finally {
      setIsProcessing(false);
      setSelectedPlan(null);
    }
  };

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
          <button
            onClick={() => router.back()}
            className="mt-4 text-blue-600 hover:text-blue-800"
          >
            ← Vissza
          </button>
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
          <button
            onClick={() => router.push('/auth/login')}
            className="mt-4 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
          >
            Bejelentkezés
          </button>
        </div>
      </div>
    );
  }

  const isCurrentUserPremium = userData?.subscriptionStatus === 'premium' && userData?.isSubscriptionActive;

  if (isCurrentUserPremium) {
    return (
      <div className="min-h-screen bg-gray-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="text-center">
            <div className="text-green-600 text-6xl mb-4">✅</div>
            <h1 className="text-3xl font-bold text-gray-900 mb-4">Már rendelkezik aktív előfizetéssel</h1>
            <p className="text-gray-600 mb-8">
              Ön már prémium felhasználó. A csomag kezeléséhez látogasson el a Google Play Store-ba.
            </p>
            <button
              onClick={() => router.push('/subscription')}
              className="bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700"
            >
              Előfizetés kezelése
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            Válassza ki az előfizetési csomagját
          </h1>
          <p className="text-xl text-gray-600 max-w-3xl mx-auto">
            Szerezzen teljes hozzáférést minden funkcióhoz és növelje a tanulási hatékonyságát
          </p>
        </div>

        {/* Csomagok */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-5xl mx-auto">
          {plans.map((plan) => (
            <div
              key={plan.id}
              className={`relative bg-white rounded-2xl shadow-lg p-8 transition-all ${
                plan.popular
                  ? 'border-2 border-blue-500 scale-105'
                  : 'border border-gray-200 hover:shadow-xl'
              }`}
            >
              {plan.popular && (
                <div className="absolute -top-4 left-1/2 transform -translate-x-1/2">
                  <span className="bg-blue-500 text-white text-sm font-semibold px-4 py-2 rounded-full">
                    Legnépszerűbb
                  </span>
                </div>
              )}

              <div className="text-center mb-8">
                <h3 className="text-2xl font-bold text-gray-900 mb-2">{plan.name}</h3>
                <p className="text-gray-600 mb-6">{plan.description}</p>
                
                <div className="mb-4">
                  {plan.originalPrice && (
                    <div className="flex items-center justify-center space-x-2 mb-2">
                      <span className="text-lg text-gray-500 line-through">
                        {plan.originalPrice.toLocaleString('hu-HU')} Ft
                      </span>
                      <span className="bg-red-100 text-red-800 text-sm font-semibold px-2 py-1 rounded">
                        -{plan.discount}
                      </span>
                    </div>
                  )}
                  <div className="text-4xl font-bold text-gray-900">
                    {plan.price.toLocaleString('hu-HU')} Ft
                  </div>
                  <div className="text-gray-600">/{plan.period}</div>
                </div>
              </div>

              <ul className="space-y-4 mb-8">
                {plan.features.map((feature, index) => (
                  <li key={index} className="flex items-start">
                    <span className="text-green-500 text-xl mr-3 mt-0.5">✓</span>
                    <span className="text-gray-700">{feature}</span>
                  </li>
                ))}
              </ul>

              <button
                onClick={() => handleSelectPlan(plan.id)}
                disabled={isProcessing}
                className={`w-full py-4 px-6 rounded-xl font-semibold text-lg transition-colors ${
                  plan.popular
                    ? 'bg-blue-600 text-white hover:bg-blue-700 disabled:bg-blue-300'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200 disabled:bg-gray-50'
                }`}
              >
                {isProcessing && selectedPlan === plan.id ? (
                  <div className="flex items-center justify-center">
                    <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-current mr-2"></div>
                    Feldolgozás...
                  </div>
                ) : (
                  `Választás - ${plan.price.toLocaleString('hu-HU')} Ft/${plan.period}`
                )}
              </button>
            </div>
          ))}
        </div>

        {/* Garanciák */}
        <div className="mt-16 text-center">
          <h3 className="text-lg font-semibold text-gray-900 mb-6">Miért válassza az előfizetésünket?</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-4xl mx-auto">
            <div className="text-center">
              <div className="text-3xl mb-3">🔒</div>
              <h4 className="font-semibold text-gray-900 mb-2">Biztonságos fizetés</h4>
              <p className="text-sm text-gray-600">
                OTP SimplePay-en keresztül biztonságos bankkártyás fizetés
              </p>
            </div>
            <div className="text-center">
              <div className="text-3xl mb-3">↩️</div>
              <h4 className="font-semibold text-gray-900 mb-2">30 napos garancia</h4>
              <p className="text-sm text-gray-600">
                Ha nem elégedett, 30 napon belül teljes visszatérítés
              </p>
            </div>
            <div className="text-center">
              <div className="text-3xl mb-3">❌</div>
              <h4 className="font-semibold text-gray-900 mb-2">Bármikor lemondható</h4>
              <p className="text-sm text-gray-600">
                Előfizetését bármikor lemondhatja, nincs kötelezettség
              </p>
            </div>
          </div>
        </div>

        {/* Vissza gomb */}
        <div className="mt-8 text-center">
          <button
            onClick={() => router.back()}
            className="text-gray-600 hover:text-gray-800"
          >
            ← Vissza az előfizetés kezeléséhez
          </button>
        </div>
      </div>
    </div>
  );
}






