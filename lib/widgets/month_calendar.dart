import 'package:flutter/material.dart';

import '../data/stamp_repository.dart';

/// 月間カレンダー。記録済みの日はグレー塗り、今日はネイビーの枠で強調する。
///
/// 表示中の月や記録の状態は親が持ち、この部品は描画とタップの通知だけを行う。
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.stampedDates,
    required this.today,
    required this.onDayTap,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  /// 表示する月(その月の1日)。
  final DateTime month;

  /// 記録済みの日付("YYYY-MM-DD")。
  final Set<String> stampedDates;

  final DateTime today;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  static const _weekdayLabels = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // DateTime.weekday は月=1〜日=7。日曜始まりにするため 7 で割った余りを使う。
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weekCount = ((leadingBlanks + daysInMonth) / 7).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: '前の月',
              onPressed: onPrevMonth,
            ),
            Expanded(
              child: Text(
                '${month.year}年${month.month}月',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: '次の月',
              onPressed: onNextMonth,
            ),
          ],
        ),
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(child: Text(label, style: textTheme.labelSmall)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var week = 0; week < weekCount; week++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _cellFor(
                      context,
                      day: week * 7 + col - leadingBlanks + 1,
                      daysInMonth: daysInMonth,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cellFor(
    BuildContext context, {
    required int day,
    required int daysInMonth,
  }) {
    if (day < 1 || day > daysInMonth) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }

    final scheme = Theme.of(context).colorScheme;
    final date = DateTime(month.year, month.month, day);
    final todayDate = DateTime(today.year, today.month, today.day);
    final isToday = date == todayDate;
    final isFuture = date.isAfter(todayDate);
    final isStamped = stampedDates.contains(dateKey(date));
    final radius = BorderRadius.circular(12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: isStamped ? Colors.grey.shade300 : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: isFuture ? null : () => onDayTap(date),
            child: Container(
              alignment: Alignment.center,
              decoration: isToday
                  ? BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(color: scheme.primary, width: 2),
                    )
                  : null,
              child: Text(
                '$day',
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isFuture
                      ? scheme.onSurface.withValues(alpha: 0.3)
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
