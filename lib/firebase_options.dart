import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyDUPB6FocIZhvWbX9U9UpIJMvtxMyk3NoE',
    appId: '1:853226305803:web:0e15d415e723304b938a0e',
    messagingSenderId: '853226305803',
    projectId: 'sparxtexhapp',
    authDomain: 'sparxtexhapp.firebaseapp.com',
    storageBucket: 'sparxtexhapp.firebasestorage.app',
    measurementId: 'G-072P20LX5Z',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDUPB6FocIZhvWbX9U9UpIJMvtxMyk3NoE',
    appId: '1:853226305803:android:0e15d415e723304b938a0e', // Note: Guessed android suffix as user only provided web appId
    messagingSenderId: '853226305803',
    projectId: 'sparxtexhapp',
    storageBucket: 'sparxtexhapp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDUPB6FocIZhvWbX9U9UpIJMvtxMyk3NoE',
    appId: '1:853226305803:ios:0e15d415e723304b938a0e', // Note: Guessed ios suffix as user only provided web appId
    messagingSenderId: '853226305803',
    projectId: 'sparxtexhapp',
    storageBucket: 'sparxtexhapp.firebasestorage.app',
    iosBundleId: 'com.example.companyApp',
  );
}
