import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../learning/my_learning_screen.dart';
import '../support/support_screen.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback onToggleTheme;
  const ProfileScreen({super.key, required this.onToggleTheme});

  static const String supportNumber = '918860055778';
  static const String telegramLink = 'https://t.me/Selection_Lab';
  static const String youtubeLink = 'https://youtube.com/@selection_lab';
  static const String termsUrl = 'https://selectionlab.in/terms';
  static const String privacyUrl = 'https://selectionlab.in/privacy';
  static const String supportUrl = 'https://selectionlab.in/support';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.selectionlab.selection_lab';

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _contactSupport(String userName) {
    final msg = Uri.encodeComponent(
        'Hi Selection Lab Team,\n\nI am $userName. I need help with: ');
    _launch('https://wa.me/$supportNumber?text=$msg');
  }

  /// Permanently deletes the account (Google Play requirement).
  Future<void> _deleteAccount(BuildContext context, bool isDark) async {
    final auth = context.read<AuthProvider>();

    // Step 1 — warn
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Text('Delete Account?',
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 17)),
          ],
        ),
        content: Text(
          'This will permanently delete your account and all your data — '
          'including purchased courses, test attempts and progress.\n\n'
          'This action cannot be undone.',
          style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 13.5,
              height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    // Step 2 — type DELETE to confirm
    final controller = TextEditingController();
    final typed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm deletion',
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type DELETE below to confirm.',
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : const Color(0xFFF2F3F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isDark ? Colors.white24 : Colors.black26),
              ),
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'DELETE',
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontWeight: FontWeight.w500),
                ),
              ),
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
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (typed != true || !context.mounted) return;

    // Step 3 — call the API
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
      Navigator.pop(context); // close loader

      final ok = res.statusCode == 200 &&
          (jsonDecode(res.body)['success'] == true);

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final userName = user?['name']?.toString() ?? 'Student';
    final email = user?['email']?.toString() ?? '';
    final targetExam = user?['target_exam']?.toString() ?? '';
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Profile',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: isDark ? Colors.white : Colors.black87),
            onPressed: onToggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Profile header card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, const Color(0xFFFF8E00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white24,
                    backgroundImage: (user?['photo_url'] != null &&
                            user!['photo_url'].toString().isNotEmpty)
                        ? NetworkImage(user['photo_url'])
                        : null,
                    child: (user?['photo_url'] == null ||
                            user!['photo_url'].toString().isEmpty)
                        ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold)),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12.5)),
                        ],
                        if (targetExam.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.flag_rounded,
                                    color: Colors.white, size: 13),
                                const SizedBox(width: 5),
                                Text(targetExam,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Learning ──
            _sectionLabel(isDark, 'LEARNING'),
            _sectionCard(isDark, [
              _menuItem(isDark, Icons.play_lesson_rounded, 'My Learning',
                  'Courses, mock & descriptive series', () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MyLearningScreen()));
              }),
            ]),

            const SizedBox(height: 16),

            // ── Community & support ──
            _sectionLabel(isDark, 'COMMUNITY & SUPPORT'),
            _sectionCard(isDark, [
              // Ticket pehle — ye track hota hai aur reply email par bhi jata hai.
              // WhatsApp neeche rakha hai kyunki wo scale nahi karta.
              // Ab app ke andar. Pehle Chrome me website khulti thi, jahan
              // student ka session alag hota tha — isliye zyadatar ticket bina
              // user_id ke aate the aur admin ko pata hi nahi chalta tha ki
              // kisne bheja hai.
              _menuItem(isDark, Icons.confirmation_number_rounded,
                  'Raise a Ticket', 'Payment, access or any other problem',
                  () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SupportScreen()),
                      ),
                  iconColor: const Color(0xFFFFAB00)),
              _menuItem(isDark, Icons.support_agent_rounded, 'Chat on WhatsApp',
                  'Quick question? Message us', () => _contactSupport(userName),
                  iconColor: const Color(0xFF25D366)),
              _menuItem(isDark, Icons.telegram, 'Join Telegram',
                  'Updates & discussion', () => _launch(telegramLink),
                  iconColor: const Color(0xFF0088CC)),
              _menuItem(isDark, Icons.play_circle_fill_rounded,
                  'YouTube Channel', 'Free video lectures',
                  () => _launch(youtubeLink),
                  iconColor: Colors.red),
            ]),

            const SizedBox(height: 16),

            // ── App ──
            _sectionLabel(isDark, 'APP'),
            _sectionCard(isDark, [
              _menuItem(isDark, Icons.star_rounded, 'Rate App',
                  'Love the app? Rate us on Play Store',
                  () => _launch(playStoreUrl),
                  iconColor: Colors.amber),
              _menuItem(isDark, Icons.description_rounded, 'Terms of Service',
                  '', () => _launch(termsUrl)),
              _menuItem(isDark, Icons.privacy_tip_rounded, 'Privacy Policy',
                  '', () => _launch(privacyUrl)),
              _menuItem(isDark, Icons.info_outline_rounded, 'About',
                  'Version 1.0.0', () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Selection Lab',
                  applicationVersion: '1.0.0',
                  applicationIcon: Image.asset('assets/images/logo.png',
                      width: 48, height: 48),
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                        'Your companion for SSC, IB, Railway & Govt exam preparation. Made with care for aspirants.'),
                  ],
                );
              }),
            ]),

            const SizedBox(height: 24),

            // ── Logout ──
            OutlinedButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor:
                        isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: Text('Logout?',
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87)),
                    content: Text('Are you sure you want to logout?',
                        style: TextStyle(
                            color:
                                isDark ? Colors.white70 : Colors.black54)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Logout',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                LoginScreen(onToggleTheme: onToggleTheme)));
                  }
                }
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: const Text('Logout',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.withOpacity(0.6)),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 12),

            // ── Delete account (Google Play requirement) ──
            TextButton.icon(
              onPressed: () => _deleteAccount(context, isDark),
              icon: Icon(Icons.delete_forever_rounded,
                  color: Colors.red.withOpacity(0.75), size: 19),
              label: Text('Delete Account',
                  style: TextStyle(
                      color: Colors.red.withOpacity(0.75),
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5)),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),

            const SizedBox(height: 8),
            Text('Made with care for aspirants',
                style: TextStyle(
                    color: isDark ? Colors.white24 : Colors.black26,
                    fontSize: 11)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(bool isDark, String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: isDark ? Colors.white38 : Colors.black38)),
      ),
    );
  }

  Widget _sectionCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _menuItem(bool isDark, IconData icon, String title, String subtitle,
      VoidCallback onTap,
      {Color? iconColor}) {
    return ListTile(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87)),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45))
          : null,
      trailing: Icon(Icons.chevron_right_rounded,
          color: isDark ? Colors.white38 : Colors.black38),
    );
  }
}
