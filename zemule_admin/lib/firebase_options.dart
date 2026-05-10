import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions is configured for web only in zemule_admin.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBWa2XgoDDet8oo1tdVOKcJwThfofTeduI',
    appId: '1:815164008115:web:46a11508c95ab4285cb2c6',
    messagingSenderId: '815164008115',
    projectId: 'zemule-ec16a',
    authDomain: 'zemule-ec16a.firebaseapp.com',
    storageBucket: 'zemule-ec16a.firebasestorage.app',
    measurementId: 'G-T7J8LB57JC',
  );
}

