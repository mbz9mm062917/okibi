import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'data/post.dart';
import 'data/post_repository.dart';
import 'data/user_repository.dart';
import 'home_page.dart';
import 'timeline_page.dart';

/// ログイン後の土台。下のナビゲーションバーで、ホームとタイムラインを行き来する。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _posts = PostRepository();
  final _users = UserRepository();

  /// タイムラインの購読。ここで一度だけ作り、画面を切り替えても使い回す。
  late final Stream<List<Post>> _timeline = _posts.watchTimeline(
    uid: FirebaseAuth.instance.currentUser!.uid,
  );

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack なので、タブを切り替えても各画面の状態(表示中の月など)が残る。
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(users: _users),
          TimelinePage(posts: _timeline, loadProfile: _users.fetchProfile),
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
