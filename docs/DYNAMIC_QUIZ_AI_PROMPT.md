# Feladatleírás: Dinamikus Kvíz Funkció Implementálása a Mobilalkalmazásban

## 1. A Funkció Célja és Működése

A **Dinamikus Kvíz** egy új jegyzettípus, amelynek célja, hogy a felhasználók számára interaktív, véletlenszerűsített teszteket biztosítson. Ahelyett, hogy a kérdések statikusan a jegyzet HTML kódjában lennének, a rendszer egy központi **Kérdésbankból** (`question_banks` kollekció) dolgozik.

**A Működés Lényege:**
1.  Az admin felületen létrehozunk egy **Kérdésbankot**, és hozzárendeljük egy **Kategóriához** (pl. "Anatómia"). Ezt feltöltjük a témához tartozó kérdésekkel.
2.  Az admin létrehoz egy **Interaktív Jegyzetet**, aminek a típusát beállítja **`dynamic_quiz`**-ra, a kategóriáját pedig szintén **"Anatómia"**-ra. A jegyzet HTML tartalma egy általános "kvíz-sablon", ami egy speciális helyőrzőt (`/*KÉRDÉSEK_HELYE*/`) tartalmaz a kérdések helyén.
3.  Amikor a felhasználó a mobilalkalmazásban megnyitja ezt a jegyzetet, az app a háttérben:
    a. Felismeri, hogy ez egy dinamikus kvíz, és megnézi a kategóriáját ("Anatómia").
    b. Lekérdezi a `question_banks` kollekcióból azt a dokumentumot, amelynek a kategóriája "Anatómia".
    c. A kapott kérdésbankból véletlenszerűen kiválaszt egy előre meghatározott számú kérdést (pl. 10-et).
    d. Ezt a 10 kérdést JSON formátumba alakítja, és behelyettesíti a HTML sablonban lévő `/*KÉRDÉSEK_HELYE*/` helyőrző helyére.
    e. A kész, feltöltött HTML-t jeleníti meg a felhasználónak.

## 2. Felhasználói Élmény a Mobilalkalmazásban

*   A felhasználó elindít egy kvízt.
*   Minden alkalommal más sorrendben, és potenciálisan más kérdéseket kap.
*   Válaszadás után azonnali vizuális visszajelzést kap (helyes/helytelen).
*   Megjelenik a helyes válaszhoz tartozó indoklás.
*   A kvíz végén egy összesített eredménnyel és újrapróbálkozási lehetőséggel találkozik.

## 3. Elvégzendő Fejlesztési Feladatok a Mobilalkalmazásban

### A. Adatlekérdezési Logika Implementálása

Módosítani kell a jegyzetmegtekintő logikáját. Amikor a betöltendő jegyzet `type` mezőjének értéke `'dynamic_quiz'`, a következő lépéseket kell végrehajtani:

1.  **Jegyzet Adatainak Lekérése:** A `notes` kollekcióból le kell kérdezni a jegyzet dokumentumát az `noteId` alapján.
2.  **Kategória Meghatározása:** Ki kell olvasni a jegyzet `category` mezőjét.
3.  **Kérdésbank Lekérdezése:** Egy új lekérdezést kell indítani a `question_banks` kollekcióra, ahol a `category` mező megegyezik a jegyzet kategóriájával. `(collection('question_banks').where('category', isEqualTo: noteCategory).limit(1))`
4.  **Kérdések Feldolgozása:**
    *   A kapott kérdésbank dokumentumból ki kell nyerni a `questions` tömböt.
    *   A tömb elemeit véletlenszerűen össze kell keverni (`questions.shuffle()`).
    *   Ki kell választani az első X elemet (pl. `questions.take(10)`). Ha kevesebb kérdés van, akkor az összeset.
5.  **HTML Generálás:**
    *   A kiválasztott kérdéseket JSON formátumú stringgé kell alakítani (`jsonEncode`).
    *   Be kell tölteni a jegyzet `pages` mezőjéből a HTML sablont.
    *   A sablonban ki kell cserélni a `/*KÉRDÉSEK_HELYE*/` stringet a generált JSON stringre.
6.  **Megjelenítés:** Az így kapott, dinamikusan generált HTML kódot kell átadni a megjelenítő `WebView`-nek.

### B. Firestore Biztonsági Szabályok (Referencia)

Biztosítani kell, hogy a mobilalkalmazás felhasználói olvasási joggal rendelkezzenek a `question_banks` kollekcióra. A jelenlegi szabályrendszer már tartalmazza ezt a szabályt, ami minden bejelentkezett felhasználónak engedélyezi az olvasást:

```javascript
match /question_banks/{bankId} {
  allow read, write: if request.auth != null
               && request.auth.token.email in ['tattila.ninox@gmail.com', 'tolgyesi.attila@univerz.eu'];
}
```
**Fontos:** Ezt a szabályt ki kell egészíteni úgy, hogy minden authentikált felhasználó olvashassa a kérdésbankokat, ne csak az adminok. A javasolt szabály:
```javascript
match /question_banks/{bankId} {
  allow read: if request.auth != null;
  allow write: if request.auth.token.email in ['tattila.ninox@gmail.com', 'tolgyesi.attila@univerz.eu'];
}
```

### C. Hibakezelés

Az alkalmazásnak fel kell készülnie a következő hibalehetőségekre:

*   **Nincs a kategóriához tartozó kérdésbank:** A felhasználó egy informatív üzenetet kapjon (pl. "Ehhez a témakörhöz jelenleg nem tartozik kvíz.").
*   **A kérdésbank üres:** Hasonló üzenet jelenjen meg, mint az előző pontban.
*   **Hálózati hiba:** A lekérdezés során fellépő hálózati hibát kezelni kell, és újrapróbálkozási lehetőséget kell biztosítani.

## 4. Adatmodell Referencia

**Kérdésbank (`question_banks` kollekció):**
```json
{
  "name": "Kártevőirtási Szabályok",
  "category": "Kártevőirtás",
  "questions": [
    {
      "question": "Melyik a legfontosabb dokumentum...?",
      "options": [
        { "text": "A megrendelő utasítása.", "isCorrect": false, "rationale": "A biztonsági előírásokat jogi szabályok határozzák meg." },
        { "text": "A Biztonsági Adatlap (SDS).", "isCorrect": true, "rationale": "A 8-as pontja tartalmazza a kötelező védőfelszerelést." },
        { "text": "A cég belső szabályzata.", "isCorrect": false, "rationale": "A belső szabályzatnak is egy magasabb rendű dokumentumon kell alapulnia." },
        { "text": "A szakember tapasztalata.", "isCorrect": false, "rationale": "A tapasztalat fontos, de a jogszabály konkrét dokumentumra hivatkozik." }
      ]
    }
  ]
}
```

**Kvíz Jegyzet (`notes` kollekció):**
```json
{
  "title": "Kvíz: Szabályok és Előírások",
  "category": "Kártevőirtás",
  "type": "dynamic_quiz",
  "pages": [
    "<!DOCTYPE html>...<script>const quizData = /*KÉRDÉSEK_HELYE*/; ...</script></html>"
  ]
}
```

Ez a specifikáció biztosítja a szükséges információkat a dinamikus kvíz funkció mobilalkalmazásba történő, sikeres implementálásához. 