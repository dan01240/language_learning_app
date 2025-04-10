// lib/features/video_player/services/youtube_service.dart
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// YouTube動画の情報を取得するためのサービスクラス
class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();
  bool _isDisposed = false;

  /// コンストラクタ
  YouTubeService();

  /// リソースを解放
  void dispose() {
    if (!_isDisposed) {
      _yt.close();
      _isDisposed = true;
    }
  }

  /// YouTube動画のメタデータを取得
  Future<VideoMetadata?> getVideoMetadata(String videoId) async {
    if (_isDisposed) return null;

    try {
      // 動画情報を取得
      final video = await _yt.videos.get(videoId);

      return VideoMetadata(
        id: video.id.value,
        title: video.title,
        author: video.author,
        duration: video.duration,
        thumbnailUrl: video.thumbnails.highResUrl,
      );
    } catch (e) {
      print('動画メタデータの取得エラー: $e');
      return null;
    }
  }

  /// 再生可能な動画URLを取得（最高品質のみ）
  Future<String?> getVideoUrl(String videoId) async {
    if (_isDisposed) return null;

    try {
      // 利用可能なストリームマニフェストを取得
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // 音声付きの最高品質の動画ストリームを取得
      final streamInfo = manifest.muxed.withHighestBitrate();

      if (streamInfo != null) {
        return streamInfo.url.toString();
      }

      return null;
    } catch (e) {
      print('動画URLの取得エラー: $e');
      return null;
    }
  }

  /// 字幕トラックを取得（YouTubeの場合）
  /// 注意: この機能はYouTube APIの制限により完全には機能しないことがあります
  Future<List<SubtitleTrack>> getSubtitleTracks(String videoId) async {
    if (_isDisposed) return [];

    try {
      // 字幕トラックを取得
      final manifest = await _yt.videos.closedCaptions.getManifest(videoId);

      return manifest.tracks
          .map(
            (track) => SubtitleTrack(
              language: track.language.code,
              name: track.language.name,
              url: '', // YouTubeAPIからは直接URLを取得できないため空にします
            ),
          )
          .toList();
    } catch (e) {
      print('字幕トラックの取得エラー: $e');
      return [];
    }
  }
}

/// 動画のメタデータを表すクラス
class VideoMetadata {
  final String id;
  final String title;
  final String author;
  final Duration? duration;
  final String thumbnailUrl;

  VideoMetadata({
    required this.id,
    required this.title,
    required this.author,
    this.duration,
    required this.thumbnailUrl,
  });
}

/// 字幕トラックを表すクラス
class SubtitleTrack {
  final String language;
  final String name;
  final String url;

  SubtitleTrack({
    required this.language,
    required this.name,
    required this.url,
  });
}
