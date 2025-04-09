import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:language_learning_app/features/home/home_screen.dart';
import 'package:language_learning_app/features/video_player/video_screen.dart';
import 'package:language_learning_app/features/saved_words/saved_word_screen.dart';
import 'package:language_learning_app/core/constants.dart';

/// アプリケーションのルーティングを管理するクラス
class AppRouter {
  /// アプリケーションのルーターを作成
  static GoRouter get router => _router;

  static final GoRouter _router = GoRouter(
    initialLocation: AppConstants.homeRoute,
    routes: [
      GoRoute(
        path: AppConstants.homeRoute,
        pageBuilder:
            (context, state) =>
                MaterialPage(key: state.pageKey, child: const HomeScreen()),
      ),
      GoRoute(
        path: AppConstants.videoRoute,
        pageBuilder: (context, state) {
          final videoId = state.uri.queryParameters['videoId'] ?? '';
          return MaterialPage(
            key: state.pageKey,
            child: VideoScreen(videoId: videoId),
          );
        },
      ),
      GoRoute(
        path: AppConstants.savedWordsRoute,
        pageBuilder:
            (context, state) => MaterialPage(
              key: state.pageKey,
              child: const SavedWordScreen(),
            ),
      ),
    ],
    errorPageBuilder:
        (context, state) => MaterialPage(
          key: state.pageKey,
          child: Scaffold(
            appBar: AppBar(title: const Text('エラー')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ページが見つかりませんでした'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go(AppConstants.homeRoute),
                    child: const Text('ホームに戻る'),
                  ),
                ],
              ),
            ),
          ),
        ),
  );
}
