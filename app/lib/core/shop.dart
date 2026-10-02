// lib/core/shop.dart
//
// App ke andar khareedna on/off — admin panel → App Content →
// "Purchases in the App (Android)". Default OFF.
//
// OFF: price, Buy / Enroll / Unlock, checkout aur coupon kahin nahi dikhte.
//      Free aur pehle se khareeda hua content poora chalta hai. Jo paid cheez
//      khareedi nahi, wo 🔒 Locked dikhti hai (price ke bina).
// ON : sab pehle jaisa.
//
// Config abhi load nahi hua (ya internet nahi) to bhi OFF maana jata hai —
// galti se bhi bina admin ke "on" kiye price nahi dikhna chahiye.
//
// Build ke andar:        context.shopOn        (config badle to rebuild)
// Button/callback ke andar: context.shopOnRead  (sirf ek baar padhta hai)

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/providers/app_config_provider.dart';

extension ShopX on BuildContext {
  bool get shopOn =>
      watch<AppConfigProvider>().config['app_purchases_enabled'] == true;

  bool get shopOnRead =>
      read<AppConfigProvider>().config['app_purchases_enabled'] == true;
}

/// Locked cheez par ek jaisa message (isme "website" ya koi link nahi — Play
/// Store ki policy ke hisaab se app me bahar ka khareedne ka raasta nahi dikhana)
const String kNotInAppMsg = 'This content is not available in the app yet.';
