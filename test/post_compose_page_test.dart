import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:okibi/post_compose_page.dart';

/// 「開く」ボタンから投稿作成画面を開く。閉じたときの戻り値は [onResult] で受け取る。
Future<void> pumpComposeOpener(
  WidgetTester tester, {
  required PostSubmit onSubmit,
  void Function(bool?)? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => PostComposePage(onSubmit: onSubmit),
                  ),
                );
                onResult?.call(result);
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

Finder submitButton() => find.widgetWithText(FilledButton, '投稿');

void main() {
  group('PostComposePage', () {
    testWidgets('本文が空(空白のみ含む)の間は「投稿」を押せない', (tester) async {
      await pumpComposeOpener(tester, onSubmit: ({
        required text,
        required genreTag,
        required isPublic,
      }) async {});

      expect(tester.widget<FilledButton>(submitButton()).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(tester.widget<FilledButton>(submitButton()).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'こんにちは');
      await tester.pump();
      expect(tester.widget<FilledButton>(submitButton()).onPressed, isNotNull);
    });

    testWidgets('初期値は「その他」タグ・公開で、投稿すると閉じて true が返る', (tester) async {
      String? sentText;
      String? sentTag;
      bool? sentPublic;
      bool? result;

      await pumpComposeOpener(
        tester,
        onResult: (r) => result = r,
        onSubmit: ({
          required text,
          required genreTag,
          required isPublic,
        }) async {
          sentText = text;
          sentTag = genreTag;
          sentPublic = isPublic;
        },
      );

      await tester.enterText(find.byType(TextField), '  今日は走った  ');
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(sentText, '今日は走った'); // 前後の空白は取り除かれる
      expect(sentTag, 'その他');
      expect(sentPublic, isTrue);
      expect(result, isTrue);
      expect(find.byType(PostComposePage), findsNothing);
    });

    testWidgets('選んだジャンルと非公開の設定が反映される', (tester) async {
      String? sentTag;
      bool? sentPublic;

      await pumpComposeOpener(
        tester,
        onSubmit: ({
          required text,
          required genreTag,
          required isPublic,
        }) async {
          sentTag = genreTag;
          sentPublic = isPublic;
        },
      );

      await tester.enterText(find.byType(TextField), 'ベンチプレス');
      await tester.tap(find.text('筋トレ'));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(sentTag, '筋トレ');
      expect(sentPublic, isFalse);
    });

    testWidgets('保存に失敗したら画面を閉じずにメッセージを出す', (tester) async {
      await pumpComposeOpener(
        tester,
        onSubmit: ({
          required text,
          required genreTag,
          required isPublic,
        }) async => throw Exception('通信エラー'),
      );

      await tester.enterText(find.byType(TextField), 'テスト');
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(find.byType(PostComposePage), findsOneWidget);
      expect(find.textContaining('投稿に失敗しました'), findsOneWidget);
      // 失敗後は入力を残したまま、もう一度押せる。
      expect(tester.widget<FilledButton>(submitButton()).onPressed, isNotNull);
    });
  });
}
