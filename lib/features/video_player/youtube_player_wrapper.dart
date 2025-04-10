import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class YouTubePlayerWrapper extends StatefulWidget {
  final String videoId;
  final Function(YoutubePlayerController)? onControllerCreated;
  final Function? onVideoEnd;

  const YouTubePlayerWrapper({
    Key? key,
    required this.videoId,
    this.onControllerCreated,
    this.onVideoEnd,
  }) : super(key: key);

  @override
  State<YouTubePlayerWrapper> createState() => _YouTubePlayerWrapperState();
}

class _YouTubePlayerWrapperState extends State<YouTubePlayerWrapper>
    with WidgetsBindingObserver {
  YoutubePlayerController? _controller;
  bool _isPlayerReady = false;
  bool _playerError = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // アプリがバックグラウンドに行ったらプレーヤーを一時停止
    if (state == AppLifecycleState.paused) {
      _pauseAndCleanupPlayer();
    }
  }

  @override
  void dispose() {
    _cleanupResources();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// リソースをクリーンアップ
  void _cleanupResources() {
    // まだ処理されていなければ実行
    if (_isDisposed) return;
    _isDisposed = true;

    // コントローラのクリーンアップ
    _pauseAndCleanupPlayer();

    // デバッグ情報
    debugPrint('YouTubePlayerWrapper: リソースのクリーンアップ完了');
  }

  /// プレーヤーを停止して解放
  void _pauseAndCleanupPlayer() {
    if (_controller == null) return;

    try {
      // まずは一時停止
      _controller!.pause();

      // リスナーを削除
      _controller!.removeListener(_controllerListener);

      // 少し遅延させてからコントローラを破棄
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          _controller!.dispose();
          _controller = null;
          debugPrint('YouTubePlayerWrapper: コントローラの解放完了');
        } catch (e) {
          debugPrint('YouTubePlayerWrapper: コントローラの解放でエラー: $e');
        }
      });
    } catch (e) {
      debugPrint('YouTubePlayerWrapper: プレーヤーの停止でエラー: $e');
    }
  }

  void _initializePlayer() {
    try {
      // youtube_player_flutter パッケージを使用してコントローラを初期化
      _controller = YoutubePlayerController(
        initialVideoId: widget.videoId,
        flags: const YoutubePlayerFlags(
          // iOS向けの最適化設定
          autoPlay: true,
          mute: false,
          hideControls: false,
          hideThumbnail: false,
          disableDragSeek: false,
          enableCaption: false,
          forceHD: false,
          loop: false,
        ),
      );

      // コントローラの状態変化リスナー
      _controller!.addListener(_controllerListener);

      debugPrint('YouTubePlayerWrapper: プレーヤー初期化完了');
    } catch (e) {
      debugPrint('YouTubePlayerWrapper: プレーヤー初期化でエラー: $e');
      setState(() {
        _playerError = true;
      });
    }
  }

  void _controllerListener() {
    if (_isDisposed || _controller == null) return;

    try {
      // ビデオの準備ができた時
      if (_controller!.value.isReady && !_isPlayerReady) {
        if (mounted && !_isDisposed) {
          setState(() {
            _isPlayerReady = true;
          });

          if (widget.onControllerCreated != null) {
            widget.onControllerCreated!(_controller!);
          }

          debugPrint('YouTubePlayerWrapper: プレーヤー準備完了');
        }
      }

      // ビデオが終了した時
      if (_controller!.value.playerState == PlayerState.ended &&
          widget.onVideoEnd != null &&
          !_isDisposed) {
        widget.onVideoEnd!();
      }

      // エラーが発生した時
      if (_controller!.value.hasError && !_playerError && !_isDisposed) {
        setState(() {
          _playerError = true;
        });
      }
    } catch (e) {
      debugPrint('YouTubePlayerWrapper: コントローラリスナーでエラー: $e');
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
      debugPrint('YouTubeアプリ起動エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // コントローラがnullの場合はローディング表示
    if (_controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        // YoutubePlayerを使用
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: YoutubePlayer(
            controller: _controller!,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.red,
            progressColors: const ProgressBarColors(
              playedColor: Colors.red,
              handleColor: Colors.redAccent,
            ),
            onReady: () {
              if (!_isDisposed && mounted) {
                setState(() {
                  _isPlayerReady = true;
                });

                if (widget.onControllerCreated != null) {
                  widget.onControllerCreated!(_controller!);
                }

                debugPrint('YouTubePlayerWrapper: onReady イベント');
              }
            },
            onEnded: (_) {
              if (!_isDisposed && widget.onVideoEnd != null) {
                widget.onVideoEnd!();
                debugPrint('YouTubePlayerWrapper: onEnded イベント');
              }
            },
            bottomActions: [
              // 動画の進行状況を表示
              CurrentPosition(),
              ProgressBar(
                isExpanded: true,
                colors: const ProgressBarColors(
                  playedColor: Colors.red,
                  handleColor: Colors.redAccent,
                  bufferedColor: Colors.white70,
                  backgroundColor: Colors.grey,
                ),
              ),
              RemainingDuration(),
              const PlaybackSpeedButton(),
            ],
          ),
        ),

        // Loading indicator
        if (!_isPlayerReady)
          Container(
            color: Colors.black45,
            child: const Center(child: CircularProgressIndicator()),
          ),

        // エラー発生時にYouTubeアプリで開くボタンを表示
        if (_playerError)
          Container(
            color: Colors.black45,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '動画の読み込みに問題が発生しました',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('YouTubeアプリで開く'),
                    onPressed: _openInYouTubeApp,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
