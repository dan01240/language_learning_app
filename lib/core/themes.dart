import 'package:flutter/material.dart';

/// アプリケーションのテーマを定義するクラス
class AppTheme {
  /// ライトモード用テーマ
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
      cardTheme: CardTheme(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      fontFamily: 'Roboto',
    );
  }

  /// ダークモード用テーマ
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
      cardTheme: CardTheme(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      fontFamily: 'Roboto',
    );
  }
}

/// テーマの色定義
class AppColors {
  static const Color primary = Color(0xFF2196F3);
  static const Color accent = Color(0xFF03A9F4);
  static const Color background = Color(0xFFF5F5F5);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color subtitleBackground = Color(0x88000000);
  static const Color subtitleText = Color(0xFFFFFFFF);
  static const Color selectedWord = Color(0xFFFFD54F);
}

/// テキストスタイルの定義
class AppTextStyles {
  static const TextStyle subtitleText = TextStyle(
    color: AppColors.subtitleText,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle subtitleTranslation = TextStyle(
    color: AppColors.subtitleText,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.italic,
  );

  static const TextStyle selectedWord = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    backgroundColor: AppColors.selectedWord,
  );
}
