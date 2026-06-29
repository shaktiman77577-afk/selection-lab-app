import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import 'quiz_result_screen.dart';

class QuizPlayScreen extends StatefulWidget {
  final int examId;
  final int subjectId;
  final int? topicId;
  final int timerSeconds; // 0 = no timer
  final int questionCount;
  final String quizTitle;
  const QuizPlayScreen({
    super.key,
    required this.examId,
    required this.subjectId,
    this.topicId,
    required this.timerSeconds,
    required this.questionCount,
    required this.quizTitle,
  });

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _attemptId = 0;
  bool _loading = true;
  String? _error;

  String? _selectedAnswer;
  bool _answered = false;
  String? _correctAnswer;
  String? _explanation;

  // Stats
  int _correct = 0;
  int _wrong = 0;
  int _skipped = 0;

  // Timer
  Timer? _timer;
  int _timeLeft = 0;
  bool _paused = false;

  String? _token;

  // Animation & sound
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _shakeWrong = false;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _loadSoundPref();
    _startQuiz();
  }

  Future<void> _loadSoundPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _soundEnabled = prefs.getBool('quiz_sound') ?? true);
  }

  Future<void> _toggleSound() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _soundEnabled = !_soundEnabled);
    await prefs.setBool('quiz_sound', _soundEnabled);
  }

  Future<void> _playSound(String file) async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/$file'));
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startQuiz() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(AppConstants.tokenKey);

      final res = await http.post(
        Uri.parse('${AppConstants.apiUrl}/quiz/start'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'mode': widget.topicId != null ? 'topic' : 'subject',
          'exam_id': widget.examId,
          'subject_id': widget.subjectId,
          'topic_id': widget.topicId,
          'language': 'en',
          'question_count': widget.questionCount,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _attemptId = data['attempt_id'] ?? 0;
          _questions = List<Map<String, dynamic>>.from(data['questions'] ?? []);
          _loading = false;
        });
        if (_questions.isEmpty) {
          setState(() => _error = 'No questions available for this selection');
        } else {
          _startTimer();
        }
      } else {
        setState(() {
          _loading = false;
          _error = 'Failed to load quiz (${res.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Connection error. Please try again.';
      });
    }
  }

  void _startTimer() {
    if (widget.timerSeconds == 0) return; // no timer mode
    _timeLeft = widget.timerSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_paused) return;
      if (_timeLeft <= 0) {
        t.cancel();
        if (!_answered) _submitAnswer(null); // auto-skip on timeout
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  Future<void> _submitAnswer(String? answer) async {
    if (_answered) return;
    _timer?.cancel();

    setState(() {
      _selectedAnswer = answer;
      _answered = true;
    });

    final q = _questions[_currentIndex];
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.apiUrl}/quiz/submit-answer'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'attempt_id': _attemptId,
          'question_id': q['id'],
          'selected_answer': answer,
          'time_taken_seconds': widget.timerSeconds == 0 ? 0 : (widget.timerSeconds - _timeLeft),
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final isCorrect = data['is_correct'] == true;
        setState(() {
          _correctAnswer = data['correct_answer'];
          _explanation = data['explanation_en'];
          if (answer == null) {
            _skipped++;
          } else if (isCorrect) {
            _correct++;
          } else {
            _wrong++;
          }
        });
        // Animation + sound feedback
        if (answer != null) {
          if (isCorrect) {
            _confettiController.play();
            _playSound('correct.wav');
          } else {
            _playSound('wrong.wav');
            setState(() => _shakeWrong = true);
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) setState(() => _shakeWrong = false);
            });
          }
        }
      }
    } catch (_) {
      // Even if submit fails, show correct answer locally
      setState(() {
        _correctAnswer = q['correct_answer'];
        if (answer == null) _skipped++;
        else if (answer == q['correct_answer']) _correct++;
        else _wrong++;
      });
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
        _correctAnswer = null;
        _explanation = null;
      });
      _startTimer();
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    _timer?.cancel();
    _playSound('complete.wav');
    try {
      await http.post(
        Uri.parse('${AppConstants.apiUrl}/quiz/finish'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'attempt_id': _attemptId}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          total: _questions.length,
          correct: _correct,
          wrong: _wrong,
          skipped: _skipped,
          quizTitle: widget.quizTitle,
        ),
      ));
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    HapticFeedback.lightImpact();
  }

  Future<void> _confirmStop() async {
    setState(() => _paused = true);
    final stop = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          title: Text('Quit Quiz?', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: Text('Your progress so far will be saved. Are you sure?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Resume')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quit', style: TextStyle(color: Colors.red))),
          ],
        );
      },
    );
    if (stop == true) {
      _finishQuiz();
    } else {
      setState(() => _paused = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);

    if (_loading) {
      return Scaffold(backgroundColor: bg, body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: bg, elevation: 0, iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 56, color: Colors.orange),
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];
    final options = {
      'A': q['option_a'] ?? '',
      'B': q['option_b'] ?? '',
      'C': q['option_c'] ?? '',
      'D': q['option_d'] ?? '',
    };

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _confirmStop),
        title: Text('Q ${_currentIndex + 1}/${_questions.length}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        actions: [
          IconButton(
            icon: Icon(_soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded),
            onPressed: _toggleSound,
          ),
          if (widget.timerSeconds > 0)
            IconButton(
              icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              onPressed: _togglePause,
            ),
        ],
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            backgroundColor: isDark ? Colors.white12 : Colors.black12,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
            minHeight: 4,
          ),

          // Timer
          if (widget.timerSeconds > 0)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_rounded, size: 18, color: _timeLeft <= 10 ? Colors.red : AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    _paused ? 'PAUSED' : '$_timeLeft sec',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _paused ? Colors.orange : (_timeLeft <= 10 ? Colors.red : AppColors.primary)),
                  ),
                ],
              ),
            ),

          // Question + options
          Expanded(
            child: _paused
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pause_circle_filled_rounded, size: 64, color: AppColors.primary),
                        const SizedBox(height: 12),
                        Text('Quiz Paused', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _togglePause,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Resume'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Question
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          q['question'] ?? '',
                          style: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Options
                      ...options.entries.map((e) => _optionTile(e.key, e.value, isDark)),

                      // Explanation (after answer)
                      if (_answered && _explanation != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lightbulb_rounded, color: Colors.blue, size: 18),
                                  const SizedBox(width: 6),
                                  Text('Explanation', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_explanation!, style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
          ),
        ],
          ),
          // Confetti overlay
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, AppColors.primary, Colors.pink, Colors.orange, Colors.purple],
            numberOfParticles: 25,
            gravity: 0.3,
          ),
        ],
      ),

      // Bottom action
      bottomNavigationBar: _paused
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: _answered
                  ? ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(_currentIndex < _questions.length - 1 ? 'Next Question' : 'Finish Quiz', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  : OutlinedButton(
                      onPressed: () => _submitAnswer(null),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? Colors.white38 : Colors.black38),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Skip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                    ),
            ),
    );
  }

  Widget _optionTile(String key, String value, bool isDark) {
    Color bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    Color borderColor = isDark ? Colors.white12 : Colors.black12;
    Color textColor = isDark ? Colors.white : Colors.black87;
    IconData? trailingIcon;
    Color? iconColor;

    if (_answered) {
      if (key == _correctAnswer) {
        bgColor = Colors.green.withOpacity(0.15);
        borderColor = Colors.green;
        trailingIcon = Icons.check_circle_rounded;
        iconColor = Colors.green;
      } else if (key == _selectedAnswer) {
        bgColor = Colors.red.withOpacity(0.15);
        borderColor = Colors.red;
        trailingIcon = Icons.cancel_rounded;
        iconColor = Colors.red;
      }
    }

    final isShaking = _shakeWrong && key == _selectedAnswer && key != _correctAnswer;

    return GestureDetector(
      onTap: _answered ? null : () => _submitAnswer(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(isShaking ? 8.0 : 0.0, 0, 0),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _answered && key == _correctAnswer ? Colors.green : (_answered && key == _selectedAnswer ? Colors.red : AppColors.primary.withOpacity(0.12)),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(key, style: TextStyle(fontWeight: FontWeight.bold, color: (_answered && (key == _correctAnswer || key == _selectedAnswer)) ? Colors.white : AppColors.primary)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: textColor))),
            if (trailingIcon != null) Icon(trailingIcon, color: iconColor),
          ],
        ),
      ),
    );
  }
}
