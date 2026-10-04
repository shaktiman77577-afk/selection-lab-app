// lib/core/utils/support_info.dart
//
// Support (WhatsApp) ke liye student ke device aur app ki ek-ek line.
// Student ko khud kuch likhna na pade - hum bata sakein ki kaunse phone aur
// kaunse app version par dikkat aa rahi hai.

import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SupportInfo {
  /// Jaise: "samsung SM-A515F (Android 13, SDK 33)"
  static Future<String> device() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        return '${a.manufacturer} ${a.model} '
            '(Android ${a.version.release}, SDK ${a.version.sdkInt})';
      }
      if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        return '${i.name} (iOS ${i.systemVersion})';
      }
    } catch (_) {}
    return 'Unknown device';
  }

  /// Jaise: "v1.1.0 (5)"
  static Future<String> app() async {
    try {
      final p = await PackageInfo.fromPlatform();
      return 'v${p.version} (${p.buildNumber})';
    } catch (_) {
      return 'unknown';
    }
  }
}
