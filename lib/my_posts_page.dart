import 'package:flutter/material.dart';

import 'data/post.dart';
import 'data/user_repository.dart';
import 'widgets/post_card.dart';

/// 自分の投稿の一覧。タイムラインには出ない非公開の投稿も含めて表示する。
class MyPostsPage extends StatelessWidget {
  const MyPostsPage({
    super.key,
    required this.posts,
    required this.loadProfile,
    this.watchHasReacted,
    this.onToggleReaction,
  });

  final Stream<List<Post>> posts;
  final Future<UserProfile> Function(String uid) loadProfile;
  final Stream<bool> Function(String postId)? watchHasReacted;
  final Future<void> Function(String postId)? onToggleReaction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自分の投稿')),
      body: StreamBuilder<List<Post>>(
        stream: posts,
        builder: (context, snapshot) => PostListBody(
          snapshot: snapshot,
          loadProfile: loadProfile,
          emptyMessage: 'まだ投稿がありません',
          showVisibility: true,
          watchHasReacted: watchHasReacted,
          onToggleReaction: onToggleReaction,
        ),
      ),
    );
  }
}
