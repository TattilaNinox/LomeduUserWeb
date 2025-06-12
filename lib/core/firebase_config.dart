import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
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