import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:convert';
import '../constants/app_constants.dart';

/// Reusable Razorpay payment handler for courses and PDFs.
/// Usage:
///   final service = RazorpayService();
///   service.payForCourse(context, userId: 5, courseId: 1, onSuccess: () {...});
class RazorpayService {
  late Razorpay _razorpay;

  // Callbacks set per-payment
  void Function()? _onSuccess;
  void Function(String error)? _onError;
  BuildContext? _context;

  // Verification data (set before opening checkout)
  String _verifyEndpoint = '';
  Map<String, dynamic> _verifyBody = {};

  RazorpayService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  // ── COURSE PAYMENT ──────────────────────────────────────────────────────────
  Future<void> payForCourse(
    BuildContext context, {
    required int userId,
    required int courseId,
    required String userName,
    required String userEmail,
    required void Function() onSuccess,
    required void Function(String error) onError,
  }) async {
    _context = context;
    _onSuccess = onSuccess;
    _onError = onError;

    try {
      // 1. Create order on backend
      final res = await http.post(
        Uri.parse('${AppConstants.apiUrl}/payments/course-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'course_id': courseId}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        onError(data['detail'] ?? 'Could not start payment');
        return;
      }

      // 2. Set verify data for after payment
      _verifyEndpoint = '${AppConstants.apiUrl}/payments/verify-course';
      _verifyBody = {'user_id': userId, 'course_id': courseId};

      // 3. Open Razorpay checkout
      _openCheckout(
        keyId: data['key_id'],
        orderId: data['order_id'],
        amount: data['amount'],
        name: data['title'] ?? 'Selection Lab',
        description: 'Course Purchase',
        userName: userName,
        userEmail: userEmail,
      );
    } catch (e) {
      onError('Payment error: $e');
    }
  }

  // ── PDF PAYMENT ───────────────────────────────────────────────────────────────
  Future<void> payForPdf(
    BuildContext context, {
    required int userId,
    required int pdfId,
    required String userName,
    required String userEmail,
    required void Function() onSuccess,
    required void Function(String error) onError,
  }) async {
    _context = context;
    _onSuccess = onSuccess;
    _onError = onError;

    try {
      final res = await http.post(
        Uri.parse('${AppConstants.apiUrl}/payments/pdf-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'pdf_id': pdfId}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        onError(data['detail'] ?? 'Could not start payment');
        return;
      }

      _verifyEndpoint = '${AppConstants.apiUrl}/payments/verify-pdf';
      _verifyBody = {'user_id': userId, 'pdf_id': pdfId};

      _openCheckout(
        keyId: data['key_id'],
        orderId: data['order_id'],
        amount: data['amount'],
        name: data['title'] ?? 'Selection Lab',
        description: 'PDF Purchase',
        userName: userName,
        userEmail: userEmail,
      );
    } catch (e) {
      onError('Payment error: $e');
    }
  }

  // ── OPEN CHECKOUT ─────────────────────────────────────────────────────────────
  void _openCheckout({
    required String keyId,
    required String orderId,
    required int amount,
    required String name,
    required String description,
    required String userName,
    required String userEmail,
  }) {
    final options = {
      'key': keyId,
      'order_id': orderId,
      'amount': amount,
      'name': name,
      'description': description,
      'prefill': {
        'name': userName,
        'email': userEmail,
      },
      'theme': {'color': '#FFAB00'},
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      _onError?.call('Could not open checkout: $e');
    }
  }

  // ── PAYMENT SUCCESS → VERIFY ON BACKEND ──────────────────────────────────────
  Future<void> _handleSuccess(PaymentSuccessResponse response) async {
    try {
      final body = {
        ..._verifyBody,
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
      };
      final res = await http.post(
        Uri.parse(_verifyEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        _onSuccess?.call();
      } else {
        _onError?.call(data['detail'] ?? 'Payment verification failed');
      }
    } catch (e) {
      _onError?.call('Verification error: $e');
    }
  }

  void _handleError(PaymentFailureResponse response) {
    _onError?.call(response.message ?? 'Payment failed or cancelled');
  }

  void _handleWallet(ExternalWalletResponse response) {
    // External wallet selected (handled by Razorpay)
  }
}
