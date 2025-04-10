import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

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

class _YouTubePlayerWrapperState extends State<YouTubePlayerWrapper> {
  late final YoutubePlayerController _controller;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: false,
        desktopMode: false,
        privacyEnhanced: true,
        useHybridComposition: true,
      ),
    );

    _controller.setFullScreenListener((isFullScreen) {
      debugPrint('isFullScreen: $isFullScreen');
    });

    if (widget.onControllerCreated != null) {
      widget.onControllerCreated!(_controller);
    }

    // リスナーを追加
    _controller.setFullScreenListener((isFullScreen) {
      debugPrint('isFullScreen: $isFullScreen');
    });

    _controller.listen((event) {
      if (event.playerState == PlayerState.ended && widget.onVideoEnd != null) {
        widget.onVideoEnd!();
      }

      if (event.isReady && !_isPlayerReady) {
        setState(() {
          _isPlayerReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      aspectRatio: 16 / 9,
      builder: (context, player) {
        return player;
      },
    );
  }
}
