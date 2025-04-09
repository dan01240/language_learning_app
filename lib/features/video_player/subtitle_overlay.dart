import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:language_learning_app/core/constants.dart';
import 'package:language_learning_app/core/themes.dart';
import 'package:language_learning_app/features/video_player/models/subtitle.dart';
import 'package:language_learning_app/features/dictionary/dictionary_popup.dart';

/// ビデオプレーヤーの上に字幕を表示するオーバーレイウィジェット
class SubtitleOverlay extends StatelessWidget {
  /// 現在表示する字幕
  final Subtitle? currentSubtitle;

  /// 字幕がタップされた時のコールバック
  final Function(String word)? onWordTap;

  /// コンストラクタ
  const SubtitleOverlay({Key? key, this.currentSubtitle, this.onWordTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (currentSubtitle == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: AppConstants.subtitlePadding,
      right: AppConstants.subtitlePadding,
      bottom: AppConstants.subtitleBottomMargin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.subtitleBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTappableText(
              context,
              currentSubtitle!.text,
              AppTextStyles.subtitleText,
            ),
            if (currentSubtitle!.translation != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  currentSubtitle!.translation!,
                  style: AppTextStyles.subtitleTranslation,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// タップ可能な字幕テキストを構築
  Widget _buildTappableText(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    // 空白で単語を分割
    final words = text.split(' ');

    return RichText(
      text: TextSpan(
        children:
            words.asMap().entries.map((entry) {
              final index = entry.key;
              final word = entry.value;

              // 単語を選択可能に
              return TextSpan(
                text: word + (index < words.length - 1 ? ' ' : ''),
                style: style,
                recognizer:
                    TapGestureRecognizer()
                      ..onTap = () {
                        _showDictionaryPopup(context, word);
                        if (onWordTap != null) {
                          onWordTap!(word);
                        }
                      },
              );
            }).toList(),
      ),
      textAlign: TextAlign.center,
    );
  }

  /// 辞書ポップアップを表示
  void _showDictionaryPopup(BuildContext context, String word) {
    // 単語から記号を削除
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').trim();

    if (cleanWord.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => DictionaryPopup(word: cleanWord),
    );
  }
}
