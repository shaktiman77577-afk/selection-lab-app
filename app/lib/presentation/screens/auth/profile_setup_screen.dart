import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../home/home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final String googleId;
  final String email;
  final String displayName;

  const ProfileSetupScreen({
    super.key,
    required this.onToggleTheme,
    required this.googleId,
    required this.email,
    required this.displayName,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _cityController = TextEditingController();
  final _targetExamController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
    _nameController.text = widget.displayName;
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _nicknameController.dispose();
    _cityController.dispose();
    _targetExamController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    if (_cityController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your city');
      return;
    }
    if (_targetExamController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please select your target exam');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.mediumImpact();

    try {
      final url = Uri.parse('${AppConstants.apiUrl}/users/setup-profile');

      final body = jsonEncode({
        'google_id': widget.googleId,
        'email': widget.email,
        'name': _nameController.text.trim(),
        'phone': _mobileController.text.trim(),
        'nickname': _nicknameController.text.trim(),
        'city': _cityController.text.trim(),
        'target_exam': _targetExamController.text.trim(),
      });

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a, __) =>
                HomeScreen(onToggleTheme: widget.onToggleTheme),
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              data['detail'] ?? 'Error ${response.statusCode}. Try again.';
        });
      }
    } catch (e) {
      // Shows the REAL error so we can debug
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }
    if (_mobileController.text.trim().length != 10) {
      setState(() => _errorMessage = 'Enter valid 10-digit mobile number');
      return;
    }
    if (_nicknameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a nickname');
      return;
    }
    setState(() {
      _errorMessage = null;
      _currentStep = 1;
    });
    _animController.reset();
    _animController.forward();
  }

  void _prevStep() {
    setState(() {
      _currentStep = 0;
      _errorMessage = null;
    });
    _animController.reset();
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DotPatternPainter()),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Column(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.2),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Image.asset('assets/images/logo.png'),
                          ),
                          const SizedBox(height: 16),
                          RichText(
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'COMPLETE YOUR\n',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                TextSpan(
                                  text: 'PROFILE',
                                  style: TextStyle(
                                    color: Color(0xFFFFAB00),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Help us personalise your learning experience',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              _stepDot(0, 'Personal Info'),
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: _currentStep >= 1
                                      ? const Color(0xFFFFAB00)
                                      : Colors.white12,
                                ),
                              ),
                              _stepDot(1, 'Exam Details'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Form(
                          key: _formKey,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF141414).withOpacity(0.97),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color:
                                    const Color(0xFFFFAB00).withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 30,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_errorMessage != null) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    margin:
                                        const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color:
                                              Colors.red.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                                if (_currentStep == 0) ...[
                                  _label('Full Name'),
                                  _field(
                                    controller: _nameController,
                                    hint: 'Enter your full name',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                  const SizedBox(height: 16),
                                  _label('Mobile Number'),
                                  _field(
                                    controller: _mobileController,
                                    hint: '10-digit mobile number',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _label('Nickname'),
                                  _field(
                                    controller: _nicknameController,
                                    hint: 'What should we call you?',
                                    icon: Icons.badge_outlined,
                                  ),
                                  const SizedBox(height: 28),
                                  _goldButton(
                                    label: 'NEXT →',
                                    onTap: _nextStep,
                                    isLoading: false,
                                  ),
                                ] else ...[
                                  _label('City'),
                                  _field(
                                    controller: _cityController,
                                    hint: 'Your city',
                                    icon: Icons.location_city_outlined,
                                  ),
                                  const SizedBox(height: 16),
                                  _label('Target Exam'),
                                  _field(
                                    controller: _targetExamController,
                                    hint: 'e.g. SSC CGL, UPSC, Bank PO',
                                    icon: Icons.school_outlined,
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      'SSC CGL',
                                      'SSC CHSL',
                                      'UPSC',
                                      'Bank PO',
                                      'Bank Clerk',
                                      'Railway NTPC',
                                      'Delhi Police',
                                      'UP Police',
                                    ].map((exam) {
                                      final isSelected =
                                          _targetExamController.text == exam;
                                      return GestureDetector(
                                        onTap: () => setState(() =>
                                            _targetExamController.text =
                                                exam),
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFFFFAB00)
                                                    .withOpacity(0.2)
                                                : Colors.white
                                                    .withOpacity(0.05),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFFFFAB00)
                                                  : Colors.white12,
                                            ),
                                          ),
                                          child: Text(
                                            exam,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? const Color(0xFFFFAB00)
                                                  : Colors.white54,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 28),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: _prevStep,
                                        child: Container(
                                          height: 54,
                                          width: 54,
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withOpacity(0.05),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: Colors.white12),
                                          ),
                                          child: const Icon(
                                            Icons.arrow_back_rounded,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _goldButton(
                                          label: 'GET STARTED',
                                          onTap: _submitProfile,
                                          isLoading: _isLoading,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }

  Widget _stepDot(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFFFFAB00) : Colors.white12,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white38,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFFFFAB00) : Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
        prefixIcon:
            Icon(icon, color: const Color(0xFFFFAB00), size: 20),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFFFAB00), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _goldButton({
    required String label,
    required VoidCallback onTap,
    required bool isLoading,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFAB00), Color(0xFFFF6F00)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFAB00).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;

    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter oldDelegate) => false;
}
