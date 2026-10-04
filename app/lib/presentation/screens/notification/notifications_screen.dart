// lib/presentation/screens/notification/notifications_screen.dart
//
// Redesign (Sep 2026): clean look. Aur ek sudhaar: tap karne par notification
// "read" mark hota hai (POST /notifications/{id}/read). Pehle app ye call
// karta hi nahi tha, isliye har notification hamesha unread dikhta tha.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/ui.dart';
import '../descriptive/descriptive_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String? _token;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, String> get _headers =>
      _token != null ? {'Authorization': 'Bearer $_token'} : {};

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(AppConstants.tokenKey) ?? prefs.getString('token');
      final res = await http
          .get(Uri.parse('${AppConstants.apiUrl}/notifications/'),
              headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() {
          _error = 'Could not load notifications.';
          _loading = false;
        });
        return;
      }
      final data = jsonDecode(res.body);
      final l = data is Map ? data['notifications'] : null;
      setState(() {
        _items = l is List
            ? l.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load notifications. Check your internet.';
        _loading = false;
      });
    }
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['is_read'] == true) return;
    HapticFeedback.selectionClick();
    setState(() => n['is_read'] = true);
    try {
      await http
          .post(Uri.parse('${AppConstants.apiUrl}/notifications/${n['id']}/read'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  (IconData, Color) _style(String type) {
    switch (type) {
      case 'offer':
        return (Icons.local_offer_rounded, const Color(0xFFB47F00));
      case 'payment':
        return (Icons.check_circle_rounded, kDGreen);
      case 'course':
        return (Icons.school_rounded, const Color(0xFFD9822B));
      default:
        return (Icons.notifications_rounded, const Color(0xFF2C6FD1));
    }
  }

  String _timeAgo(dynamic s) {
    final d = DateTime.tryParse('${s ?? ''}');
    if (d == null) return '';
    final diff = DateTime.now().difference(d.toLocal());
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final t = dtOf(context);
    final state = ListStateView(
      loading: _loading,
      error: _error,
      empty: _items.isEmpty,
      emptyText: "You're all caught up!\nNew updates will appear here.",
      emptyIcon: Icons.notifications_none_rounded,
      onRetry: _load,
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            if (state.show)
              state
            else
              for (final n in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _card(t, n),
                ),
          ],
        ),
      ),
    );
  }

  Widget _card(DT t, Map<String, dynamic> n) {
    final unread = n['is_read'] != true;
    final (icon, color) = _style('${n['type'] ?? 'general'}');
    return AppCard(
      borderColor: unread ? t.primary.withOpacity(0.35) : null,
      onTap: () => _markRead(n),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('${n['title'] ?? ''}',
                          style: TextStyle(
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 14,
                              color: t.text)),
                    ),
                    if (unread)
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: t.primary, shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${n['body'] ?? ''}',
                    style: TextStyle(fontSize: 13, height: 1.45, color: t.text2)),
                const SizedBox(height: 6),
                Text(_timeAgo(n['sent_at'] ?? n['created_at']),
                    style: TextStyle(fontSize: 11, color: t.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
