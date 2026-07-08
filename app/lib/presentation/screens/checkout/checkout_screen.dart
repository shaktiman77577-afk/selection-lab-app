// lib/presentation/screens/checkout/checkout_screen.dart
//
// Universal checkout screen used by Course / Mock Series / Descriptive Series
// purchases. Shows price breakdown, lets the user apply a coupon (public
// coupons for this product show automatically), then triggers Razorpay.

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

  num get _finalAmount => (widget.price - _discount).clamp(1, widget.price);

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
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: t.text)),
                const SizedBox(height: 14),
                _priceRow('Price', '₹${widget.price.toInt()}', t),
                if (widget.originalPrice > widget.price)
                  _priceRow(
                      'You save',
                      '₹${(widget.originalPrice - widget.price).toInt()}',
                      t,
                      valueColor: kDGreen),
                if (_discount > 0)
                  _priceRow('Coupon discount', '− ₹${_discount.toInt()}', t,
                      valueColor: kDGreen),
                Divider(color: t.line, height: 24),
                _priceRow('Total payable', '₹${_finalAmount.toInt()}', t,
                    bold: true),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Have a coupon?',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: t.text)),
          const SizedBox(height: 8),
          if (_appliedCode != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: kDGreen.withOpacity(0.1),
                border: Border.all(color: kDGreen.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: kDGreen, size: 18),
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
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code',
                      filled: true,
                      fillColor: t.card,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: t.line)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
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
                        horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(_checkingCoupon ? '...' : 'Apply'),
                ),
              ],
            ),
            if (_couponError != null) ...[
              const SizedBox(height: 6),
              Text(_couponError!,
                  style: const TextStyle(
                      color: Color(0xFFC0392B), fontSize: 12.5)),
            ],
          ],
          if (_publicCoupons.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Available offers',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: t.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _publicCoupons.map((c) {
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kDGold.withOpacity(0.1),
                      border: Border.all(color: kDGold.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$code · $label',
                        style: const TextStyle(
                            color: kDGold,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _paying ? null : _pay,
            style: ElevatedButton.styleFrom(
              backgroundColor: kDGold,
              foregroundColor: const Color(0xFF1A1A1A),
              minimumSize: const Size(double.infinity, 52),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
                _paying ? 'Please wait…' : 'Pay ₹${_finalAmount.toInt()}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text('Secured by Razorpay',
                style: TextStyle(fontSize: 11.5, color: t.muted)),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, DT t,
      {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 15 : 13.5,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  color: bold ? t.text : t.muted)),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 17 : 13.5,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? (bold ? kDGold : t.text))),
        ],
      ),
    );
  }
}
