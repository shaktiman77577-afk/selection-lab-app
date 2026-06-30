import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'leaderboard_screen.dart';
import '../learning/my_learning_screen.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

class ProfileScreen extends StatelessWidget {
  final VoidCallback onToggleTheme;
  const ProfileScreen({super.key, required this.onToggleTheme});

  static const String supportNumber = '918860055778';
  static const String telegramLink = 'https://t.me/Selection_Lab';
  static const String youtubeLink = 'https://youtube.com/@selection_lab';

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _contactSupport(String userName) {
    final msg = Uri.encodeComponent('Hi Selection Lab Team,\n\nI am $userName. I need help with: ');
    _launch('https://wa.me/$supportNumber?text=$msg');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final userName = user?['name']?.toString() ?? 'Student';
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        actions: [
          IconButton(
            icon: Icon(Icons.brightness_6_outlined, color: isDark ? Colors.white : Colors.black87),
            onPressed: onToggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, const Color(0xFFFF8E00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white24,
                    backgroundImage: (user?['photo_url'] != null && user!['photo_url'].toString().isNotEmpty)
                        ? NetworkImage(user['photo_url']) : null,
                    child: (user?['photo_url'] == null || user!['photo_url'].toString().isEmpty)
                        ? Text(userName[0].toUpperCase(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  if (user?['email'] != null && user!['email'].toString().isNotEmpty)
                    Text(user['email'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _stat('Points', '${user?['points'] ?? 0}', Icons.stars_rounded),
                      _divider(),
                      _stat('Streak', '${user?['streak_days'] ?? 0}d', Icons.local_fire_department_rounded),
                      _divider(),
                      _stat('Exam', user?['target_exam']?.toString() ?? '-', Icons.flag_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionCard(isDark, [
              _menuItem(isDark, Icons.play_lesson_rounded, 'My Learning', 'Your enrolled courses', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MyLearningScreen()));
              }),
              _menuItem(isDark, Icons.download_rounded, 'Downloads', 'Offline content', () {}),
              _menuItem(isDark, Icons.bookmark_rounded, 'Bookmarks', 'Saved items', () {}),
            ]),
            const SizedBox(height: 14),
            _sectionCard(isDark, [
              _menuItem(isDark, Icons.card_giftcard_rounded, 'Refer & Earn', 'Code: ${user?['referral_code'] ?? '-'}', () {
                final code = user?['referral_code']?.toString() ?? '';
                if (code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral code not available')));
                  return;
                }
                _launch('https://wa.me/?text=${Uri.encodeComponent('Join Selection Lab for SSC/Govt exam prep! Use my code $code. Download: https://selectionlab.online')}');
              }),
              _menuItem(isDark, Icons.leaderboard_rounded, 'Leaderboard', 'Your rank', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
              }),
            ]),
            const SizedBox(height: 14),
            _sectionCard(isDark, [
              _menuItem(isDark, Icons.support_agent_rounded, 'Help & Support', 'Chat with us on WhatsApp',
                  () => _contactSupport(userName), iconColor: const Color(0xFF25D366)),
              _menuItem(isDark, Icons.telegram, 'Join Telegram', 'Updates & discussion',
                  () => _launch(telegramLink), iconColor: const Color(0xFF0088CC)),
              _menuItem(isDark, Icons.play_circle_fill_rounded, 'YouTube Channel', 'Free video lectures',
                  () => _launch(youtubeLink), iconColor: Colors.red),
            ]),
            const SizedBox(height: 14),
            _sectionCard(isDark, [
              _menuItem(isDark, Icons.star_rounded, 'Rate App', 'Love the app? Rate us', () {
                _launch('https://play.google.com/store/apps/details?id=com.selectionlab.selection_lab');
              }, iconColor: Colors.amber),
              _menuItem(isDark, Icons.privacy_tip_rounded, 'Terms & Privacy', '', () => _launch('https://selectionlab.online')),
              _menuItem(isDark, Icons.info_outline_rounded, 'About', 'Version 1.0.0', () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Selection Lab',
                  applicationVersion: '1.0.0',
                  applicationIcon: Image.asset('assets/images/logo.png', width: 48, height: 48),
                  children: [const SizedBox(height: 12), const Text('Your companion for SSC, Bank & Govt exam preparation. Made with care for aspirants.')],
                );
              }),
            ]),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    title: Text('Logout?', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                    content: Text('Are you sure you want to logout?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(onToggleTheme: onToggleTheme)));
                  }
                }
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Made with care for aspirants', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 11)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: Colors.white24);

  Widget _sectionCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _menuItem(bool isDark, IconData icon, String title, String subtitle, VoidCallback onTap, {Color? iconColor}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)) : null,
      trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.black38),
    );
  }
}
