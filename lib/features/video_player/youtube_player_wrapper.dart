import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YouTubePlayerWrapper extends StatefulWidget {
  final String videoId;

  const YouTubePlayerWrapper({super.key, required this.videoId});

  @override
  State<YouTubePlayerWrapper> createState() => _YouTubePlayerWrapperState();
}

class _YouTubePlayerWrapperState extends State<YouTubePlayerWrapper> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      controller: _controller,
      showVideoProgressIndicator: true,
      progressIndicatorColor: Colors.teal,
    );
  }
}
