// lib/text_styles.dart

import 'package:flutter/material.dart';

class TextStyles {
  static const String fontFamily = 'SF-Pro';

  static TextStyle heading1(BuildContext context) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface, // Color según el tema
    );
  }

  static TextStyle normalText(BuildContext context) {
    return TextStyle(
      fontFamily: fontFamily,
      color: Theme.of(context)
          .colorScheme
          .onSurface
          .withOpacity(0.8), // Texto normal según el tema
    );
  }

  static TextStyle normalTextBold(BuildContext context) {
    return TextStyle(
      fontFamily: fontFamily,
      color: Theme.of(context)
          .colorScheme
          .onSurface, // Texto normal en modo oscuro
    );
  }
}
