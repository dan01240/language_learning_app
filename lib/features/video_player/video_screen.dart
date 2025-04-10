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
                icon: Icons.replay_5,
                label: '5秒戻る',
                onPressed:
                    _controller != null
                        ? () async {
                          try {
                            final currentTime = await _controller!.currentTime;
                            _controller!.seekTo(
                              seconds: currentTime - 5,
                              allowSeekAhead: true,
                            );
                          } catch (e) {
                            print('シーク中にエラー: $e');
                          }
                        }
                        : null,
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
                icon: Icons.forward_5,
                label: '5秒進む',
                onPressed:
                    _controller != null
                        ? () async {
                          try {
                            final currentTime = await _controller!.currentTime;
                            _controller!.seekTo(
                              seconds: currentTime + 5,
                              allowSeekAhead: true,
                            );
                          } catch (e) {
                            print('シーク中にエラー: $e');
                          }
                        }
                        : null,
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
