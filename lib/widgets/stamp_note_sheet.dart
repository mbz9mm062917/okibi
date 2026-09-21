import 'package:flutter/material.dart';

enum StampSheetAction { save, cancelStamp }

/// シートを閉じたときの結果。「あとで」やシート外タップで閉じた場合は null が返る。
class StampSheetResult {
  const StampSheetResult(this.action, [this.note = '']);

  final StampSheetAction action;
  final String note;
}

/// スタンプに一言を添える(または記録済みの日を編集する)ためのシートを表示する。
///
/// [isEditing] が false のときは記録した直後の「一言添える?」の促し、
/// true のときは記録済みの日をタップしたときの編集用で、「記録を取り消す」が出る。
/// 取り消しをシートの中に置くのは、日付を誤タップしただけで記録が消えないようにするため。
Future<StampSheetResult?> showStampNoteSheet(
  BuildContext context, {
  required String title,
  required bool isEditing,
  String initialNote = '',
}) {
  return showModalBottomSheet<StampSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _StampNoteSheet(
      title: title,
      isEditing: isEditing,
      initialNote: initialNote,
    ),
  );
}

class _StampNoteSheet extends StatefulWidget {
  const _StampNoteSheet({
    required this.title,
    required this.isEditing,
    required this.initialNote,
  });

  final String title;
  final bool isEditing;
  final String initialNote;

  @override
  State<_StampNoteSheet> createState() => _StampNoteSheetState();
}

class _StampNoteSheetState extends State<_StampNoteSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialNote);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      StampSheetResult(StampSheetAction.save, _controller.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      // キーボードが出てもボタンが隠れないよう、その分だけ下に余白を足す。
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLength: 140,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'ひとことどうぞ(任意)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.isEditing)
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    const StampSheetResult(StampSheetAction.cancelStamp),
                  ),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  child: const Text('記録を取り消す'),
                ),
              const Spacer(),
              if (!widget.isEditing)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('あとで'),
                ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: const Text('保存')),
            ],
          ),
        ],
      ),
    );
  }
}
