import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.apiUrl}/users/leaderboard'),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _users = List<Map<String, dynamic>>.from(data['leaderboard'] ?? []);
          _loading = false;
        });
      } else {
        setState(() { _loading = false; _error = 'Failed to load (${res.statusCode})'; });
      }
    } catch (e) {
      setState(() { _loading = false; _error = 'Connection error'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    final auth = context.read<AuthProvider>();
    final myId = auth.user?['id'];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text('Leaderboard', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.error_outline_rounded, size: 56, color: Colors.orange),
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () { setState(() { _loading = true; _error = null; }); _loadLeaderboard(); }, child: const Text('Retry')),
                ]))
              : _users.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.leaderboard_outlined, size: 56, color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 12),
                      Text('No rankings yet', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                      const SizedBox(height: 4),
                      Text('Play quizzes to earn points!', style: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : Colors.black26)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _loadLeaderboard,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Top 3 podium
                          if (_users.length >= 3) _buildPodium(isDark),
                          const SizedBox(height: 16),
                          // Rest of the list
                          ..._users.asMap().entries.map((entry) {
                            final rank = entry.key + 1;
                            final u = entry.value;
                            // Skip top 3 if podium shown
                            if (_users.length >= 3 && rank <= 3) return const SizedBox.shrink();
                            return _rankTile(rank, u, u['id'] == myId, cardBg, isDark);
                          }),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildPodium(bool isDark) {
    final first = _users[0];
    final second = _users[1];
    final third = _users[2];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _podiumPlace(second, 2, 90, Colors.grey.shade400, isDark),
          const SizedBox(width: 12),
          _podiumPlace(first, 1, 120, const Color(0xFFFFD700), isDark),
          const SizedBox(width: 12),
          _podiumPlace(third, 3, 70, const Color(0xFFCD7F32), isDark),
        ],
      ),
    );
  }

  Widget _podiumPlace(Map<String, dynamic> u, int rank, double height, Color medalColor, bool isDark) {
    final name = (u['name'] ?? 'User').toString();
    final points = u['points'] ?? 0;
    final pic = u['profile_pic'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: rank == 1 ? 64 : 54,
              height: rank == 1 ? 64 : 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: medalColor, width: 3),
              ),
              child: ClipOval(
                child: pic != null && pic.toString().isNotEmpty
                    ? Image.network(pic, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarFallback(name))
                    : _avatarFallback(name),
              ),
            ),
            Positioned(
              bottom: -10,
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: medalColor, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF0F0F0F) : Colors.white, width: 2)),
                child: Center(child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 70,
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87)),
        ),
        Text('$points pts', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [medalColor.withOpacity(0.7), medalColor.withOpacity(0.3)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28))),
        ),
      ],
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: AppColors.primary.withOpacity(0.2),
      child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18))),
    );
  }

  Widget _rankTile(int rank, Map<String, dynamic> u, bool isMe, Color cardBg, bool isDark) {
    final name = (u['name'] ?? 'User').toString();
    final points = u['points'] ?? 0;
    final streak = u['streak_days'] ?? 0;
    final pic = u['profile_pic'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary.withOpacity(0.12) : cardBg,
        borderRadius: BorderRadius.circular(14),
        border: isMe ? Border.all(color: AppColors.primary, width: 1.5) : null,
      ),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('#$rank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white70 : Colors.black54))),
          const SizedBox(width: 8),
          Container(
            width: 42, height: 42,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: ClipOval(
              child: pic != null && pic.toString().isNotEmpty
                  ? Image.network(pic, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarFallback(name))
                  : _avatarFallback(name),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87))),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)), child: const Text('YOU', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                    ],
                  ],
                ),
                if (streak > 0) Text('🔥 $streak day streak', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$points', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
              Text('points', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
            ],
          ),
        ],
      ),
    );
  }
}
