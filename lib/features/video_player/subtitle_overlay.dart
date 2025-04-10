// lib/features/video_player/subtitle_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:language_learning_app/core/constants.dart';
import 'package:language_learning_app/core/themes.dart';
import 'package:language_learning_app/features/video_player/models/subtitle.dart';
import 'package:language_learning_app/features/dictionary/dictionary_popup.dart';

class SubtitleOverlay extends StatelessWidget {
  final Subtitle? currentSubtitle;
  final Function(String word)? onWordTap;
  final bool showTranslation;

  const SubtitleOverlay({
    Key? key,
    this.currentSubtitle,
    this.onWordTap,
    this.showTranslation = true,
  }) : super(key: key);

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
            if (showTranslation && currentSubtitle!.translation != null)
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

  Widget _buildTappableText(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    // 単語に分割（英語固有の処理なので、他言語対応の場合は変更が必要）
    final words = text.split(' ');

    return RichText(
      text: TextSpan(
        children:
            words.asMap().entries.map((entry) {
              final index = entry.key;
              final word = entry.value;

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

  void _showDictionaryPopup(BuildContext context, String word) {
    // 単語から記号を削除
    final cleanWord =
        word.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();

    if (cleanWord.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => DictionaryPopup(word: cleanWord),
    );
  }
}
