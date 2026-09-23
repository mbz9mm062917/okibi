import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:okibi/data/post.dart';
import 'package:okibi/data/user_repository.dart';
import 'package:okibi/timeline_page.dart';
import 'package:okibi/widgets/post_card.dart';

Post post({
  String id = 'p1',
  String authorUid = 'u1',
  String text = '本文',
  String genreTag = '筋トレ',
  bool isPublic = true,
  DateTime? createdAt,
}) {
  return Post(
    id: id,
    authorUid: authorUid,
    text: text,
    genreTag: genreTag,
    isPublic: isPublic,
    reactionCount: 0,
    createdAt: createdAt ?? DateTime(2020, 1, 1, 9, 5),
  );
}

Future<void> pumpTimeline(
  WidgetTester tester,
  Stream<List<Post>> posts, {
  Stream<List<Post>>? followingPosts,
  void Function(String uid)? onOpenProfile,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: TimelinePage(
        posts: posts,
        followingPosts: followingPosts ?? Stream.value(const <Post>[]),
        loadProfile: (uid) async => UserProfile(displayName: '名前-$uid'),
        onOpenProfile: onOpenProfile ?? (_) {},
      ),
    ),
  );
}

void main() {
  group('TimelinePage', () {
    testWidgets('公開投稿の本文・投稿者名・ジャンルを表示する', (tester) async {
      await pumpTimeline(
        tester,
        Stream.value([
          post(id: 'a', authorUid: 'u1', text: '朝ランした', genreTag: '筋トレ'),
          post(id: 'b', authorUid: 'u2', text: '英単語を50個', genreTag: '勉強'),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('朝ランした'), findsOneWidget);
      expect(find.text('名前-u1'), findsOneWidget);
      expect(find.text('#筋トレ'), findsOneWidget);
      expect(find.text('英単語を50個'), findsOneWidget);
      expect(find.text('名前-u2'), findsOneWidget);
      expect(find.text('#勉強'), findsOneWidget);
    });

    testWidgets('自分の非公開の投稿も並び、「非公開」の印が付く', (tester) async {
      await pumpTimeline(
        tester,
        Stream.value([
          post(id: 'a', text: '公開の投稿'),
          post(id: 'b', text: '自分だけの投稿', isPublic: false),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('公開の投稿'), findsOneWidget);
      expect(find.text('自分だけの投稿'), findsOneWidget);
      expect(find.text('非公開'), findsOneWidget); // 非公開の1件だけ
    });

    testWidgets('投稿が無いときは案内を表示する', (tester) async {
      await pumpTimeline(tester, Stream.value(const <Post>[]));
      await tester.pumpAndSettle();

      expect(find.text('まだ投稿がありません'), findsOneWidget);
    });

    testWidgets('読み込みに失敗したらエラーを表示する', (tester) async {
      await pumpTimeline(tester, Stream.error('権限がありません'));
      await tester.pumpAndSettle();

      expect(find.textContaining('読み込めませんでした'), findsOneWidget);
    });

    testWidgets('「フォロー中」タブにはフォロー中の人の投稿が並ぶ', (tester) async {
      await pumpTimeline(
        tester,
        Stream.value([post(id: 'a', authorUid: 'u1', text: '全体の投稿')]),
        followingPosts:
            Stream.value([post(id: 'b', authorUid: 'u2', text: 'フォロー中の人の投稿')]),
      );
      await tester.pumpAndSettle();

      // 最初は「全体」タブ。
      expect(find.text('全体の投稿'), findsOneWidget);

      await tester.tap(find.text('フォロー中'));
      await tester.pumpAndSettle();

      expect(find.text('フォロー中の人の投稿'), findsOneWidget);
      expect(find.text('名前-u2'), findsOneWidget);
    });

    testWidgets('「フォロー中」タブは、誰の投稿も無いとき案内を出す', (tester) async {
      await pumpTimeline(tester, Stream.value([post(text: '全体の投稿')]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('フォロー中'));
      await tester.pumpAndSettle();

      expect(find.textContaining('フォロー中の人の投稿は、まだありません'), findsOneWidget);
    });

    testWidgets('投稿者の名前をタップすると、その人のUIDで onOpenProfile が呼ばれる', (tester) async {
      final opened = <String>[];
      await pumpTimeline(
        tester,
        Stream.value([post(authorUid: 'u9', text: '本文')]),
        onOpenProfile: opened.add,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('名前-u9'));
      await tester.pump();

      expect(opened, ['u9']);
    });

    testWidgets('自分の非公開の投稿は「フォロー中」タブには「非公開」の印を出さない', (tester) async {
      // フォロー中には他の人の公開投稿だけが来る。印は「全体」タブでだけ付く。
      await pumpTimeline(
        tester,
        Stream.value(const <Post>[]),
        followingPosts: Stream.value([post(text: '公開の投稿')]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('フォロー中'));
      await tester.pumpAndSettle();

      expect(find.text('公開の投稿'), findsOneWidget);
      expect(find.text('非公開'), findsNothing);
    });

    testWidgets('タブを切り替えて戻っても投稿が表示される', (tester) async {
      // 単発の Stream は1回しか購読できない。購読が張り直されると失敗する。
      await pumpTimeline(tester, Stream.value([post(text: '全体の投稿')]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('フォロー中'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('全体'));
      await tester.pumpAndSettle();

      expect(find.text('全体の投稿'), findsOneWidget);
    });
  });

  group('formatPostTime', () {
    final now = DateTime(2026, 9, 21, 20, 0);

    test('今日の投稿は時刻だけ', () {
      expect(formatPostTime(DateTime(2026, 9, 21, 9, 5), now: now), '09:05');
    });

    test('今日以外は日付つき', () {
      expect(
        formatPostTime(DateTime(2026, 9, 19, 19, 30), now: now),
        '9/19 19:30',
      );
    });

    test('同じ日付でも年が違えば日付つき', () {
      expect(
        formatPostTime(DateTime(2025, 9, 21, 9, 5), now: now),
        '9/21 09:05',
      );
    });
  });
}
