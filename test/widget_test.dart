import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:okibi/widgets/month_calendar.dart';

/// 2026年9月を、今日=9/21 として表示するカレンダーを組み立てる。
///
/// 日付マスは横幅に比例した正方形なので、テスト画面(横800px)のままだと縦が
/// 伸びてはみ出す。実機でホーム画面に置かれる幅(約300dp)に合わせて制限する。
Future<void> pumpCalendar(
  WidgetTester tester, {
  Set<String> stamped = const {},
  ValueChanged<DateTime>? onDayTap,
  VoidCallback? onPrevMonth,
  VoidCallback? onNextMonth,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 300,
            child: MonthCalendar(
              month: DateTime(2026, 9),
              stampedDates: stamped,
              today: DateTime(2026, 9, 21),
              onDayTap: onDayTap ?? (_) {},
              onPrevMonth: onPrevMonth ?? () {},
              onNextMonth: onNextMonth ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('MonthCalendar', () {
    testWidgets('月の日数分だけ日付が並び、1日は正しい曜日の列に置かれる', (tester) async {
      await pumpCalendar(tester);

      expect(find.text('2026年9月'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('31'), findsNothing); // 9月は30日まで

      // 2026-09-01 は火曜日。日曜始まりなので「火」の列の真下に来るはず。
      final tuesdayX = tester.getCenter(find.text('火')).dx;
      final firstDayX = tester.getCenter(find.text('1')).dx;
      expect(firstDayX, closeTo(tuesdayX, 1));
    });

    testWidgets('記録済みの日だけグレー塗りになる', (tester) async {
      await pumpCalendar(tester, stamped: {'2026-09-19'});

      final greyCell = find.byWidgetPredicate(
        (w) => w is Material && w.color == Colors.grey.shade300,
      );
      expect(
        find.descendant(of: greyCell, matching: find.text('19')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: greyCell, matching: find.text('18')),
        findsNothing,
      );
    });

    testWidgets('今日と過去の日付はタップに反応し、未来の日付は反応しない', (tester) async {
      final tapped = <DateTime>[];
      await pumpCalendar(tester, onDayTap: tapped.add);

      await tester.tap(find.text('19'));
      await tester.tap(find.text('21'));
      await tester.tap(find.text('25')); // 未来
      await tester.pump();

      expect(tapped, [DateTime(2026, 9, 19), DateTime(2026, 9, 21)]);
    });

    testWidgets('前の月/次の月ボタンでコールバックが呼ばれる', (tester) async {
      var prev = 0;
      var next = 0;
      await pumpCalendar(
        tester,
        onPrevMonth: () => prev++,
        onNextMonth: () => next++,
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.tap(find.byIcon(Icons.chevron_right));

      expect(prev, 1);
      expect(next, 2);
    });
  });
}
