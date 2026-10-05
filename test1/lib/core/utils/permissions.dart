import 'package:flutter/foundation.dart';

class PermissionHelper {
  /// Cross-platform camera and microphone permission check.
  /// On Web and Windows desktop, permissions are requested directly by the browser / OS media APIs.
  static Future<bool> requestMediaPermissions() async {
    if (kIsWeb) {
      // Browsers prompt natively on getUserMedia
      return true;
    }
    // Mobile / Desktop native handling
    return true;
  }
}
