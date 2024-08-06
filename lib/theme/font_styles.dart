// lib/text_styles.dart

import 'package:flutter/material.dart';

class TextStyles {
  static const String fontFamily = 'SF-Pro';

  static TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  static TextStyle normalText =
      TextStyle(fontFamily: fontFamily, color: Colors.white.withOpacity(0.8));
}
