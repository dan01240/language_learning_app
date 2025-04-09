/// 字幕を表すクラス
class Subtitle {
  /// 字幕の開始時間（ミリ秒）
  final int startTime;

  /// 字幕の終了時間（ミリ秒）
  final int endTime;

  /// 字幕のテキスト（原語）
  final String text;

  /// 翻訳されたテキスト（翻訳先言語、例: 日本語）
  final String? translation;

  /// コンストラクタ
  Subtitle({
    required this.startTime,
    required this.endTime,
    required this.text,
    this.translation,
  });

  /// JSONからSubtitleオブジェクトを生成
  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(
      startTime: (json['start'] * 1000).round(),
      endTime: (json['end'] * 1000).round(),
      text: json['text'],
      translation: json['translation'],
    );
  }

  /// SubtitleオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'start': startTime / 1000.0,
      'end': endTime / 1000.0,
      'text': text,
      'translation': translation,
    };
  }

  /// 特定の時間に表示するべき字幕かどうかを判定
  bool isVisibleAt(int timeMs) {
    return timeMs >= startTime && timeMs <= endTime;
  }

  @override
  String toString() {
    return '[$startTime -> $endTime] $text${translation != null ? ' | $translation' : ''}';
  }
}

/// 字幕リストを管理するクラス
class SubtitleList {
  final List<Subtitle> subtitles;

  SubtitleList(this.subtitles);

  /// JSONからSubtitleListオブジェクトを生成
  factory SubtitleList.fromJson(List<dynamic> jsonList) {
    final List<Subtitle> subtitles =
        jsonList.map((json) => Subtitle.fromJson(json)).toList();
    return SubtitleList(subtitles);
  }

  /// 特定の時間に表示すべき字幕を取得
  Subtitle? getVisibleSubtitleAt(int timeMs) {
    for (final subtitle in subtitles) {
      if (subtitle.isVisibleAt(timeMs)) {
        return subtitle;
      }
    }
    return null;
  }
}

/// サンプル字幕データ
class SampleSubtitles {
  static List<Subtitle> get data => [
    Subtitle(
      startTime: 1000,
      endTime: 4000,
      text: "Hello, welcome to this language learning video.",
      translation: "こんにちは、この言語学習ビデオへようこそ。",
    ),
    Subtitle(
      startTime: 5000,
      endTime: 8000,
      text: "Today we will learn some basic vocabulary.",
      translation: "今日は基本的な語彙を学びます。",
    ),
    Subtitle(
      startTime: 9000,
      endTime: 13000,
      text: "Let's start with greetings and introductions.",
      translation: "挨拶と自己紹介から始めましょう。",
    ),
    Subtitle(
      startTime: 14000,
      endTime: 17000,
      text: "My name is Alex. Nice to meet you.",
      translation: "私の名前はアレックスです。よろしくお願いします。",
    ),
  ];
}
