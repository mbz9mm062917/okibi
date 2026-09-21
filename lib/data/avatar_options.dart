import 'package:flutter/material.dart';

/// アバターに選べるアイコン。
class AvatarIconOption {
  const AvatarIconOption(this.id, this.icon, this.label);

  final String id;
  final IconData icon;
  final String label;
}

/// アバターに選べる色。
class AvatarColorOption {
  const AvatarColorOption(this.id, this.color, this.label);

  final String id;
  final Color color;
  final String label;
}

/// 12種のアイコン × 8色 = 96通り。写真なしでも被りにくくするための組み合わせ。
const avatarIcons = [
  AvatarIconOption('fire', Icons.local_fire_department, '火'),
  AvatarIconOption('dumbbell', Icons.fitness_center, 'ダンベル'),
  AvatarIconOption('run', Icons.directions_run, 'ラン'),
  AvatarIconOption('book', Icons.menu_book, '本'),
  AvatarIconOption('pen', Icons.edit, 'ペン'),
  AvatarIconOption('code', Icons.code, 'コード'),
  AvatarIconOption('coffee', Icons.coffee, 'コーヒー'),
  AvatarIconOption('music', Icons.music_note, '音楽'),
  AvatarIconOption('leaf', Icons.eco, '葉'),
  AvatarIconOption('moon', Icons.nightlight, '月'),
  AvatarIconOption('sun', Icons.wb_sunny, '太陽'),
  AvatarIconOption('star', Icons.star, '星'),
];

const avatarColors = [
  AvatarColorOption('navy', Color(0xFF232838), 'ネイビー'),
  AvatarColorOption('ember', Color(0xFFE8833A), 'オレンジ'),
  AvatarColorOption('moss', Color(0xFF6B8E6B), 'モスグリーン'),
  AvatarColorOption('sky', Color(0xFF6C8EBF), 'そら'),
  AvatarColorOption('plum', Color(0xFF8E6C9E), 'すみれ'),
  AvatarColorOption('rose', Color(0xFFC9748A), 'ばら'),
  AvatarColorOption('sand', Color(0xFFC8A96A), 'すな'),
  AvatarColorOption('slate', Color(0xFF7A8794), 'スレート'),
];

const defaultAvatarIconId = 'fire';
const defaultAvatarColorId = 'navy';

/// IDからアイコンを引く。未設定・未知のID(以前の 'default' など)は人型アイコンにする。
IconData avatarIconFor(String? id) =>
    avatarIcons.where((o) => o.id == id).firstOrNull?.icon ?? Icons.person;

/// IDから色を引く。未設定・未知のIDはネイビー。
Color avatarColorFor(String? id) =>
    avatarColors.where((o) => o.id == id).firstOrNull?.color ??
    avatarColors.first.color;
