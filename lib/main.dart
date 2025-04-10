// lib/main.dart
import 'package:flutter/material.dart';
import 'package:language_learning_app/app/app.dart';

void main() async {
  // Flutter binding initialization is required before any platform channels are used
  WidgetsFlutterBinding.ensureInitialized();

  // Run the app with the app widget from app.dart
  runApp(const LanguageLearningApp());
}
