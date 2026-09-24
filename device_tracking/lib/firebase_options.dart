import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return android; // Using android config as fallback
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
        return android;
      case TargetPlatform.linux:
        default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAGf3G1Cq0FMQ9qiVeG6iBABfR-H_zm3Go',
    appId: '1:486635395952:android:0ebe71dd0341b7a93e8db5',
    messagingSenderId: '486635395952',
    projectId: 'trackingservice-f817e',
    storageBucket: 'trackingservice-f817e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAGf3G1Cq0FMQ9qiVeG6iBABfR-H_zm3Go',
    // Spoofing the iOS App ID format so Firebase iOS SDK does not crash
    appId: '1:486635395952:ios:0ebe71dd0341b7a93e8db5',
    messagingSenderId: '486635395952',
    projectId: 'trackingservice-f817e',
    storageBucket: 'trackingservice-f817e.firebasestorage.app',
    iosBundleId: 'com.alwafa.deviceTracking',
  );
}
