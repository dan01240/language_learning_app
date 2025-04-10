// lib/features/video_player/widgets/youtube_iframe_player.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YouTubeIframePlayerWidget extends StatefulWidget {
  final String videoId;
  final Function(YoutubePlayerController)? onControllerReady;
  final Function? onVideoEnd;

  const YouTubeIframePlayerWidget({
    Key? key,
    required this.videoId,
    this.onControllerReady,
    this.onVideoEnd,
  }) : super(key: key);

  @override
  State<YouTubeIframePlayerWidget> createState() =>
      _YouTubeIframePlayerWidgetState();
}

class _YouTubeIframePlayerWidgetState extends State<YouTubeIframePlayerWidget> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    _controller = YoutubePlayerController();

    // ビデオをロード
    _controller.loadVideoById(videoId: widget.videoId, startSeconds: 0);

    // コントローラーの準備ができたらコールバックを呼び出す
    if (widget.onControllerReady != null) {
      widget.onControllerReady!(_controller);
    }
  }

  @override
  void dispose() {
    // 画面を離れる際に縦向きに戻す
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: YoutubePlayerScaffold(
        controller: _controller,
        aspectRatio: 16 / 9,
        builder: (context, player) {
          return player;
        },
      ),
    );
  }
}
