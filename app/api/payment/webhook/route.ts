import { NextRequest, NextResponse } from 'next/server';
import { getFirestore } from 'firebase-admin/firestore';
import { initializeApp, getApps, cert } from 'firebase-admin/app';
import crypto from 'crypto';

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

// SimplePay webhook aláírás ellenőrzése
function verifySignature(payload: string, signature: string, secret: string): boolean {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
  
  return crypto.timingSafeEqual(
    Buffer.from(signature, 'hex'),
    Buffer.from(expectedSignature, 'hex')
  );
}

// Előfizetés aktiválása
async function grantSubscription(
  userId: string,
  simplePayTransactionId: string,
  simplePayOrderId: string,
  productId: string,
  subscriptionDays: number
) {
  const userRef = db.collection('users').doc(userId);
  
  const now = new Date();
  const expiryDate = new Date(now.getTime() + (subscriptionDays * 24 * 60 * 60 * 1000));
  
  const subscriptionData = {
    // Kompatibilitási mezők (a mobilalkalmazás ezeket használja)
    isSubscriptionActive: true,
    subscriptionStatus: 'premium',
    subscriptionEndDate: expiryDate,
    
    // Részletes adatok
    subscription: {
      status: 'ACTIVE',
      productId: productId,
      purchaseToken: simplePayTransactionId,
      orderId: simplePayOrderId,
      endTime: expiryDate.toISOString(),
      lastUpdateTime: now.toISOString(),
      source: 'otp_simplepay',
    },
    
    // Meta adatok
    lastPaymentDate: now,
    updatedAt: now,
  };

  try {
    await userRef.set(subscriptionData, { merge: true });
    console.log(`Successfully granted subscription for user ${userId} until ${expiryDate.toISOString()}`);
    return { success: true };
  } catch (error) {
    console.error(`Failed to grant subscription for user ${userId}:`, error);
    return { success: false, error: error.message };
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.text();
    const signature = request.headers.get('x-simplepay-signature');
    
    if (!signature) {
      console.error('Missing signature in webhook request');
      return NextResponse.json({ error: 'Missing signature' }, { status: 400 });
    }

    // Aláírás ellenőrzése
    const secret = process.env.SIMPLEPAY_SECRET_KEY!;
    if (!verifySignature(body, signature, secret)) {
      console.error('Invalid signature in webhook request');
      return NextResponse.json({ error: 'Invalid signature' }, { status: 401 });
    }

    const webhookData = JSON.parse(body);
    console.log('SimplePay webhook received:', webhookData);

    // Csak sikeres fizetéseket dolgozunk fel
    if (webhookData.status !== 'SUCCESS') {
      console.log('Payment not successful, ignoring webhook');
      return NextResponse.json({ success: true });
    }

    const {
      orderRef,
      transactionId,
      orderId,
      total,
      items
    } = webhookData;

    // Felhasználó azonosítása az orderRef-ből
    // Az orderRef formátuma: WEB_timestamp_random
    const userId = orderRef.split('_')[1]; // Ez egy egyszerűsített megoldás
    // Valós implementációban a userId-t az orderRef-ben kellene tárolni

    if (!userId) {
      console.error('Could not extract userId from orderRef:', orderRef);
      return NextResponse.json({ error: 'Invalid order reference' }, { status: 400 });
    }

    // Termék azonosítása
    const productId = items?.[0]?.ref || 'unknown';
    const subscriptionDays = productId === 'yearly' ? 365 : 30;

    // Előfizetés aktiválása
    const result = await grantSubscription(
      userId,
      transactionId,
      orderId,
      productId,
      subscriptionDays
    );

    if (!result.success) {
      console.error('Failed to grant subscription:', result.error);
      return NextResponse.json({ error: 'Failed to grant subscription' }, { status: 500 });
    }

    // Webhook feldolgozás naplózása
    await db.collection('processed_transactions').doc(transactionId).set({
      orderRef,
      transactionId,
      orderId,
      userId,
      productId,
      amount: total,
      processedAt: new Date(),
      status: 'completed'
    });

    return NextResponse.json({ success: true });

  } catch (error) {
    console.error('Webhook processing error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
