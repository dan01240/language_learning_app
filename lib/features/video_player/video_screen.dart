import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:language_learning_app/features/video_player/models/subtitle.dart';
import 'package:language_learning_app/features/video_player/subtitle_overlay.dart';
import 'package:language_learning_app/features/video_player/subtitle_loader.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:provider/provider.dart';
import 'package:language_learning_app/features/saved_words/saved_word_repository.dart';
import 'package:language_learning_app/core/constants.dart';

/// ビデオ再生画面
class VideoScreen extends StatefulWidget {
  /// ビデオID
  final String videoId;

  /// コンストラクタ
  const VideoScreen({Key? key, required this.videoId}) : super(key: key);

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  YoutubePlayerController? _controller;
  Timer? _subtitleTimer;
  Subtitle? _currentSubtitle;
  SubtitleList? _subtitles;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadSubtitles();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subtitleTimer?.cancel();
    super.dispose();
  }

  /// 字幕データを読み込む
  Future<void> _loadSubtitles() async {
    if (_isDisposed) return;

    try {
      final subtitles = await SubtitleLoader.loadSubtitlesForVideo(
        widget.videoId,
      );

      if (mounted) {
        setState(() {
          _subtitles = subtitles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '字幕の読み込みに失敗しました: $e';
        });
      }
    }
  }

  /// YouTubeコントローラーが作成されたときのコールバック
  void _onControllerCreated(YoutubePlayerController controller) {
    _controller = controller;
    _startSubtitleTimer();
  }

  /// 字幕同期用のタイマーを開始
  void _startSubtitleTimer() {
    _subtitleTimer?.cancel();
    _subtitleTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (timer) => _updateSubtitle(),
    );
  }

  /// 現在の再生時間に合わせて字幕を更新
  Future<void> _updateSubtitle() async {
    if (!mounted || _controller == null || _subtitles == null) return;

    try {
      final position = await _controller!.currentTime;
      final currentTimeMs = (position * 1000).round();
      final subtitle = _subtitles!.getVisibleSubtitleAt(currentTimeMs);

      if (subtitle != _currentSubtitle) {
        setState(() {
          _currentSubtitle = subtitle;
        });
      }
    } catch (e) {
      // 黙って処理
      debugPrint('字幕更新中にエラー: $e');
    }
  }

  /// 単語がタップされたときの処理
  void _onWordTap(String word) {
    _controller?.pauseVideo();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // バックボタン処理で直接popを使う
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: const Text('Language Learning Player'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmark),
              onPressed: () {
                // 画面をpopしてから新しい画面に遷移
                Navigator.of(context).pop();
                context.go(AppConstants.savedWordsRoute);
              },
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
                  // プレーヤー
                  if (widget.videoId.isNotEmpty)
                    YoutubePlayerScaffold(
                      controller:
                          YoutubePlayerController.fromVideoId(
                              videoId: widget.videoId,
                              autoPlay: true,
                              params: const YoutubePlayerParams(
                                showControls: true,
                                showFullscreenButton: false,
                                desktopMode: false,
                                privacyEnhanced: true,
                                useHybridComposition: true,
                              ),
                            )
                            ..setFullScreenListener((isFullScreen) {})
                            ..listen((event) {})
                            ..onInit = () => _onControllerCreated(_controller!),
                      aspectRatio: 16 / 9,
                      builder: (context, player) {
                        return player;
                      },
                    )
                  else
                    Container(
                      color: Colors.black,
                      child: const Center(
                        child: Text(
                          'ビデオIDが無効です',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),

                  // 字幕オーバーレイ
                  if (_currentSubtitle != null)
                    SubtitleOverlay(
                      currentSubtitle: _currentSubtitle,
                      onWordTap: _onWordTap,
                    ),

                  // ローディング表示
                  if (_isLoading)
                    Container(
                      color: Colors.black45,
                      child: const Center(child: CircularProgressIndicator()),
                    ),

                  // エラー表示
                  if (_errorMessage != null)
                    Container(
                      color: Colors.black45,
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // コントロールパネル
            Expanded(child: _buildControlPanel()),
          ],
        ),
      ),
    );
  }

  /// コントロールパネル部分を構築
  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '字幕コントロール',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.replay_5,
                label: '5秒戻る',
                onPressed:
                    _controller != null
                        ? () async {
                          final time = await _controller!.currentTime;
                          _controller!.seekTo(
                            seconds: time - 5,
                            allowSeekAhead: true,
                          );
                        }
                        : null,
              ),
              _buildControlButton(
                icon: Icons.skip_previous,
                label: '前の字幕',
                onPressed: _controller != null ? _goToPreviousSubtitle : null,
              ),
              _buildControlButton(
                icon: Icons.play_arrow,
                label: '再生',
                onPressed:
                    _controller != null
                        ? () {
                          _controller!.playVideo();
                        }
                        : null,
              ),
              _buildControlButton(
                icon: Icons.pause,
                label: '一時停止',
                onPressed:
                    _controller != null
                        ? () {
                          _controller!.pauseVideo();
                        }
                        : null,
              ),
              _buildControlButton(
                icon: Icons.skip_next,
                label: '次の字幕',
                onPressed: _controller != null ? _goToNextSubtitle : null,
              ),
              _buildControlButton(
                icon: Icons.forward_5,
                label: '5秒進む',
                onPressed:
                    _controller != null
                        ? () async {
                          final time = await _controller!.currentTime;
                          _controller!.seekTo(
                            seconds: time + 5,
                            allowSeekAhead: true,
                          );
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
  Future<void> _goToPreviousSubtitle() async {
    if (_controller == null || _subtitles == null) return;

    final currentPosition = (await _controller!.currentTime * 1000).round();
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
      final seconds = previousSubtitle.startTime / 1000.0;
      _controller!.seekTo(seconds: seconds, allowSeekAhead: true);
    }
  }

  /// 次の字幕に移動
  Future<void> _goToNextSubtitle() async {
    if (_controller == null || _subtitles == null) return;

    final currentPosition = (await _controller!.currentTime * 1000).round();
    Subtitle? nextSubtitle;

    // 現在の字幕の後にある字幕を探す
    for (final subtitle in _subtitles!.subtitles) {
      if (subtitle.startTime > currentPosition) {
        nextSubtitle = subtitle;
        break;
      }
    }

    if (nextSubtitle != null) {
      final seconds = nextSubtitle.startTime / 1000.0;
      _controller!.seekTo(seconds: seconds, allowSeekAhead: true);
    }
  }
}
