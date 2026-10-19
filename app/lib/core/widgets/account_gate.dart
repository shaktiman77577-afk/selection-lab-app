// lib/core/widgets/account_gate.dart
//
// Login bina OTP (Oct 2026) — website ke AccountPopup jaisa, app ke liye.
// HomeScreen khulte hi AccountGate.run():
//
//  1. Sliding session: din me ek baar /users/refresh-token — naya token.
//     Roz aane wala student kabhi logout nahi hota (dobara OTP nahi).
//     Token hi nahi / expire ho gaya / account merge ho chuka -> "Sign in again"
//     (PDF wagairah ab login token maangte hain).
//  2. App session me ek baar /users/account-status, phir sirf EK cheez:
//       - profile adhoora        -> "Complete profile" (baad me bhi chalega)
//       - phone wala, password nahi -> password set karna ZAROORI
//       - email nahi             -> email jodo (doosre account ka ho to merge)
//       - phone nahi             -> number jodo (doosre account ka ho to merge)
//
// AccountGate.openLink() — My Learning ka "Purchase missing?": doosre login
// (Google vs mobile) wale account ko is account me milao.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers/auth_provider.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/profile_setup_screen.dart';
import '../../presentation/screens/home/home_screen.dart';

const _gold = Color(0xFFFFAB00);

enum AccountKind { profile, password, email, phone, link }

class AccountGate {
  static bool _checked = false; // is app session me status dekh liya
  static bool _running = false;
  static VoidCallback? _toggleTheme;

  // Kitne din baad dobara poochna hai ("Later" dabaya to)
  static const _snoozeDays = {
    AccountKind.profile: 1,
    AccountKind.email: 3,
    AccountKind.phone: 3,
  };

  static String _snoozeKey(AccountKind k, Object? uid) =>
      'acct_snooze_${k.name}_$uid';

  static Future<bool> _snoozed(AccountKind k, Object? uid) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_snoozeKey(k, uid)) ?? 0) >
        DateTime.now().millisecondsSinceEpoch;
  }

  static Future<void> _snooze(AccountKind k, Object? uid) async {
    final days = _snoozeDays[k] ?? 0;
    if (days <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_snoozeKey(k, uid),
        DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch);
  }

  /// HomeScreen khulte hi. Kuch galat ho to chupchaap ruk jaata hai.
  static Future<void> run(BuildContext context,
      {required VoidCallback onToggleTheme}) async {
    _toggleTheme = onToggleTheme;
    if (_running) return;
    _running = true;
    try {
      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn) return;

      // 1) Sliding session
      final s = await auth.refreshSession();
      if (!context.mounted) return;
      if (s == 'merged' || s == 'expired' || s == 'no_token') {
        await _signInAgain(context, merged: s == 'merged');
        return;
      }

      // 2) Account update — app session me ek baar
      if (_checked) return;
      final st = await auth.accountStatus();
      if (!st.ok || !context.mounted) return;
      _checked = true;
      final d = st.data;
      final uid = auth.user?['id'];

      AccountKind? kind;
      if (d['profile_completed'] != true) {
        if (!await _snoozed(AccountKind.profile, uid)) kind = AccountKind.profile;
      } else if (d['needs_password'] == true) {
        kind = AccountKind.password;
      } else if (d['has_email'] != true &&
          !await _snoozed(AccountKind.email, uid)) {
        kind = AccountKind.email;
      } else if (d['has_phone'] != true &&
          !await _snoozed(AccountKind.phone, uid)) {
        kind = AccountKind.phone;
      }
      if (kind == null) return;

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!context.mounted) return;
      await _show(context, kind);
    } catch (_) {
      // popup na khule to bhi app chalta rahe
    } finally {
      _running = false;
    }
  }

  /// "Purchase missing?" — doosre account ko is account me milao.
  static Future<void> openLink(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    await _show(context, AccountKind.link);
  }

  static Future<void> _signInAgain(BuildContext context,
      {required bool merged}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(merged ? 'Your accounts were merged' : 'Please sign in again'),
          content: Text(merged
              ? 'This account was merged into your other Selection Lab account. '
                  'Sign in again — all your courses and purchases are there.'
              : 'For your security, please sign in again to keep opening your '
                  'courses, PDFs and tests.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => LoginScreen(onToggleTheme: _toggleTheme ?? () {})),
      (_) => false,
    );
  }

  static Future<void> _show(BuildContext context, AccountKind kind) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?['id'];

    if (kind == AccountKind.profile) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Complete your profile'),
          content: const Text(
              'Your profile is incomplete. It takes a minute — add your mobile '
              'number and a password so you can sign in without OTP.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Later')),
            ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Complete now')),
          ],
        ),
      );
      if (!context.mounted) return;
      if (go == true) {
        final u = auth.user ?? {};
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(
            onToggleTheme: _toggleTheme ?? () {},
            googleId: (u['google_id'] ?? '').toString(),
            email: (u['email'] ?? '').toString(),
            displayName: (u['name'] ?? '').toString(),
          ),
        ));
      } else {
        await _snooze(kind, uid);
      }
      return;
    }

    final mergedDone = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // Password zaroori hai — bahar tap karke band nahi hota
      isDismissible: kind != AccountKind.password,
      enableDrag: kind != AccountKind.password,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountSheet(kind: kind),
    );
    if (!context.mounted) return;
    if (mergedDone == true) {
      // Naya (bacha hua) account — home dobara, taaki sab nayi id se aaye
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => HomeScreen(onToggleTheme: _toggleTheme ?? () {})),
        (_) => false,
      );
    } else if (mergedDone == null) {
      await _snooze(kind, uid); // "Later" / bahar tap
    }
  }
}

/// Bottom sheet: password / email / phone / link — aur zaroorat ho to merge.
/// Pop value: true = merge ho gaya, false = kaam ho gaya, null = baad me.
class _AccountSheet extends StatefulWidget {
  final AccountKind kind;
  const _AccountSheet({required this.kind});

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _Merge {
  final String via; // phone | email
  final String value;
  final String name;
  final String contact;
  bool codeSent = false;
  _Merge(this.via, this.value, this.name, this.contact);
}

class _AccountSheetState extends State<_AccountSheet> {
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _value = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _canSkip = false;
  String _error = '';
  String _done = '';
  _Merge? _merge;

  AccountKind get kind => widget.kind;

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    _value.dispose();
    _code.dispose();
    super.dispose();
  }

  void _finish(String msg, {bool merged = false}) {
    HapticFeedback.mediumImpact();
    setState(() {
      _done = msg;
      _busy = false;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) Navigator.of(context).pop(merged);
    });
  }

  Future<void> _savePassword() async {
    setState(() => _error = '');
    if (_pw.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (_pw.text != _pw2.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() => _busy = true);
    final r = await context.read<AuthProvider>().setPassword(_pw.text);
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _busy = false;
        _error = r.detail;
        // Server ki gadbad me student atke nahi
        if (r.status == 0 || r.status >= 500) _canSkip = true;
      });
      return;
    }
    _finish('Password saved ✓ Next time sign in with your mobile number and password.');
  }

  Future<void> _saveContact() async {
    setState(() => _error = '');
    final auth = context.read<AuthProvider>();
    final raw = _value.text.trim();
    final isLink = kind == AccountKind.link;
    final isPhone = isLink ? !raw.contains('@') : kind == AccountKind.phone;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final v = isPhone
        ? (digits.length > 10 ? digits.substring(digits.length - 10) : digits)
        : raw.toLowerCase();
    if (isPhone && !RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
      setState(() => _error = 'Please enter a valid 10-digit mobile number');
      return;
    }
    if (!isPhone && !RegExp(r'^\S+@\S+\.\S+$').hasMatch(v)) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    setState(() => _busy = true);
    final c = isPhone
        ? await auth.accountCheck(phone: v)
        : await auth.accountCheck(email: v);
    if (!mounted) return;
    if (!c.ok) {
      setState(() {
        _busy = false;
        _error = c.detail;
      });
      return;
    }
    final status = c.data['status'];
    if (status == 'other') {
      final o = c.data['other'];
      final other = o is Map ? o : const {};
      if (other['banned'] == true) {
        setState(() {
          _busy = false;
          _error = 'This is linked to a suspended account. Please contact support.';
        });
        return;
      }
      setState(() {
        _busy = false;
        _merge = _Merge(isPhone ? 'phone' : 'email', v,
            (other['name'] ?? '').toString(), (other['contact'] ?? '').toString());
      });
      return;
    }
    if (isLink) {
      // Link me sirf merge — naya number/email is account par nahi jodte
      setState(() {
        _busy = false;
        _error = status == 'mine'
            ? 'This is already your current account. Enter the mobile number or email you used when you made the purchase.'
            : 'No Selection Lab account found with this ${isPhone ? 'mobile number' : 'email'}. Please check and try again.';
      });
      return;
    }
    if (status == 'free') {
      final err = isPhone
          ? await auth.addContact(phone: v)
          : await auth.addContact(email: v);
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _busy = false;
          _error = err;
        });
        return;
      }
    }
    _finish(isPhone ? 'Mobile number saved ✓' : 'Email saved ✓');
  }

  Future<void> _startMerge() async {
    final m = _merge;
    if (m == null) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final auth = context.read<AuthProvider>();
    final String? err;
    if (m.via == 'phone') {
      err = await auth.sendOtp(m.value);
    } else {
      final r = await auth.mergeStart(email: m.value);
      err = r.ok ? null : r.detail;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err != null) {
        _error = err;
      } else {
        m.codeSent = true;
      }
    });
  }

  Future<void> _confirmMerge() async {
    final m = _merge;
    if (m == null) return;
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Please enter the 6-digit code');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final auth = context.read<AuthProvider>();
    String? err;
    try {
      if (m.via == 'phone') {
        final idToken = await auth.otpIdToken(code);
        err = await auth.mergeConfirm(phone: m.value, idToken: idToken);
      } else {
        err = await auth.mergeConfirm(email: m.value, code: code);
      }
    } catch (e) {
      err = auth.otpErrorText(e);
    }
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err!;
      });
      return;
    }
    _finish('Accounts merged ✓ Everything is now in one account.', merged: true);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF221C10);
    final text2 = dark ? const Color(0xFFCFC7B6) : const Color(0xFF4A4232);
    final muted = dark ? const Color(0xFF9A917F) : const Color(0xFF776F5C);
    final card = dark ? const Color(0xFF16130E) : Colors.white;
    final chip = dark ? Colors.white.withOpacity(0.06) : const Color(0xFFF7F5EF);
    final line =
        dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.10);
    final user = context.read<AuthProvider>().user ?? {};
    final m = _merge;

    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          counterText: '',
          filled: true,
          fillColor: chip,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: _gold, width: 1.5)),
        );
    final fieldStyle =
        TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w600);
    final pStyle = TextStyle(color: text2, fontSize: 14, height: 1.55);

    Widget goldBtn(String label, VoidCallback onTap) => SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: const Color(0xFF1A1A1A),
              disabledBackgroundColor: _gold.withOpacity(0.5),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF1A1A1A)))
                : Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        );
    Widget laterBtn(String label) => Center(
          child: TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(label,
                style: TextStyle(
                    color: muted, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
        );

    final title = m != null
        ? 'Merge your accounts'
        : kind == AccountKind.link
            ? 'Link your other account'
            : kind == AccountKind.password
                ? 'Set your password'
                : kind == AccountKind.email
                    ? 'Add your email'
                    : 'Add your mobile number';

    final children = <Widget>[];
    if (_done.isNotEmpty) {
      children.add(Text(_done,
          style: const TextStyle(
              color: Color(0xFF2E9E57),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              height: 1.5)));
    } else if (m != null) {
      children.addAll([
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text:
                    'This ${m.via == 'phone' ? 'mobile number' : 'email'} is linked to your other Selection Lab account'),
            if (m.name.isNotEmpty)
              TextSpan(
                  text: ' (${m.name})',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            const TextSpan(
                text:
                    '. Merge both into one — courses, purchases and test results from both stay together.'),
          ]),
          style: pStyle,
        ),
        const SizedBox(height: 14),
        if (!m.codeSent)
          goldBtn(
              'Send ${m.via == 'phone' ? 'OTP' : 'code'} to ${m.contact.isNotEmpty ? m.contact : 'verify'}',
              _startMerge)
        else ...[
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
                color: text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 8),
            decoration: deco('6-digit code'),
          ),
          const SizedBox(height: 10),
          goldBtn('Verify & merge', _confirmMerge),
        ],
        laterBtn('Not now'),
      ]);
    } else if (kind == AccountKind.password) {
      final phone = (user['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
      final p10 = phone.length > 10 ? phone.substring(phone.length - 10) : phone;
      children.addAll([
        Text.rich(
          TextSpan(children: [
            const TextSpan(
                text:
                    "We're moving to password sign-in. Set a password once — next time sign in with your mobile number"),
            if (p10.isNotEmpty)
              TextSpan(
                  text: ' ($p10)',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            const TextSpan(text: ' and this password, no OTP needed.'),
          ]),
          style: pStyle,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pw,
          obscureText: true,
          style: fieldStyle,
          decoration: deco('New password (min 6 characters)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _pw2,
          obscureText: true,
          style: fieldStyle,
          decoration: deco('Confirm password'),
          onSubmitted: (_) => _savePassword(),
        ),
        const SizedBox(height: 12),
        goldBtn('Save password', _savePassword),
        if (_canSkip) laterBtn('Skip for now'),
      ]);
    } else {
      final isLink = kind == AccountKind.link;
      children.addAll([
        Text(
          isLink
              ? 'Bought something with a different login (for example Google instead of mobile number)? '
                  'Enter the mobile number or email of that account. We will verify it with a code and move '
                  'everything into one account.'
              : kind == AccountKind.email
                  ? 'Add your email so you can reset your password for free anytime, and get purchase receipts.'
                  : 'Add your mobile number so you can sign in with it.',
          style: pStyle,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _value,
          keyboardType: kind == AccountKind.phone
              ? TextInputType.phone
              : TextInputType.emailAddress,
          maxLength: kind == AccountKind.phone ? 10 : null,
          style: fieldStyle,
          decoration: deco(isLink
              ? 'Mobile number or email'
              : kind == AccountKind.email
                  ? 'you@example.com'
                  : '10-digit mobile number'),
          onSubmitted: (_) => _saveContact(),
        ),
        const SizedBox(height: 12),
        goldBtn(isLink ? 'Continue' : 'Save', _saveContact),
        laterBtn(isLink ? 'Cancel' : 'Later'),
      ]);
    }

    if (_error.isNotEmpty) {
      children.addAll([
        const SizedBox(height: 6),
        Text(_error,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFFD64545), fontSize: 13, height: 1.45)),
      ]);
    }

    return PopScope(
      // Password zaroori — back button se bhi band nahi (jab tak skip na mile)
      canPop: kind != AccountKind.password || _canSkip || _done.isNotEmpty,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: line, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(title,
                      style: TextStyle(
                          color: text,
                          fontSize: 19,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
