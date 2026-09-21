import 'package:flutter/material.dart';

import 'data/post.dart';
import 'data/user_repository.dart';
import 'my_posts_page.dart';
import 'profile_edit_page.dart';
import 'widgets/avatar_view.dart';

/// 自分のプロフィール画面。
///
/// データの取得・保存は外から渡す(Firebaseなしでテストできるようにするため)。
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.watchMyPosts,
    required this.loadProfile,
    required this.onSaveProfile,
    required this.onSignOut,
  });

  final Stream<UserProfile> profile;

  /// 「自分の投稿」を開くたびに新しい購読を作る。
  final Stream<List<Post>> Function() watchMyPosts;
  final Future<UserProfile> Function(String uid) loadProfile;
  final Future<void> Function(ProfileEdit edit) onSaveProfile;
  final Future<void> Function() onSignOut;

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
        padding: const EdgeInsets.all(16),
        children: [
          _Header(profile: data, onEdit: () => _openEdit(context, data)),
          const SizedBox(height: 16),
          _Stats(recordDayCount: data.recordDayCount),
          const SizedBox(height: 16),
          _MenuCard(
            icon: Icons.article_outlined,
            title: '自分の投稿',
            subtitle: '非公開の投稿も含めて見られます',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MyPostsPage(
                  posts: watchMyPosts(),
                  loadProfile: loadProfile,
                ),
              ),
            ),
          ),
          _MenuCard(
            icon: Icons.calendar_month_outlined,
            title: '自分のカレンダー',
            subtitle: 'ホームに戻ります',
            onTap: () => Navigator.of(context).pop(),
          ),
          const _MenuCard(
            icon: Icons.auto_stories_outlined,
            title: '月の振り返り',
            subtitle: '準備中',
          ),
          const _MenuCard(
            icon: Icons.groups_outlined,
            title: 'グループ',
            subtitle: '準備中',
          ),
          const _MenuCard(
            icon: Icons.lock_outline,
            title: '公開範囲の設定',
            subtitle: '準備中',
          ),
          _MenuCard(
            icon: Icons.logout,
            title: 'ログアウト',
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }

  /// 押し間違いでログアウトしないよう、確認してから実行する。
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ログアウトしますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // この画面はログイン画面の上に重なっているので、先に閉じてからログアウトする。
    Navigator.of(context).popUntil((route) => route.isFirst);
    await onSignOut();
  }

  Future<void> _openEdit(BuildContext context, UserProfile current) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProfileEditPage(initial: current, onSave: onSaveProfile),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィールを更新しました')),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.onEdit});

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Column(
      children: [
        AvatarView(profile: profile, radius: 40),
        const SizedBox(height: 12),
        Text(profile.displayName, style: textTheme.titleLarge),
        if (profile.statusMessage.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            profile.statusMessage,
            style: textTheme.bodyMedium?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
        ],
        if (profile.genreTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final tag in profile.genreTags)
                Text('#$tag', style: textTheme.bodySmall?.copyWith(color: muted)),
            ],
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onEdit, child: const Text('プロフィールを編集')),
      ],
    );
  }
}

/// フォロー/フォロワー数(準備中)と記録日数。記録日数は本人にだけ表示する。
class _Stats extends StatelessWidget {
  const _Stats({required this.recordDayCount});

  final int recordDayCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    Widget stat(String label, String value, {String? note}) {
      return Expanded(
        child: Column(
          children: [
            Text(value, style: textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(label, style: textTheme.bodySmall?.copyWith(color: muted)),
            if (note != null)
              Text(note, style: textTheme.labelSmall?.copyWith(color: muted)),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stat('フォロー', '—'),
        stat('フォロワー', '—'),
        stat('記録日数', '$recordDayCount日', note: 'あなただけに表示'),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// null のときは押せない(準備中)メニューとして、グレーで表示される。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }
}
