import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:language_learning_app/features/video_player/models/subtitle.dart';
import 'package:language_learning_app/features/video_player/subtitle_overlay.dart';
import 'package:language_learning_app/features/video_player/youtube_player_wrapper.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
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
  late YoutubePlayerController _controller;
  Timer? _subtitleTimer;
  Subtitle? _currentSubtitle;
  final SubtitleList _subtitles = SubtitleList(SampleSubtitles.data);
  bool _isLoading = true;
  bool _isPlayerReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadSubtitles();
  }

  @override
  void dispose() {
    _subtitleTimer?.cancel();

    // コントローラーが初期化されている場合のみdispose
    if (_isPlayerReady) {
      _controller.dispose();
    }

    super.dispose();
  }

  /// YouTubeプレーヤーを初期化
  void _initializePlayer() {
    if (widget.videoId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ビデオIDが指定されていません';
      });
      return;
    }

    try {
      _controller = YoutubePlayerController(
        initialVideoId: widget.videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: false, // YouTubeの字幕は無効にする
        ),
      );

      _controller.addListener(() {
        if (!mounted) return;

        if (_controller.value.isReady && !_isPlayerReady) {
          setState(() {
            _isPlayerReady = true;
          });

          // プレーヤーの準備ができたら字幕同期用のタイマーを開始
          _subtitleTimer = Timer.periodic(
            const Duration(milliseconds: 200),
            (timer) => _updateSubtitle(),
          );
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'プレーヤーの初期化に失敗しました: $e';
      });
    }
  }

  /// 字幕データを読み込む
  Future<void> _loadSubtitles() async {
    try {
      // TODO: APIから字幕データを取得する処理を実装
      // サンプルデータを使用
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '字幕の読み込みに失敗しました: $e';
      });
    }
  }

  /// 現在の再生時間に合わせて字幕を更新
  void _updateSubtitle() {
    if (!mounted) return; // ウィジェットがアンマウントされていたら何もしない

    if (_controller.value.isPlaying || _controller.value.hasPlayed) {
      try {
        final currentTimeMs = (_controller.value.position.inMilliseconds);
        final subtitle = _subtitles.getVisibleSubtitleAt(currentTimeMs);

        if (subtitle != _currentSubtitle) {
          setState(() {
            _currentSubtitle = subtitle;
          });
        }
      } catch (e) {
        // エラーを黙って処理（タイマーが呼び出されているがコントローラーがまだ準備できていない可能性）
      }
    }
  }

  /// 単語がタップされたときの処理
  void _onWordTap(String word) {
    if (_isPlayerReady) {
      _controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go(AppConstants.homeRoute);
          },
        ),
        title: const Text('Language Learning Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              context.go(AppConstants.savedWordsRoute);
            },
          ),
        ],
      ),
      body: Column(
        children: [_buildVideoPlayer(), Expanded(child: _buildControlPanel())],
      ),
    );
  }

  /// ビデオプレーヤー部分を構築
  Widget _buildVideoPlayer() {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child:
              widget.videoId.isNotEmpty
                  ? YouTubePlayerWrapper(
                    videoId: widget.videoId,
                    controller: _controller,
                  )
                  : Container(
                    color: Colors.black,
                    child: const Center(
                      child: Text(
                        'ビデオIDが無効です',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
        ),
        if (_currentSubtitle != null && _isPlayerReady)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: SubtitleOverlay(
              currentSubtitle: _currentSubtitle,
              onWordTap: _onWordTap,
            ),
          ),
        if (_isLoading && !_isPlayerReady)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        if (_errorMessage != null)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
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
          ),
      ],
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
                    _isPlayerReady
                        ? () => _controller.seekTo(
                          _controller.value.position -
                              const Duration(seconds: 5),
                        )
                        : null,
              ),
              _buildControlButton(
                icon: Icons.skip_previous,
                label: '前の字幕',
                onPressed: _isPlayerReady ? _goToPreviousSubtitle : null,
              ),
              _buildControlButton(
                icon:
                    _isPlayerReady && _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                label:
                    _isPlayerReady && _controller.value.isPlaying
                        ? '一時停止'
                        : '再生',
                onPressed:
                    _isPlayerReady
                        ? () {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                          setState(() {});
                        }
                        : null,
              ),
              _buildControlButton(
                icon: Icons.skip_next,
                label: '次の字幕',
                onPressed: _isPlayerReady ? _goToNextSubtitle : null,
              ),
              _buildControlButton(
                icon: Icons.forward_5,
                label: '5秒進む',
                onPressed:
                    _isPlayerReady
                        ? () => _controller.seekTo(
                          _controller.value.position +
                              const Duration(seconds: 5),
                        )
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
    if (!_isPlayerReady) return;

    final currentPosition = _controller.value.position.inMilliseconds;
    Subtitle? previousSubtitle;

    // 現在の字幕の前にある字幕を探す
    for (int i = _subtitles.subtitles.length - 1; i >= 0; i--) {
      final subtitle = _subtitles.subtitles[i];
      if (subtitle.endTime < currentPosition) {
        previousSubtitle = subtitle;
        break;
      }
    }

    if (previousSubtitle != null) {
      _controller.seekTo(Duration(milliseconds: previousSubtitle.startTime));
    }
  }

  /// 次の字幕に移動
  void _goToNextSubtitle() {
    if (!_isPlayerReady) return;

    final currentPosition = _controller.value.position.inMilliseconds;
    Subtitle? nextSubtitle;

    // 現在の字幕の後にある字幕を探す
    for (final subtitle in _subtitles.subtitles) {
      if (subtitle.startTime > currentPosition) {
        nextSubtitle = subtitle;
        break;
      }
    }

    if (nextSubtitle != null) {
      _controller.seekTo(Duration(milliseconds: nextSubtitle.startTime));
    }
  }
}
