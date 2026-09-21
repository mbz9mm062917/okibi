import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:okibi/widgets/stamp_note_sheet.dart';

/// 「開く」ボタンからシートを表示し、閉じたときの結果を [onResult] で受け取る。
Future<void> pumpSheetOpener(
  WidgetTester tester, {
  required bool isEditing,
  String initialNote = '',
  required void Function(StampSheetResult?) onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                onResult(
                  await showStampNoteSheet(
                    context,
                    title: 'テスト',
                    isEditing: isEditing,
                    initialNote: initialNote,
                  ),
                );
              },
              child: const Text('開く'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('開く'));
  await tester.pumpAndSettle();
}

void main() {
  group('StampNoteSheet', () {
    testWidgets('促し: 入力して「保存」すると一言が返る。取り消しボタンは出ない', (tester) async {
      StampSheetResult? result;
      await pumpSheetOpener(
        tester,
        isEditing: false,
        onResult: (r) => result = r,
      );

      expect(find.text('記録を取り消す'), findsNothing);

      await tester.enterText(find.byType(TextField), 'よく寝た');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(result?.action, StampSheetAction.save);
      expect(result?.note, 'よく寝た');
    });

    testWidgets('促し: 「あとで」で閉じると null が返る', (tester) async {
      var closed = false;
      StampSheetResult? result;
      await pumpSheetOpener(
        tester,
        isEditing: false,
        onResult: (r) {
          closed = true;
          result = r;
        },
      );

      await tester.tap(find.text('あとで'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result, isNull);
    });

    testWidgets('編集: 既存の一言が入力欄に表示され、「あとで」は出ない', (tester) async {
      await pumpSheetOpener(
        tester,
        isEditing: true,
        initialNote: '走った',
        onResult: (_) {},
      );

      expect(find.text('走った'), findsOneWidget);
      expect(find.text('あとで'), findsNothing);
    });

    testWidgets('編集: 「記録を取り消す」で取り消しが返る', (tester) async {
      StampSheetResult? result;
      await pumpSheetOpener(
        tester,
        isEditing: true,
        onResult: (r) => result = r,
      );

      await tester.tap(find.text('記録を取り消す'));
      await tester.pumpAndSettle();

      expect(result?.action, StampSheetAction.cancelStamp);
    });
  });
}
