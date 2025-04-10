// lib/features/video_player/subtitle_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:language_learning_app/features/video_player/models/subtitle.dart';

class SubtitleService {
  // 本番環境では実際のAPIエンドポイントを使用
  static const String apiBaseUrl = 'https://your-api-endpoint.com';

  // ビデオIDに対する字幕を取得
  static Future<List<Subtitle>> getSubtitlesForVideo(String videoId) async {
    try {
      // Phase 1では、サンプルデータを使用
      // Phase 2で実際のAPIを統合
      return _loadSampleSubtitles();

      // 実際のAPI呼び出しの例（Phase 2で実装）
      /*
      final response = await http.get(
        Uri.parse('$apiBaseUrl/transcribe?videoId=$videoId'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Subtitle.fromWhisperJson(item)).toList();
      } else {
        throw Exception('字幕の取得に失敗しました: ${response.statusCode}');
      }
      */
    } catch (e) {
      print('字幕取得エラー: $e');
      // エラー時にはサンプルデータを返す
      return _loadSampleSubtitles();
    }
  }

  // サンプル字幕データを読み込む
  static Future<List<Subtitle>> _loadSampleSubtitles() async {
    try {
      // ファイル読み込みを試みる
      final jsonString = await rootBundle.loadString(
        'lib/data/sample_subtitles.json',
      );
      final List<dynamic> jsonList = jsonDecode(jsonString);

      return jsonList
          .map(
            (json) => Subtitle(
              startTime: (json['start'] * 1000).round(),
              endTime: (json['end'] * 1000).round(),
              text: json['text'],
              translation: json['translation'],
            ),
          )
          .toList();
    } catch (e) {
      print('サンプル字幕読み込みエラー: $e');
      // ハードコードされたサンプルデータを返す
      return [
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
        Subtitle(
          startTime: 18000,
          endTime: 22000,
          text: "In English, we say 'Hello' or 'Hi' for greeting.",
          translation: "英語では、挨拶に「Hello」または「Hi」と言います。",
        ),
        Subtitle(
          startTime: 23000,
          endTime: 27000,
          text:
              "When meeting someone for the first time, say 'Nice to meet you'.",
          translation: "初めて会う人には「Nice to meet you」と言います。",
        ),
      ];
    }
  }
}
