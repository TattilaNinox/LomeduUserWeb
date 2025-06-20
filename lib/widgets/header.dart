import 'package:flutter/material.dart';
import '../screens/note_create_screen.dart';

/// Az alkalmazás felső fejlécét (Header) megvalósító widget.
///
/// Ez egy `StatelessWidget`, amely tartalmazza a keresőmezőt,
/// az adminisztrátor nevét és az "Új jegyzet" gombot.
/// A keresőmező állapotát nem itt kezeli, hanem a `ValueChanged`
/// callback segítségével "felemeli" a szülő widgethez.
class Header extends StatelessWidget {
  /// Callback függvény, amely minden alkalommal meghívódik, amikor
  /// a keresőmező tartalma megváltozik.
  /// A szülő widget feladata, hogy kezelje a keresési logikát.
  final ValueChanged<String> onSearchChanged;

  /// A `Header` widget konstruktora.
  const Header({super.key, required this.onSearchChanged});

  @override
  Widget build(BuildContext context) {
    // Egy fix magasságú konténer, ami a fejléc sávját képezi.
    return Container(
      height: 60, // Kissé magasabb, hogy a tartalom kényelmesen elférjen
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      margin: const EdgeInsets.only(top: 10, left: 10, right: 10), // Felső és oldalsó margó
      decoration: BoxDecoration(
        color: Colors.white, // A színt a decoration-ön belül kell megadni
        borderRadius: BorderRadius.circular(8), // Lekerekített sarkok
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // Az elemek egy sorban helyezkednek el.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Vertikális középre igazítás
        children: [
          // Keresőmező
          SizedBox(
            width: 200, // Keskenyebb keresőmező
            height: 36, // Alacsonyabb magasság
            child: TextField(
              // A `onChanged` eseményre a konstruktorban kapott callback
              // függvény van kötve, ami minden karakter beírásakor lefut.
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Keresés...',
                contentPadding: const EdgeInsets.symmetric(vertical: 0), // Belső padding csökkentése
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280), size: 20),
              ),
            ),
          ),
          // A `Spacer` kitölti a rendelkezésre álló vízszintes teret,
          // így a tőle jobbra lévő elemeket a jobb szélre tolja.
          const Spacer(),
          // Adminisztrátor nevének megjelenítése.
          const Text(
            'Adminisztrátor',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(width: 16),
          // "Új jegyzet" gomb.
          ElevatedButton(
            onPressed: () {
              // Fontos: Ez a navigáció a `go_router`-t megkerülve, a régebbi
              // `Navigator.of(context).push` módszerrel történik. Ez akkor
              // lehet indokolt, ha egy modális ablakot vagy egy olyan oldalt
              // akarunk megjeleníteni, ami nem része a fő URL-alapú navigációnak.
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NoteCreateScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text(
              'Új jegyzet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
