import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:okibi/data/post.dart';
import 'package:okibi/data/user_repository.dart';
import 'package:okibi/widgets/post_card.dart';

Post post({
  String id = 'p1',
  String authorUid = 'u1',
  String text = '本文',
  int reactionCount = 0,
}) {
  return Post(
    id: id,
    authorUid: authorUid,
    text: text,
    genreTag: '',
    isPublic: true,
    reactionCount: reactionCount,
    createdAt: DateTime(2020, 1, 1, 9, 5),
  );
}

Future<void> pumpCard(
  WidgetTester tester, {
  required Post item,
  Stream<bool> Function(String postId)? watchHasReacted,
  Future<void> Function(String postId)? onToggleReaction,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PostCard(
          post: item,
          loadProfile: (uid) async => UserProfile(displayName: '名前-$uid'),
          watchHasReacted: watchHasReacted,
          onToggleReaction: onToggleReaction,
        ),
      ),
    ),
  );
}

Finder fireIcon() => find.byIcon(Icons.local_fire_department);
Finder fireOutlineIcon() => find.byIcon(Icons.local_fire_department_outlined);

void main() {
  group('PostCard の炎リアクション', () {
    testWidgets('反応先の指定が無いときは数だけ表示し、タップできない', (tester) async {
      await pumpCard(tester, item: post(reactionCount: 3));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(fireOutlineIcon(), findsOneWidget);

      await tester.tap(fireOutlineIcon());
      await tester.pump();
      // タップしても何も起きない(onToggleReaction が無い)。
    });

    testWidgets('反応していないときは輪郭アイコン、タップで onToggleReaction が呼ばれる', (tester) async {
      final toggled = <String>[];
      await pumpCard(
        tester,
        item: post(id: 'p9', reactionCount: 1),
        watchHasReacted: (_) => Stream.value(false),
        onToggleReaction: (postId) async => toggled.add(postId),
      );
      await tester.pumpAndSettle();

      expect(fireOutlineIcon(), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(fireOutlineIcon());
      await tester.pump();

      expect(toggled, ['p9']);
    });

    testWidgets('反応しているときは塗りつぶしアイコンになる', (tester) async {
      await pumpCard(
        tester,
        item: post(reactionCount: 2),
        watchHasReacted: (_) => Stream.value(true),
        onToggleReaction: (_) async {},
      );
      await tester.pumpAndSettle();

      expect(fireIcon(), findsOneWidget);
      expect(fireOutlineIcon(), findsNothing);
    });

    testWidgets('処理中に連打しても onToggleReaction は1回しか呼ばれない', (tester) async {
      var calls = 0;
      final completer = Completer<void>();
      await pumpCard(
        tester,
        item: post(),
        watchHasReacted: (_) => Stream.value(false),
        onToggleReaction: (_) {
          calls++;
          return completer.future;
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(fireOutlineIcon());
      await tester.pump();
      await tester.tap(fireOutlineIcon());
      await tester.pump();

      expect(calls, 1);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('失敗したらスナックバーで知らせる', (tester) async {
      await pumpCard(
        tester,
        item: post(),
        watchHasReacted: (_) => Stream.value(false),
        onToggleReaction: (_) async => throw Exception('通信エラー'),
      );
      await tester.pumpAndSettle();

      await tester.tap(fireOutlineIcon());
      await tester.pumpAndSettle();

      expect(find.textContaining('リアクションに失敗しました'), findsOneWidget);
    });
  });
}
