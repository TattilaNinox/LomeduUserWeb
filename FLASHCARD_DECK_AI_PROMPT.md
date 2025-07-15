# Feladatleírás: Tanulókártya Paklik Megjelenítése a Mobilalkalmazásban

## 1. A Funkció Célja és Lényege

A **Tanulókártya Pakli** ("flashcard deck") egy jegyzettípus, amely kétoldalas kártyák segítségével segíti a hallgatók memorizálását.
Az adminfelületen a szerkesztő megadhat egy paklicímet, kategóriát, majd egy tetszőleges számú kártyát (előlapi & hátlapi szöveg).  
A pakli a `notes` kollekcióban tárolódik, ahol a dokumentum `type` mezője **`"deck"`**.

## 2. Adatmodell Referencia

```json
{
  "title": "Farmakológia – alapfogalmak",
  "category_id": "abc123",           // referencia a categories kollekcióra
  "category": "Farmakológia",        // denormalizált név (gyors listázáshoz)
  "type": "deck",
  "status": "Draft",                // vagy Published / Archived
  "flashcards": [
    { "front": "Mi a farmakokinetika?", "back": "A gyógyszer sorsának vizsgálata a szervezetben." },
    { "front": "Mi a farmakodinamika?", "back": "A gyógyszer hatásának vizsgálata a szervezetre." }
  ],
  "tags": ["farmakológia", "alap"],
  "createdAt": "<timestamp>",
  "modified": "<timestamp>",
  "deletedAt": null                  // soft-delete esetén timestamp
}
```
*Megjegyzés:* A `flashcards` tömbben a kártyák sorrendje fixen számít – ezt az admin drag-and-drop rendezi, majd menti.

## 3. Felhasználói Forgatókönyv (User Story)

1. **Dia**, a hallgató, a *Jegyzetek* listában meglát egy paklit (lap ikon).  
2. Rákattint a *„Farmakológia – alapfogalmak"* címre.  
3. Az alkalmazás egy új képernyőn rácsban megjeleníti a kártyákat.  
4. Dia rányom egy kártyára → az átfordul (flip-animáció) és megmutatja a hátlap szövegét.  
5. Újabb érintéssel visszafordul a kártya.  
6. (Későbbi bővítés) A felhasználó válthat tanuló/teszt üzemmód között, vagy exportálhatja a paklit.

## 4. Megjelenítési Logika a Mobilalkalmazásban

1. **Lekérdezés**:
   ```dart
   final doc = await FirebaseFirestore.instance.collection('notes').doc(deckId).get();
   final data = doc.data()!;
   if (data['type'] != 'deck') return; // védőág
   final cards = List<Map<String, dynamic>>.from(data['flashcards'] ?? []);
   ```
2. **Képernyő felépítése**:
   * Ha a lista **üres**, jelenítsünk meg informatív üzenetet („Ez a pakli üres.”).
   * Egy **GridView**-t ajánlott használni, `childAspectRatio: 1.6` körüli értékkel, hogy a kártya aránya reális maradjon.
3. **Kártya komponens**: használható ugyanaz az elv, mint a weben (lásd `FlippableCard`):
   ```dart
   class FlashcardWidget extends StatefulWidget {
     final String front;
     final String back;
     const FlashcardWidget({required this.front, required this.back});
     // ...
   }
   ```
   * Fronton nagy, félkövér szöveg → tap → animáció → hátlap (justify + automata elválasztás).
4. **Felhasználói állapot** (későbbi bővítés):
   * Hány kártyát nézett át?  
   * Jelölje-e a "tudom / nem tudom" állapotot?
5. **Hibakezelés**:
   * **Offline** → Cache-eljük a pakli JSON-t, hogy internet nélkül is megjelenjen.  
   * **Hálózati hiba** → Snackbar "Hálózati hiba, próbáld újra." gombbal.

## 5. UI Vázlat

```mermaid
flowchart TD
  A[Jegyzet lista] -- icon(deck) --> B[Pakli Képernyő]
  B --> C[GridView ‑ kártyák]
  C -->|tap| D[FlippableCard\n(front/back)]
  B -->|Back| A
```

## 6. Engedélyek & Firestore Szabályok

* **Olvasás** a `notes` kollekcióból már engedélyezett minden authentikált felhasználónak.  
* Nincs szükség külön szabálymódosításra.

## 7. Edge Case-ek

* **Üres pakli** → Információs üzenet.  
* **Hosszú szöveg** → Hátlapnál tördelés + automatikus elválasztás (CSS `hyphens: auto`).  
* **`deletedAt` != null** → Ne listázzuk.  
* **Régi eszköz / gyenge GPU** → Animáció nélkül is meg kell jeleníteni (pl. fallback egyszerű fordításra).

---
*Ezzel a dokumentummal a mobil-app fejlesztő (AI) pontosan érti, hogyan kell felismerni és megjeleníteni a `deck` típusú jegyzeteket.* 