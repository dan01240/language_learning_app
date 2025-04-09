import 'package:flutter/material.dart';
import 'youtube_player_wrapper.dart';

class VideoScreen extends StatelessWidget {
  const VideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 例: 任意のYouTube動画ID
    const videoId = 'dQw4w9WgXcQ'; // Rickroll動画

    return Scaffold(
      appBar: AppBar(title: const Text('YouTube Player')),
      body: Column(
        children: const [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: YouTubePlayerWrapper(videoId: videoId),
          ),
          Expanded(child: Center(child: Text('ここに字幕やUIが追加されます'))),
        ],
      ),
    );
  }
}
