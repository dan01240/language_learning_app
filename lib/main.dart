import 'package:flutter/material.dart';
import 'package:language_learning_app/app/app.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // YouTubeプレーヤーのAPIを初期化
  await YoutubePlayerController.ensureInitialized();

  runApp(const LanguageLearningApp());
}
