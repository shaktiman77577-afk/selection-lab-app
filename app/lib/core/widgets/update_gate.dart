// lib/core/widgets/update_gate.dart
//
// App update check — poore app ke upar (MaterialApp.builder me lagta hai).
//
// Backend /app-config ke "app_update" se (Railway env vars):
//   MIN_APP_BUILD     — isse purana build chal hi nahi sakta: poori screen par
//                       "Please update" (band nahi hota). Security badlav
//                       (jaise paid content ka naya check) deploy karne se
//                       pehle isse purane app band karte hain.
//   LATEST_APP_BUILD  — isse purana ho to neeche chhota "Update available"
//                       banner, "Later" se band ho jata hai (is session ke liye).
//   APP_UPDATE_MESSAGE, APP_STORE_URL — optional.
// Build number = pubspec.yaml ke version ka "+" ke baad wala hissa.
//
// Config na mile (offline) to kuch nahi rokte — app normal chalta hai.

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers/app_config_provider.dart';
import '../theme/app_theme.dart';

class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  int? _build;
  bool _laterTapped = false;

  static const _defaultStore =
      'https://play.google.com/store/apps/details?id=com.selectionlab.selection_lab';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _build = int.tryParse(p.buildNumber) ?? 0);
    }).catchError((_) {});
  }

  int _int(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

  Future<void> _openStore(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<AppConfigProvider>();
    final build = _build;
    final u = cfg.config['app_update'];
    if (!cfg.loaded || build == null || u is! Map) return widget.child;

    final minBuild = _int(u['min_build']);
    final latest = _int(u['latest_build']);
    final msg = '${u['message'] ?? ''}'.trim();
    final store = '${u['store_url'] ?? ''}'.trim().isEmpty
        ? _defaultStore
        : '${u['store_url']}'.trim();

    if (minBuild > 0 && build < minBuild) {
      return _ForceUpdate(
          message: msg, onUpdate: () => _openStore(store));
    }

    if (latest > 0 && build < latest && !_laterTapped) {
      return Stack(
        children: [
          widget.child,
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                color: Brand.navy,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.system_update_rounded,
                          color: Brand.gold, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            msg.isNotEmpty
                                ? msg
                                : 'A new version of Selection Lab is available.',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _laterTapped = true),
                        child: const Text('Later',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton(
                        onPressed: () => _openStore(store),
                        child: const Text('Update',
                            style: TextStyle(
                                color: Brand.gold,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return widget.child;
  }
}

class _ForceUpdate extends StatelessWidget {
  final String message;
  final VoidCallback onUpdate;
  const _ForceUpdate({required this.message, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF0F1115) : const Color(0xFFF5F6FA),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/images/logo.png',
                      width: 72,
                      height: 72,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
                const SizedBox(height: 20),
                Text('Please update the app',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : const Color(0xFF1B2331))),
                const SizedBox(height: 8),
                Text(
                    message.isNotEmpty
                        ? message
                        : 'This version of Selection Lab is no longer supported. '
                            'Update to the latest version to continue — your '
                            'courses and progress are safe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: dark
                            ? const Color(0xFFC9CED8)
                            : const Color(0xFF3D4656))),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onUpdate,
                    icon: const Icon(Icons.system_update_rounded),
                    label: const Text('Update now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
