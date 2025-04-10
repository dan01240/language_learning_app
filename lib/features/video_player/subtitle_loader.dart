import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:language_learning_app/features/video_player/models/subtitle.dart';

/// 字幕データをロードするためのクラス
class SubtitleLoader {
  /// サンプルの字幕データをロード
  static Future<SubtitleList> loadSampleSubtitles() async {
    try {
      // サンプル字幕JSONファイルを読み込む
      final jsonString = await rootBundle.loadString(
        'lib/data/sample_subtitles.json',
      );
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return SubtitleList.fromJson(jsonList);
    } catch (e) {
      // JSONファイルが読み込めない場合はモデルに定義されたサンプルデータを使用
      return SubtitleList(SampleSubtitles.data);
    }
  }

  /// ビデオIDに対応する字幕をロード（将来的にAPIから取得する想定）
  static Future<SubtitleList> loadSubtitlesForVideo(String videoId) async {
    try {
      // TODO: 実際のAPIから字幕データを取得する処理を実装
      // 現在はサンプルデータを返す
      return loadSampleSubtitles();
    } catch (e) {
      // エラー時にはモデルに定義されたサンプルデータを使用
      return SubtitleList(SampleSubtitles.data);
    }
  }
}
