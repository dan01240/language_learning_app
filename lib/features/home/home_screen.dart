import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:language_learning_app/core/constants.dart';
import 'package:language_learning_app/features/home/widgets/video_card.dart';
import 'package:language_learning_app/features/saved_words/saved_word_repository.dart';

/// ホーム画面
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final List<Map<String, String>> _sampleVideos = [
    {
      'id': 'dQw4w9WgXcQ',
      'title': 'Rick Astley - Never Gonna Give You Up',
      'thumbnail': 'https://img.youtube.com/vi/dQw4w9WgXcQ/mqdefault.jpg',
    },
    {
      'id': 'jNQXAC9IVRw',
      'title': 'Me at the zoo',
      'thumbnail': 'https://img.youtube.com/vi/jNQXAC9IVRw/mqdefault.jpg',
    },
    {
      'id': '1JLUn2DFW4w',
      'title': 'A Simple Introduction to English',
      'thumbnail': 'https://img.youtube.com/vi/1JLUn2DFW4w/mqdefault.jpg',
    },
  ];

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language Learning App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () => context.go(AppConstants.savedWordsRoute),
            tooltip: '保存した単語',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 設定画面に遷移
            },
            tooltip: '設定',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoUrlInput(),
            const SizedBox(height: 24),
            _buildRecentVideosSection(),
            const SizedBox(height: 24),
            _buildSampleVideosSection(),
          ],
        ),
      ),
    );
  }

  /// YouTube URL入力部分を構築
  Widget _buildVideoUrlInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YouTube URLまたはビデオIDを入力',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'https://youtube.com/watch?v=...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      () => _openVideo(_extractVideoId(_urlController.text)),
                  child: const Text('開く'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 最近視聴したビデオセクションを構築
  Widget _buildRecentVideosSection() {
    // TODO: 最近視聴したビデオを取得する処理を実装
    final recentVideos = <Map<String, String>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '最近視聴したビデオ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (recentVideos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text('まだ視聴履歴はありません', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: recentVideos.length,
              itemBuilder: (context, index) {
                final video = recentVideos[index];
                return VideoCard(
                  videoId: video['id']!,
                  title: video['title']!,
                  thumbnailUrl: video['thumbnail']!,
                  onTap: () => _openVideo(video['id']!),
                );
              },
            ),
          ),
      ],
    );
  }

  /// サンプルビデオセクションを構築
  Widget _buildSampleVideosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'サンプルビデオ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _sampleVideos.length,
            itemBuilder: (context, index) {
              final video = _sampleVideos[index];
              return VideoCard(
                videoId: video['id']!,
                title: video['title']!,
                thumbnailUrl: video['thumbnail']!,
                onTap: () => _openVideo(video['id']!),
              );
            },
          ),
        ),
      ],
    );
  }

  /// YouTubeのURLからビデオIDを抽出
  String _extractVideoId(String url) {
    // URLからIDを抽出するロジック
    if (url.isEmpty) return '';

    // すでにIDのみの場合
    if (url.length == 11 && !url.contains('/') && !url.contains('.')) {
      return url;
    }

    // youtube.com/watch?v=VIDEO_ID 形式
    final regExpWatch = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([^&\?#]+)',
    );
    final matchWatch = regExpWatch.firstMatch(url);
    if (matchWatch != null && matchWatch.groupCount >= 1) {
      return matchWatch.group(1) ?? '';
    }

    // youtu.be/VIDEO_ID 形式
    final regExpShort = RegExp(r'youtu\.be\/([^&\?#]+)');
    final matchShort = regExpShort.firstMatch(url);
    if (matchShort != null && matchShort.groupCount >= 1) {
      return matchShort.group(1) ?? '';
    }

    return url;
  }

  /// ビデオ再生画面に遷移
  void _openVideo(String videoId) {
    if (videoId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('有効なビデオIDを入力してください')));
      return;
    }

    context.go('${AppConstants.videoRoute}?videoId=$videoId');
  }
}
