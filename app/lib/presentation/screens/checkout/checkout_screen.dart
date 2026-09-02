// lib/presentation/screens/checkout/checkout_screen.dart
//
// Universal checkout — price breakdown, coupon apply (with confetti + sound),
// animated pay flow (loading → success/failed overlay), Razorpay.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/razorpay_service.dart';
import '../../../data/providers/auth_provider.dart';
import '../descriptive/descriptive_theme.dart';

enum _PayState { idle, loading, success, failed }

class CheckoutScreen extends StatefulWidget {
  final String productType; // 'course' | 'mock' | 'descriptive' | 'tier2' | 'live_batch' | 'live_class'
  final int productId;
  final String title;
  final num price;
  final num originalPrice;
  final void Function() onSuccess;

  CheckoutScreen({
    super.key,
    required this.productType,
    required this.productId,
    required this.title,
    required this.price,
    required this.onSuccess,
    num? originalPrice,
  }) : originalPrice = originalPrice ?? price;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with TickerProviderStateMixin {
  final _couponCtrl = TextEditingController();
  final RazorpayService _razorpay = RazorpayService();
  final AudioPlayer _audio = AudioPlayer();

  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 900));
  late final AnimationController _shakeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));

  List<Map<String, dynamic>> _publicCoupons = [];
  String? _appliedCode;
  num _discount = 0;
  bool _checkingCoupon = false;
  String? _couponError;

  _PayState _payState = _PayState.idle;

  @override
  void initState() {
    super.initState();
    _loadPublicCoupons();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackCart());
  }

  /// Records this checkout so an abandoned-cart reminder can be sent
  /// if the user leaves without paying. Fire-and-forget — never blocks UI.
  Future<void> _trackCart() async {
    try {
      final auth = context.read<AuthProvider>();
      final rawId = auth.user?['id'];
      final uid = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
      if (uid == null) return;

      await http.post(
        Uri.parse('${AppConstants.apiUrl}/cart/track'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': uid,
          'product_type': widget.productType,
          'product_id': widget.productId,
          'title': widget.title,
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  @override
  void dispose() {
    _razorpay.dispose();
    _couponCtrl.dispose();
    _confetti.dispose();
    _shakeCtrl.dispose();
    _audio.dispose();
    super.dispose();
  }

  void _playSound(String file) {
    // never let a missing asset crash the flow
    _audio.play(AssetSource('sounds/$file')).catchError((_) {});
  }

  num get _baseDiscount =>
      widget.originalPrice > widget.price ? widget.originalPrice - widget.price : 0;
  num get _finalAmount => (widget.price - _discount).clamp(1, widget.price);
  num get _totalSaved => _baseDiscount + _discount;

  String get _productLabel {
    switch (widget.productType) {
      case 'mock':
        return 'Mock Test Series';
      case 'descriptive':
        return 'Descriptive Series';
      case 'live_batch':
        return 'Live Batch';
      case 'live_class':
        return 'Live Class';
      default:
        return 'Course';
    }
  }

  IconData get _productIcon {
    switch (widget.productType) {
      case 'mock':
        return Icons.quiz_rounded;
      case 'descriptive':
        return Icons.edit_note_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  Future<void> _loadPublicCoupons() async {
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.apiUrl}/coupons/public'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      final list = (data['coupons'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .where((c) {
        final scopeType = (c['scope_type'] ?? 'all').toString();
        if (scopeType == 'all') return true;
        return scopeType == widget.productType &&
            (c['scope_id']?.toString() ?? '') == widget.productId.toString();
      }).toList();
      if (mounted) setState(() => _publicCoupons = list);
    } catch (_) {}
  }

  Future<void> _applyCoupon(String code) async {
    if (code.trim().isEmpty) return;
    setState(() {
      _checkingCoupon = true;
      _couponError = null;
    });
    try {
      final res = await http
          .post(
            Uri.parse('${AppConstants.apiUrl}/coupons/validate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code': code.trim(),
              'amount': widget.price,
              'product_type': widget.productType,
              'product_id': widget.productId.toString(),
            }),
          )
          .timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body);
      if (data['valid'] == true) {
        setState(() {
          _appliedCode = code.trim().toUpperCase();
          _discount = (data['discount'] as num?) ?? 0;
          _checkingCoupon = false;
        });
        HapticFeedback.mediumImpact();
        _confetti.play();
        _playSound('coupon_success.mp3');
      } else {
        setState(() {
          _appliedCode = null;
          _discount = 0;
          _couponError = data['reason']?.toString() ?? 'Invalid coupon';
          _checkingCoupon = false;
        });
        HapticFeedback.heavyImpact();
        _shakeCtrl.forward(from: 0);
        _playSound('coupon_error.mp3');
      }
    } catch (e) {
      setState(() {
        _checkingCoupon = false;
        _couponError = 'Could not validate coupon. Check connection.';
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCode = null;
      _discount = 0;
      _couponCtrl.clear();
      _couponError = null;
    });
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pay() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?['id'] as int?;
    if (uid == null) {
      _snack('Please log in to continue.');
      return;
    }
    setState(() => _payState = _PayState.loading);
    HapticFeedback.mediumImpact();

    void onSuccess() async {
      if (!mounted) return;
      setState(() => _payState = _PayState.success);
      HapticFeedback.heavyImpact();
      _confetti.play();
      _playSound('coupon_success.mp3');
      widget.onSuccess();
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) Navigator.pop(context, true);
    }

    void onError(String err) async {
      if (!mounted) return;
      setState(() => _payState = _PayState.failed);
      HapticFeedback.heavyImpact();
      _shakeCtrl.forward(from: 0);
      _playSound('coupon_error.mp3');
      await Future.delayed(const Duration(milliseconds: 1600));
      if (mounted) {
        setState(() => _payState = _PayState.idle);
        _snack(err);
      }
    }

    final userName = (auth.user?['name'] ?? 'Student').toString();
    final userEmail = (auth.user?['email'] ?? '').toString();

    switch (widget.productType) {
      case 'course':
        _razorpay.payForCourse(context,
            userId: uid,
            courseId: widget.productId,
            userName: userName,
            userEmail: userEmail,
            couponCode: _appliedCode,
            onSuccess: onSuccess,
            onError: onError);
        break;
      case 'mock':
        _razorpay.payForMockSeries(context,
            userId: uid,
            seriesId: widget.productId,
            userName: userName,
            userEmail: userEmail,
            couponCode: _appliedCode,
            onSuccess: onSuccess,
            onError: onError);
        break;
      case 'descriptive':
        _razorpay.payForDescriptive(context,
            userId: uid,
            seriesId: widget.productId,
            userName: userName,
            userEmail: userEmail,
            couponCode: _appliedCode,
            onSuccess: onSuccess,
            onError: onError);
        break;
      case 'tier2':
        _razorpay.payForTier2(context,
            userId: uid,
            seriesId: widget.productId,
            userName: userName,
            userEmail: userEmail,
            couponCode: _appliedCode,
            onSuccess: onSuccess,
            onError: onError);
        break;
      case 'live_batch':
        _razorpay.payForLive(context,
            userId: uid,
            kind: 'batch',
            itemId: widget.productId,
            userName: userName,
            userEmail: userEmail,
            onSuccess: onSuccess,
            onError: onError);
        break;
      case 'live_class':
        _razorpay.payForLive(context,
            userId: uid,
            kind: 'class',
            itemId: widget.productId,
            userName: userName,
            userEmail: userEmail,
            onSuccess: onSuccess,
            onError: onError);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = DT(Theme.of(context).brightness == Brightness.dark);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: t.text),
        title: Text('Checkout',
            style: TextStyle(fontWeight: FontWeight.w800, color: t.text)),
      ),
      body: Stack(
        children: [
          _content(t),
          // confetti burst from top-center
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 7,
              gravity: 0.25,
              emissionFrequency: 0.05,
              colors: const [kDGold, kDGreen, kDNavy2, Colors.white],
            ),
          ),
          if (_payState != _PayState.idle) _payOverlay(t),
        ],
      ),
    );
  }

  Widget _content(DT t) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── Product card ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kDNavy, kDNavy2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: kDGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_productIcon, color: kDGold, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_productLabel.toUpperCase(),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 3),
                    Text(widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Price breakdown ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(16),
            boxShadow: t.shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 17, color: kDGold),
                  const SizedBox(width: 7),
                  Text('Price Details',
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: t.text)),
                ],
              ),
              const SizedBox(height: 14),
              _row(t, '$_productLabel Price',
                  '₹${widget.originalPrice.toInt()}'),
              if (_baseDiscount > 0)
                _row(t, 'Discount', '− ₹${_baseDiscount.toInt()}',
                    valueColor: kDGreen),
              _feeRow(t, 'Internet Handling Fee', '₹10'),
              _feeRow(t, 'Platform Fee', '₹5'),
              _row(t, 'GST', 'Included',
                  valueColor: t.muted, valueSize: 12.5),
              if (_discount > 0)
                _row(t, 'Coupon ($_appliedCode)', '− ₹${_discount.toInt()}',
                    valueColor: kDGreen),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: _dashedDivider(t),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Payable',
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: t.text)),
                  Text('₹${_finalAmount.toInt()}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: kDGold)),
                ],
              ),
              if (_totalSaved > 0) ...[
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  key: ValueKey(_totalSaved),
                  tween: Tween(begin: 0.9, end: 1),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.elasticOut,
                  builder: (_, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: kDGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                        '🎉 You are saving ₹${_totalSaved.toInt()} on this order',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: kDGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Coupon section ──
        AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (context, child) {
            final dx = (_couponError != null)
                ? (8 * (1 - _shakeCtrl.value) *
                    (0.5 - ((_shakeCtrl.value * 4) % 1)).sign)
                : 0.0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kDGold.withOpacity(t.dark ? 0.10 : 0.06),
                  t.card,
                ],
              ),
              border: Border.all(
                  color: _couponError != null
                      ? const Color(0xFFC0392B).withOpacity(0.5)
                      : kDGold.withOpacity(0.35)),
              borderRadius: BorderRadius.circular(18),
              boxShadow: t.shadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: kDGold.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(Icons.local_offer_rounded,
                          size: 16, color: kDGold),
                    ),
                    const SizedBox(width: 10),
                    Text('Apply Coupon',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: t.text)),
                  ],
                ),
                const SizedBox(height: 14),

                if (_appliedCode != null)
                  // Applied state
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: kDGreen.withOpacity(0.10),
                      border: Border.all(color: kDGreen.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: kDGreen, size: 19),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                              '$_appliedCode applied — ₹${_discount.toInt()} off',
                              style: const TextStyle(
                                  color: kDGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5)),
                        ),
                        GestureDetector(
                          onTap: _removeCoupon,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: t.dark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Remove',
                                style: TextStyle(
                                    color: t.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Input field (full width, own row — never collapses)
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.dark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _couponError != null
                              ? const Color(0xFFC0392B).withOpacity(0.6)
                              : kDGold.withOpacity(0.45),
                          width: 1.3),
                    ),
                    child: TextField(
                      controller: _couponCtrl,
                      textCapitalization: TextCapitalization.characters,
                      cursorColor: kDGold,
                      style: TextStyle(
                          color: t.dark ? Colors.white : Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Enter coupon code',
                        hintStyle: TextStyle(
                            color: t.dark
                                ? Colors.white38
                                : Colors.black.withOpacity(0.35),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3),
                      ),
                    ),
                  ),
                  if (_couponError != null) ...[
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 15, color: Color(0xFFC0392B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(_couponError!,
                              style: const TextStyle(
                                  color: Color(0xFFC0392B),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Apply button (full width)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _checkingCoupon
                          ? null
                          : () => _applyCoupon(_couponCtrl.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDGold,
                        foregroundColor: const Color(0xFF1A1A1A),
                        disabledBackgroundColor: kDGold.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _checkingCoupon
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Color(0xFF1A1A1A)),
                            )
                          : const Text('Apply Coupon',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                    ),
                  ),
                ],

                if (_publicCoupons.isNotEmpty && _appliedCode == null) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('AVAILABLE OFFERS',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                              letterSpacing: 1.0,
                              color: t.muted)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Divider(
                              color: t.line, thickness: 1, height: 1)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._publicCoupons.map((c) {
                    final code = (c['code'] ?? '').toString();
                    final label = c['discount_type'] == 'percent'
                        ? '${c['discount_value']}% OFF'
                        : '₹${c['discount_value']} OFF';
                    return GestureDetector(
                      onTap: () {
                        _couponCtrl.text = code;
                        _applyCoupon(code);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 12),
                        decoration: BoxDecoration(
                          color: kDGold.withOpacity(0.07),
                          border: Border.all(color: kDGold.withOpacity(0.35)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: kDGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                  Icons.confirmation_number_outlined,
                                  color: kDGold,
                                  size: 17),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(code,
                                      style: const TextStyle(
                                          color: kDGold,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          letterSpacing: 0.5)),
                                  const SizedBox(height: 1),
                                  Text(label,
                                      style: TextStyle(
                                          color: t.muted, fontSize: 11.5)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: kDGold,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Text('APPLY',
                                  style: TextStyle(
                                      color: Color(0xFF1A1A1A),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10.5,
                                      letterSpacing: 0.5)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),

        // ── Pay button ──
        ElevatedButton(
          onPressed: _payState != _PayState.idle ? null : _pay,
          style: ElevatedButton.styleFrom(
            backgroundColor: kDGold,
            foregroundColor: const Color(0xFF1A1A1A),
            minimumSize: const Size(double.infinity, 54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 18),
              const SizedBox(width: 8),
              Text('Pay Securely  ·  ₹${_finalAmount.toInt()}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_rounded, size: 14, color: t.muted),
            const SizedBox(width: 5),
            Text('100% secure payments powered by Razorpay',
                style: TextStyle(fontSize: 11.5, color: t.muted)),
          ],
        ),
      ],
    );
  }

  // ── Full-screen pay overlay (loading / success / failed) ──
  Widget _payOverlay(DT t) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.75),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _payState == _PayState.loading
                ? Column(
                    key: const ValueKey('loading'),
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: CircularProgressIndicator(
                            color: kDGold, strokeWidth: 3.5),
                      ),
                      SizedBox(height: 22),
                      Text('Here we go! 🚀',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 6),
                      Text('Opening secure payment…',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  )
                : _payState == _PayState.success
                    ? _resultBadge(
                        key: 'success',
                        icon: Icons.check_rounded,
                        color: kDGreen,
                        title: 'Payment Successful!',
                        subtitle: 'Unlocking your content…',
                      )
                    : _resultBadge(
                        key: 'failed',
                        icon: Icons.close_rounded,
                        color: const Color(0xFFC0392B),
                        title: 'Payment Failed',
                        subtitle: 'No money was deducted. Try again.',
                      ),
          ),
        ),
      ),
    );
  }

  Widget _resultBadge({
    required String key,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Column(
      key: ValueKey(key),
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (_, v, __) => Transform.scale(
            scale: v,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
              ),
              child: Icon(icon, color: color, size: 52),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  Widget _row(DT t, String label, String value,
      {Color? valueColor, double valueSize = 13.5}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: t.text2)),
          Text(value,
              style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? t.text)),
        ],
      ),
    );
  }

  Widget _feeRow(DT t, String label, String struckAmount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: t.text2)),
          Row(
            children: [
              Text(struckAmount,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: t.muted,
                      decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 6),
              const Text('FREE',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kDGreen)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dashedDivider(DT t) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 8).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: 4, height: 1, color: t.line),
          ),
        );
      },
    );
  }
}
