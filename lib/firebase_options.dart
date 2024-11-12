import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyASn90rXw7Ga_l28ajSD0rTASvmEwUOPLM',
    appId: '1:1597115911:web:a0d165807b9284c79564a2',
    messagingSenderId: '1597115911',
    projectId: 'schafkopf-70bc6',
    authDomain: 'schafkopf-70bc6.firebaseapp.com',
    storageBucket: 'schafkopf-70bc6.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyASn90rXw7Ga_l28ajSD0rTASvmEwUOPLM',
    appId: '1:1597115911:web:a0d165807b9284c79564a2',
    messagingSenderId: '1597115911',
    projectId: 'schafkopf-70bc6',
    storageBucket: 'schafkopf-70bc6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyASn90rXw7Ga_l28ajSD0rTASvmEwUOPLM',
    appId: '1:1597115911:web:a0d165807b9284c79564a2',
    messagingSenderId: '1597115911',
    projectId: 'schafkopf-70bc6',
    storageBucket: 'schafkopf-70bc6.firebasestorage.app',
    iosClientId: '1597115911-app.apps.googleusercontent.com',
    iosBundleId: 'com.example.schafkopf',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyASn90rXw7Ga_l28ajSD0rTASvmEwUOPLM',
    appId: '1:1597115911:web:a0d165807b9284c79564a2',
    messagingSenderId: '1597115911',
    projectId: 'schafkopf-70bc6',
    storageBucket: 'schafkopf-70bc6.firebasestorage.app',
    iosClientId: '1597115911-app.apps.googleusercontent.com',
    iosBundleId: 'com.example.schafkopf',
  );
} 