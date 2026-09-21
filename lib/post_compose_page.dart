import 'package:flutter/material.dart';

import 'data/genre_tags.dart';

/// 投稿を保存する処理。画面から切り離しておくことで、Firebaseなしでテストできる。
typedef PostSubmit = Future<void> Function({
  required String text,
  required String genreTag,
  required bool isPublic,
});

/// 投稿作成画面。保存に成功すると `true` を返して閉じる。
class PostComposePage extends StatefulWidget {
  const PostComposePage({super.key, required this.onSubmit});

  final PostSubmit onSubmit;

  @override
  State<PostComposePage> createState() => _PostComposePageState();
}

class _PostComposePageState extends State<PostComposePage> {
  final _controller = TextEditingController();
  String _genreTag = defaultGenreTag;
  bool _isPublic = true;
  bool _submitting = false;

  bool get _canSubmit => !_submitting && _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // 入力の有無で「投稿」ボタンの有効/無効を切り替えるため、変更のたびに再描画する。
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        text: _controller.text.trim(),
        genreTag: _genreTag,
        isPublic: _isPublic,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('投稿を書く'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _canSubmit ? _submit : null,
              child: const Text('投稿'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _controller,
              minLines: 6,
              maxLines: 12,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'いまの気持ちや、ふり返りを書いてみよう',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('ジャンル', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final tag in postGenreTags)
                  ChoiceChip(
                    label: Text(tag),
                    selected: _genreTag == tag,
                    onSelected: (_) => setState(() => _genreTag = tag),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('公開する'),
              subtitle: const Text('オフにすると、自分だけに表示されます'),
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
            ),
          ],
        ),
      ),
    );
  }
}
