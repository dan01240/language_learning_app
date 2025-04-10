/// 時間フォーマットのユーティリティクラス
class TimeFormatter {
  /// ミリ秒を時:分:秒形式にフォーマット
  static String formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final hours = (minutes / 60).floor();

    final hoursStr = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    final minutesStr = '${(minutes % 60).toString().padLeft(2, '0')}:';
    final secondsStr = (seconds % 60).toString().padLeft(2, '0');

    return '$hoursStr$minutesStr$secondsStr';
  }

  /// 時:分:秒形式の文字列をミリ秒に変換
  static int durationToMilliseconds(String timeString) {
    final parts = timeString.split(':');

    if (parts.isEmpty || parts.length > 3) {
      throw const FormatException('無効な時間形式');
    }

    int hours = 0;
    int minutes = 0;
    int seconds = 0;

    if (parts.length == 3) {
      hours = int.parse(parts[0]);
      minutes = int.parse(parts[1]);
      seconds = int.parse(parts[2]);
    } else if (parts.length == 2) {
      minutes = int.parse(parts[0]);
      seconds = int.parse(parts[1]);
    } else {
      seconds = int.parse(parts[0]);
    }

    return ((hours * 3600) + (minutes * 60) + seconds) * 1000;
  }

  /// 文字形式の日付をフォーマット (yyyy/MM/dd)
  static String formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
