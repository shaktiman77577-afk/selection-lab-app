import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import 'mock_test_result_screen.dart';

enum QStatus { notVisited, notAnswered, answered, markedReviewEmpty, answeredAndMarked }

class MockTestPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> mockTest;
  const MockTestPlayerScreen({super.key, required this.mockTest});

  @override
  State<MockTestPlayerScreen> createState() => _MockTestPlayerScreenState();
}

class _MockTestPlayerScreenState extends State<MockTestPlayerScreen> {
  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;
  String? _error;

  int _currentIndex = 0;
  final Map<int, String?> _selectedAnswers = {};
  final Map<int, QStatus> _statuses = {};

  Timer? _timer;
  int _timeLeft = 0;
  int _totalDuration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuestions());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user?['id'] ?? 0;
      final testId = widget.mockTest['id'];

      final res = await http.get(
        Uri.parse('${AppConstants.apiUrl}/mock-tests/$testId?user_id=$userId'),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final qs = List<Map<String, dynamic>>.from(data['questions'] ?? []);
        setState(() {
          _questions = qs;
          _loading = false;
          for (int i = 0; i < _questions.length; i++) {
            _statuses[i] = QStatus.notVisited;
          }
          if (_questions.isNotEmpty) _statuses[0] = QStatus.notAnswered;
        });
        if (_questions.isEmpty) {
          setState(() => _error = 'No questions in this test');
        } else {
          _startTimer();
        }
      } else {
        setState(() { _loading = false; _error = 'Failed to load (${res.statusCode})'; });
      }
    } catch (e) {
      setState(() { _loading = false; _error = 'Error: $e'; });
    }
  }

  void _startTimer() {
    _totalDuration = ((widget.mockTest['duration_minutes'] ?? 10) as num).toInt() * 60;
    _timeLeft = _totalDuration;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft <= 0) {
        t.cancel();
        _submitTest();
      } else {
        if (mounted) setState(() => _timeLeft--);
      }
    });
  }

  String get _formattedTime {
    final m = (_timeLeft % 3600) ~/ 60;
    final s = _timeLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _selectOption(String option) => setState(() => _selectedAnswers[_currentIndex] = option);

  void _clearResponse() {
    setState(() => _selectedAnswers[_currentIndex] = null);
    HapticFeedback.lightImpact();
  }

  void _saveAndNext() {
    final selected = _selectedAnswers[_currentIndex];
    setState(() => _statuses[_currentIndex] = selected != null ? QStatus.answered : QStatus.notAnswered);
    _goNext();
  }

  void _markAndNext() {
    final selected = _selectedAnswers[_currentIndex];
    setState(() => _statuses[_currentIndex] = selected != null ? QStatus.answeredAndMarked : QStatus.markedReviewEmpty);
    _goNext();
  }

  void _goNext() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        if (_statuses[_currentIndex] == QStatus.notVisited) _statuses[_currentIndex] = QStatus.notAnswered;
      });
    }
  }

  void _jumpTo(int index) {
    setState(() {
      _currentIndex = index;
      if (_statuses[index] == QStatus.notVisited) _statuses[index] = QStatus.notAnswered;
    });
    Navigator.pop(context);
  }

  Color _statusColor(QStatus status) {
    switch (status) {
      case QStatus.notVisited: return Colors.grey.shade400;
      case QStatus.notAnswered: return Colors.red;
      case QStatus.answered: return Colors.green;
      case QStatus.markedReviewEmpty: return Colors.purple;
      case QStatus.answeredAndMarked: return Colors.purple;
    }
  }

  Future<void> _submitTest() async {
    _timer?.cancel();
    final Map<String, dynamic> answersMap = {};
    for (int i = 0; i < _questions.length; i++) {
      answersMap[_questions[i]['id'].toString()] = _selectedAnswers[i];
    }
    final auth = context.read<AuthProvider>();
    final userId = auth.user?['id'] ?? 0;
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.apiUrl}/mock-tests/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'mock_test_id': widget.mockTest['id'],
          'answers': answersMap,
          'time_taken_seconds': _totalDuration - _timeLeft,
        }),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => MockTestResultScreen(result: data, testTitle: widget.mockTest['title'] ?? 'Mock Test'),
        ));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submit failed')));
    }
  }

  void _confirmSubmit() {
    final answered = _statuses.values.where((s) => s == QStatus.answered || s == QStatus.answeredAndMarked).length;
    showDialog(context: context, builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text('Submit Test?', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text('Answered: $answered / ${_questions.length}\n\nSubmit now?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _submitTest(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Submit'),
          ),
        ],
      );
    });
  }

  void _showPalette() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Question Palette', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 8, children: [
              _legendChip(Colors.green, 'Answered', isDark),
              _legendChip(Colors.red, 'Not Answered', isDark),
              _legendChip(Colors.purple, 'Marked', isDark),
              _legendChip(Colors.grey.shade400, 'Not Visited', isDark),
            ]),
            const SizedBox(height: 20),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: _questions.length,
                itemBuilder: (context, i) {
                  final status = _statuses[i] ?? QStatus.notVisited;
                  final isMarked = status == QStatus.answeredAndMarked;
                  return GestureDetector(
                    onTap: () => _jumpTo(i),
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          borderRadius: BorderRadius.circular(8),
                          border: i == _currentIndex ? Border.all(color: AppColors.primary, width: 2) : null,
                        ),
                        child: Center(child: Text('${i + 1}', style: TextStyle(color: status == QStatus.notVisited ? Colors.black54 : Colors.white, fontWeight: FontWeight.bold))),
                      ),
                      if (isMarked)
                        Positioned(bottom: -3, right: -3, child: Container(
                          width: 14, height: 14,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.check, size: 9, color: Colors.white),
                        )),
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendChip(Color color, String label, bool isDark) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    // Loading
    if (_loading) {
      return Scaffold(backgroundColor: bg, body: const Center(child: CircularProgressIndicator()));
    }
    // Error
    if (_error != null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: bg, iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87)),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.error_outline_rounded, size: 56, color: Colors.orange),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
          ]),
        )),
      );
    }
    // Empty safety
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: bg, iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87)),
        body: Center(child: Text('No questions', style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
      );
    }

    final q = _questions[_currentIndex];
    final selected = _selectedAnswers[_currentIndex];
    final posMarks = (q['marks'] ?? 2).toString();
    final negMark = (widget.mockTest['negative_marking'] ?? 0).toString();
    final optionEntries = [
      ['A', '${q['option_a'] ?? ''}'],
      ['B', '${q['option_b'] ?? ''}'],
      ['C', '${q['option_c'] ?? ''}'],
      ['D', '${q['option_d'] ?? ''}'],
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(widget.mockTest['title'] ?? 'Mock Test', style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: _timeLeft < 60 ? Colors.red : Colors.white24, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.timer_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Center(child: Text(_formattedTime, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
            ]),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scrollable content
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 170),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('Question ${_currentIndex + 1} of ${_questions.length}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                      const Spacer(),
                      Text('+$posMarks', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      Text('-$negMark', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(q['question']?.toString() ?? '', style: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 24),
                  for (final opt in optionEntries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _selectOption(opt[0]),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selected == opt[0] ? AppColors.primary.withOpacity(0.15) : cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selected == opt[0] ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12), width: selected == opt[0] ? 2 : 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected == opt[0] ? AppColors.primary : Colors.transparent,
                                    border: Border.all(color: selected == opt[0] ? AppColors.primary : Colors.grey, width: 2),
                                  ),
                                  child: selected == opt[0] ? const Icon(Icons.check, size: 16, color: Colors.white) : Center(child: Text(opt[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13))),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Text(opt[1], style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Fixed footer
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Material(
              elevation: 8,
              color: cardBg,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(
                          onPressed: _markAndNext,
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.purple), padding: const EdgeInsets.symmetric(vertical: 12)),
                          child: const Text('Mark & Next', style: TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.bold)),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton(
                          onPressed: _clearResponse,
                          style: OutlinedButton.styleFrom(side: BorderSide(color: isDark ? Colors.white38 : Colors.black38), padding: const EdgeInsets.symmetric(vertical: 12)),
                          child: Text('Clear', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        InkWell(
                          onTap: _showPalette,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.grid_view_rounded, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton(
                          onPressed: _saveAndNext,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: Text(_currentIndex < _questions.length - 1 ? 'Save & Next' : 'Save', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        )),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _confirmSubmit,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
                          child: const Text('Submit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}