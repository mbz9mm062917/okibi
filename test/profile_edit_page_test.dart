import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:okibi/data/user_repository.dart';
import 'package:okibi/profile_edit_page.dart';

/// 「開く」ボタンから編集画面を開く。保存内容は [onSave] で受け取る。
Future<void> pumpEditOpener(
  WidgetTester tester, {
  required UserProfile initial,
  required Future<void> Function(ProfileEdit) onSave,
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
                    builder: (_) => ProfileEditPage(initial: initial, onSave: onSave),
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

Finder saveButton() => find.widgetWithText(FilledButton, '保存');

const initialProfile = UserProfile(
  displayName: 'あ',
  statusMessage: '毎朝走ってます',
  avatarIconId: 'run',
  avatarColorId: 'moss',
  genreTags: ['筋トレ'],
);

void main() {
  group('ProfileEditPage', () {
    testWidgets('現在の名前・一言が入力欄に入っている', (tester) async {
      await pumpEditOpener(tester, initial: initialProfile, onSave: (_) async {});

      expect(find.text('あ'), findsOneWidget);
      expect(find.text('毎朝走ってます'), findsOneWidget);
    });

    testWidgets('ニックネームが空の間は「保存」を押せない', (tester) async {
      await pumpEditOpener(tester, initial: initialProfile, onSave: (_) async {});

      await tester.enterText(find.widgetWithText(TextField, 'ニックネーム'), '  ');
      await tester.pump();

      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    });

    testWidgets('何も変えずに保存すると、現在の内容がそのまま渡される', (tester) async {
      ProfileEdit? saved;
      bool? result;
      await pumpEditOpener(
        tester,
        initial: initialProfile,
        onSave: (e) async => saved = e,
        onResult: (r) => result = r,
      );

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(saved?.displayName, 'あ');
      expect(saved?.statusMessage, '毎朝走ってます');
      expect(saved?.avatarIconId, 'run');
      expect(saved?.avatarColorId, 'moss');
      expect(saved?.genreTags, ['筋トレ']);
      expect(result, isTrue);
    });

    testWidgets('アイコン・色・名前・ジャンルを変えて保存できる', (tester) async {
      ProfileEdit? saved;
      await pumpEditOpener(
        tester,
        initial: initialProfile,
        onSave: (e) async => saved = e,
      );

      await tester.tap(find.byTooltip('本'));
      await tester.tap(find.byTooltip('ばら'));
      await tester.enterText(find.widgetWithText(TextField, 'ニックネーム'), '  ほのお  ');
      await tester.tap(find.widgetWithText(FilterChip, '勉強'));
      await tester.pump();
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(saved?.avatarIconId, 'book');
      expect(saved?.avatarColorId, 'rose');
      expect(saved?.displayName, 'ほのお'); // 前後の空白は取り除かれる
      expect(saved?.genreTags, containsAll(['筋トレ', '勉強']));
    });

    testWidgets('ジャンルは3つまで。3つ選ぶと残りは押せなくなる', (tester) async {
      await pumpEditOpener(tester, initial: initialProfile, onSave: (_) async {});

      await tester.tap(find.widgetWithText(FilterChip, '勉強'));
      await tester.tap(find.widgetWithText(FilterChip, '仕事'));
      await tester.pump();

      // 選んでいない「創作」は押せない。選んでいる「勉強」は外せる。
      expect(
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, '創作')).onSelected,
        isNull,
      );
      expect(
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, '勉強')).onSelected,
        isNotNull,
      );
    });

    testWidgets('未設定のアイコン・色でも開ける(以前の "default" など)', (tester) async {
      ProfileEdit? saved;
      await pumpEditOpener(
        tester,
        initial: const UserProfile(displayName: 'あ', avatarIconId: 'default'),
        onSave: (e) async => saved = e,
      );

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(saved?.avatarIconId, 'fire'); // 既定のアイコンに置き換わる
      expect(saved?.avatarColorId, 'navy');
    });

    testWidgets('保存に失敗したら閉じずにメッセージを出す', (tester) async {
      await pumpEditOpener(
        tester,
        initial: initialProfile,
        onSave: (_) async => throw Exception('通信エラー'),
      );

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(find.byType(ProfileEditPage), findsOneWidget);
      expect(find.textContaining('保存に失敗しました'), findsOneWidget);
    });
  });
}
