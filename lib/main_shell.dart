import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'data/follow_repository.dart';
import 'data/post.dart';
import 'data/post_repository.dart';
import 'data/reaction_repository.dart';
import 'data/user_repository.dart';
import 'home_page.dart';
import 'timeline_page.dart';
import 'user_profile_page.dart';
import 'utils/stream_utils.dart';

/// ログイン後の土台。下のナビゲーションバーで、ホームとタイムラインを行き来する。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _posts = PostRepository();
  final _users = UserRepository();
  final _follows = FollowRepository();
  final _reactions = ReactionRepository();

  late final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  /// タイムライン「全体」の購読。ここで一度だけ作り、画面を切り替えても使い回す。
  late final Stream<List<Post>> _timeline = _posts.watchTimeline(uid: _myUid);

  /// タイムライン「フォロー中」の購読。フォローしている人が増減するたびに、
  /// その人たちの投稿を取り直す。
  late final Stream<List<Post>> _followingTimeline = switchMap(
    _follows.watchFollowingUids(_myUid),
    _posts.watchPostsByAuthors,
  );

  int _index = 0;

  /// 他の人(または自分)のプロフィールを開く。
  void _openUserProfile(String uid) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          isMe: uid == _myUid,
          profile: _users.watchProfile(uid),
          isFollowing: _follows.watchIsFollowing(_myUid, uid),
          followingCount:
              _follows.watchFollowingUids(uid).map((uids) => uids.length),
          followerCount: _follows.watchFollowerCount(uid),
          posts: _posts.watchPublicPostsBy(uid),
          loadProfile: _users.fetchProfile,
          onSetFollowing: (following) => _follows.setFollowing(
            me: _myUid,
            other: uid,
            following: following,
          ),
          watchHasReacted: (postId) =>
              _reactions.watchHasReacted(postId: postId, uid: _myUid),
          onToggleReaction: (postId) =>
              _reactions.toggleReaction(postId: postId, uid: _myUid),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack なので、タブを切り替えても各画面の状態(表示中の月など)が残る。
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(users: _users, follows: _follows),
          TimelinePage(
            posts: _timeline,
            followingPosts: _followingTimeline,
            loadProfile: _users.fetchProfile,
            onOpenProfile: _openUserProfile,
            watchHasReacted: (postId) =>
                _reactions.watchHasReacted(postId: postId, uid: _myUid),
            onToggleReaction: (postId) =>
                _reactions.toggleReaction(postId: postId, uid: _myUid),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_agenda_outlined),
            selectedIcon: Icon(Icons.view_agenda),
            label: 'タイムライン',
          ),
        ],
      ),
    );
  }
}
