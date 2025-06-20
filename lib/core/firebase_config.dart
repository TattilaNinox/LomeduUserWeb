import 'package:firebase_core/firebase_core.dart';

/// A Firebase konfigurációért és inicializálásáért felelős osztály.
///
/// Ez az osztály egyetlen statikus metódust tartalmaz, amely az alkalmazás
/// indításakor szükséges a Firebase szolgáltatásokkal való kapcsolat
/// létrehozásához. A konfigurációs adatok (API kulcsok stb.) itt vannak
/// keményen kódolva.
class FirebaseConfig {
  /// Inicializálja a Firebase alkalmazást a megadott opciókkal.
  ///
  /// Ezt a statikus metódust az alkalmazás `main` függvényéből kell meghívni
  /// a `runApp()` előtt, hogy a Firebase szolgáltatások (pl. Firestore, Auth)
  /// elérhetőek legyenek az alkalmazás további részeiben.
  static Future<void> initialize() async {
    // A `Firebase.initializeApp` egy aszinkron művelet, amely létrehozza
    // a kapcsolatot a Firebase projekttel a Flutter alkalmazás és a
    // Google szerverei között.
    await Firebase.initializeApp(
      // A `FirebaseOptions` objektum tartalmazza azokat az egyedi azonosítókat,
      // amelyek a projektünket azonosítják a Firebase platformon.
      // Ezeket az adatokat a Firebase konzolból lehet kimásolni
      // a projekt beállításai > "Webalkalmazás" szekcióból.
      options: const FirebaseOptions(
        apiKey: "AIzaSyCWkH2x7ujj3xc8M1fhJAMphWo7pLBhV_k",
        authDomain: "orlomed-f8f9f.firebaseapp.com",
        projectId: "orlomed-f8f9f",
        storageBucket: "orlomed-f8f9f.firebasestorage.app",
        messagingSenderId: "673799768268",
        appId: "1:673799768268:web:2313db56d5226e17c6da69",
      ),
    );
  }
}