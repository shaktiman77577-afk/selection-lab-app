import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import 'mock_test_instructions_screen.dart';

class MockTestListScreen extends StatefulWidget {
  const MockTestListScreen({super.key});

  @override
  State<MockTestListScreen> createState() => _MockTestListScreenState();
}

class _MockTestListScreenState extends State<MockTestListScreen> {
  List<Map<String, dynamic>> _tests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.apiUrl}/mock-tests/')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _tests = List<Map<String, dynamic>>.from(data['mock_tests'] ?? []);
      }
      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
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
        title: Text('Mock Tests', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 56, color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 12),
                      Text('No mock tests available yet', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tests.length,
                  itemBuilder: (context, i) => _testCard(_tests[i], isDark, cardBg),
                ),
    );
  }

  Widget _testCard(Map<String, dynamic> t, bool isDark, Color cardBg) {
    final isFree = t['is_free'] == true;
    final isPurchased = t['is_purchased'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.assignment_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(t['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                    ),
                    if (isFree)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: const Text('FREE', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // Stats row
                Row(
                  children: [
                    _stat(Icons.help_outline_rounded, '${t['total_questions']} Qs', isDark),
                    const SizedBox(width: 16),
                    _stat(Icons.timer_outlined, '${t['duration_minutes']} min', isDark),
                    const SizedBox(width: 16),
                    _stat(Icons.star_outline_rounded, '${t['total_marks']} marks', isDark),
                  ],
                ),
                if (t['negative_marking'] != null && t['negative_marking'] > 0) ...[
                  const SizedBox(height: 8),
                  Text('Negative marking: -${t['negative_marking']} per wrong answer',
                      style: TextStyle(fontSize: 11, color: Colors.red.withOpacity(0.8))),
                ],
              ],
            ),
          ),
          // Action button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (isFree || isPurchased) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => MockTestInstructionsScreen(mockTest: t),
                    ));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Purchase required (Razorpay coming soon)')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isFree || isPurchased) ? AppColors.primary : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  (isFree || isPurchased) ? 'Start Test' : 'Rs.${t['price']} - Buy',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
