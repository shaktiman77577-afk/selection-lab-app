// lib/presentation/screens/profile/profile_screen.dart
//
// Redesign (Sep 2026): clean look (DT tokens + ui.dart).
// - "About Selection Lab" (Why us, faculty, exams) yahan
// - "My Learning" menu hataya — wo ab bottom tab hai
// - Version ab asli (package_info), pehle "1.0.0" likha hua tha
// Logout aur Delete Account (Google Play requirement) ka logic waisa hi.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/providers/auth_provider.dart';
import '../about/about_screen.dart';
import '../auth/login_screen.dart';
import '../descriptive/descriptive_theme.dart';
import '../support/support_screen.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback onToggleTheme;
  const ProfileScreen({super.key, required this.onToggleTheme});

  static const String supportNumber = '918860055778';
  static const String telegramLink = 'https://t.me/Selection_Lab';
  static const String youtubeLink = 'https://youtube.com/@selection_lab';
  static const String termsUrl = 'https://selectionlab.in/terms';
  static const String privacyUrl = 'https://selectionlab.in/privacy';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.selectionlab.selection_lab';

  static const _red = Color(0xFFC0392B);

  Future<void> _launch(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _contactSupport(String userName) {
    final msg = Uri.encodeComponent(
        'Hi Selection Lab Team,\n\nI am $userName. I need help with: ');
    _launch('https://wa.me/$supportNumber?text=$msg');
  }

  /// Account hamesha ke liye delete (Google Play requirement)
  Future<void> _deleteAccount(BuildContext context) async {
    final auth = context.read<AuthProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: _red, size: 22),
          SizedBox(width: 8),
          Text('Delete account?', style: TextStyle(fontSize: 17)),
        ]),
        content: const Text(
          'This will permanently delete your account and all your data — '
          'including purchased courses, test attempts and progress.\n\n'
          'This action cannot be undone.',
          style: TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final controller = TextEditingController();
    final typed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm deletion', style: TextStyle(fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type DELETE below to confirm.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, letterSpacing: 1),
              decoration: const InputDecoration(hintText: 'DELETE'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(
                ctx, controller.text.trim().toUpperCase() == 'DELETE'),
            child: const Text('Delete forever',
                style: TextStyle(color: _red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (typed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);
      final res = await http.delete(
        Uri.parse('${AppConstants.apiUrl}/users/me'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      if (!context.mounted) return;
      Navigator.pop(context); // loader

      var ok = false;
      try {
        ok = res.statusCode == 200 && jsonDecode(res.body)['success'] == true;
      } catch (_) {}

      if (ok) {
        await auth.logout();
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => LoginScreen(onToggleTheme: onToggleTheme)),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your account has been deleted.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not delete account. Please try again.')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final auth = context.read<AuthProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (confirm != true) return;
    await auth.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => LoginScreen(onToggleTheme: onToggleTheme)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final user = context.watch<AuthProvider>().user;
    final name = '${user?['name'] ?? 'Student'}';
    final email = '${user?['email'] ?? ''}';
    final phone = '${user?['phone'] ?? ''}';
    final exam = '${user?['target_exam'] ?? ''}';
    final photo = '${user?['photo_url'] ?? ''}';

    void push(Widget w) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(t.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: onToggleTheme,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // ── Header ──
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: kDNavy,
                  backgroundImage:
                      photo.startsWith('http') ? NetworkImage(photo) : null,
                  child: photo.startsWith('http')
                      ? null
                      : Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: kDGold)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: t.text)),
                      if (email.isNotEmpty || phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(email.isNotEmpty ? email : phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: t.muted)),
                      ],
                      if (exam.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Tag('🎯 $exam', color: t.primary),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          _label(t, 'HELP & COMMUNITY'),
          _group(t, [
            _item(t, Icons.confirmation_number_rounded, 'Raise a ticket',
                'Payment, access or any other problem',
                () => push(const SupportScreen()),
                color: const Color(0xFFB47F00)),
            _item(t, Icons.support_agent_rounded, 'Chat on WhatsApp',
                'Quick question? Message us', () => _contactSupport(name),
                color: const Color(0xFF1FA855)),
            _item(t, Icons.telegram, 'Join Telegram', 'Updates & discussion',
                () => _launch(telegramLink),
                color: const Color(0xFF0088CC)),
            _item(t, Icons.play_circle_fill_rounded, 'YouTube channel',
                'Free video lectures', () => _launch(youtubeLink),
                color: const Color(0xFFD64545)),
          ]),

          const SizedBox(height: 22),
          _label(t, 'APP'),
          _group(t, [
            _item(t, Icons.info_outline_rounded, 'About Selection Lab',
                'Why us, faculty and exams we cover',
                () => push(const AboutScreen())),
            _item(t, Icons.star_rounded, 'Rate the app',
                'Love the app? Rate us on Play Store',
                () => _launch(playStoreUrl),
                color: const Color(0xFFB47F00)),
            _item(t, Icons.description_outlined, 'Terms of service', '',
                () => _launch(termsUrl)),
            _item(t, Icons.privacy_tip_outlined, 'Privacy policy', '',
                () => _launch(privacyUrl)),
          ]),

          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded, color: _red),
            label: const Text('Log out', style: TextStyle(color: _red)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _red.withOpacity(0.5)),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _deleteAccount(context),
            child: Text('Delete account',
                style: TextStyle(
                    color: _red.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          const SizedBox(height: 6),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) => Text(
              snap.hasData
                  ? 'Selection Lab · v${snap.data!.version} (${snap.data!.buildNumber})'
                  : 'Selection Lab',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: t.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(DT t, String s) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(s,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: t.muted)),
      );

  Widget _group(DT t, List<Widget> items) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 60, color: t.line),
            items[i],
          ],
        ],
      ),
    );
  }

  Widget _item(DT t, IconData icon, String title, String subtitle,
      VoidCallback onTap,
      {Color? color}) {
    final c = color ?? t.primary;
    return ListTile(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: c, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14, color: t.text)),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, style: TextStyle(fontSize: 11.5, color: t.muted)),
      trailing: Icon(Icons.chevron_right_rounded, color: t.muted),
    );
  }
}
