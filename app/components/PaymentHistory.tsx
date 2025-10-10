'use client';

import { useState, useEffect } from 'react';
import { format } from 'date-fns';
import { hu } from 'date-fns/locale';

interface UserData {
  subscriptionStatus: 'free' | 'premium' | 'expired';
  isSubscriptionActive: boolean;
  subscription?: {
    status: string;
    productId?: string;
    source?: string;
    purchaseToken?: string;
    orderId?: string;
  };
  lastPaymentDate?: any;
}

interface PaymentHistoryProps {
  userData: UserData | null;
}

interface PaymentRecord {
  id: string;
  date: string;
  amount: number;
  status: 'completed' | 'pending' | 'failed';
  method: string;
  description: string;
  invoiceUrl?: string;
}

export default function PaymentHistory({ userData }: PaymentHistoryProps) {
  const [payments, setPayments] = useState<PaymentRecord[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Itt kellene lekérni a valódi fizetési előzményeket
    // Jelenleg mock adatokat használunk
    const mockPayments: PaymentRecord[] = [];
    
    if (userData?.lastPaymentDate) {
      mockPayments.push({
        id: '1',
        date: userData.lastPaymentDate.toDate ? 
          userData.lastPaymentDate.toDate().toISOString() : 
          new Date().toISOString(),
        amount: userData.subscription?.productId?.includes('yearly') ? 29900 : 2990,
        status: 'completed',
        method: userData.subscription?.source === 'google_play' ? 'Google Play' : 'OTP SimplePay',
        description: userData.subscription?.productId?.includes('yearly') ? 
          'Éves előfizetés' : 'Havi előfizetés'
      });
    }

    setPayments(mockPayments);
    setLoading(false);
  }, [userData]);

  const formatDate = (dateString: string) => {
    try {
      return format(new Date(dateString), 'yyyy. MMMM dd. HH:mm', { locale: hu });
    } catch (error) {
      return 'N/A';
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed':
        return 'text-green-600 bg-green-100';
      case 'pending':
        return 'text-yellow-600 bg-yellow-100';
      case 'failed':
        return 'text-red-600 bg-red-100';
      default:
        return 'text-gray-600 bg-gray-100';
    }
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case 'completed':
        return 'Sikeres';
      case 'pending':
        return 'Folyamatban';
      case 'failed':
        return 'Sikertelen';
      default:
        return 'Ismeretlen';
    }
  };

  if (loading) {
    return (
      <div className="bg-white rounded-lg shadow-md p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Fizetési előzmények</h3>
        <div className="animate-pulse space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="flex items-center space-x-4">
              <div className="h-4 bg-gray-200 rounded w-1/4"></div>
              <div className="h-4 bg-gray-200 rounded w-1/4"></div>
              <div className="h-4 bg-gray-200 rounded w-1/4"></div>
              <div className="h-4 bg-gray-200 rounded w-1/4"></div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <h3 className="text-lg font-semibold text-gray-900 mb-4">Fizetési előzmények</h3>
      
      {payments.length === 0 ? (
        <div className="text-center py-8">
          <div className="text-gray-400 text-4xl mb-4">📄</div>
          <p className="text-gray-600">Még nincsenek fizetési előzmények</p>
          <p className="text-sm text-gray-500 mt-1">
            Az első vásárlás után itt jelennek meg a részletek
          </p>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Dátum
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Leírás
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Összeg
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Fizetési mód
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Státusz
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Műveletek
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {payments.map((payment) => (
                <tr key={payment.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {formatDate(payment.date)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {payment.description}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {payment.amount.toLocaleString('hu-HU')} Ft
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {payment.method}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${getStatusColor(payment.status)}`}>
                      {getStatusText(payment.status)}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {payment.status === 'completed' && payment.invoiceUrl && (
                      <a
                        href={payment.invoiceUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-blue-600 hover:text-blue-800"
                      >
                        Számla letöltése
                      </a>
                    )}
                    {payment.status === 'completed' && !payment.invoiceUrl && (
                      <span className="text-gray-400">Számla nem elérhető</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="mt-6 pt-4 border-t border-gray-200">
        <div className="flex justify-between items-center">
          <p className="text-sm text-gray-600">
            {payments.length} fizetés található
          </p>
          <button
            onClick={() => {
              // Itt lehetne exportálni a fizetési előzményeket
              alert('Export funkció hamarosan elérhető');
            }}
            className="text-sm text-blue-600 hover:text-blue-800"
          >
            Exportálás
          </button>
        </div>
      </div>
    </div>
  );
}






