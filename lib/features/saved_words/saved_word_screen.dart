import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:language_learning_app/features/saved_words/saved_word_repository.dart';
import 'package:language_learning_app/core/themes.dart';
import 'package:language_learning_app/core/constants.dart';

/// 保存した単語を表示する画面
class SavedWordScreen extends StatelessWidget {
  const SavedWordScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go(AppConstants.homeRoute);
          },
        ),
        title: const Text('保存した単語'),
      ),
      body: Consumer<SavedWordRepository>(
        builder: (context, repository, child) {
          final savedWords = repository.savedWords;

          if (savedWords.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 72, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('保存した単語はまだありません'),
                  SizedBox(height: 8),
                  Text(
                    'ビデオを視聴中に単語をタップして保存できます',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: savedWords.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final word = savedWords[index];
              return Dismissible(
                key: Key(word.word),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  repository.removeWord(word.word);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${word.word}を削除しました')),
                  );
                },
                child: ListTile(
                  title: Text(
                    word.word,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(word.meaning),
                      const SizedBox(height: 4),
                      Text(
                        '保存日: ${_formatDate(word.savedAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      repository.removeWord(word.word);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${word.word}を削除しました')),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 日付をフォーマットする
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
