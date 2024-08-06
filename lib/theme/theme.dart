import 'package:flutter/material.dart';

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    background: Colors.white,
    primary: Colors.black,
    secondary: Colors.grey.shade200,
  ), // ColorScheme.light
); // ThemeData

ThemeData darkMode = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      background: Colors.black,
      primary: Colors.deepPurple,
      inversePrimary: Colors.deepPurple,
      secondary: Colors.grey.shade900,
    ),
    useMaterial3: true // ColorScheme.dark
    ); // ThemeData
