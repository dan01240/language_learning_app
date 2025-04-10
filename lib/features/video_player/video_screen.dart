// lib/features/video_player/video_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:language_learning_app/features/video_player/models/subtitle.dart';
import 'package:language_learning_app/features/video_player/subtitle_overlay.dart';
import 'package:language_learning_app/features/video_player/subtitle_loader.dart';
import 'package:language_learning_app/features/video_player/services/youtube_service.dart';
import 'package:language_learning_app/features/video_player/widgets/native_video_player.dart';
import 'package:language_learning_app/core/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// ビデオ再生画面
class VideoScreen extends StatefulWidget {
  /// ビデオID
  final String videoId;

  /// コンストラクタ
  const VideoScreen({Key? key, required this.videoId}) : super(key: key);

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> with WidgetsBindingObserver {
  // YouTubeサービス
  final YouTubeService _youtubeService = YouTubeService();

  // 動画情報
  String? _videoUrl;
  VideoMetadata? _videoMetadata;

  // 字幕関連
  final GlobalKey<NativeVideoPlayerState> _videoPlayerKey =
      GlobalKey<NativeVideoPlayerState>();
  Timer? _subtitleTimer;
  Subtitle? _currentSubtitle;
  SubtitleList? _subtitles;

  // 状態フラグ
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPlayerReady = false;
  bool _playerError = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVideoData();
    _loadSubtitles();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // アプリがバックグラウンドに行ったらプレーヤーを一時停止
    if (state == AppLifecycleState.paused) {
      _pausePlayer();
    }
  }

  @override
  void dispose() {
    print('VideoScreen: dispose called');
    _isDisposed = true;

    // タイマーをキャンセル
    if (_subtitleTimer != null) {
      _subtitleTimer!.cancel();
      _subtitleTimer = null;
    }

    // YouTubeサービスを解放
    _youtubeService.dispose();

    // 画面を離れる際に縦向きに戻す
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 動画の情報をロード
  Future<void> _loadVideoData() async {
    if (_isDisposed) return;

    try {
      // まず動画のメタデータを取得
      final metadata = await _youtubeService.getVideoMetadata(widget.videoId);

      if (_isDisposed) return;

      if (metadata == null) {
        setState(() {
          _errorMessage = '動画情報の取得に失敗しました';
          _isLoading = false;
          _playerError = true;
        });
        return;
      }

      // 次に再生可能なURLを取得
      final videoUrl = await _youtubeService.getVideoUrl(widget.videoId);

      if (_isDisposed) return;

      if (videoUrl == null) {
        setState(() {
          _errorMessage = '再生可能な動画URLの取得に失敗しました';
          _isLoading = false;
          _playerError = true;
        });
        return;
      }

      // 情報を更新
      setState(() {
        _videoMetadata = metadata;
        _videoUrl = videoUrl;
        _isLoading = false;
      });
    } catch (e) {
      print('動画データのロードエラー: $e');
      if (_isDisposed) return;

      setState(() {
        _errorMessage = '動画の読み込みに失敗しました: $e';
        _isLoading = false;
        _playerError = true;
      });
    }
  }

  /// プレーヤーを一時停止
  void _pausePlayer() {
    if (_isDisposed) return;

    final videoPlayerState = _videoPlayerKey.currentState;
    if (videoPlayerState != null) {
      videoPlayerState.pause();
    }
  }

  /// プレーヤーの準備ができたときの処理
  void _onPlayerReady() {
    if (_isDisposed) return;

    setState(() {
      _isPlayerReady = true;
      _isLoading = false;
    });
    _startSubtitleTimer();
  }

  /// プレーヤーのエラー時の処理
  void _onPlayerError() {
    if (_isDisposed) return;

    setState(() {
      _playerError = true;
      _errorMessage = 'プレーヤーでエラーが発生しました。別の方法で再生してみてください。';
    });
  }

  /// 字幕データを読み込む
  Future<void> _loadSubtitles() async {
    if (_isDisposed) return;

    try {
      final subtitles = await SubtitleLoader.loadSubtitlesForVideo(
        widget.videoId,
      );

      if (_isDisposed) return;

      if (mounted) {
        setState(() {
          _subtitles = subtitles;
        });
      }
    } catch (e) {
      if (_isDisposed) return;

      if (mounted) {
        setState(() {
          print('字幕の読み込みエラー: $e');
          // 字幕エラーはクリティカルではないので、ユーザーには表示しない
        });
      }
    }
  }

  /// 字幕同期用のタイマーを開始
  void _startSubtitleTimer() {
    if (_isDisposed) return;

    _subtitleTimer?.cancel();
    _subtitleTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      _updateSubtitle();
    });
  }

  /// 現在の再生時間に合わせて字幕を更新
  void _updateSubtitle() {
    if (_isDisposed || !mounted || _subtitles == null || !_isPlayerReady)
      return;

    try {
      final videoPlayerState = _videoPlayerKey.currentState;
      if (videoPlayerState == null) return;

      final currentTimeMs = videoPlayerState.getCurrentPositionMs();
      if (currentTimeMs == null) return;

      final subtitle = _subtitles!.getVisibleSubtitleAt(currentTimeMs);

      if (subtitle != _currentSubtitle) {
        setState(() {
          _currentSubtitle = subtitle;
        });
      }
    } catch (e) {
      // エラーを黙って処理
      print('字幕更新中にエラー: $e');
    }
  }

  /// 単語がタップされたときの処理
  void _onWordTap(String word) {
    if (_isDisposed) return;

    final videoPlayerState = _videoPlayerKey.currentState;
    if (videoPlayerState != null) {
      videoPlayerState.pause();
    }
  }

  /// YouTubeアプリで開く
  Future<void> _openInYouTubeApp() async {
    final youtubeUrl = 'https://www.youtube.com/watch?v=${widget.videoId}';
    final uri = Uri.parse(youtubeUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('YouTubeアプリを開けませんでした')));
        }
      }
    } catch (e) {
      print('YouTubeアプリ起動エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // GoRouterを使用してホーム画面に戻る
            context.go(AppConstants.homeRoute);
          },
        ),
        title: Text(_videoMetadata?.title ?? 'Language Learning Player'),
        actions: [
          // エラー時にYouTubeアプリで開くボタンを表示
          if (_playerError)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: _openInYouTubeApp,
              tooltip: 'YouTubeアプリで開く',
            ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              // GoRouterを使用して保存単語画面に移動
              context.go(AppConstants.savedWordsRoute);
            },
            tooltip: '保存した単語',
          ),
        ],
      ),
      body: Column(
        children: [
          // ビデオプレーヤー部分
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                // プレーヤーを表示
                if (_videoUrl != null && !_isDisposed)
                  NativeVideoPlayer(
                    key: _videoPlayerKey,
                    videoUrl: _videoUrl!,
                    onReady: _onPlayerReady,
                    onError: _onPlayerError,
                    autoPlay: true,
                  ),

                // 動画URLがまだない場合はサムネイルを表示
                if (_videoUrl == null &&
                    _videoMetadata != null &&
                    !_isLoading &&
                    !_playerError)
                  Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: _videoMetadata!.thumbnailUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder:
                            (context, url) => Container(
                              color: Colors.black,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              color: Colors.black54,
                              child: const Icon(
                                Icons.error,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                      ),
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                    ],
                  ),

                // 字幕オーバーレイ
                if (_currentSubtitle != null && !_isDisposed && _isPlayerReady)
                  SubtitleOverlay(
                    currentSubtitle: _currentSubtitle,
                    onWordTap: _onWordTap,
                  ),

                // ローディング表示
                if (_isLoading && !_isDisposed)
                  Container(
                    color: Colors.black45,
                    child: const Center(child: CircularProgressIndicator()),
                  ),

                // エラー表示
                if (_errorMessage != null && !_isDisposed)
                  Container(
                    color: Colors.black45,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (_playerError)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('YouTubeアプリで開く'),
                            onPressed: _openInYouTubeApp,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // コントロールパネル
          Expanded(child: _buildControlPanel()),
        ],
      ),
    );
  }

  /// コントロールパネル部分を構築
  Widget _buildControlPanel() {
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトルと投稿者
          if (_videoMetadata != null) ...[
            Text(
              _videoMetadata!.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _videoMetadata!.author,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Divider(height: 24),
          ],

          const Text(
            '字幕コントロール',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.replay_5,
                label: '5秒戻る',
                onPressed:
                    (_isPlayerReady && !_isDisposed && _videoUrl != null)
                        ? () {
                          final videoPlayerState = _videoPlayerKey.currentState;
                          if (videoPlayerState != null) {
                            videoPlayerState.seekBackward(5);
                          }
                        }
                        : null,
              ),
              _buildControlButton(
                icon: Icons.skip_previous,
                label: '前の字幕',
                onPressed:
                    (_isPlayerReady && !_isDisposed && _videoUrl != null)
                        ? _goToPreviousSubtitle
                        : null,
              ),
              _buildControlButton(
                icon: Icons.play_arrow,
                label: '再生',
                onPressed:
                    (_isPlayerReady && !_isDisposed && _videoUrl != null)
                        ? () {
                          final videoPlayerState = _videoPlayerKey.currentState;
                          if (videoPlayerState != null) {
                            videoPlayerState.play();
                          }
                        }
                        : null,
              ),
              _buildControlButton(
                icon: Icons.pause,
                label: '一時停止',
                onPressed:
                    (_isPlayerReady && !_isDisposed && _videoUrl != null)
                        ? () {
                          final videoPlayerState = _videoPlayerKey.currentState;
                          if (videoPlayerState != null) {
                            videoPlayerState.pause();
                          }
                        }
                        : null,
              ),
              _buildControlButton(
                icon: Icons.skip_next,
                label: '次の字幕',
                onPressed:
                    (_isPlayerReady && !_isDisposed && _videoUrl != null)
                        ? _goToNextSubtitle
                        : null,
              ),
              _buildControlButton(
                icon: Icons.forward_5,
                label: '5秒進む',
                onPressed:
                    (_isPlayerReady && !_isDisposed && _videoUrl != null)
                        ? () {
                          final videoPlayerState = _videoPlayerKey.currentState;
                          if (videoPlayerState != null) {
                            videoPlayerState.seekForward(5);
                          }
                        }
                        : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// コントロールボタンを構築
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onPressed,
          iconSize: 32,
          color: onPressed == null ? Colors.grey : null,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: onPressed == null ? Colors.grey : null,
          ),
        ),
      ],
    );
  }

  /// 前の字幕に移動
  void _goToPreviousSubtitle() {
    if (!_isPlayerReady ||
        _isDisposed ||
        _subtitles == null ||
        _videoUrl == null)
      return;

    try {
      final videoPlayerState = _videoPlayerKey.currentState;
      if (videoPlayerState == null) return;

      final currentPosition = videoPlayerState.getCurrentPositionMs();
      if (currentPosition == null) return;

      Subtitle? previousSubtitle;

      // 現在の字幕の前にある字幕を探す
      for (int i = _subtitles!.subtitles.length - 1; i >= 0; i--) {
        final subtitle = _subtitles!.subtitles[i];
        if (subtitle.endTime < currentPosition) {
          previousSubtitle = subtitle;
          break;
        }
      }

      if (previousSubtitle != null) {
        videoPlayerState.seekTo(
          Duration(milliseconds: previousSubtitle.startTime),
        );
      }
    } catch (e) {
      print('前の字幕へのシークエラー: $e');
    }
  }

  /// 次の字幕に移動
  void _goToNextSubtitle() {
    if (!_isPlayerReady ||
        _isDisposed ||
        _subtitles == null ||
        _videoUrl == null)
      return;

    try {
      final videoPlayerState = _videoPlayerKey.currentState;
      if (videoPlayerState == null) return;

      final currentPosition = videoPlayerState.getCurrentPositionMs();
      if (currentPosition == null) return;

      Subtitle? nextSubtitle;

      // 現在の字幕の後にある字幕を探す
      for (final subtitle in _subtitles!.subtitles) {
        if (subtitle.startTime > currentPosition) {
          nextSubtitle = subtitle;
          break;
        }
      }

      if (nextSubtitle != null) {
        videoPlayerState.seekTo(Duration(milliseconds: nextSubtitle.startTime));
      }
    } catch (e) {
      print('次の字幕へのシークエラー: $e');
    }
  }
}
