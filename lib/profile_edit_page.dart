import 'package:flutter/material.dart';

import 'data/avatar_options.dart';
import 'data/genre_tags.dart';
import 'data/user_repository.dart';
import 'widgets/avatar_view.dart';

/// プロフィール編集画面で入力された内容。
class ProfileEdit {
  const ProfileEdit({
    required this.displayName,
    required this.statusMessage,
    required this.avatarIconId,
    required this.avatarColorId,
    required this.genreTags,
  });

  final String displayName;
  final String statusMessage;
  final String avatarIconId;
  final String avatarColorId;
  final List<String> genreTags;
}

/// プロフィール編集画面。保存に成功すると `true` を返して閉じる。
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final UserProfile initial;
  final Future<void> Function(ProfileEdit edit) onSave;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  static const _maxGenres = 3;

  late final TextEditingController _name =
      TextEditingController(text: widget.initial.displayName);
  late final TextEditingController _status =
      TextEditingController(text: widget.initial.statusMessage);

  // 未設定・未知のIDのときは、既定のアイコン/色から始める。
  late String _iconId = avatarIcons.any((o) => o.id == widget.initial.avatarIconId)
      ? widget.initial.avatarIconId!
      : defaultAvatarIconId;
  late String _colorId = avatarColors.any((o) => o.id == widget.initial.avatarColorId)
      ? widget.initial.avatarColorId!
      : defaultAvatarColorId;
  late final Set<String> _genres = {...widget.initial.genreTags};

  bool _saving = false;

  bool get _canSave => !_saving && _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // 名前の入力の有無で「保存」ボタンの有効/無効を切り替える。
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _status.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(
        ProfileEdit(
          displayName: _name.text.trim(),
          statusMessage: _status.text.trim(),
          avatarIconId: _iconId,
          avatarColorId: _colorId,
          genreTags: _genres.toList(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィールを編集'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              child: const Text('保存'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: IconAvatar(iconId: _iconId, colorId: _colorId, radius: 40)),
            const SizedBox(height: 16),
            Text('アイコン', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in avatarIcons)
                  Tooltip(
                    message: option.label,
                    child: InkResponse(
                      onTap: () => setState(() => _iconId = option.id),
                      radius: 28,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _iconId == option.id
                                ? scheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(option.icon, color: avatarColorFor(_colorId)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('カラー', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in avatarColors)
                  Tooltip(
                    message: option.label,
                    child: InkResponse(
                      onTap: () => setState(() => _colorId = option.id),
                      radius: 24,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: option.color,
                        child: _colorId == option.id
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: 'ニックネーム',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _status,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '一言ステータス(任意)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('ジャンル(3つまで)', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final tag in postGenreTags)
                  FilterChip(
                    label: Text(tag),
                    selected: _genres.contains(tag),
                    // 3つ選んだら、選んでいないチップは押せなくする。
                    onSelected: _genres.contains(tag) || _genres.length < _maxGenres
                        ? (selected) => setState(() {
                              selected ? _genres.add(tag) : _genres.remove(tag);
                            })
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
