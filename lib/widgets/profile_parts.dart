import 'package:flutter/material.dart';

import '../data/user_repository.dart';
import 'avatar_view.dart';

/// プロフィールの上部。アバター・名前・一言・ジャンルを縦に並べる。
/// [action] には、編集ボタンやフォローボタンなど、その画面ごとのボタンを渡す。
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.profile, this.action});

  final UserProfile profile;
  final Widget? action;

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
        if (action != null) ...[
          const SizedBox(height: 12),
          action!,
        ],
      ],
    );
  }
}

/// フォロー数などの数字1つ分。数字は控えめなトーンで見せる。Row の中で使う。
class ProfileStat extends StatelessWidget {
  const ProfileStat({
    super.key,
    required this.label,
    required this.value,
    this.note,
  });

  final String label;
  final String value;

  /// 数字の下に添える小さな注記(例:「あなただけに表示」)。
  final String? note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Expanded(
      child: Column(
        children: [
          Text(value, style: textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(label, style: textTheme.bodySmall?.copyWith(color: muted)),
          if (note != null)
            Text(note!, style: textTheme.labelSmall?.copyWith(color: muted)),
        ],
      ),
    );
  }
}

/// 数を表示用の文字にする。読み込み中(null)は「—」。
String countText(int? count) => count == null ? '—' : '$count';

/// フォロー数・フォロワー数のように、ストリームで届く数を [ProfileStat] で表示する。
/// 読み込み中(まだ値が無い)間は「—」を出す。Row の中で使う。
class CountStat extends StatelessWidget {
  const CountStat({super.key, required this.label, required this.count});

  final String label;
  final Stream<int> count;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: count,
      builder: (context, snapshot) =>
          ProfileStat(label: label, value: countText(snapshot.data)),
    );
  }
}
