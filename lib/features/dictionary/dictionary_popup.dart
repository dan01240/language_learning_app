import 'package:flutter/material.dart';
import 'package:language_learning_app/features/dictionary/dictionary_service.dart';
import 'package:language_learning_app/core/themes.dart';

/// 単語の意味を表示するポップアップウィジェット
class DictionaryPopup extends StatefulWidget {
  /// 検索する単語
  final String word;

  /// コンストラクタ
  const DictionaryPopup({Key? key, required this.word}) : super(key: key);

  @override
  State<DictionaryPopup> createState() => _DictionaryPopupState();
}

class _DictionaryPopupState extends State<DictionaryPopup> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DictionaryEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadDictionaryData();
  }

  /// 辞書データを読み込む
  Future<void> _loadDictionaryData() async {
    try {
      final service = DictionaryService();
      final entries = await service.lookupWord(widget.word);

      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '単語の検索中にエラーが発生しました: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(height: 24),
            Expanded(child: _buildContent()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  /// ポップアップのヘッダー部分を構築
  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.word,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// ポップアップのコンテンツ部分を構築
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_entries.isEmpty) {
      return const Center(child: Text('この単語の意味が見つかりませんでした。'));
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.partOfSpeech != null)
                Text(
                  entry.partOfSpeech!,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 4),
              ...entry.meanings.map(
                (meaning) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('・ $meaning'),
                ),
              ),
              if (entry.examples.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...entry.examples.map(
                  (example) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '例: $example',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// ポップアップのフッター部分を構築
  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.bookmark_border),
          label: const Text('保存'),
          onPressed: () {
            // TODO: 単語を保存する機能を実装
            Navigator.of(context).pop();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('${widget.word}を保存しました')));
          },
        ),
        TextButton(
          child: const Text('閉じる'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
