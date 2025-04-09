/// アプリケーション全体で使用する定数を定義するクラス
class AppConstants {
  /// アプリの名前
  static const String appName = 'Language Learning App';

  /// 各画面のルート名
  static const String homeRoute = '/';
  static const String videoRoute = '/video';
  static const String savedWordsRoute = '/saved-words';
  static const String settingsRoute = '/settings';

  /// API関連の定数
  static const String jishoApiBaseUrl = 'https://jisho.org/api/v1/search/words';

  /// 字幕表示用の定数
  static const double subtitlePadding = 16.0;
  static const double subtitleBottomMargin = 56.0;
  static const int subtitleDisplayDuration = 200; // ミリ秒

  /// ローカルストレージのキー
  static const String savedWordsKey = 'saved_words';
  static const String recentVideosKey = 'recent_videos';
  static const String appSettingsKey = 'app_settings';
}

/// エラーメッセージ
class ErrorMessages {
  static const String videoLoadFailed = 'ビデオの読み込みに失敗しました';
  static const String subtitleLoadFailed = '字幕の読み込みに失敗しました';
  static const String networkError = 'ネットワークエラーが発生しました';
  static const String dictionaryError = '辞書データの取得に失敗しました';
}
