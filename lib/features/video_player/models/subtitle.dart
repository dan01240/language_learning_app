// lib/features/video_player/models/subtitle.dart
class Subtitle {
  final int startTime; // ミリ秒
  final int endTime; // ミリ秒
  final String text;
  final String? translation;

  Subtitle({
    required this.startTime,
    required this.endTime,
    required this.text,
    this.translation,
  });

  factory Subtitle.fromWhisperJson(
    Map<String, dynamic> json, {
    String? translation,
  }) {
    return Subtitle(
      startTime: (json['start'] * 1000).round(),
      endTime: (json['end'] * 1000).round(),
      text: json['text'].trim(),
      translation: translation,
    );
  }

  // fromJson メソッドを追加
  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(
      startTime: (json['start'] * 1000).round(),
      endTime: (json['end'] * 1000).round(),
      text: json['text'],
      translation: json['translation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': startTime / 1000.0,
      'end': endTime / 1000.0,
      'text': text,
      'translation': translation,
    };
  }

  bool isVisibleAt(int timeMs) {
    return timeMs >= startTime && timeMs <= endTime;
  }
}

class SubtitleList {
  final List<Subtitle> subtitles;

  SubtitleList(this.subtitles);

  factory SubtitleList.fromJson(List<dynamic> jsonList) {
    final List<Subtitle> subtitles =
        jsonList.map((json) => Subtitle.fromJson(json)).toList();
    return SubtitleList(subtitles);
  }

  Subtitle? getVisibleSubtitleAt(int timeMs) {
    for (final subtitle in subtitles) {
      if (subtitle.isVisibleAt(timeMs)) {
        return subtitle;
      }
    }
    return null;
  }
}
