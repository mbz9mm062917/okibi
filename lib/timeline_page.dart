import 'package:flutter/material.dart';

import 'data/post.dart';
import 'data/user_repository.dart';
import 'widgets/post_card.dart';

/// タイムライン画面。
///
/// - 「全体」: 公開投稿と自分の投稿(非公開含む)を新しい順に並べる
/// - 「フォロー中」: フォローしている人の公開投稿を新しい順に並べる
///
/// 投稿の取得元や、投稿者の名前の取得方法は外から渡す。
/// (Firebaseなしでテストできるようにするため)
class TimelinePage extends StatelessWidget {
  const TimelinePage({
    super.key,
    required this.posts,
    required this.followingPosts,
    required this.loadProfile,
    required this.onOpenProfile,
  });

  final Stream<List<Post>> posts;
  final Stream<List<Post>> followingPosts;
  final Future<UserProfile> Function(String uid) loadProfile;

  /// 投稿者の名前やアイコンがタップされたとき、その人のUIDを渡す。
  final void Function(String uid) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('タイムライン'),
          bottom: const TabBar(
            tabs: [Tab(text: '全体'), Tab(text: 'フォロー中')],
          ),
        ),
        // 投稿の購読は TabBarView の外に置く。タブを切り替えても購読が
        // 張り直されないようにするため。
        body: StreamBuilder<List<Post>>(
          stream: posts,
          builder: (context, allSnapshot) {
            return StreamBuilder<List<Post>>(
              stream: followingPosts,
              builder: (context, followingSnapshot) {
                return TabBarView(
                  children: [
                    PostListBody(
                      snapshot: allSnapshot,
                      loadProfile: loadProfile,
                      emptyMessage: 'まだ投稿がありません',
                      // 自分の非公開の投稿も並ぶので、「非公開」の印を付ける。
                      showVisibility: true,
                      onAuthorTap: onOpenProfile,
                    ),
                    PostListBody(
                      snapshot: followingSnapshot,
                      loadProfile: loadProfile,
                      emptyMessage:
                          'フォロー中の人の投稿は、まだありません\n全体タブで気になる人の名前をタップして、フォローしてみましょう',
                      onAuthorTap: onOpenProfile,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
