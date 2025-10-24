# Feladatleírás: Interaktív Jegyzetek Megjelenítése a Mobilalkalmazásban

## 1. A Funkció Célja és Lényege

Az **Interaktív Jegyzet** egy HTML-alapú jegyzettípus, amely lehetővé teszi összetett, dinamikus tananyagok (pl. beágyazott animációk, JavaScript-alapú kérdéssorok, iframe-ek, diagramok) megjelenítését.  
Az adminfelületen a szerkesztő egyetlen HTML oldalt (illetve a jövőben több oldalt) tölthet fel, opcionális **hangfájllal** (mp3) és **videófájllal** (mp4/mov/avi ≤ 5 MB) együtt.  
A jegyzetet a `notes` kollekcióban tároljuk, ahol a dokumentum `type` mezője **`"interactive"`**.

## 2. Felhasználói Forgatókönyv (User Story)

1. **Dávid**, a hallgató, megnyitja az alkalmazás *Jegyzetek* szekcióját.  
2. A listában az interaktív jegyzetek ugyanúgy szerepelnek, mint a szöveges jegyzetek, de egy **villám-ikon** vagy **"INT" badge** jelzi, hogy speciális tartalomról van szó.  
3. Rákattint a *„Kapilláris keringés – interaktív"* című jegyzetre.  
4. Az alkalmazás **teljes képernyős WebView-t** nyit, és betölti a jegyzet HTML-kódját.  
5. A felhasználó scrollozhat, interakcióba léphet a beágyazott elemekkel.  
6. Ha a jegyzethez tartozik hangfájl (**`audioUrl`**), a képernyő alján megjelenik egy *mini audio lejátszó* (play / pause, seek bar).  
7. Ha **`videoUrl`** is van, egy natív videólejátszó jelenik meg a HTML alatt (vagy lebegő gombbal teljes képernyőre váltható).  
8. A "Vissza" navigációval a hallgató visszatér a listához.

## 3. Adatmodell Referencia

`notes` kollekció példa dokumentum (releváns mezők):
```json
{
  "title": "Kapilláris keringés – interaktív",
  "category": "Élettan",
  "type": "interactive",
  "status": "Published",            // vagy Draft / Archived
  "modified": "<timestamp>",
  "pages": [
    "<!DOCTYPE html><html><head>...<script>/* saját JS */</script></head><body>...</body></html>"
  ],
  "audioUrl": "https://storage.googleapis.com/.../noteId/lecture.mp3",  // opcionális
  "videoUrl": "https://storage.googleapis.com/.../noteId/demo.mp4",    // opcionális
  "tags": ["élettan", "keringés"],
  "deletedAt": null                 // ha soft-delete
}
```
*Jelenleg a **`pages`** tömb első eleme kerül megjelenítésre, de a struktúra fel van készítve több oldalra.*

## 4. Megjelenítési Logika a Mobilalkalmazásban

1. **Lekérdezés**:  
   ```dart
   final doc = await FirebaseFirestore.instance.collection('notes').doc(noteId).get();
   final data = doc.data() as Map<String, dynamic>;
   ```
2. **Típus ellenőrzése**:  
   ```dart
   if (data['type'] == 'interactive') {
     // speciális megjelenítés
   }
   ```
3. **WebView betöltés**:  
   ```dart
   final htmlString = (data['pages'] as List).first as String;
   final controller = WebViewController()
     ..setJavaScriptMode(JavaScriptMode.unrestricted)
     ..loadHtmlString(htmlString);
   ```
4. **Opcionális média**:
   * **Audio**: ha `audioUrl` != null → `AudioPlayer` widget (just_audio vagy hasonló).  
   * **Video**: ha `videoUrl` != null → `VideoPlayer` widget (video_player).
5. **Hibakezelés**:
   * Ha a HTML üres vagy hibás → "A tartalom jelenleg nem elérhető."   
   * Offline állapot → "Nincs internetkapcsolat."   
   * Sikertelen média-betöltés → snackbar hibaüzenet, de a HTML továbbra is látható.

## 5. UI Vázlat

```mermaid
flowchart TD
  A[Jegyzet lista] -- katt("interactive") --> B[Interaktív Jegyzet Képernyő]
  B -->|WebView| C[HTML tartalom]
  B -->|if audioUrl| D[Mini Audio Player]
  B -->|if videoUrl| E[Video Player]
  B -->|Back| A
```

## 6. Szerepkörök és Engedélyek

* Olvasás a `notes` kollekcióból **már engedélyezve** minden authentikált felhasználónak.  
* Nincs extra Firestore szabály módosítás.

## 7. Edge Case-ek

* **Régi eszköz / WebView hiánya** → Figyelmeztetés, hogy a tartalom nem támogatott.  
* **Nagyméretű videó (> 5 MB)** → Admin felület már korlátozza, ezért mobilon nem jöhet létre.
* **`deletedAt` != null** → Jegyzet ne jelenjen meg a listában.

## 8. Technológiai Ajánlások

* **webview_flutter** (3.0+) a HTML megjelenítéséhez.  
* **just_audio** + **audio_session** a stabil háttér-hanghoz.  
* **video_player** natív videólejátszáshoz (iOS / Android).  
* Cache-eld a médiafájlokat (`CachedNetworkImage` helyett pl. *BetterPlayer* video esetén), hogy offline is lejátszható legyen.

---
*Ezzel a dokumentummal az AI-alapú fejlesztő egyértelműen megérti, hogyan kell felismerni és kirenderelni az "interactive" típusú jegyzeteket a mobilalkalmazásban.* 