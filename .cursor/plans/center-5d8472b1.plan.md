<!-- 5d8472b1-f248-4615-8e78-7c34f5879ade fcf43ade-96c6-41ed-8062-7eb98000ef57 -->
# Feltételes nullázó ikon és gomb távolság javítása

A tanulási nézet AppBar-jában lévő kör alakú nullázó ikon csak akkor jelenjen meg, ha legalább egy számláló (_againCount, _hardCount, _goodCount, _easyCount) értéke nagyobb 0-nál.

Érintett fájl:

- `lib/screens/flashcard_study_screen.dart`

Lépések:

1. Adjunk hozzá egy privát gettert (`bool get _hasProgress => _againCount + _hardCount + _goodCount + _easyCount > 0;`).
2. Az AppBar `actions` listájában csak akkor adjuk hozzá az `IconButton`-t, ha `_hasProgress` igaz.
3. A számlálók növelésekor/begyűjtésekor a meglévő setState hívások már frissítik a számlálókat, így a feltétel automatikusan érvényesül.

### Teendők

- [ ] _hasProgress getter létrehozása
- [ ] IconButton feltételes megjelenítése
- [ ] Funkció ellenőrzése futás közben

### To-dos

- [ ] Set crossAxisAlignment.center in card content Column
- [ ] Add textAlign.center to question Text
- [ ] Add textAlign.center to answer Text
- [ ] Run the app and verify question, answer (and any explanation) are centered