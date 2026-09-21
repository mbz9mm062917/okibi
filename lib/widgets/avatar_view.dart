import 'package:flutter/material.dart';

import '../data/avatar_options.dart';
import '../data/user_repository.dart';

/// 選んだアイコンと色で描く丸いアバター。編集画面のプレビューにも使う。
class IconAvatar extends StatelessWidget {
  const IconAvatar({
    super.key,
    this.iconId,
    this.colorId,
    this.radius = 16,
  });

  final String? iconId;
  final String? colorId;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: avatarColorFor(colorId),
      child: Icon(avatarIconFor(iconId), color: Colors.white, size: radius * 1.1),
    );
  }
}

/// プロフィールから作るアバター。[profile] が null(読み込み中)のときは仮の表示にする。
class AvatarView extends StatelessWidget {
  const AvatarView({super.key, this.profile, this.radius = 16});

  final UserProfile? profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
      );
    }
    final photoUrl = p.avatarPhotoUrl;
    if (p.avatarType == 'photo' && photoUrl != null) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(photoUrl));
    }
    return IconAvatar(
      iconId: p.avatarIconId,
      colorId: p.avatarColorId,
      radius: radius,
    );
  }
}
