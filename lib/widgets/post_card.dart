import 'package:flutter/material.dart';

import '../data/post.dart';
import '../data/user_repository.dart';
import 'avatar_view.dart';

/// 投稿の時刻を表示用に整える。今日の投稿は「19:30」、それ以外は「9/21 19:30」。
String formatPostTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final hm = '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
  final isToday = time.year == current.year &&
      time.month == current.month &&
      time.day == current.day;
  return isToday ? hm : '${time.month}/${time.day} $hm';
}

/// 投稿1件分のカード。[showVisibility] が true のとき、非公開の投稿に「非公開」と添える。
/// [onAuthorTap] を渡すと、投稿者のアイコンと名前がタップできて、その人のUIDが渡される。
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.loadProfile,
    this.showVisibility = false,
    this.onAuthorTap,
  });

  final Post post;
  final Future<UserProfile> Function(String uid) loadProfile;
  final bool showVisibility;
  final void Function(String uid)? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FutureBuilder<UserProfile>(
                  future: loadProfile(post.authorUid),
                  builder: (context, snapshot) {
                    // 読み込み中・失敗時は名前を「…」にして、投稿の表示は止めない。
                    final author = Row(
                      children: [
                        AvatarView(profile: snapshot.data, radius: 16),
                        const SizedBox(width: 8),
                        Text(
                          snapshot.data?.displayName ?? '…',
                          style: textTheme.titleSmall,
                        ),
                      ],
                    );
                    final onTap = onAuthorTap;
                    if (onTap == null) return author;
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onTap(post.authorUid),
                      child: author,
                    );
                  },
                ),
                const Spacer(),
                if (showVisibility && !post.isPublic) ...[
                  Icon(Icons.lock_outline, size: 14, color: muted),
                  const SizedBox(width: 2),
                  Text('非公開', style: textTheme.bodySmall?.copyWith(color: muted)),
                  const SizedBox(width: 8),
                ],
                Text(
                  formatPostTime(post.createdAt),
                  style: textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.text),
            if (post.genreTag.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '#${post.genreTag}',
                style: textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 投稿の一覧。読み込み中・失敗・0件・一覧の4つの状態を出し分ける。
class PostListBody extends StatelessWidget {
  const PostListBody({
    super.key,
    required this.snapshot,
    required this.loadProfile,
    required this.emptyMessage,
    this.showVisibility = false,
    this.onAuthorTap,
  });

  final AsyncSnapshot<List<Post>> snapshot;
  final Future<UserProfile> Function(String uid) loadProfile;
  final String emptyMessage;
  final bool showVisibility;
  final void Function(String uid)? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('読み込めませんでした\n${snapshot.error}'),
        ),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = snapshot.data!;
    if (items.isEmpty) {
      return Center(child: Text(emptyMessage));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) => PostCard(
        post: items[index],
        loadProfile: loadProfile,
        showVisibility: showVisibility,
        onAuthorTap: onAuthorTap,
      ),
    );
  }
}
