'use client';

import { useState } from 'react';
import { format } from 'date-fns';
import { hu } from 'date-fns/locale';

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

interface SubscriptionStatusCardProps {
  userData: UserData | null;
}

export default function SubscriptionStatusCard({ userData }: SubscriptionStatusCardProps) {
  const [isLoading, setIsLoading] = useState(false);

  if (!userData) {
    return (
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="animate-pulse">
          <div className="h-4 bg-gray-200 rounded w-1/4 mb-4"></div>
          <div className="h-8 bg-gray-200 rounded w-1/2 mb-2"></div>
          <div className="h-4 bg-gray-200 rounded w-3/4"></div>
        </div>
      </div>
    );
  }

  const getStatusInfo = () => {
    const { subscriptionStatus, isSubscriptionActive, subscriptionEndDate } = userData;
    
    if (subscriptionStatus === 'premium' && isSubscriptionActive) {
      return {
        status: 'Aktív Premium',
        color: 'green',
        icon: '✅',
        description: 'Előfizetése aktív és minden funkció elérhető'
      };
    } else if (subscriptionStatus === 'expired' || (!isSubscriptionActive && subscriptionStatus === 'premium')) {
      return {
        status: 'Lejárt előfizetés',
        color: 'red',
        icon: '⚠️',
        description: 'Előfizetése lejárt, frissítse a fizetést a folytatáshoz'
      };
    } else if (subscriptionStatus === 'free') {
      return {
        status: 'Ingyenes fiók',
        color: 'blue',
        icon: '🆓',
        description: 'Korlátozott funkciók elérhetők'
      };
    } else {
      return {
        status: 'Ismeretlen állapot',
        color: 'gray',
        icon: '❓',
        description: 'Nem sikerült meghatározni az előfizetési állapotot'
      };
    }
  };

  const getTrialInfo = () => {
    const { subscription } = userData;
    if (subscription?.status === 'TRIAL') {
      return {
        isTrial: true,
        endTime: subscription.endTime
      };
    }
    return { isTrial: false };
  };

  const formatDate = (date: any) => {
    if (!date) return 'N/A';
    
    try {
      if (date.toDate) {
        // Firestore Timestamp
        return format(date.toDate(), 'yyyy. MMMM dd.', { locale: hu });
      } else if (typeof date === 'string') {
        // ISO string
        return format(new Date(date), 'yyyy. MMMM dd.', { locale: hu });
      } else if (date.seconds) {
        // Firestore Timestamp object
        return format(new Date(date.seconds * 1000), 'yyyy. MMMM dd.', { locale: hu });
      }
      return 'N/A';
    } catch (error) {
      console.error('Date formatting error:', error);
      return 'N/A';
    }
  };

  const getRemainingDays = (endDate: any) => {
    if (!endDate) return null;
    
    try {
      let date: Date;
      if (endDate.toDate) {
        date = endDate.toDate();
      } else if (typeof endDate === 'string') {
        date = new Date(endDate);
      } else if (endDate.seconds) {
        date = new Date(endDate.seconds * 1000);
      } else {
        return null;
      }
      
      const now = new Date();
      const diffTime = date.getTime() - now.getTime();
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
      
      return diffDays > 0 ? diffDays : 0;
    } catch (error) {
      console.error('Date calculation error:', error);
      return null;
    }
  };

  const statusInfo = getStatusInfo();
  const trialInfo = getTrialInfo();
  const remainingDays = getRemainingDays(userData.subscriptionEndDate);

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <div className="flex items-start justify-between mb-6">
        <div>
          <h2 className="text-xl font-semibold text-gray-900">Előfizetési állapot</h2>
          <p className="text-sm text-gray-600 mt-1">
            {userData.displayName || userData.email}
          </p>
        </div>
        <div className="text-right">
          <div className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${
            statusInfo.color === 'green' ? 'bg-green-100 text-green-800' :
            statusInfo.color === 'red' ? 'bg-red-100 text-red-800' :
            statusInfo.color === 'blue' ? 'bg-blue-100 text-blue-800' :
            'bg-gray-100 text-gray-800'
          }`}>
            <span className="mr-2">{statusInfo.icon}</span>
            {statusInfo.status}
          </div>
        </div>
      </div>

      <div className="space-y-4">
        <div>
          <p className="text-sm text-gray-600 mb-2">{statusInfo.description}</p>
        </div>

        {trialInfo.isTrial && (
          <div className="bg-purple-50 border border-purple-200 rounded-lg p-4">
            <div className="flex items-center">
              <span className="text-purple-600 text-lg mr-2">🎯</span>
              <div>
                <p className="text-sm font-medium text-purple-900">Próbaidőszak aktív</p>
                <p className="text-xs text-purple-700">
                  {trialInfo.endTime ? `Lejár: ${formatDate(trialInfo.endTime)}` : 'Próbaidőszak folyamatban'}
                </p>
              </div>
            </div>
          </div>
        )}

        {userData.subscriptionEndDate && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <p className="text-sm font-medium text-gray-700">Lejárati dátum</p>
              <p className="text-sm text-gray-600">
                {formatDate(userData.subscriptionEndDate)}
              </p>
            </div>
            {remainingDays !== null && remainingDays > 0 && (
              <div>
                <p className="text-sm font-medium text-gray-700">Hátralévő napok</p>
                <p className="text-sm text-gray-600">
                  {remainingDays} nap
                </p>
              </div>
            )}
          </div>
        )}

        {userData.subscription?.source && (
          <div>
            <p className="text-sm font-medium text-gray-700">Fizetési forrás</p>
            <p className="text-sm text-gray-600">
              {userData.subscription.source === 'google_play' ? 'Google Play Store' :
               userData.subscription.source === 'otp_simplepay' ? 'OTP SimplePay' :
               userData.subscription.source === 'registration_trial' ? 'Regisztrációs próbaidő' :
               userData.subscription.source}
            </p>
          </div>
        )}

        {userData.lastPaymentDate && (
          <div>
            <p className="text-sm font-medium text-gray-700">Utolsó fizetés</p>
            <p className="text-sm text-gray-600">
              {formatDate(userData.lastPaymentDate)}
            </p>
          </div>
        )}
      </div>

      {/* Akció gombok */}
      <div className="mt-6 pt-6 border-t border-gray-200">
        <div className="flex flex-col sm:flex-row gap-3">
          {statusInfo.color === 'red' && (
            <button
              onClick={() => {
                // Navigate to payment
                window.location.href = '/subscription/upgrade';
              }}
              className="flex-1 bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors text-sm font-medium"
            >
              Előfizetés megújítása
            </button>
          )}
          
          {statusInfo.color === 'blue' && (
            <button
              onClick={() => {
                // Navigate to upgrade
                window.location.href = '/subscription/upgrade';
              }}
              className="flex-1 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium"
            >
              Premium előfizetés
            </button>
          )}

          <button
            onClick={() => {
              // Refresh data
              window.location.reload();
            }}
            className="flex-1 bg-gray-100 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-200 transition-colors text-sm font-medium"
          >
            Adatok frissítése
          </button>
        </div>
      </div>
    </div>
  );
}
