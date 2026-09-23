import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'data/follow_repository.dart';
import 'data/post_repository.dart';
import 'data/reaction_repository.dart';
import 'data/stamp_repository.dart';
import 'data/user_repository.dart';
import 'post_compose_page.dart';
import 'profile_edit_page.dart';
import 'profile_page.dart';
import 'widgets/avatar_view.dart';
import 'widgets/month_calendar.dart';
import 'widgets/stamp_note_sheet.dart';

/// ホーム画面。月間カレンダーと、今日を記録する縦長ボタンを表示する。
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.users, required this.follows});

  /// タイムラインと共有するので外から受け取る(プロフィールのキャッシュを共通にするため)。
  final UserRepository users;

  /// プロフィール画面のフォロー数・フォロワー数の表示に使う。
  final FollowRepository follows;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  UserRepository get _users => widget.users;
  final _stamps = StampRepository();
  final _posts = PostRepository();
  final _reactions = ReactionRepository();

  late final User _user = FirebaseAuth.instance.currentUser!;
  late final DateTime _today = DateTime.now();

  /// プロフィール(users/{uid})が無ければ作成する。完了するまで本体は表示しない。
  late final Future<void> _ready = _users.ensureUserDocument(_user);

  /// 右上のアバター表示用。プロフィールを編集するとここにも反映される。
  late final Stream<UserProfile> _myProfile = _users.watchProfile(_user.uid);

  late DateTime _month = DateTime(_today.year, _today.month);
  late Stream<Set<String>> _monthStream = _stamps.watchMonth(_user.uid, _month);
  late final Stream<bool> _todayStream = _stamps.watchStamped(_user.uid, _today);

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _monthStream = _stamps.watchMonth(_user.uid, _month);
    });
  }

  /// [action] を実行し、失敗したらスナックバーで知らせる。成功したら true。
  Future<bool> _guard(Future<void> Function() action, String failMessage) async {
    try {
      await action();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$failMessage: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _onDayTap(DateTime date, {required bool isStamped}) {
    return isStamped ? _editStamp(date) : _addStamp(date);
  }

  /// 記録を付け、そのあと「一言添える?」を促す。
  ///
  /// 先に記録を保存するので、促しを「あとで」で閉じても記録は残る。
  Future<void> _addStamp(DateTime date) async {
    final saved = await _guard(
      () => _stamps.setStamped(uid: _user.uid, date: date, stamped: true),
      '記録の保存に失敗しました',
    );
    if (!saved || !mounted) return;

    final result = await showStampNoteSheet(
      context,
      title: '一言添える?',
      isEditing: false,
    );
    if (result == null || result.action != StampSheetAction.save) return;

    await _guard(
      () => _stamps.setNote(uid: _user.uid, date: date, note: result.note),
      '一言の保存に失敗しました',
    );
  }

  /// 記録済みの日の一言の確認・編集、または記録の取り消し。
  Future<void> _editStamp(DateTime date) async {
    String? note;
    final loaded = await _guard(
      () async => note = await _stamps.fetchNote(_user.uid, date),
      '一言の読み込みに失敗しました',
    );
    if (!loaded || !mounted) return;

    final result = await showStampNoteSheet(
      context,
      title: '${date.month}月${date.day}日の記録',
      isEditing: true,
      initialNote: note ?? '',
    );
    if (result == null) return;

    switch (result.action) {
      case StampSheetAction.save:
        await _guard(
          () => _stamps.setNote(uid: _user.uid, date: date, note: result.note),
          '一言の保存に失敗しました',
        );
      case StampSheetAction.cancelStamp:
        await _guard(
          () => _stamps.setStamped(uid: _user.uid, date: date, stamped: false),
          '記録の取り消しに失敗しました',
        );
    }
  }

  Future<void> _openCompose() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PostComposePage(
          onSubmit: ({required text, required genreTag, required isPublic}) =>
              _posts.createPost(
                uid: _user.uid,
                text: text,
                genreTag: genreTag,
                isPublic: isPublic,
              ),
        ),
      ),
    );
    if (posted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿しました')),
      );
    }
  }

  Future<void> _signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          profile: _users.watchProfile(_user.uid),
          followingCount: widget.follows
              .watchFollowingUids(_user.uid)
              .map((uids) => uids.length),
          followerCount: widget.follows.watchFollowerCount(_user.uid),
          watchMyPosts: () => _posts.watchMyPosts(_user.uid),
          loadProfile: _users.fetchProfile,
          watchHasReacted: (postId) =>
              _reactions.watchHasReacted(postId: postId, uid: _user.uid),
          onToggleReaction: (postId) =>
              _reactions.toggleReaction(postId: postId, uid: _user.uid),
          onSaveProfile: (ProfileEdit edit) => _users.updateProfile(
            _user.uid,
            displayName: edit.displayName,
            statusMessage: edit.statusMessage,
            avatarIconId: edit.avatarIconId,
            avatarColorId: edit.avatarColorId,
            genreTags: edit.genreTags,
          ),
          onSignOut: _signOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OKIBI'),
        actions: [
          StreamBuilder<UserProfile>(
            stream: _myProfile,
            builder: (context, snapshot) => IconButton(
              icon: AvatarView(profile: snapshot.data, radius: 14),
              tooltip: 'プロフィール',
              onPressed: _openProfile,
            ),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('プロフィールの準備に失敗しました\n${snapshot.error}'),
              ),
            );
          }
          return _buildBody();
        },
      ),
      // 仮の入口。ホームのレイアウトを作り直すときに位置を決め直す。
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCompose,
        icon: const Icon(Icons.edit),
        label: const Text('投稿する'),
      ),
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 右の記録ボタンをカレンダーと同じ高さにするため IntrinsicHeight を使う。
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: StreamBuilder<Set<String>>(
                      stream: _monthStream,
                      builder: (context, snapshot) {
                        final stamped = snapshot.data ?? const <String>{};
                        return MonthCalendar(
                          month: _month,
                          stampedDates: stamped,
                          today: _today,
                          onDayTap: (date) => _onDayTap(
                            date,
                            isStamped: stamped.contains(dateKey(date)),
                          ),
                          onPrevMonth: () => _changeMonth(-1),
                          onNextMonth: () => _changeMonth(1),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 72, child: _buildRecordButton()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '日付をタップして記録します。記録済みの日は、一言の編集や取り消しができます',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return StreamBuilder<bool>(
      stream: _todayStream,
      builder: (context, snapshot) {
        final recorded = snapshot.data ?? false;
        return FilledButton(
          onPressed: recorded ? null : () => _addStamp(_today),
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(recorded ? Icons.check : Icons.local_fire_department),
              const SizedBox(height: 8),
              Text(recorded ? '記録済み' : '記録する'),
            ],
          ),
        );
      },
    );
  }
}
