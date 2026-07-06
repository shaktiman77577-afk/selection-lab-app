// lib/presentation/screens/descriptive/descriptive_player_screen.dart
//
// PLACEHOLDER (Slice 1). The full exam player — sections, timer, question
// palette, answer box, auto-score result — arrives in Slice 2 and replaces
// this whole file.

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class DescriptivePlayerScreen extends StatelessWidget {
  final int testId;
  final int seriesId;
  const DescriptivePlayerScreen(
      {super.key, required this.testId, required this.seriesId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA),
      appBar: AppBar(title: const Text('Descriptive Test'), elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_note, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              Text('Exam screen coming soon',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text(
                'The full writing-test experience is being added to the app. '
                'For now you can attempt this test on our website.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: isDark ? Colors.white60 : Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
