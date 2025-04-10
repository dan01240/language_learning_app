import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:language_learning_app/features/video_player/models/subtitle.dart';
import 'package:language_learning_app/features/video_player/subtitle_overlay.dart';
import 'package:language_learning_app/features/video_player/subtitle_loader.dart';
import 'package:language_learning_app/core/constants.dart';
import 'package:url_launcher/url_launcher.dart';

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
  YoutubePlayerController? _controller;
  Timer? _subtitleTimer;
  Subtitle? _currentSubtitle;
  SubtitleList? _subtitles;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPlayerReady = false;
  bool _playerError = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
    _loadSubtitles();
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

    // タイマーをキャンセル
    if (_subtitleTimer != null) {
      _subtitleTimer!.cancel();
      _subtitleTimer = null;
    }

    // コントローラのクリーンアップ
    _pauseAndCleanupPlayer();

    // 画面を離れる際に縦向きに戻す
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // デバッグ情報
    debugPrint('VideoScreen: リソースのクリーンアップ完了');
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
          debugPrint('VideoScreen: コントローラの解放完了');
        } catch (e) {
          debugPrint('VideoScreen: コントローラの解放でエラー: $e');
        }
      });
    } catch (e) {
      debugPrint('VideoScreen: プレーヤーの停止でエラー: $e');
    }
  }

  /// YouTubeプレーヤーを初期化
  void _initializePlayer() {
    try {
      // youtube_player_flutter パッケージを使用
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

      // コントローラーの状態変化リスナー
      _controller!.addListener(_controllerListener);

      debugPrint('VideoScreen: プレーヤー初期化完了');
    } catch (e) {
      debugPrint('VideoScreen: プレーヤー初期化でエラー: $e');
      setState(() {
        _playerError = true;
        _errorMessage = 'プレーヤーの初期化に失敗しました: $e';
      });
    }
  }

  /// コントローラのリスナー
  void _controllerListener() {
    if (_isDisposed || _controller == null) return;

    try {
      // ビデオの準備ができた時
      if (_controller!.value.isReady && !_isPlayerReady) {
        if (mounted && !_isDisposed) {
          setState(() {
            _isPlayerReady = true;
            _isLoading = false;
          });
          _startSubtitleTimer();
        }
      }

      // エラーが発生した時
      if (_controller!.value.hasError && !_playerError) {
        if (mounted && !_isDisposed) {
          setState(() {
            _playerError = true;
            _errorMessage = 'プレーヤーでエラーが発生しました。別の方法で再生してみてください。';
          });
        }
      }
    } catch (e) {
      debugPrint('VideoScreen: コントローラリスナーでエラー: $e');
    }
  }

  /// 字幕データを読み込む
  Future<void> _loadSubtitles() async {
    try {
      final subtitles = await SubtitleLoader.loadSubtitlesForVideo(
        widget.videoId,
      );

      if (mounted && !_isDisposed) {
        setState(() {
          _subtitles = subtitles;
        });
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _errorMessage = '字幕の読み込みに失敗しました: $e';
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
      } else {
        _updateSubtitle();
      }
    });
  }

  /// 現在の再生時間に合わせて字幕を更新
  void _updateSubtitle() {
    if (!mounted ||
        _isDisposed ||
        _subtitles == null ||
        !_isPlayerReady ||
        _controller == null)
      return;

    try {
      final position = _controller!.value.position;
      final currentTimeMs = position.inMilliseconds;
      final subtitle = _subtitles!.getVisibleSubtitleAt(currentTimeMs);

      if (subtitle != _currentSubtitle && mounted && !_isDisposed) {
        setState(() {
          _currentSubtitle = subtitle;
        });
      }
    } catch (e) {
      // エラーを黙って処理
      debugPrint('字幕更新中にエラー: $e');
    }
  }

  /// 単語がタップされたときの処理
  void _onWordTap(String word) {
    if (_isDisposed || _controller == null) return;

    try {
      _controller!.pause();
    } catch (e) {
      debugPrint('単語タップ時のビデオ停止でエラー: $e');
    }
  }

  /// 安全に前の画面に戻る
  void _safelyNavigateBack(BuildContext context) {
    if (_isDisposed) return;

    // リソースをクリーンアップして、遅延させてからナビゲーション
    _cleanupResources();

    // 画面遷移前に少し遅延させる（リソース解放の時間を確保）
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      // ナビゲーションスタックがある場合はpop、なければルートに遷移
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      } else {
        // 通常はここには来ないはず
        Navigator.of(context).pushReplacementNamed('/');
      }

      debugPrint('VideoScreen: ナビゲーション完了');
    });
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
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _safelyNavigateBack(context),
          ),
          title: const Text('Language Learning Player'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        _safelyNavigateBack(context);
        return false; // falseを返して独自のナビゲーション処理を行う
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _safelyNavigateBack(context),
          ),
          title: const Text('Language Learning Player'),
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
              onPressed: () => _navigateToSavedWords(context),
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
                        if (!_isDisposed) {
                          setState(() {
                            _isPlayerReady = true;
                            _isLoading = false;
                          });
                          _startSubtitleTimer();
                          debugPrint('VideoScreen: プレーヤー準備完了');
                        }
                      },
                      onEnded: (metaData) {
                        debugPrint('Video ended');
                      },
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
      ),
    );
  }

  /// 保存済み単語画面に遷移
  void _navigateToSavedWords(BuildContext context) {
    if (_isDisposed) return;

    // リソースをクリーンアップして、遅延させてからナビゲーション
    _cleanupResources();

    // 画面遷移前に少し遅延させる（リソース解放の時間を確保）
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      // まずはホーム画面に戻る
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();

        // ホーム画面に戻った後、保存単語画面に遷移
        Future.delayed(const Duration(milliseconds: 100), () {
          try {
            Navigator.of(context).pushNamed(AppConstants.savedWordsRoute);
          } catch (e) {
            debugPrint('保存単語画面への遷移エラー: $e');
          }
        });
      } else {
        // 直接保存単語画面に遷移
        try {
          Navigator.of(
            context,
          ).pushReplacementNamed(AppConstants.savedWordsRoute);
        } catch (e) {
          debugPrint('保存単語画面への直接遷移エラー: $e');
        }
      }
    });
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
                    (_isPlayerReady && !_isDisposed && _controller != null)
                        ? () {
                          try {
                            final currentPosition = _controller!.value.position;
                            _controller!.seekTo(
                              currentPosition - const Duration(seconds: 5),
                            );
                          } catch (e) {
                            debugPrint('シーク操作エラー: $e');
                          }
                        }
                        : null,
              ),
              _buildControlButton(
                icon: Icons.skip_previous,
                label: '前の字幕',
                onPressed:
                    (_isPlayerReady && !_isDisposed && _controller != null)
                        ? _goToPreviousSubtitle
                        : null,
              ),
              _buildControlButton(
                icon: Icons.play_arrow,
                label: '再生',
                onPressed:
                    (_isPlayerReady && !_isDisposed && _controller != null)
                        ? () {
                          try {
                            _controller!.play();
                          } catch (e) {
                            debugPrint('再生操作エラー: $e');
                          }
                        }
                        : null,
              ),
              _buildControlButton(
                icon: Icons.pause,
                label: '一時停止',
                onPressed:
                    (_isPlayerReady && !_isDisposed && _controller != null)
                        ? () {
                          try {
                            _controller!.pause();
                          } catch (e) {
                            debugPrint('一時停止操作エラー: $e');
                          }
                        }
                        : null,
              ),
              _buildControlButton(
                icon: Icons.skip_next,
                label: '次の字幕',
                onPressed:
                    (_isPlayerReady && !_isDisposed && _controller != null)
                        ? _goToNextSubtitle
                        : null,
              ),
              _buildControlButton(
                icon: Icons.forward_5,
                label: '5秒進む',
                onPressed:
                    (_isPlayerReady && !_isDisposed && _controller != null)
                        ? () {
                          try {
                            final currentPosition = _controller!.value.position;
                            _controller!.seekTo(
                              currentPosition + const Duration(seconds: 5),
                            );
                          } catch (e) {
                            debugPrint('シーク操作エラー: $e');
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
        _controller == null)
      return;

    try {
      final currentPosition = _controller!.value.position.inMilliseconds;
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
        _controller!.seekTo(Duration(milliseconds: previousSubtitle.startTime));
      }
    } catch (e) {
      debugPrint('前の字幕へのシークエラー: $e');
    }
  }

  /// 次の字幕に移動
  void _goToNextSubtitle() {
    if (!_isPlayerReady ||
        _isDisposed ||
        _subtitles == null ||
        _controller == null)
      return;

    try {
      final currentPosition = _controller!.value.position.inMilliseconds;
      Subtitle? nextSubtitle;

      // 現在の字幕の後にある字幕を探す
      for (final subtitle in _subtitles!.subtitles) {
        if (subtitle.startTime > currentPosition) {
          nextSubtitle = subtitle;
          break;
        }
      }

      if (nextSubtitle != null) {
        _controller!.seekTo(Duration(milliseconds: nextSubtitle.startTime));
      }
    } catch (e) {
      debugPrint('次の字幕へのシークエラー: $e');
    }
  }
}
