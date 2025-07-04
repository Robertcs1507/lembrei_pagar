// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBpZfmjpoaOhOBaRprklV5JGZxejl3kapk',
    appId: '1:810915098643:web:ddb0e85c227a7c37d98fe6',
    messagingSenderId: '810915098643',
    projectId: 'lembrei-de-pagar-a2d6c',
    authDomain: 'lembrei-de-pagar-a2d6c.firebaseapp.com',
    storageBucket: 'lembrei-de-pagar-a2d6c.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDiPkbsjlJgs2jliNOY88O-fy3y_GTnlfY',
    appId: '1:810915098643:android:e874f5feefb0ffe6d98fe6',
    messagingSenderId: '810915098643',
    projectId: 'lembrei-de-pagar-a2d6c',
    storageBucket: 'lembrei-de-pagar-a2d6c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAIokK8sNGuv5s7qOhrJb4VRHYeoXBBWcQ',
    appId: '1:810915098643:ios:05411385f56803d5d98fe6',
    messagingSenderId: '810915098643',
    projectId: 'lembrei-de-pagar-a2d6c',
    storageBucket: 'lembrei-de-pagar-a2d6c.firebasestorage.app',
    iosBundleId: 'com.example.lembreiPegar',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAIokK8sNGuv5s7qOhrJb4VRHYeoXBBWcQ',
    appId: '1:810915098643:ios:05411385f56803d5d98fe6',
    messagingSenderId: '810915098643',
    projectId: 'lembrei-de-pagar-a2d6c',
    storageBucket: 'lembrei-de-pagar-a2d6c.firebasestorage.app',
    iosBundleId: 'com.example.lembreiPegar',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBpZfmjpoaOhOBaRprklV5JGZxejl3kapk',
    appId: '1:810915098643:web:4ef43577cab0d978d98fe6',
    messagingSenderId: '810915098643',
    projectId: 'lembrei-de-pagar-a2d6c',
    authDomain: 'lembrei-de-pagar-a2d6c.firebaseapp.com',
    storageBucket: 'lembrei-de-pagar-a2d6c.firebasestorage.app',
  );
}
