# Feladatleírás: Kötegek (Bundles) Funkció a Mobilalkalmazásban

## 1. A Funkció Célja (Mi ez és miért jó?)

A **Köteg (Bundle)** egy **prezentációs célú egység**, amely több, már meglévő jegyzetet fűz össze egyetlen, sorrendbe rendezett "tananyaggá" vagy "diavetítéssé".

A felhasználó a mobilalkalmazásban nem hoz létre és nem szerkeszt kötegeket, hanem a webes admin felületen összeállított kötegeket tudja **megtekinteni és végiglapozni** prezentációs módban. Ez lehetővé teszi, hogy egy-egy témakört (pl. "Szív anatómiája") összefüggéseiben, egyetlen folyamatos anyagként tanulhasson.

## 2. Felhasználói Forgatókönyv (User Story)

1.  **Anna, a felhasználó,** megnyitja a mobilalkalmazást, hogy felkészüljön egy vizsgára.
2.  A főmenüből kiválasztja a **"Kötegek" (Bundles)** menüpontot.
3.  Egy letisztult, görgethető listát lát a rendelkezésre álló kötegekről. Minden elemen szerepel a köteg címe, rövid leírása és a benne lévő jegyzetek száma.
4.  Anna rábök a **"Kardiológiai Alapok"** nevű kötegre.
5.  Betöltődik a köteg részletes oldala, ahol látja a köteg teljes leírását és a benne lévő jegyzetek listáját. Itt egy nagy, jól látható **"Prezentáció indítása"** gomb fogadja.
6.  Anna megnyomja a gombot. Az alkalmazás teljes képernyős prezentációs módba vált.
7.  Megjelenik a köteg első jegyzetének tartalma. A képernyő tetején látja a köteg címét és azt, hogy hol tart (pl. "1 / 12"). A képernyő alján **"Előző"** és **"Következő"** gombok vannak.
8.  Anna a **"Következő"** gombbal végiglapozza a 12 jegyzetet, mintha egy prezentáció diáit nézné.
9.  Az utolsó jegyzet után a "Következő" gomb inaktívvá válik. Anna a "Befejezés" vagy "Kilépés" gombbal visszatérhet a kötegek listájához.

## 3. Részletes Megvalósítás (Képernyők és Működés)

### A. Köteg Lista Képernyő

*   **Cél:** Az összes elérhető köteg megjelenítése.
*   **Adatforrás:** A `bundles` Firestore collection lekérdezése, `updatedAt` szerint csökkenő sorrendben.
*   **UI Felépítés:**
    *   Egy `ListView` vagy `Column` egy `SingleChildScrollView`-ban.
    *   Minden elem egy kártya (`Card`) widget, ami a következőket tartalmazza:
        *   **Cím:** `bundle.name` (pl. "Kardiológiai Alapok") - Nagy, félkövér betűtípus.
        *   **Leírás:** `bundle.description` (pl. "A szív- és érrendszer anatómiája és alapvető működése.") - Normál méretű szöveg, 2-3 sorra korlátozva.
        *   **Meta-adatok:** Egy sorban, kisebb betűvel:
            *   Jegyzetek száma: `bundle.noteIds.length` (pl. "12 jegyzet")
            *   Kategória: `bundle.category` (pl. "Anatómia")
    *   **Interakció:** A kártyára koppintva a felhasználó a **Köteg Részletek Képernyőre** navigál, átadva neki a `bundle.id`-t.

### B. Prezentációs Képernyő

*   **Cél:** A köteg jegyzeteinek egyenkénti, fókuszált megjelenítése.
*   **Állapotkezelés (State Management):** Ennek a képernyőnek ismernie kell:
    *   A teljes `bundle` objektumot.
    *   Az aktuális pozíciót: `currentIndex` (egy egész szám, kezdetben 0).
*   **Adatforrás:**
    1.  A `bundle` objektumból kiveszi az aktuális jegyzet ID-ját: `noteId = bundle.noteIds[currentIndex]`.
    2.  Ezzel az `noteId`-val lekérdezi a `notes` collection-ből a megfelelő jegyzet dokumentumot.
*   **UI Felépítés:**
    *   **Fejléc (AppBar):**
        *   Cím: `bundle.name`
        *   Haladás jelző: `"${currentIndex + 1} / ${bundle.noteIds.length}"`
        *   Kilépés gomb (X), ami visszanavigál a Köteg Lista Képernyőre.
    *   **Tartalom (Body):**
        *   A lekérdezett `note` dokumentum HTML tartalmának (`pages`) renderelése egy `WebView` vagy `HtmlWidget`-ben.
        *   Ha a jegyzethez tartozik `audioUrl`, egy beágyazott audio lejátszó widget megjelenítése a tartalom alatt.
    *   **Lábléc (Footer) / Navigációs Sáv:**
        *   Egy `Row` widget két gombbal:
            *   **"Előző" gomb:**
                *   `onPressed`: Csökkenti a `currentIndex`-t 1-gyel, majd újrarendereli a képernyőt az új jegyzetadatokkal.
                *   Inaktív (`disabled`), ha `currentIndex == 0`.
            *   **"Következő" gomb:**
                *   `onPressed`: Növeli a `currentIndex`-t 1-gyel, majd újrarendereli a képernyőt.
                *   Inaktív (`disabled`), ha `currentIndex` az utolsó elem indexe.
*   **Interakció:** A gombok frissítik a `currentIndex` állapotot, ami kiváltja a UI újraépítését az új adatokkal.

## 4. Adatmodell (Referencia)

A `bundles` collection dokumentumai így néznek ki:

```json
{
  "id": "string",
  "name": "string",
  "description": "string",
  "noteIds": ["note_id_1", "note_id_2", ...],
  "category": "string",
  "tags": ["tag1", "tag2", ...],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## 5. Hibakezelés (Edge Cases)

*   **Ha a `bundles` collection üres:** A lista képernyőn egy informatív üzenet jelenjen meg: "Nincsenek elérhető kötegek. Látogass vissza később!"
*   **Ha egy köteg `noteIds` tömbje üres:** A Köteg Lista képernyőn a kártya jelezheti (pl. "0 jegyzet"), de a rákoppintás után a Részletek oldalon a "Prezentáció indítása" gomb legyen inaktív, és egy üzenet jelenjen meg: "Ez a köteg jelenleg nem tartalmaz jegyzeteket."
*   **Ha egy jegyzet nem tölthető be a `notes` collection-ből a prezentáció során:** A tartalom helyén egy hibaüzenet jelenjen meg (pl. "Hiba a jegyzet betöltésekor"), de a navigáció (Előző/Következő) továbbra is működjön, hogy a felhasználó tovább tudjon haladni a többi jegyzetre. 