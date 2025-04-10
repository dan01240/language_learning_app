// lib/features/video_player/widgets/native_video_player.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

/// ネイティブビデオプレーヤーウィジェット
class NativeVideoPlayer extends StatefulWidget {
  /// 再生するビデオのURL
  final String videoUrl;

  /// プレーヤーの準備ができたときのコールバック
  final VoidCallback? onReady;

  /// エラー発生時のコールバック
  final VoidCallback? onError;

  /// ビデオ再生完了時のコールバック
  final VoidCallback? onVideoCompleted;

  /// 再生位置更新時のコールバック
  final Function(Duration)? onPositionChanged;

  /// 初期値として自動再生するかどうか
  final bool autoPlay;

  /// コンストラクタ
  const NativeVideoPlayer({
    Key? key,
    required this.videoUrl,
    this.onReady,
    this.onError,
    this.onVideoCompleted,
    this.onPositionChanged,
    this.autoPlay = true,
  }) : super(key: key);

  @override
  State<NativeVideoPlayer> createState() => NativeVideoPlayerState();
}

class NativeVideoPlayerState extends State<NativeVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isDisposed = false;
  Timer? _positionUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(NativeVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // URLが変更された場合はプレーヤーを再初期化
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeCurrentController();
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopPositionUpdateTimer();
    _disposeCurrentController();
    super.dispose();
  }

  /// プレーヤーのコントローラを初期化
  void _initializePlayer() async {
    if (_isDisposed) return;

    try {
      print('URLでビデオプレーヤーを初期化: ${widget.videoUrl}');
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      // コントローラの初期化
      await controller.initialize();

      if (_isDisposed) {
        // 初期化中に画面が破棄された場合
        controller.dispose();
        return;
      }

      // 初期化成功したらステートを更新
      setState(() {
        _controller = controller;
        _isInitialized = true;
        _hasError = false;
        _duration = controller.value.duration;
      });

      // イベントリスナーの設定
      _controller!.addListener(_videoPlayerListener);

      // 自動再生が有効なら再生開始
      if (widget.autoPlay) {
        _controller!.play();
        setState(() {
          _isPlaying = true;
        });
      }

      // 再生位置の定期更新タイマーを開始
      _startPositionUpdateTimer();

      // 準備完了のコールバックを呼び出し
      if (widget.onReady != null) {
        widget.onReady!();
      }
    } catch (e) {
      print('ビデオプレーヤーの初期化エラー: $e');
      if (_isDisposed) return;

      setState(() {
        _hasError = true;
      });

      if (widget.onError != null) {
        widget.onError!();
      }
    }
  }

  /// ビデオプレーヤーの状態変化リスナー
  void _videoPlayerListener() {
    if (_isDisposed || _controller == null) return;

    try {
      // 再生完了の検出
      if (_controller!.value.position >= _controller!.value.duration) {
        if (widget.onVideoCompleted != null) {
          widget.onVideoCompleted!();
        }
      }

      // 再生状態の更新
      final isPlaying = _controller!.value.isPlaying;
      if (isPlaying != _isPlaying) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }

      // エラー状態の更新
      if (_controller!.value.hasError && !_hasError) {
        setState(() {
          _hasError = true;
        });

        if (widget.onError != null) {
          widget.onError!();
        }
      }
    } catch (e) {
      print('ビデオリスナーエラー: $e');
    }
  }

  /// 再生位置の定期更新タイマーを開始
  void _startPositionUpdateTimer() {
    _stopPositionUpdateTimer(); // 既存のタイマーがあれば停止

    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (
      timer,
    ) {
      if (_isDisposed || _controller == null || !_isInitialized) {
        timer.cancel();
        return;
      }

      try {
        final newPosition = _controller!.value.position;

        // 再生位置が変わったらコールバックを呼び出し
        if (newPosition != _position) {
          setState(() {
            _position = newPosition;
          });

          if (widget.onPositionChanged != null) {
            widget.onPositionChanged!(newPosition);
          }
        }
      } catch (e) {
        print('再生位置の更新エラー: $e');
      }
    });
  }

  /// 再生位置更新タイマーを停止
  void _stopPositionUpdateTimer() {
    if (_positionUpdateTimer != null) {
      _positionUpdateTimer!.cancel();
      _positionUpdateTimer = null;
    }
  }

  /// 現在のコントローラを破棄
  void _disposeCurrentController() {
    if (_controller != null) {
      try {
        print('ビデオプレーヤーのコントローラを破棄');
        _controller!.removeListener(_videoPlayerListener);
        _controller!.pause();
        _controller!.dispose();
      } catch (e) {
        print('コントローラの破棄エラー: $e');
      } finally {
        _controller = null;
      }
    }
  }

  /// 再生を開始
  void play() {
    if (_isDisposed || _controller == null || !_isInitialized) return;

    try {
      _controller!.play();
    } catch (e) {
      print('再生開始エラー: $e');
    }
  }

  /// 再生を一時停止
  void pause() {
    if (_isDisposed || _controller == null || !_isInitialized) return;

    try {
      _controller!.pause();
    } catch (e) {
      print('一時停止エラー: $e');
    }
  }

  /// 指定した位置にシーク
  void seekTo(Duration position) {
    if (_isDisposed || _controller == null || !_isInitialized) return;

    try {
      _controller!.seekTo(position);
    } catch (e) {
      print('シークエラー: $e');
    }
  }

  /// 現在の再生位置を取得
  Duration? getCurrentPosition() {
    if (_isDisposed || _controller == null || !_isInitialized) return null;

    try {
      return _controller!.value.position;
    } catch (e) {
      print('再生位置取得エラー: $e');
      return null;
    }
  }

  /// ミリ秒単位で現在の再生位置を取得
  int? getCurrentPositionMs() {
    final position = getCurrentPosition();
    return position?.inMilliseconds;
  }

  /// 指定秒数だけ前にシーク
  void seekBackward(int seconds) {
    if (_isDisposed || _controller == null || !_isInitialized) return;

    try {
      final currentPosition = _controller!.value.position;
      final newPosition = currentPosition - Duration(seconds: seconds);
      _controller!.seekTo(newPosition.isNegative ? Duration.zero : newPosition);
    } catch (e) {
      print('後方シークエラー: $e');
    }
  }

  /// 指定秒数だけ先にシーク
  void seekForward(int seconds) {
    if (_isDisposed || _controller == null || !_isInitialized) return;

    try {
      final currentPosition = _controller!.value.position;
      final newPosition = currentPosition + Duration(seconds: seconds);
      final maxDuration = _controller!.value.duration;

      // 動画の長さを超えないようにする
      if (newPosition > maxDuration) {
        _controller!.seekTo(maxDuration);
      } else {
        _controller!.seekTo(newPosition);
      }
    } catch (e) {
      print('前方シークエラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ビデオプレーヤー
          if (_isInitialized && _controller != null && !_hasError)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),

          // コントロールオーバーレイ
          if (_isInitialized && _controller != null && !_hasError)
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                  _isPlaying = !_isPlaying;
                });
              },
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // プログレスバー
          if (_isInitialized && _controller != null && !_hasError)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.black38,
                child: Row(
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: const TextStyle(color: Colors.white),
                    ),
                    Expanded(
                      child: Slider(
                        value: _position.inMilliseconds.toDouble(),
                        min: 0.0,
                        max: _duration.inMilliseconds.toDouble(),
                        onChanged: (value) {
                          final newPosition = Duration(
                            milliseconds: value.toInt(),
                          );
                          _controller!.seekTo(newPosition);
                        },
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          // ローディング表示
          if (!_isInitialized && !_hasError) const CircularProgressIndicator(),

          // エラー表示
          if (_hasError)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                const Text(
                  '動画の再生中にエラーが発生しました',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _disposeCurrentController();
                    _initializePlayer();
                  },
                  child: const Text('再試行'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 時間の書式整形
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }
}
