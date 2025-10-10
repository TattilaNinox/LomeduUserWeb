# Lomedu Webes Előfizetési Rendszer

Ez a dokumentum leírja, hogyan kell beállítani a webes előfizetési rendszert OTP SimplePay integrációval.

## 🚀 Funkciók

- **Előfizetési státusz megjelenítése** - Valós idejű előfizetési információk
- **OTP SimplePay integráció** - Biztonságos fizetési folyamat
- **7 napos próbaidőszak** - Automatikus aktiválás regisztrációkor
- **Fizetési előzmények** - Teljes tranzakció történet
- **Responsive design** - Mobil és desktop optimalizált

## 📁 Fájlstruktúra

```
app/
├── subscription/
│   ├── page.tsx                 # Fő előfizetési oldal
│   └── upgrade/
│       └── page.tsx            # Csomag választó oldal
├── components/
│   ├── SubscriptionStatusCard.tsx  # Státusz kártya
│   ├── PaymentPlans.tsx           # Fizetési csomagok
│   └── PaymentHistory.tsx         # Fizetési előzmények
├── api/
│   ├── payment/
│   │   ├── create/route.ts        # Fizetés létrehozása
│   │   └── webhook/route.ts       # SimplePay webhook
│   └── auth/
│       └── [...nextauth]/route.ts # NextAuth konfiguráció
└── providers/
    └── AuthProvider.tsx           # Auth context
```

## ⚙️ Telepítés

### 1. Függőségek telepítése

```bash
npm install
```

### 2. Környezeti változók beállítása

Hozzon létre egy `.env.local` fájlt a projekt gyökerében:

```env
# Firebase konfiguráció
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=your-client-email
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY\n-----END PRIVATE KEY-----\n"

# NextAuth konfiguráció
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=your-nextauth-secret

# Google OAuth
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret

# OTP SimplePay konfiguráció
SIMPLEPAY_MERCHANT_ID=your-merchant-id
SIMPLEPAY_SECRET_KEY=your-secret-key
```

### 3. Firebase beállítás

1. **Firebase Admin SDK kulcsok**:
   - Menjen a Firebase Console-ba
   - Projekt beállítások → Szolgáltatásfiókok
   - Generáljon egy új privát kulcsot
   - Töltse le a JSON fájlt és másolja ki a szükséges mezőket

2. **Firestore szabályok**:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
       match /processed_transactions/{transactionId} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

### 4. OTP SimplePay beállítás

1. **Regisztráció**:
   - Regisztráljon az [OTP SimplePay](https://simplepay.hu) oldalon
   - Válassza az "Egyedi fejlesztés" opciót

2. **API kulcsok**:
   - Merchant ID és Secret Key beszerzése
   - Webhook URL beállítása: `https://yourdomain.com/api/payment/webhook`

3. **Tesztelés**:
   - Sandbox környezet használata fejlesztéskor
   - Production környezet éles használathoz

### 5. Google OAuth beállítás

1. **Google Cloud Console**:
   - Hozzon létre egy új projektet vagy válasszon egy meglévőt
   - Engedélyezze a Google+ API-t
   - Hozzon létre OAuth 2.0 hitelesítő adatokat

2. **Authorized redirect URIs**:
   ```
   http://localhost:3000/api/auth/callback/google
   https://yourdomain.com/api/auth/callback/google
   ```

## 🔧 Használat

### Előfizetési oldal megnyitása

```typescript
// Navigálás az előfizetési oldalra
router.push('/subscription');
```

### Fizetési folyamat indítása

```typescript
// API hívás a fizetés létrehozásához
const response = await fetch('/api/payment/create', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    planId: 'monthly', // vagy 'yearly'
    userId: 'user-id'
  })
});

const { paymentUrl } = await response.json();
window.location.href = paymentUrl;
```

### Webhook feldolgozás

A SimplePay automatikusan hívja a webhook endpoint-ot sikeres fizetés esetén:

```
POST /api/payment/webhook
```

## 📊 Adatbázis séma

### Users kollekció

```javascript
{
  email: string,
  displayName: string,
  userType: 'user' | 'admin',
  
  // Előfizetési mezők
  isSubscriptionActive: boolean,
  subscriptionStatus: 'free' | 'premium' | 'expired',
  subscriptionEndDate: Timestamp,
  
  // Részletes előfizetési adatok
  subscription: {
    status: 'ACTIVE' | 'TRIAL' | 'EXPIRED',
    productId: string,
    purchaseToken: string,
    orderId: string,
    endTime: string,
    lastUpdateTime: string,
    source: 'google_play' | 'otp_simplepay' | 'registration_trial'
  },
  
  // Meta adatok
  lastPaymentDate: Timestamp,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Processed Transactions kollekció

```javascript
{
  orderRef: string,
  transactionId: string,
  orderId: string,
  userId: string,
  productId: string,
  amount: number,
  processedAt: Timestamp,
  status: 'completed' | 'failed'
}
```

## 🧪 Tesztelés

### 1. Lokális fejlesztés

```bash
npm run dev
```

### 2. SimplePay sandbox tesztelés

- Használja a sandbox környezetet fejlesztéskor
- Teszt bankkártya adatok használata
- Webhook tesztelése ngrok-kal

### 3. Firebase Emulator Suite

```bash
# Firebase emulátorok indítása
firebase emulators:start
```

## 🚀 Deployment

### Vercel (ajánlott)

1. **GitHub integráció**:
   - Csatlakoztassa a GitHub repository-t
   - Automatikus deployment minden push-nál

2. **Környezeti változók**:
   - Adja hozzá a szükséges env változókat a Vercel dashboard-on

3. **Domain beállítás**:
   - Állítsa be a custom domain-t
   - Frissítse a NEXTAUTH_URL-t

### Egyéb platformok

- **Netlify**: Statikus site generálás
- **Railway**: Full-stack alkalmazás
- **DigitalOcean**: VPS deployment

## 🔒 Biztonság

### 1. Webhook aláírás ellenőrzés

```typescript
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
```

### 2. Firebase Security Rules

```javascript
// Felhasználói adatok védelme
match /users/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

### 3. API Rate Limiting

```typescript
// API hívások korlátozása
const rateLimit = new Map();

export async function POST(request: NextRequest) {
  const ip = request.ip;
  const now = Date.now();
  const windowMs = 15 * 60 * 1000; // 15 perc
  const maxRequests = 100;
  
  // Rate limiting logika...
}
```

## 📈 Monitoring

### 1. Firebase Analytics

```typescript
// Események követése
import { getAnalytics, logEvent } from 'firebase/analytics';

logEvent(analytics, 'subscription_created', {
  plan_id: 'monthly',
  value: 2990,
  currency: 'HUF'
});
```

### 2. Error Tracking

```typescript
// Hibák naplózása
try {
  // Fizetési logika
} catch (error) {
  console.error('Payment error:', error);
  // Sentry vagy más error tracking szolgáltatás
}
```

## 🆘 Hibaelhárítás

### Gyakori problémák

1. **Firebase kapcsolat hiba**:
   - Ellenőrizze a service account kulcsokat
   - Győződjön meg róla, hogy a Firestore engedélyezve van

2. **SimplePay webhook nem működik**:
   - Ellenőrizze a webhook URL-t
   - Tesztelje ngrok-kal lokálisan

3. **NextAuth konfiguráció hiba**:
   - Ellenőrizze a Google OAuth beállításokat
   - Győződjön meg róla, hogy a redirect URI helyes

### Logok ellenőrzése

```bash
# Vercel logok
vercel logs

# Firebase logok
firebase functions:log
```

## 📞 Támogatás

Ha problémába ütközik, ellenőrizze:

1. **Dokumentáció**: [Next.js](https://nextjs.org/docs), [Firebase](https://firebase.google.com/docs)
2. **SimplePay dokumentáció**: [SimplePay API](https://simplepay.hu/developer)
3. **GitHub Issues**: Hozzon létre egy issue-t a repository-ban

## 🔄 Frissítések

### Verzió követés

- **v1.0.0**: Alapvető előfizetési rendszer
- **v1.1.0**: SimplePay integráció
- **v1.2.0**: Fizetési előzmények
- **v1.3.0**: Responsive design

### Breaking Changes

- **v1.1.0**: Firebase Admin SDK szükséges
- **v1.2.0**: NextAuth v4 szükséges

---

**Megjegyzés**: Ez a dokumentum folyamatosan frissül. Kérjük, ellenőrizze a legfrissebb verziót.






