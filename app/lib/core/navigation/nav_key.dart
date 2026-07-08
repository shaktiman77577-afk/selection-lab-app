// lib/core/navigation/nav_key.dart
//
// Global navigator key so background/terminated push-notification taps can
// navigate to a screen without needing a BuildContext.

import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
