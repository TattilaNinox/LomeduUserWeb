# OTP SimplePay v2 Integráció - Teljes Implementációs Útmutató

## 📋 Áttekintés

Ez a dokumentum leírja a Flutter Web alkalmazás OTP SimplePay v2 integrációjának teljes implementációját. A rendszer hibrid fizetési megoldást biztosít: webes felhasználók SimplePay-en keresztül, mobil felhasználók Google Play Billing-en keresztül fizethetnek.

## 🎯 Új Funkciók (2025. október)

### ✅ Implementált Fejlesztések

1. **IPN Confirm Visszaigazolás** (SimplePay 9.6.2 követelmény)
   - Aláírt JSON válasz `receiveDate` mezővel
   - HMAC-SHA384 signature a válasz headerben
   - Teljes megfelelés az éles környezeti követelményeknek

2. **Audit Log Rendszer**
   - `payment_audit_logs` Firestore kollekció
   - Minden tranzakció részletes naplózása
   - Környezet (sandbox/production) azonosítás
   - Metaadatok: userId, orderRef, action, timestamp

3. **Környezet Státusz UI**
   - Sandbox/Production jelzés a subscription képernyőn
   - Vizuális megkülönböztetés (kék = teszt, piros = éles)
   - Real-time környezet megjelenítés

4. **Query Státusz Gomb**
   - Manuális fizetési státusz ellenőrzés
   - SimplePay Query API integráció
   - Auto-complete funkció sikeres fizetéseknél
   - Részletes státusz információk

5. **Részletes Hibaüzenetek**
   - SimplePay hibakódok emberi nyelvű fordítása
   - 20+ hibakód magyarázat
   - Kontextusos hibaüzenetek

## 🏗️ Architektúra

### Komponensek
- **Flutter Web UI**: React-szerű komponensek Flutter-ben
- **WebPaymentService**: SimplePay v2 API integráció
- **HybridPaymentService**: Platform detection és hibrid logika
- **Cloud Functions**: Szerveroldali fizetési feldolgozás
- **Firestore**: Adatbázis és előfizetési állapot kezelés

### Adatfolyam
1. **Webes fizetés**: Flutter Web → Cloud Functions → SimplePay API → Webhook → Firestore
2. **Mobil fizetés**: Flutter Mobile → Google Play Billing → Cloud Functions → Firestore

## 🔧 Telepítés és Konfiguráció

### 1. Environment Változók

Hozzon létre egy `.env` fájlt a projekt gyökerében:

```env
# SimplePay konfiguráció
SIMPLEPAY_MERCHANT_ID=your_merchant_id_here
SIMPLEPAY_SECRET_KEY=your_secret_key_here
SIMPLEPAY_ENV=sandbox  # vagy 'production'

# Firebase konfiguráció
FIREBASE_PROJECT_ID=orlomed-f8f9f
FIREBASE_CLIENT_EMAIL=your_service_account_email
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY\n-----END PRIVATE KEY-----\n"

# NextAuth konfiguráció (webes alkalmazáshoz)
NEXTAUTH_URL=https://lomedu-user-web.web.app
NEXTAUTH_SECRET=your_nextauth_secret

# Google OAuth
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Környezet (Flutter build-hez)
PRODUCTION=false
```

### 2. Firebase Functions Telepítés

```bash
cd functions
npm install
firebase deploy --only functions
```

### 3. Firestore Szabályok Frissítése

```bash
firebase deploy --only firestore:rules
```

### 4. Flutter Web Build

```bash
flutter build web --dart-define=PRODUCTION=false
```

## 🧪 Tesztelés

### 1. Lokális Fejlesztés

```bash
# Firebase emulátorok indítása
firebase emulators:start

# Flutter web fejlesztés
flutter run -d chrome --web-port 3000
```

### 2. SimplePay Sandbox Tesztelés

#### Teszt Bankkártya Adatok
- **Sikeres fizetés**: 4000 0000 0000 0002
- **Sikertelen fizetés**: 4000 0000 0000 0119
- **CVV**: 123
- **Lejárati dátum**: Bármely jövőbeli dátum

#### Tesztelési Lépések
1. Nyissa meg a webes alkalmazást
2. Navigáljon az előfizetési oldalra
3. Válasszon egy csomagot
4. Használja a teszt bankkártya adatokat
5. Ellenőrizze a Firestore-ban a fizetési rekordot

### 3. Webhook Tesztelés

#### Ngrok használata
```bash
# Ngrok telepítése
npm install -g ngrok

# Ngrok indítása
ngrok http 3000

# Webhook URL beállítása SimplePay-ben
https://your-ngrok-url.ngrok.io/api/webhook/simplepay
```

#### Webhook Tesztelés Postman-nal
```http
POST https://your-ngrok-url.ngrok.io/api/webhook/simplepay
Content-Type: application/json
x-simplepay-signature: your_test_signature

{
  "orderRef": "WEB_test_user_1234567890_abcdefgh",
  "transactionId": "test_transaction_123",
  "orderId": "test_order_456",
  "status": "SUCCESS",
  "total": 2990,
  "items": [
    {
      "ref": "monthly_web",
      "title": "Havi előfizetés",
      "amount": 2990
    }
  ]
}
```

## 📊 Monitoring és Debugging

### 1. Cloud Functions Logok

```bash
# Functions logok megtekintése
firebase functions:log

# Valós idejű logok
firebase functions:log --follow

# Audit logok lekérdezése
firebase firestore:get payment_audit_logs
```

### 2. Firestore Adatok Ellenőrzése

```javascript
// Audit logok
db.collection('payment_audit_logs')
  .orderBy('timestamp', 'desc')
  .limit(50)
  .get()
  .then(snapshot => {
    snapshot.forEach(doc => {
      console.log(doc.id, doc.data());
    });
  });

// Fizetési rekordok
db.collection('web_payments').get().then(snapshot => {
  snapshot.forEach(doc => {
    console.log(doc.id, doc.data());
  });
});
```

### 3. Flutter Debug Logok

```dart
// Debug módban automatikusan megjelennek
debugPrint('Payment initiated: $result');
```

### 4. Audit Log Struktúra

```json
{
  "userId": "user123",
  "orderRef": "WEB_user123_1234567890",
  "action": "PAYMENT_INITIATED|PAYMENT_CONFIRMED|WEBHOOK_RECEIVED|PAYMENT_INITIATION_FAILED|PAYMENT_STATUS_QUERIED",
  "planId": "monthly_premium_prepaid",
  "amount": 4350,
  "environment": "sandbox",
  "timestamp": "2025-10-23T12:34:56Z",
  "metadata": {
    "transactionId": "...",
    "orderId": "...",
    "errorCodes": [],
    "queryStatus": "SUCCESS"
  }
}
```

## 🔒 Biztonsági Megfontolások

### 1. Webhook Aláírás Ellenőrzés
- Minden webhook kérés aláírása HMAC SHA-256-tal ellenőrzött
- Secret key biztonságos tárolása environment változókban

### 2. Firestore Szabályok
- Felhasználók csak saját adataikat olvashatják
- Cloud Functions service account-tal írhatnak

### 3. API Kulcsok
- Production és sandbox kulcsok elkülönítése
- Kulcsok rotálása rendszeresen

## 🚀 Production Deployment

### 1. Environment Változók Beállítása

```bash
# Firebase Functions environment változók (secrets)
firebase functions:secrets:set SIMPLEPAY_MERCHANT_ID
firebase functions:secrets:set SIMPLEPAY_SECRET_KEY
firebase functions:secrets:set SIMPLEPAY_ENV
firebase functions:secrets:set NEXTAUTH_URL

# Flutter Web build production módban
flutter build web --dart-define=PRODUCTION=true
```

### 2. SimplePay Production Beállítások

1. Jelentkezzen be a SimplePay merchant portálra
2. Váltson production környezetre
3. Állítsa be a webhook URL-t: `https://europe-west1-orlomed-f8f9f.cloudfunctions.net/simplepayWebhook`
4. Tesztelje a production API kulcsokat
5. **Fontos**: Az IPN Confirm válasz most már teljes mértékben megfelel a SimplePay 9.6.2 követelményének

### 3. Firebase Production Deploy

```bash
# Functions deployment
firebase deploy --only functions

# Firestore rules deployment
firebase deploy --only firestore:rules

# Hosting deployment (ha használja)
firebase deploy --only hosting
```

### 4. Firestore Indexek (Audit Logokhoz)

```bash
# Az alábbi indexek létrehozása szükséges:
# - payment_audit_logs: userId (ASC), timestamp (DESC)
# - payment_audit_logs: orderRef (ASC), timestamp (DESC)
# - payment_audit_logs: environment (ASC), timestamp (DESC)

firebase firestore:indexes
```

## 📈 Teljesítmény Optimalizálás

### 1. Cloud Functions Optimalizálás
- Cold start csökkentése
- Memory és CPU optimalizálás
- Timeout beállítások

### 2. Flutter Web Optimalizálás
- Tree shaking
- Code splitting
- Asset optimalizálás

### 3. Firestore Optimalizálás
- Indexek létrehozása
- Batch műveletek használata
- Offline cache kezelés

## 🐛 Hibaelhárítás

### Gyakori Problémák

#### 1. SimplePay API Hiba
```
Error: SimplePay API hiba: Invalid merchant
```
**Megoldás**: Ellenőrizze a SIMPLEPAY_MERCHANT_ID-t

#### 2. Webhook Aláírás Hiba
```
Error: Invalid signature in webhook request
```
**Megoldás**: Ellenőrizze a SIMPLEPAY_SECRET_KEY-t és az aláírás számítást

#### 3. Firestore Permission Hiba
```
Error: Missing or insufficient permissions
```
**Megoldás**: Ellenőrizze a Firestore szabályokat

#### 4. Cloud Functions Timeout
```
Error: Function execution took longer than 60s
```
**Megoldás**: Növelje a timeout értéket vagy optimalizálja a kódot

### Debug Lépések

1. **Konfiguráció ellenőrzése**
   ```dart
   PaymentConfig.printConfigurationStatus();
   ```

2. **Network kérések ellenőrzése**
   - Chrome DevTools Network tab
   - Firebase Functions logok

3. **Firestore adatok ellenőrzése**
   - Firebase Console
   - Firestore emulator

## 📚 API Dokumentáció

### WebPaymentService

#### `initiatePayment()`
```dart
final result = await WebPaymentService.initiatePayment(
  planId: 'monthly_web',
  userId: 'user123',
);
```

#### `getPaymentHistory()`
```dart
final history = await WebPaymentService.getPaymentHistory('user123');
```

### HybridPaymentService

#### `getAvailablePlans()`
```dart
final plans = HybridPaymentService.getAvailablePlans();
```

#### `getSubscriptionStatus()`
```dart
final status = await HybridPaymentService.getSubscriptionStatus('user123');
```

### SimplePay Hibakódok

A rendszer automatikusan lefordítja a SimplePay hibakódokat érthető magyar üzenetekre:

| Hibakód | Magyar Magyarázat |
|---------|-------------------|
| 5321 | Aláírási hiba: A SimplePay nem tudta ellenőrizni a kérés aláírását |
| 5001 | Hiányzó merchant azonosító |
| 5002 | Érvénytelen merchant azonosító |
| 5101 | Hiányzó vagy érvénytelen orderRef |
| 5102 | Duplikált orderRef - ez a megrendelés már létezik |
| 5201 | Érvénytelen összeg - negatív vagy nulla |
| 5301 | Hiányzó vagy érvénytelen customer email |
| 5801 | Tranzakció nem található |
| 5802 | Tranzakció már feldolgozva |

### Query Payment Status

```dart
// Cloud Function hívás
final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
final callable = functions.httpsCallable('queryPaymentStatus');

final result = await callable.call({'orderRef': 'WEB_user123_1234567890'});
final data = result.data as Map<String, dynamic>;

print('Status: ${data['status']}');
print('Transaction ID: ${data['transactionId']}');
```

## 🔄 Frissítések és Karbantartás

### 1. SimplePay API Frissítések
- Rendszeres API dokumentáció ellenőrzése
- Breaking changes kezelése
- Version compatibility tesztelése

### 2. Flutter Frissítések
- Flutter SDK frissítése
- Dependencies frissítése
- Breaking changes kezelése

### 3. Firebase Frissítések
- Cloud Functions Node.js verzió frissítése
- Firestore szabályok frissítése
- Security rules optimalizálása

## 📞 Támogatás

### 1. SimplePay Támogatás
- Dokumentáció: https://simplepay.hu/developer
- Támogatás: support@simplepay.hu

### 2. Firebase Támogatás
- Dokumentáció: https://firebase.google.com/docs
- Támogatás: Firebase Console

### 3. Flutter Támogatás
- Dokumentáció: https://flutter.dev/docs
- Közösség: https://flutter.dev/community

---

**Megjegyzés**: Ez a dokumentum folyamatosan frissül. Kérjük, ellenőrizze a legfrissebb verziót a SimplePay szerződés megkötése előtt.
