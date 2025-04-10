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

  /// YouTubeビデオIDが有効かチェックする
  static bool _isValidVideoId(String? videoId) {
    if (videoId == null || videoId.isEmpty) return false;

    // 基本的な検証: YouTubeのビデオIDは11文字の英数字
    final validIdPattern = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    return validIdPattern.hasMatch(videoId);
  }

  // ナビゲーターのキー
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppConstants.homeRoute,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppConstants.homeRoute,
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const HomeScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
      ),
      GoRoute(
        path: AppConstants.videoRoute,
        pageBuilder: (context, state) {
          final videoId = state.uri.queryParameters['videoId'] ?? '';

          // 無効なビデオIDの場合はホーム画面にリダイレクト
          if (!_isValidVideoId(videoId)) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: Scaffold(
                appBar: AppBar(title: const Text('エラー')),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('無効なビデオIDです'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('戻る'),
                      ),
                    ],
                  ),
                ),
              ),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
            );
          }

          return CustomTransitionPage(
            key: state.pageKey,
            child: VideoScreen(videoId: videoId),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: AppConstants.savedWordsRoute,
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const SavedWordScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
      ),
      // 設定画面のルートを追加
      GoRoute(
        path: AppConstants.settingsRoute,
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('設定'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                body: const Center(child: Text('設定画面は開発中です')),
              ),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
      ),
    ],
    errorPageBuilder:
        (context, state) => CustomTransitionPage(
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
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('戻る'),
                  ),
                ],
              ),
            ),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
  );
}
