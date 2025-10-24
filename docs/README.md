# orlomed_admin_web

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Dinamikus Kvíz Típusok

Az admin felület jelenleg két véletlenszerű kérdésbank-alapú kvíztípust kezel:

| `type` mező értéke | Leírás | Megjelenítő Widget |
|---------------------|---------|--------------------|
| `dynamic_quiz` | Klasszikus kvíz: minden kérdésnél **egy** helyes válasz. | `QuizViewer` |
| `dynamic_quiz_dual` | Új kvíztípus: minden kérdésnél **két** helyes válasz. | `QuizViewerDual` |

### Létrehozás / Szerkesztés

* Új menüpont a Sidebar-on: **„Új 2-válaszos Dinamikus Kvíz”**  → `/dynamic-quiz-dual/create`.
* Szerkesztés útvonala: `/quiz-dual/edit/:noteId`.
* A létrehozó és szerkesztő képernyők automatikusan **validálják**, hogy a kiválasztott kérdésbank minden kérdésénél pontosan 2 helyes válasz legyen.

### Kérdésbank követelmény

A `question_banks` kollekcióban tárolt kérdésobjektumoknak az alábbi struktúrát kell követni:

```jsonc
{
  "question": "Mi a ...?",
  "options": [
    { "text": "Opció A", "isCorrect": true },
    { "text": "Opció B", "isCorrect": true },
    { "text": "Opció C", "isCorrect": false },
    { "text": "Opció D", "isCorrect": false }
  ]
}
```

* `dynamic_quiz_dual`-hoz **két** `isCorrect: true` bejegyzés szükséges opciólistánként.

### Megjelenítés a Jegyzetlistában

* Az új típus külön ikonnal (`Icons.quiz_outlined`) jelenik meg a jegyzetek táblázatában.
* Az előnézet a `QuizViewerDual` komponensen keresztül érhető el.

---

> A fejlesztéssel kapcsolatos részletes műszaki leírás a kódban található kommenteknél, valamint a `DYNAMIC_QUIZ_AI_PROMPT.md` dokumentumban olvasható.

## Verification

This line was added to verify repository access and lint functionality.
