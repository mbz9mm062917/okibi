import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:okibi/data/post.dart';
import 'package:okibi/data/user_repository.dart';
import 'package:okibi/profile_page.dart';

const me = UserProfile(
  displayName: 'ほのお',
  statusMessage: '静かに燃えてます',
  avatarIconId: 'fire',
  avatarColorId: 'ember',
  genreTags: ['筋トレ', '読書'],
  recordDayCount: 12,
);

Post post({required String id, required String text, bool isPublic = true}) {
  return Post(
    id: id,
    authorUid: 'me',
    text: text,
    genreTag: 'その他',
    isPublic: isPublic,
    reactionCount: 0,
    createdAt: DateTime(2020, 1, 1, 9, 5),
  );
}

/// ホーム画面の上にプロフィール画面を重ねた状態を作る(実際のアプリと同じ構造)。
Future<void> pumpProfile(
  WidgetTester tester, {
  UserProfile profile = me,
  Stream<List<Post>> Function()? watchMyPosts,
  Future<void> Function()? onSignOut,
}) async {
  // ListView は画面外の項目を作らないので、下のメニューまで表示される縦長の画面にする。
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfilePage(
                    profile: Stream.value(profile),
                    watchMyPosts: watchMyPosts ?? () => Stream.value(const <Post>[]),
                    loadProfile: (uid) async => const UserProfile(displayName: 'ほのお'),
                    onSaveProfile: (_) async {},
                    onSignOut: onSignOut ?? () async {},
                  ),
                ),
              ),
              child: const Text('ホーム'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ホーム'));
  await tester.pumpAndSettle();
}

void main() {
  group('ProfilePage', () {
    testWidgets('名前・一言・ジャンル・記録日数を表示する', (tester) async {
      await pumpProfile(tester);

      expect(find.text('ほのお'), findsOneWidget);
      expect(find.text('静かに燃えてます'), findsOneWidget);
      expect(find.text('#筋トレ'), findsOneWidget);
      expect(find.text('#読書'), findsOneWidget);
      expect(find.text('12日'), findsOneWidget);
      expect(find.text('あなただけに表示'), findsOneWidget);
    });

    testWidgets('一言もジャンルも未設定なら、その欄は出ない', (tester) async {
      await pumpProfile(tester, profile: const UserProfile(displayName: 'あ'));

      expect(find.text('あ'), findsOneWidget);
      expect(find.textContaining('#'), findsNothing);
      expect(find.text('0日'), findsOneWidget);
    });

    testWidgets('準備中のメニューは押せない', (tester) async {
      await pumpProfile(tester);

      for (final title in ['月の振り返り', 'グループ', '公開範囲の設定']) {
        final tile = tester.widget<ListTile>(
          find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
        );
        expect(tile.enabled, isFalse, reason: title);
        expect(tile.onTap, isNull, reason: title);
      }
      expect(find.text('準備中'), findsNWidgets(3));
    });

    testWidgets('「自分の投稿」で、非公開の投稿には「非公開」と表示される', (tester) async {
      await pumpProfile(
        tester,
        watchMyPosts: () => Stream.value([
          post(id: 'a', text: '公開の投稿'),
          post(id: 'b', text: '自分だけの投稿', isPublic: false),
        ]),
      );

      await tester.tap(find.text('自分の投稿'));
      await tester.pumpAndSettle();

      expect(find.text('公開の投稿'), findsOneWidget);
      expect(find.text('自分だけの投稿'), findsOneWidget);
      expect(find.text('非公開'), findsOneWidget); // 非公開の1件だけ
    });

    testWidgets('「自分のカレンダー」でホームに戻る', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.text('自分のカレンダー'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfilePage), findsNothing);
      expect(find.text('ホーム'), findsOneWidget);
    });

    testWidgets('「ログアウト」は確認のポップを出し、まだログアウトしない', (tester) async {
      var signedOut = false;
      await pumpProfile(tester, onSignOut: () async => signedOut = true);

      await tester.tap(find.text('ログアウト'));
      await tester.pumpAndSettle();

      expect(find.text('ログアウトしますか?'), findsOneWidget);
      expect(signedOut, isFalse);
      expect(find.byType(ProfilePage), findsOneWidget);
    });

    testWidgets('確認で「キャンセル」を押すと、ログアウトせず画面に残る', (tester) async {
      var signedOut = false;
      await pumpProfile(tester, onSignOut: () async => signedOut = true);

      await tester.tap(find.text('ログアウト'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(find.text('ログアウトしますか?'), findsNothing);
      expect(signedOut, isFalse);
      expect(find.byType(ProfilePage), findsOneWidget);
    });

    testWidgets('確認で「ログアウト」を押すと、画面を閉じてからログアウト処理を呼ぶ', (tester) async {
      var signedOut = false;
      await pumpProfile(tester, onSignOut: () async => signedOut = true);

      await tester.tap(find.text('ログアウト'));
      await tester.pumpAndSettle();
      // メニューにも同じ文言があるので、ダイアログの中のボタンを指定する。
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('ログアウト'),
        ),
      );
      await tester.pumpAndSettle();

      expect(signedOut, isTrue);
      expect(find.byType(ProfilePage), findsNothing);
    });

    testWidgets('「プロフィールを編集」で編集画面が開く', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.text('プロフィールを編集'));
      await tester.pumpAndSettle();

      expect(find.text('ニックネーム'), findsOneWidget);
    });
  });
}
