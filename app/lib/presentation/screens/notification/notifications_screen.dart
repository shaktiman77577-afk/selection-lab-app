import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? prefs.getString('token');
      final res = await http.get(
        Uri.parse('https://api.selectionlab.online/api/notifications/'),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'offer': return Icons.local_offer_rounded;
      case 'payment': return Icons.check_circle_rounded;
      case 'course': return Icons.school_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'offer': return Colors.orange;
      case 'payment': return Colors.green;
      case 'course': return AppColors.primary;
      default: return Colors.blue;
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _emptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, i) {
                      final n = _notifications[i];
                      final type = (n['type'] ?? 'general').toString();
                      final isRead = n['is_read'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: isRead ? null : Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: _colorFor(type).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                              child: Icon(_iconFor(type), color: _colorFor(type), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(n['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                                      ),
                                      if (!isRead)
                                        Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(n['body'] ?? '', style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.white70 : Colors.black54)),
                                  const SizedBox(height: 6),
                                  Text(_timeAgo(n['sent_at'] ?? n['created_at']), style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.notifications_none_rounded, size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('No notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text('You are all caught up!\nNew updates will appear here.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
          ],
        ),
      ),
    );
  }
}
