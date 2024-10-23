import 'package:flutter/material.dart';
import 'package:smart_lock/theme/font_styles.dart';

ThemeData lightMode = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      surface: Colors.white,
      primary: Colors.black,
      secondary: Colors.grey.shade200,
    ),
    useMaterial3: true);

ThemeData darkMode = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      surface: Colors.black,
      primary: Colors.white,
      //inversePrimary: Colors.deepPurple,
      secondary: Colors.grey.shade900,
    ),
    useMaterial3: true);
