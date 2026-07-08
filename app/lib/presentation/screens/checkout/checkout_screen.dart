// lib/presentation/screens/checkout/checkout_screen.dart
//
// Universal checkout — price breakdown (with fee lines), coupon apply,
// auto-listed public offers, Razorpay pay. Used by course / mock / descriptive.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../../core/network/razorpay_service.dart';
import '../../../data/providers/auth_provider.dart';
import '../descriptive/descriptive_theme.dart';

class CheckoutScreen extends StatefulWidget {
  final String productType; // 'course' | 'mock' | 'descriptive'
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

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _couponCtrl = TextEditingController();
  final RazorpayService _razorpay = RazorpayService();

  List<Map<String, dynamic>> _publicCoupons = [];
  String? _appliedCode;
  num _discount = 0;
  bool _checkingCoupon = false;
  bool _paying = false;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _loadPublicCoupons();
  }

  @override
  void dispose() {
    _razorpay.dispose();
    _couponCtrl.dispose();
    super.dispose();
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
      } else {
        setState(() {
          _appliedCode = null;
          _discount = 0;
          _couponError = data['reason']?.toString() ?? 'Invalid coupon';
          _checkingCoupon = false;
        });
      }
    } catch (e) {
      setState(() {
        _checkingCoupon = false;
        _couponError = 'Could not validate coupon. Check connection.';
      });
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
    setState(() => _paying = true);

    void onSuccess() {
      if (!mounted) return;
      setState(() => _paying = false);
      widget.onSuccess();
      Navigator.pop(context, true);
    }

    void onError(String err) {
      if (!mounted) return;
      setState(() => _paying = false);
      _snack(err);
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
      body: ListView(
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
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Coupon section ──
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
                    Icon(Icons.local_offer_rounded, size: 17, color: kDGold),
                    const SizedBox(width: 7),
                    Text('Apply Coupon',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: t.text)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_appliedCode != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: kDGreen.withOpacity(0.1),
                      border: Border.all(color: kDGreen.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: kDGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              '$_appliedCode applied — ₹${_discount.toInt()} off',
                              style: const TextStyle(
                                  color: kDGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                        GestureDetector(
                          onTap: _removeCoupon,
                          child: Text('Remove',
                              style: TextStyle(
                                  color: t.muted,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(color: t.text),
                          decoration: InputDecoration(
                            hintText: 'Enter coupon code',
                            hintStyle: TextStyle(color: t.muted, fontSize: 13.5),
                            filled: true,
                            fillColor: t.chip,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _checkingCoupon
                            ? null
                            : () => _applyCoupon(_couponCtrl.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kDGold,
                          foregroundColor: const Color(0xFF1A1A1A),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(_checkingCoupon ? '...' : 'Apply',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  if (_couponError != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 15, color: Color(0xFFC0392B)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(_couponError!,
                              style: const TextStyle(
                                  color: Color(0xFFC0392B), fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ],
                ],
                if (_publicCoupons.isNotEmpty && _appliedCode == null) ...[
                  const SizedBox(height: 14),
                  Text('AVAILABLE OFFERS',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          color: t.muted)),
                  const SizedBox(height: 8),
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
                            horizontal: 13, vertical: 11),
                        decoration: BoxDecoration(
                          color: kDGold.withOpacity(0.07),
                          border: Border.all(
                              color: kDGold.withOpacity(0.35)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.confirmation_number_outlined,
                                color: kDGold, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(code,
                                      style: const TextStyle(
                                          color: kDGold,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                          letterSpacing: 0.5)),
                                  Text(label,
                                      style: TextStyle(
                                          color: t.muted, fontSize: 11.5)),
                                ],
                              ),
                            ),
                            Text('TAP TO APPLY',
                                style: TextStyle(
                                    color: kDGold.withOpacity(0.8),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ── Pay button ──
          ElevatedButton(
            onPressed: _paying ? null : _pay,
            style: ElevatedButton.styleFrom(
              backgroundColor: kDGold,
              foregroundColor: const Color(0xFF1A1A1A),
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_paying)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Color(0xFF1A1A1A)))
                else
                  const Icon(Icons.lock_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                    _paying
                        ? 'Please wait…'
                        : 'Pay Securely  ·  ₹${_finalAmount.toInt()}',
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
      ),
    );
  }

  // Standard breakdown row
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

  // Fee row with strikethrough + FREE badge
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
