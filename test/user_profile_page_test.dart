import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:okibi/data/post.dart';
import 'package:okibi/data/user_repository.dart';
import 'package:okibi/user_profile_page.dart';

const other = UserProfile(
  displayName: 'つき',
  statusMessage: '夜に読書',
  avatarIconId: 'moon',
  avatarColorId: 'plum',
  genreTags: ['読書'],
  recordDayCount: 99, // 他の人には見せない
);

Post post({required String id, required String text}) {
  return Post(
    id: id,
    authorUid: 'other',
    text: text,
    genreTag: 'その他',
    isPublic: true,
    reactionCount: 0,
    createdAt: DateTime(2020, 1, 1, 9, 5),
  );
}

/// 他の人のプロフィール画面を表示する。フォロー状態は [following] のストリームで操作する。
Future<void> pumpUserProfile(
  WidgetTester tester, {
  bool isMe = false,
  required Stream<bool> following,
  Stream<List<Post>>? posts,
  Future<void> Function(bool following)? onSetFollowing,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: UserProfilePage(
        isMe: isMe,
        profile: Stream.value(other),
        isFollowing: following,
        followingCount: Stream.value(2),
        followerCount: Stream.value(5),
        posts: posts ?? Stream.value(const <Post>[]),
        loadProfile: (uid) async => other,
        onSetFollowing: onSetFollowing ?? (_) async {},
      ),
    ),
  );
}

Finder followButton() => find.widgetWithText(FilledButton, 'フォローする');
Finder followingButton() => find.widgetWithText(OutlinedButton, 'フォロー中');

void main() {
  group('UserProfilePage', () {
    testWidgets('名前・一言・ジャンル・フォロー数を表示し、記録日数は出さない', (tester) async {
      await pumpUserProfile(tester, following: Stream.value(false));
      await tester.pumpAndSettle();

      expect(find.text('つき'), findsOneWidget);
      expect(find.text('夜に読書'), findsOneWidget);
      expect(find.text('#読書'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // フォロー
      expect(find.text('5'), findsOneWidget); // フォロワー
      // 記録日数は本人にだけ表示する。
      expect(find.textContaining('記録日数'), findsNothing);
      expect(find.text('99日'), findsNothing);
    });

    testWidgets('フォローしていないときは「フォローする」、押すと onSetFollowing(true)', (tester) async {
      final calls = <bool>[];
      await pumpUserProfile(
        tester,
        following: Stream.value(false),
        onSetFollowing: (v) async => calls.add(v),
      );
      await tester.pumpAndSettle();

      expect(followButton(), findsOneWidget);
      expect(followingButton(), findsNothing);

      await tester.tap(followButton());
      await tester.pumpAndSettle();

      expect(calls, [true]);
    });

    testWidgets('フォロー中のときは「フォロー中」。押すと確認が出て、まだやめない', (tester) async {
      final calls = <bool>[];
      await pumpUserProfile(
        tester,
        following: Stream.value(true),
        onSetFollowing: (v) async => calls.add(v),
      );
      await tester.pumpAndSettle();

      await tester.tap(followingButton());
      await tester.pumpAndSettle();

      expect(find.text('フォローをやめますか?'), findsOneWidget);
      expect(calls, isEmpty);
    });

    testWidgets('確認で「キャンセル」なら、フォローをやめない', (tester) async {
      final calls = <bool>[];
      await pumpUserProfile(
        tester,
        following: Stream.value(true),
        onSetFollowing: (v) async => calls.add(v),
      );
      await tester.pumpAndSettle();

      await tester.tap(followingButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
      expect(find.text('フォローをやめますか?'), findsNothing);
    });

    testWidgets('確認で「やめる」を押すと onSetFollowing(false)', (tester) async {
      final calls = <bool>[];
      await pumpUserProfile(
        tester,
        following: Stream.value(true),
        onSetFollowing: (v) async => calls.add(v),
      );
      await tester.pumpAndSettle();

      await tester.tap(followingButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();

      expect(calls, [false]);
    });

    testWidgets('フォロー状態が分かるまでは、ボタンを押せない', (tester) async {
      // 値が届かないストリーム
      await pumpUserProfile(tester, following: const Stream<bool>.empty());
      await tester.pump();

      expect(tester.widget<FilledButton>(followButton()).onPressed, isNull);
    });

    testWidgets('処理中はボタンを押せず、二重に呼ばれない', (tester) async {
      final release = Completer<void>();
      var calls = 0;
      await pumpUserProfile(
        tester,
        following: Stream.value(false),
        onSetFollowing: (_) {
          calls++;
          return release.future;
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(followButton());
      await tester.pump();
      expect(tester.widget<FilledButton>(followButton()).onPressed, isNull);

      release.complete();
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('操作に失敗したらメッセージを出す', (tester) async {
      await pumpUserProfile(
        tester,
        following: Stream.value(false),
        onSetFollowing: (_) async => throw Exception('通信エラー'),
      );
      await tester.pumpAndSettle();

      await tester.tap(followButton());
      await tester.pumpAndSettle();

      expect(find.textContaining('操作に失敗しました'), findsOneWidget);
    });

    testWidgets('自分のプロフィールを開いたときは、フォローボタンを出さない', (tester) async {
      await pumpUserProfile(tester, isMe: true, following: Stream.value(false));
      await tester.pumpAndSettle();

      expect(find.text('つき'), findsOneWidget);
      expect(followButton(), findsNothing);
      expect(followingButton(), findsNothing);
    });

    testWidgets('その人の公開投稿を表示する', (tester) async {
      await pumpUserProfile(
        tester,
        following: Stream.value(false),
        posts: Stream.value([
          post(id: 'a', text: '一つ目の投稿'),
          post(id: 'b', text: '二つ目の投稿'),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('公開の投稿'), findsOneWidget);
      expect(find.text('一つ目の投稿'), findsOneWidget);
      expect(find.text('二つ目の投稿'), findsOneWidget);
    });

    testWidgets('公開投稿が無いときは案内を出す', (tester) async {
      await pumpUserProfile(tester, following: Stream.value(false));
      await tester.pumpAndSettle();

      expect(find.text('まだ公開された投稿がありません'), findsOneWidget);
    });
  });
}
