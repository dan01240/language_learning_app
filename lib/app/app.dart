import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:language_learning_app/core/constants.dart';
import 'package:language_learning_app/core/themes.dart';
import 'package:language_learning_app/features/saved_words/saved_word_repository.dart';
import 'package:language_learning_app/features/home/home_screen.dart';

/// アプリケーションのルートウィジェット
class LanguageLearningApp extends StatelessWidget {
  const LanguageLearningApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SavedWordRepository()),
        // 他のプロバイダーをここに追加
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system, // システム設定に従う
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
