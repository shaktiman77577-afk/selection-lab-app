import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';

class ExamCategoriesScreen extends StatefulWidget {
  const ExamCategoriesScreen({super.key});

  @override
  State<ExamCategoriesScreen> createState() => _ExamCategoriesScreenState();
}

class _ExamCategoriesScreenState extends State<ExamCategoriesScreen> {
  List<dynamic> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService.get('/exams/categories');
    setState(() {
      _categories = res['categories'] ?? [];
      _loading = false;
    });
  }

  final List<Color> _colors = [
    const Color(0xFF6C63FF), const Color(0xFF00BFA5),
    const Color(0xFFFF6B6B), const Color(0xFFFFB300),
    const Color(0xFF42A5F5), const Color(0xFFAB47BC),
    const Color(0xFF26A69A), const Color(0xFFEF5350),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Exam', style: TextStyle(fontWeight: FontWeight.bold))),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _categories.isEmpty
          ? Center(child: Text('No categories available', style: TextStyle(color: AppColors.textSecondary)))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final color = _colors[i % _colors.length];
                  return GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cat['icon'] ?? '📚', style: const TextStyle(fontSize: 36)),
                          const SizedBox(height: 12),
                          Text(cat['name'] ?? '', textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
