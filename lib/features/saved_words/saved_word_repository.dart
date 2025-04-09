import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:language_learning_app/core/constants.dart';

/// 保存された単語を表すクラス
class SavedWord {
  /// 単語
  final String word;

  /// 単語の意味
  final String meaning;

  /// 単語が保存された日時
  final DateTime savedAt;

  /// コンストラクタ
  SavedWord({required this.word, required this.meaning, DateTime? savedAt})
    : savedAt = savedAt ?? DateTime.now();

  /// JSONからSavedWordオブジェクトを生成
  factory SavedWord.fromJson(Map<String, dynamic> json) {
    return SavedWord(
      word: json['word'],
      meaning: json['meaning'],
      savedAt: DateTime.parse(json['savedAt']),
    );
  }

  /// SavedWordオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'meaning': meaning,
      'savedAt': savedAt.toIso8601String(),
    };
  }
}

/// 保存された単語を管理するリポジトリ
class SavedWordRepository extends ChangeNotifier {
  List<SavedWord> _savedWords = [];

  /// 保存された単語のリスト
  List<SavedWord> get savedWords => _savedWords;

  /// コンストラクタ
  SavedWordRepository() {
    _loadSavedWords();
  }

  /// 保存された単語を読み込む
  Future<void> _loadSavedWords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedWordsJson = prefs.getString(
        AppConstants.savedWordsKey,
      );

      if (savedWordsJson != null) {
        final List<dynamic> decoded = jsonDecode(savedWordsJson);
        _savedWords = decoded.map((item) => SavedWord.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      // エラー処理
      debugPrint('保存された単語の読み込みに失敗しました: $e');
    }
  }

  /// 保存された単語を永続化する
  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        _savedWords.map((w) => w.toJson()).toList(),
      );
      await prefs.setString(AppConstants.savedWordsKey, encoded);
    } catch (e) {
      // エラー処理
      debugPrint('単語の保存に失敗しました: $e');
    }
  }

  /// 単語を保存
  Future<void> saveWord(String word, String meaning) async {
    // 既に保存されている場合は更新
    final existingIndex = _savedWords.indexWhere((item) => item.word == word);

    if (existingIndex >= 0) {
      _savedWords[existingIndex] = SavedWord(word: word, meaning: meaning);
    } else {
      _savedWords.add(SavedWord(word: word, meaning: meaning));
    }

    notifyListeners();
    await _saveToDisk();
  }

  /// 単語を削除
  Future<void> removeWord(String word) async {
    _savedWords.removeWhere((item) => item.word == word);
    notifyListeners();
    await _saveToDisk();
  }

  /// 単語を検索
  SavedWord? findWord(String word) {
    try {
      return _savedWords.firstWhere((item) => item.word == word);
    } catch (e) {
      return null;
    }
  }

  /// 保存された単語があるかどうか
  bool hasSavedWord(String word) {
    return _savedWords.any((item) => item.word == word);
  }
}
