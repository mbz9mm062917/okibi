import 'package:flutter/material.dart';

import 'data/post.dart';
import 'data/user_repository.dart';
import 'widgets/post_card.dart';
import 'widgets/profile_parts.dart';

/// 他の人のプロフィール画面。フォローボタンと、その人の公開投稿を表示する。
///
/// [isMe] が true のときは、自分のプロフィールを「他の人からの見え方」で表示する
/// (フォローボタンは出さない)。記録日数は、どちらの場合も表示しない。
///
/// データの取得・保存は外から渡す(Firebaseなしでテストできるようにするため)。
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({
    super.key,
    required this.isMe,
    required this.profile,
    required this.isFollowing,
    required this.followingCount,
    required this.followerCount,
    required this.posts,
    required this.loadProfile,
    required this.onSetFollowing,
    this.watchHasReacted,
    this.onToggleReaction,
  });

  final bool isMe;
  final Stream<UserProfile> profile;
  final Stream<bool> isFollowing;
  final Stream<int> followingCount;
  final Stream<int> followerCount;
  final Stream<List<Post>> posts;
  final Future<UserProfile> Function(String uid) loadProfile;

  /// フォローする(true)/やめる(false)。
  final Future<void> Function(bool following) onSetFollowing;

  /// 炎リアクション。渡さないときは数だけ表示される。
  final Stream<bool> Function(String postId)? watchHasReacted;
  final Future<void> Function(String postId)? onToggleReaction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール')),
      body: StreamBuilder<UserProfile>(
        stream: profile,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('読み込めませんでした\n${snapshot.error}'));
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildBody(context, data);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, UserProfile data) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ProfileHeader(
                  profile: data,
                  action: isMe
                      ? null
                      : _FollowButton(
                          isFollowing: isFollowing,
                          onSetFollowing: onSetFollowing,
                        ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CountStat(label: 'フォロー', count: followingCount),
                    CountStat(label: 'フォロワー', count: followerCount),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '公開の投稿',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<List<Post>>(
            stream: posts,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('投稿を読み込めませんでした\n${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('まだ公開された投稿がありません')),
                );
              }
              return Column(
                children: [
                  const SizedBox(height: 8),
                  for (final post in items)
                    PostCard(
                      post: post,
                      loadProfile: loadProfile,
                      watchHasReacted: watchHasReacted,
                      onToggleReaction: onToggleReaction,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 「フォローする」/「フォロー中」のボタン。
///
/// フォローをやめるときだけ確認を挟む(押し間違いで関係が切れないようにするため)。
class _FollowButton extends StatefulWidget {
  const _FollowButton({required this.isFollowing, required this.onSetFollowing});

  final Stream<bool> isFollowing;
  final Future<void> Function(bool following) onSetFollowing;

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _busy = false;

  Future<void> _set(bool following) async {
    setState(() => _busy = true);
    try {
      await widget.onSetFollowing(following);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmUnfollow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('フォローをやめますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('やめる'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _set(false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: widget.isFollowing,
      builder: (context, snapshot) {
        final following = snapshot.data;
        // 状態が分かるまで(following が null の間)と、処理中は押せない。
        final enabled = following != null && !_busy;

        if (following == true) {
          return OutlinedButton(
            onPressed: enabled ? _confirmUnfollow : null,
            child: const Text('フォロー中'),
          );
        }
        return FilledButton(
          onPressed: enabled ? () => _set(true) : null,
          child: const Text('フォローする'),
        );
      },
    );
  }
}
