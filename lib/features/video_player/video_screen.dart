// lib/features/video_player/video_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:language_learning_app/core/constants.dart';
import 'package:language_learning_app/features/video_player/models/subtitle.dart';
import 'package:language_learning_app/features/video_player/subtitle_overlay.dart';
import 'package:language_learning_app/features/video_player/subtitle_service.dart';
import 'package:language_learning_app/features/video_player/widgets/youtube_iframe_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class VideoScreen extends StatefulWidget {
  final String videoId;

  const VideoScreen({Key? key, required this.videoId}) : super(key: key);

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> with WidgetsBindingObserver {
  YoutubePlayerController? _controller;
  Subtitle? _currentSubtitle;
  List<Subtitle>? _subtitles;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showTranslation = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSubtitles();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _loadSubtitles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final subtitles = await SubtitleService.getSubtitlesForVideo(
        widget.videoId,
      );

      setState(() {
        _subtitles = subtitles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '字幕の読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  void _onControllerReady(YoutubePlayerController controller) {
    _controller = controller;

    // 動画の状態ストリームを使って字幕を同期
    _controller!.videoStateStream.listen((state) {
      _updateSubtitleFromState(state);
    });
  }

  void _updateSubtitleFromState(YoutubeVideoState state) {
    if (_subtitles == null || _subtitles!.isEmpty) return;

    final currentTimeMs = state.position.inMilliseconds;

    Subtitle? visibleSubtitle;
    for (final subtitle in _subtitles!) {
      if (subtitle.isVisibleAt(currentTimeMs)) {
        visibleSubtitle = subtitle;
        break;
      }
    }

    if (visibleSubtitle != _currentSubtitle) {
      setState(() {
        _currentSubtitle = visibleSubtitle;
      });
    }
  }

  void _onWordTap(String word) {
    _controller?.pauseVideo();
  }

  /// 現在の字幕から次の字幕を見つける
  Future<Subtitle?> _findNextSubtitle() async {
    if (_subtitles == null || _subtitles!.isEmpty) return null;
    if (_currentSubtitle == null) {
      // 現在の再生位置から最も近い字幕を見つける
      return await _findNearestSubtitle();
    }

    // 現在の字幕のインデックスを見つける
    final currentIndex = _subtitles!.indexOf(_currentSubtitle!);
    if (currentIndex == -1 || currentIndex >= _subtitles!.length - 1) {
      return null; // 最後の字幕か、見つからない場合
    }

    // 次の字幕を返す
    return _subtitles![currentIndex + 1];
  }

  /// 現在の字幕から前の字幕を見つける
  Future<Subtitle?> _findPreviousSubtitle() async {
    if (_subtitles == null || _subtitles!.isEmpty) return null;
    if (_currentSubtitle == null) {
      // 現在の再生位置から最も近い字幕を見つける
      return await _findNearestSubtitle();
    }

    // 現在の字幕のインデックスを見つける
    final currentIndex = _subtitles!.indexOf(_currentSubtitle!);
    if (currentIndex <= 0) {
      return null; // 最初の字幕か、見つからない場合
    }

    // 前の字幕を返す
    return _subtitles![currentIndex - 1];
  }

  /// 現在の再生位置から最も近い字幕を見つける
  Future<Subtitle?> _findNearestSubtitle() async {
    if (_subtitles == null || _subtitles!.isEmpty || _controller == null)
      return null;

    try {
      // 現在の再生位置を取得
      final currentTime = await _controller!.currentTime;
      final currentTimeMs = (currentTime * 1000).toInt();

      // 現在時刻より後にある最も近い字幕を探す
      for (final subtitle in _subtitles!) {
        if (subtitle.startTime >= currentTimeMs) {
          return subtitle;
        }
      }

      // 見つからなければ最初の字幕を返す
      return _subtitles!.first;
    } catch (e) {
      print('最も近い字幕の検索中にエラー: $e');
      return null;
    }
  }

  /// 次の字幕にジャンプ
  Future<void> _jumpToNextSubtitle() async {
    if (_controller == null) return;

    final nextSubtitle = await _findNextSubtitle();
    if (nextSubtitle != null) {
      // 次の字幕の開始時間にシーク
      final seekTimeSeconds = nextSubtitle.startTime / 1000.0;
      _controller!.seekTo(seconds: seekTimeSeconds, allowSeekAhead: true);

      // 現在の字幕を更新
      setState(() {
        _currentSubtitle = nextSubtitle;
      });
    }
  }

  /// 前の字幕にジャンプ
  Future<void> _jumpToPreviousSubtitle() async {
    if (_controller == null) return;

    final prevSubtitle = await _findPreviousSubtitle();
    if (prevSubtitle != null) {
      // 前の字幕の開始時間にシーク
      final seekTimeSeconds = prevSubtitle.startTime / 1000.0;
      _controller!.seekTo(seconds: seekTimeSeconds, allowSeekAhead: true);

      // 現在の字幕を更新
      setState(() {
        _currentSubtitle = prevSubtitle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('言語学習プレーヤー'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppConstants.homeRoute),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showTranslation ? Icons.translate : Icons.translate_outlined,
            ),
            onPressed: () {
              setState(() {
                _showTranslation = !_showTranslation;
              });
            },
            tooltip: '翻訳表示切替',
          ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () => context.go(AppConstants.savedWordsRoute),
            tooltip: '保存した単語',
          ),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                YouTubeIframePlayerWidget(
                  videoId: widget.videoId,
                  onControllerReady: _onControllerReady,
                ),

                if (_currentSubtitle != null)
                  SubtitleOverlay(
                    currentSubtitle: _currentSubtitle,
                    onWordTap: _onWordTap,
                    showTranslation: _showTranslation,
                  ),

                if (_isLoading)
                  Container(
                    color: Colors.black45,
                    child: const Center(child: CircularProgressIndicator()),
                  ),

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

          Expanded(child: _buildControlPanel()),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '動画コントロール',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.skip_previous,
                label: '前の字幕',
                onPressed: _controller != null ? _jumpToPreviousSubtitle : null,
              ),
              _buildControlButton(
                icon: Icons.play_arrow,
                label: '再生',
                onPressed:
                    _controller != null ? () => _controller!.playVideo() : null,
              ),
              _buildControlButton(
                icon: Icons.pause,
                label: '一時停止',
                onPressed:
                    _controller != null
                        ? () => _controller!.pauseVideo()
                        : null,
              ),
              _buildControlButton(
                icon: Icons.skip_next,
                label: '次の字幕',
                onPressed: _controller != null ? _jumpToNextSubtitle : null,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '字幕設定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('翻訳字幕を表示'),
            value: _showTranslation,
            onChanged: (value) {
              setState(() {
                _showTranslation = value;
              });
            },
          ),
        ],
      ),
    );
  }

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
}
