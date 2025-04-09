import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:language_learning_app/core/constants.dart';

/// 辞書エントリーを表すクラス
class DictionaryEntry {
  /// 単語
  final String word;

  /// 品詞
  final String? partOfSpeech;

  /// 意味のリスト
  final List<String> meanings;

  /// 例文のリスト
  final List<String> examples;

  /// コンストラクタ
  DictionaryEntry({
    required this.word,
    this.partOfSpeech,
    required this.meanings,
    this.examples = const [],
  });

  /// JSONからDictionaryEntryオブジェクトを生成
  factory DictionaryEntry.fromJishoJson(Map<String, dynamic> json) {
    final meanings = <String>[];
    final examples = <String>[];
    String? partOfSpeech;

    if (json['senses'] != null) {
      for (final sense in json['senses']) {
        if (sense['parts_of_speech'] != null &&
            sense['parts_of_speech'].isNotEmpty) {
          partOfSpeech = sense['parts_of_speech'][0];
        }

        if (sense['english_definitions'] != null) {
          meanings.addAll(List<String>.from(sense['english_definitions']));
        }

        if (sense['examples'] != null) {
          examples.addAll(
            List<String>.from(sense['examples'].map((e) => e['text'])),
          );
        }
      }
    }

    return DictionaryEntry(
      word: json['slug'] ?? '',
      partOfSpeech: partOfSpeech,
      meanings: meanings,
      examples: examples,
    );
  }

  /// モックデータからDictionaryEntryオブジェクトを生成（APIが利用できない場合）
  factory DictionaryEntry.mock(String word) {
    // 簡単なモックデータを返す
    if (word.toLowerCase() == 'hello') {
      return DictionaryEntry(
        word: 'hello',
        partOfSpeech: 'exclamation',
        meanings: ['used as a greeting', 'an expression of surprise'],
        examples: ['Hello, how are you?', 'Hello! What are you doing here?'],
      );
    } else if (word.toLowerCase() == 'welcome') {
      return DictionaryEntry(
        word: 'welcome',
        partOfSpeech: 'adjective',
        meanings: [
          'received with pleasure',
          'giving pleasure because needed or wanted',
        ],
        examples: ['You are welcome to join us', 'A welcome break from work'],
      );
    } else if (word.toLowerCase() == 'learn' ||
        word.toLowerCase() == 'learning') {
      return DictionaryEntry(
        word: 'learn',
        partOfSpeech: 'verb',
        meanings: [
          'gain knowledge or skill by studying or experience',
          'commit to memory',
        ],
        examples: [
          'I learned French in school',
          'She is learning to play the piano',
        ],
      );
    } else if (word.toLowerCase() == 'video') {
      return DictionaryEntry(
        word: 'video',
        partOfSpeech: 'noun',
        meanings: [
          'recording of moving visual images',
          'the process of recording moving visual images',
        ],
        examples: [
          'We watched a video about Japan',
          'He makes videos as a hobby',
        ],
      );
    } else {
      // 他の単語の場合は汎用的なモックデータを返す
      return DictionaryEntry(
        word: word,
        partOfSpeech: 'unknown',
        meanings: ['(この単語のモックデータはありません)'],
        examples: [],
      );
    }
  }
}

/// 辞書サービスを提供するクラス
class DictionaryService {
  /// Jisho APIを使用して単語を検索
  Future<List<DictionaryEntry>> lookupWord(String word) async {
    try {
      // 実際にはAPIにリクエストを送信するが、この例ではモックデータを返す
      // 本番環境ではコメントを外してAPIを使用する
      /*
      final response = await http.get(
        Uri.parse('${AppConstants.jishoApiBaseUrl}?keyword=$word'),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> results = data['data'] ?? [];
        
        if (results.isEmpty) {
          // 結果がない場合はモックデータを返す
          return [DictionaryEntry.mock(word)];
        }
        
        // APIレスポンスから辞書エントリーを生成
        return results
            .map<DictionaryEntry>((result) => DictionaryEntry.fromJishoJson(result))
            .toList();
      }
      */

      // モックデータを返す（デモ用）
      return [DictionaryEntry.mock(word)];
    } catch (e) {
      // 例外発生時もモックデータを返す
      return [DictionaryEntry.mock(word)];
    }
  }
}
