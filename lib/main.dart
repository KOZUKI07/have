import 'package:flutter/material.dart';
import 'package:hand_gesture_app/screens/home_page.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      primaryColor: Colors.tealAccent,
      colorScheme: ColorScheme.dark(
        primary: Colors.tealAccent,
        secondary: Colors.tealAccent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: TextStyle(color: Colors.tealAccent),
        prefixIconColor: Colors.tealAccent,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.tealAccent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.tealAccent, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.tealAccent,
          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          padding: EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(fontSize: 16, color: Colors.white),
        labelLarge: TextStyle(color: Colors.tealAccent),
      ),
      iconTheme: IconThemeData(color: Colors.tealAccent),
    ),
    home: HomePage(),
  ));
}


// #1C274C
// uvicorn api:app --host 0.0.0.0 --port 8001 --reload
// LInux version