import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YouTubePlayerWrapper extends StatefulWidget {
  final String videoId;
  final YoutubePlayerController? controller;

  const YouTubePlayerWrapper({
    super.key,
    required this.videoId,
    this.controller,
  });

  @override
  State<YouTubePlayerWrapper> createState() => _YouTubePlayerWrapperState();
}

class _YouTubePlayerWrapperState extends State<YouTubePlayerWrapper> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();

    if (widget.videoId.isEmpty) {
      return; // ビデオIDが空の場合は初期化しない
    }

    try {
      _controller =
          widget.controller ??
          YoutubePlayerController(
            initialVideoId: widget.videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: true,
              mute: false,
              enableCaption: false,
              hideThumbnail: false,
            ),
          );

      _controller.addListener(_listener);
    } catch (e) {
      print('YouTubeプレーヤーの初期化中にエラーが発生しました: $e');
    }
  }

  void _listener() {
    if (_controller.value.isReady && !_isPlayerReady) {
      _isPlayerReady = true;
      setState(() {});
    }
  }

  @override
  void dispose() {
    // 外部から提供されたコントローラでない場合のみdispose
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ビデオIDが空またはコントローラーが初期化されていない場合
    if (widget.videoId.isEmpty || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text('ビデオを読み込めません', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.teal,
        progressColors: const ProgressBarColors(
          playedColor: Colors.teal,
          handleColor: Colors.tealAccent,
        ),
        onReady: () {
          _isPlayerReady = true;
        },
        onEnded: (data) {
          // 再生終了時の処理
        },
      ),
      builder: (context, player) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            player,
            if (!_isPlayerReady)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }
}
