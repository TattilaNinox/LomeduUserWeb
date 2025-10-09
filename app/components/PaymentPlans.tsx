'use client';

import { useState } from 'react';

interface UserData {
  subscriptionStatus: 'free' | 'premium' | 'expired';
  isSubscriptionActive: boolean;
  subscription?: {
    status: string;
    productId?: string;
    source?: string;
  };
}

interface PaymentPlansProps {
  userData: UserData | null;
}

interface Plan {
  id: string;
  name: string;
  price: number;
  period: string;
  features: string[];
  popular?: boolean;
  description: string;
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

export default function PaymentPlans({ userData }: PaymentPlansProps) {
  const [selectedPlan, setSelectedPlan] = useState<string | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  const handleSelectPlan = async (planId: string) => {
    if (isProcessing) return;
    
    setIsProcessing(true);
    setSelectedPlan(planId);

    try {
      // Itt hívnánk meg a SimplePay API-t
      const response = await fetch('/api/payment/create', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          planId: planId,
          userId: userData ? 'current-user' : null, // Valódi user ID-t kellene használni
        }),
      });

      if (response.ok) {
        const { paymentUrl } = await response.json();
        // Átirányítás a SimplePay fizetési oldalra
        window.location.href = paymentUrl;
      } else {
        throw new Error('Fizetési folyamat indítása sikertelen');
      }
    } catch (error) {
      console.error('Payment error:', error);
      alert('Hiba történt a fizetés indítása során. Kérjük, próbálja újra.');
    } finally {
      setIsProcessing(false);
      setSelectedPlan(null);
    }
  };

  const isCurrentUserPremium = userData?.subscriptionStatus === 'premium' && userData?.isSubscriptionActive;

  if (isCurrentUserPremium) {
    return (
      <div className="bg-white rounded-lg shadow-md p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Előfizetési csomagok</h3>
        <div className="text-center py-8">
          <div className="text-green-600 text-4xl mb-4">✅</div>
          <h4 className="text-lg font-medium text-gray-900 mb-2">Aktív előfizetés</h4>
          <p className="text-sm text-gray-600">
            Ön már rendelkezik aktív előfizetéssel. 
            A csomag kezeléséhez látogasson el a Google Play Store-ba.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <h3 className="text-lg font-semibold text-gray-900 mb-4">Előfizetési csomagok</h3>
      
      <div className="space-y-4">
        {plans.map((plan) => (
          <div
            key={plan.id}
            className={`relative border rounded-lg p-4 transition-all ${
              plan.popular
                ? 'border-blue-500 bg-blue-50'
                : 'border-gray-200 hover:border-gray-300'
            }`}
          >
            {plan.popular && (
              <div className="absolute -top-2 left-4">
                <span className="bg-blue-500 text-white text-xs px-2 py-1 rounded-full">
                  Legnépszerűbb
                </span>
              </div>
            )}
            
            <div className="flex justify-between items-start mb-3">
              <div>
                <h4 className="font-semibold text-gray-900">{plan.name}</h4>
                <p className="text-sm text-gray-600">{plan.description}</p>
              </div>
              <div className="text-right">
                <div className="text-2xl font-bold text-gray-900">
                  {plan.price.toLocaleString('hu-HU')} Ft
                </div>
                <div className="text-sm text-gray-600">/{plan.period}</div>
              </div>
            </div>

            <ul className="space-y-2 mb-4">
              {plan.features.map((feature, index) => (
                <li key={index} className="flex items-center text-sm text-gray-600">
                  <span className="text-green-500 mr-2">✓</span>
                  {feature}
                </li>
              ))}
            </ul>

            <button
              onClick={() => handleSelectPlan(plan.id)}
              disabled={isProcessing}
              className={`w-full py-2 px-4 rounded-lg font-medium transition-colors ${
                plan.popular
                  ? 'bg-blue-600 text-white hover:bg-blue-700 disabled:bg-blue-300'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200 disabled:bg-gray-50'
              }`}
            >
              {isProcessing && selectedPlan === plan.id ? (
                <div className="flex items-center justify-center">
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-current mr-2"></div>
                  Feldolgozás...
                </div>
              ) : (
                `Választás - ${plan.price.toLocaleString('hu-HU')} Ft/${plan.period}`
              )}
            </button>
          </div>
        ))}
      </div>

      <div className="mt-6 pt-4 border-t border-gray-200">
        <div className="text-xs text-gray-500 space-y-1">
          <p>• A fizetés OTP SimplePay-en keresztül történik</p>
          <p>• Biztonságos bankkártyás fizetés</p>
          <p>• Bármikor lemondható</p>
          <p>• 30 napos pénzvisszafizetési garancia</p>
        </div>
      </div>
    </div>
  );
}
