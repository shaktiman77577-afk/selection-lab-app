// lib/presentation/screens/support/support_screen.dart
//
// Help & Raise a Ticket — ab app ke andar.
//
// Pehle Profile ka "Raise a Ticket" Chrome me selectionlab.in/support kholta
// tha. Wahan student dobara login karta tha (website ka session app se alag
// hai), isliye ticket zyadatar bina user_id ke banta tha aur admin panel me
// ye pata hi nahi chalta tha ki kisne bheja hai. Ab form app se jata hai, to
// user_id, naam, phone aur email apne aap bhar jate hain.
//
// Neeche student ke purane tickets aur unke jawab bhi dikhte hain
// (/admin-extra/tickets/mine) — pehle jawab sirf email par milta tha.
//
// Endpoints:
//   POST /admin-extra/tickets            (public — login zaroori nahi)
//   GET  /admin-extra/tickets/mine?user_id=

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import '../descriptive/descriptive_theme.dart';

class _Cat {
  final String id;
  final String icon;
  final String label;
  final String hint;
  const _Cat(this.id, this.icon, this.label, this.hint);
}

const _cats = <_Cat>[
  _Cat('payment', '💳', 'Payment problem',
      'Paid but not confirmed, refund, failed payment'),
  _Cat('access', '🔒', 'Cannot access what I bought',
      'Course, mock test or descriptive series locked'),
  _Cat('technical', '⚙️', 'Something is not working',
      'Test not opening, PDF not loading, app issue'),
  _Cat('content', '📚', 'Content or question issue',
      'Wrong answer, missing question, typo'),
  _Cat('other', '💬', 'Something else', 'Any other question'),
];

// Ticket banane se pehle turant jawab — website wale hi, taaki dono jagah
// student ko ek hi baat mile.
const _quick = <String, List<List<String>>>{
  'payment': [
    [
      'Money was deducted but I did not get access',
      'Aapka payment safe hai. Zyadatar kuch minute me apne aap khul jata hai. '
          'Na khule to neeche ticket banaiye aur payment ID (SMS ya UPI app se) '
          'likh dijiye — hum manually unlock kar denge.'
    ],
    [
      'Payment failed but money was deducted',
      'Failed payment bank khud refund karta hai, aam taur par 3-5 working days '
          'me. Aapko kuch nahi karna. Isse zyada waqt lage to transaction ID ke '
          'saath ticket banaiye.'
    ],
  ],
  'access': [
    [
      'I bought a bundle but only got one thing',
      'Pehle My Learning kholiye aur neeche kheench kar refresh kijiye. Bundle '
          'ka saara saamaan wahin dikhna chahiye. Phir bhi kuch missing ho to '
          'ticket banaiye — turant unlock kar denge.'
    ],
    [
      'My course shows as locked',
      'Dekhiye ki aap usi number ya Google account se login hain jisse payment '
          'kiya tha. Sabse common wajah yahi hoti hai. Phir bhi lock dikhe to '
          'jis number se paid kiya wo likh kar ticket banaiye.'
    ],
  ],
  'technical': [
    [
      'The test is not opening or is stuck',
      'Test band karke dobara kholiye — aapke jawab apne aap save rehte hain, '
          'kuch nahi jayega. Phir bhi na khule to kaun sa test hai, ye ticket me '
          'bata dijiye.'
    ],
    [
      'PDF is not loading',
      'PDF bade hote hain, unhe stable connection chahiye. WiFi aur mobile data '
          'badal kar dekhiye. Phir bhi na chale to kaun sa course aur kaun sa PDF '
          'hai, ticket me likh dijiye.'
    ],
  ],
  'content': [
    [
      'A question has a wrong answer',
      'Test ke result page par har question ke neeche "Report" ka button hai — '
          'wahi sabse tez tareeka hai. Ya yahan test ka naam aur question number '
          'likh kar ticket banaiye.'
    ],
  ],
  'other': [],
};

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String? _cat;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();

  bool _sending = false;
  bool _loadingMine = true;
  String? _error;
  Map<String, dynamic>? _done;
  List<Map<String, dynamic>> _mine = [];
  int? _userId;

  @override
  void initState() {
    super.initState();
    // context.read initState me safe hai jab tak build par depend na ho.
    final u = context.read<AuthProvider>().user;
    final raw = u?['id'];
    _userId = raw is int ? raw : int.tryParse('${raw ?? ''}');
    _name.text = (u?['name'] ?? '').toString();
    _phone.text = (u?['phone'] ?? '').toString();
    _email.text = (u?['email'] ?? '').toString();
    _loadMine();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    if (_userId == null) {
      setState(() => _loadingMine = false);
      return;
    }
    try {
      final res = await http
          .get(Uri.parse(
              '${AppConstants.apiUrl}/admin-extra/tickets/mine?user_id=$_userId'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final list = d['tickets'];
        if (list is List && mounted) {
          setState(() {
            _mine = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          });
        }
      }
    } catch (_) {
      // History na aaye to bhi naya ticket banaya ja sakta hai.
    }
    if (mounted) setState(() => _loadingMine = false);
  }

  Future<void> _send() async {
    final subject = _subject.text.trim();
    final message = _message.text.trim();

    if (subject.isEmpty || message.length < 10) {
      setState(() => _error =
          'Subject aur thoda detail likhiye (kam se kam 10 akshar).');
      return;
    }
    if (_phone.text.trim().isEmpty && _email.text.trim().isEmpty) {
      setState(() =>
          _error = 'Phone ya email me se ek zaroor dijiye, warna jawab kaise dein?');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final res = await http
          .post(
            Uri.parse('${AppConstants.apiUrl}/admin-extra/tickets'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': _userId,
              'name': _name.text.trim(),
              'phone': _phone.text.trim(),
              'email': _email.text.trim(),
              'category': _cat ?? 'other',
              'subject': subject,
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 25));

      final d = jsonDecode(res.body);
      if (!mounted) return;

      if (res.statusCode != 200 || d['success'] != true) {
        setState(() {
          _sending = false;
          _error = (d is Map ? d['detail'] : null)?.toString() ??
              'Ticket nahi ban paya. Thodi der baad try kijiye.';
        });
        return;
      }

      setState(() {
        _sending = false;
        _done = Map<String, dynamic>.from(d as Map);
        _subject.clear();
        _message.clear();
        _cat = null;
      });
      _loadMine();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Server tak nahi pahunch paye. Connection check kijiye.';
      });
    }
  }

  String _fmtDate(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}');
    if (d == null) return '';
    final l = d.toLocal();
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${l.day} ${m[l.month - 1]}';
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
        title: Text('Help & Support',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: t.text, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          if (_done != null) _successCard(t),
          Text('Aapki problem kya hai?',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: t.text)),
          const SizedBox(height: 12),
          ..._cats.map((c) => _catTile(t, c)),
          if (_cat != null) ...[
            const SizedBox(height: 18),
            ..._quickAnswers(t),
            _form(t),
          ],
          if (!_loadingMine && _mine.isNotEmpty) ...[
            const SizedBox(height: 26),
            Text('Your tickets',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: t.text)),
            const SizedBox(height: 12),
            ..._mine.map((m) => _ticketCard(t, m)),
          ],
        ],
      ),
    );
  }

  Widget _successCard(DT t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kDGreen.withOpacity(0.12),
        border: Border.all(color: kDGreen.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: kDGreen, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _done?['ticket_id'] != null
                        ? 'Ticket #${_done!['ticket_id']} created'
                        : 'Ticket created',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kDGreen,
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                    (_done?['message'] ??
                            'We usually reply within 24 hours.')
                        .toString(),
                    style: TextStyle(fontSize: 12.5, color: t.text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _catTile(DT t, _Cat c) {
    final on = _cat == c.id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _cat = on ? null : c.id;
          _error = null;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: on ? kDGold.withOpacity(0.10) : t.card,
          border: Border.all(color: on ? kDGold : t.line, width: on ? 1.4 : 1),
          borderRadius: BorderRadius.circular(13),
          boxShadow: on ? const [] : t.shadow,
        ),
        child: Row(
          children: [
            Text(c.icon, style: const TextStyle(fontSize: 19)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: t.text)),
                  const SizedBox(height: 2),
                  Text(c.hint,
                      style: TextStyle(fontSize: 11.5, color: t.muted)),
                ],
              ),
            ),
            Icon(on ? Icons.expand_less_rounded : Icons.chevron_right_rounded,
                color: t.muted, size: 20),
          ],
        ),
      ),
    );
  }

  List<Widget> _quickAnswers(DT t) {
    final list = _quick[_cat] ?? const [];
    if (list.isEmpty) return const [];
    return [
      Text('Ye pehle dekh lijiye',
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: t.muted)),
      const SizedBox(height: 9),
      ...list.map((qa) => Container(
            margin: const EdgeInsets.only(bottom: 9),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 13),
                childrenPadding:
                    const EdgeInsets.fromLTRB(13, 0, 13, 13),
                iconColor: t.muted,
                collapsedIconColor: t.muted,
                title: Text(qa[0],
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: t.text)),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(qa[1],
                        style: TextStyle(
                            fontSize: 13, height: 1.5, color: t.text2)),
                  ),
                ],
              ),
            ),
          )),
      const SizedBox(height: 16),
    ];
  }

  Widget _form(DT t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(14),
        boxShadow: t.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Raise a ticket',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: t.text)),
          const SizedBox(height: 12),
          _field(t, _name, 'Your name'),
          _field(t, _phone, 'Phone', keyboard: TextInputType.phone),
          _field(t, _email, 'Email', keyboard: TextInputType.emailAddress),
          _field(t, _subject, 'Subject — ek line me', max: 160),
          _field(t, _message, 'Poori baat likhiye',
              lines: 5, max: 3000),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!,
                style: const TextStyle(
                    color: Color(0xFFC0392B), fontSize: 12.5)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: kDGold,
                foregroundColor: const Color(0xFF1A1A1A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF1A1A1A)))
                  : const Text('Send ticket',
                      style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(DT t, TextEditingController c, String label,
      {int lines = 1, int? max, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TextField(
        controller: c,
        maxLines: lines,
        maxLength: max,
        keyboardType: keyboard,
        style: TextStyle(color: t.text, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: t.muted, fontSize: 13),
          counterText: '',
          filled: true,
          fillColor: t.chip,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        ),
      ),
    );
  }

  Widget _ticketCard(DT t, Map<String, dynamic> m) {
    final status = (m['status'] ?? 'open').toString();
    final reply = (m['admin_reply'] ?? '').toString();

    Color sc;
    switch (status) {
      case 'closed':
        sc = kDGreen;
        break;
      case 'replied':
        sc = kDGold;
        break;
      default:
        sc = t.muted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(13),
        boxShadow: t.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${m['id']}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: t.muted)),
              const SizedBox(width: 8),
              Text(_fmtDate(m['created_at']),
                  style: TextStyle(fontSize: 11.5, color: t.muted)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: sc.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: sc)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text((m['subject'] ?? '').toString(),
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: t.text)),
          const SizedBox(height: 4),
          Text((m['message'] ?? '').toString(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: t.text2)),
          if (reply.isNotEmpty) ...[
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: kDGold.withOpacity(0.08),
                border: Border.all(color: kDGold.withOpacity(0.25)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selection Lab team',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: kDGold)),
                  const SizedBox(height: 5),
                  Text(reply,
                      style: TextStyle(
                          fontSize: 13, height: 1.5, color: t.text2)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
