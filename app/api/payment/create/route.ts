import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { authOptions } from '../../auth/[...nextauth]/route';

// SimplePay konfiguráció
const SIMPLEPAY_CONFIG = {
  merchantId: process.env.SIMPLEPAY_MERCHANT_ID!,
  secretKey: process.env.SIMPLEPAY_SECRET_KEY!,
  baseUrl: process.env.NODE_ENV === 'production' 
    ? 'https://secure.simplepay.hu/payment/v1/' 
    : 'https://sandbox.simplepay.hu/payment/v1/',
  webhookUrl: `${process.env.NEXTAUTH_URL}/api/payment/webhook`,
  successUrl: `${process.env.NEXTAUTH_URL}/subscription?success=true`,
  cancelUrl: `${process.env.NEXTAUTH_URL}/subscription?canceled=true`,
};

interface CreatePaymentRequest {
  planId: string;
  userId: string;
}

interface SimplePayRequest {
  merchant: string;
  orderRef: string;
  customerEmail: string;
  customerName?: string;
  language: string;
  currency: string;
  total: number;
  items: Array<{
    ref: string;
    title: string;
    description: string;
    amount: number;
    price: number;
    quantity: number;
  }>;
  methods: string[];
  url: string;
  timeout: string;
  invoice: string;
  redirectUrl: string;
}

const plans = {
  monthly: {
    name: 'Havi előfizetés',
    price: 2990,
    description: 'Teljes hozzáférés minden funkcióhoz'
  },
  yearly: {
    name: 'Éves előfizetés', 
    price: 29900,
    description: '2 hónap ingyen a havi árhoz képest'
  }
};

export async function POST(request: NextRequest) {
  try {
    // Felhasználó hitelesítés ellenőrzése
    const session = await getServerSession(authOptions);
    if (!session?.user?.email) {
      return NextResponse.json(
        { error: 'Nem vagy bejelentkezve' },
        { status: 401 }
      );
    }

    const body: CreatePaymentRequest = await request.json();
    const { planId, userId } = body;

    // Terv validálása
    const plan = plans[planId as keyof typeof plans];
    if (!plan) {
      return NextResponse.json(
        { error: 'Érvénytelen csomag' },
        { status: 400 }
      );
    }

    // Egyedi rendelés azonosító generálása
    const orderRef = `WEB_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    // SimplePay kérés összeállítása
    const simplePayRequest: SimplePayRequest = {
      merchant: SIMPLEPAY_CONFIG.merchantId,
      orderRef: orderRef,
      customerEmail: session.user.email,
      customerName: session.user.name || undefined,
      language: 'HU',
      currency: 'HUF',
      total: plan.price,
      items: [{
        ref: planId,
        title: plan.name,
        description: plan.description,
        amount: plan.price,
        price: plan.price,
        quantity: 1
      }],
      methods: ['CARD'], // Bankkártya fizetés
      url: SIMPLEPAY_CONFIG.webhookUrl,
      timeout: '2024-12-31T23:59:59+00:00',
      invoice: '1', // Számla generálás
      redirectUrl: SIMPLEPAY_CONFIG.successUrl
    };

    // SimplePay API hívás
    const response = await fetch(`${SIMPLEPAY_CONFIG.baseUrl}start`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SIMPLEPAY_CONFIG.secretKey}`,
      },
      body: JSON.stringify(simplePayRequest),
    });

    if (!response.ok) {
      const errorData = await response.text();
      console.error('SimplePay API error:', errorData);
      return NextResponse.json(
        { error: 'Fizetési folyamat indítása sikertelen' },
        { status: 500 }
      );
    }

    const paymentData = await response.json();

    // Fizetési URL visszaadása
    return NextResponse.json({
      paymentUrl: paymentData.paymentUrl,
      orderRef: orderRef,
      amount: plan.price
    });

  } catch (error) {
    console.error('Payment creation error:', error);
    return NextResponse.json(
      { error: 'Belső szerver hiba' },
      { status: 500 }
    );
  }
}
