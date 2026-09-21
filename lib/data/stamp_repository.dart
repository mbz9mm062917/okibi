import 'package:cloud_firestore/cloud_firestore.dart';

/// `DateTime` を stamps のキーに使う "YYYY-MM-DD" 形式に変換する。
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `stamps/{uid_date}` ドキュメント(カレンダーのワンタップスタンプ)の読み書きを担当する。
class StampRepository {
  StampRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _stamps =>
      _db.collection('stamps');

  /// 指定した月にスタンプを押した日付("YYYY-MM-DD")の集合を監視する。
  ///
  /// ドキュメントIDが `uid_YYYY-MM-DD` なので、IDの範囲指定で1か月分を絞り込む。
  /// (uid == と date の範囲指定を組み合わせると複合インデックスが必要になるが、
  ///  ID範囲だけならインデックス不要で済む)
  Stream<Set<String>> watchMonth(String uid, DateTime month) {
    final ym = dateKey(DateTime(month.year, month.month)).substring(0, 7);
    return _stamps
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${uid}_$ym-01')
        .where(FieldPath.documentId, isLessThanOrEqualTo: '${uid}_$ym-31')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()['date'] as String).toSet());
  }

  /// 指定した日にスタンプが押されているかを監視する。
  Stream<bool> watchStamped(String uid, DateTime date) {
    return _stamps
        .doc('${uid}_${dateKey(date)}')
        .snapshots()
        .map((s) => s.exists);
  }

  /// スタンプに添えた一言を取得する。無ければ null。
  Future<String?> fetchNote(String uid, DateTime date) async {
    final snapshot = await _stamps.doc('${uid}_${dateKey(date)}').get();
    return snapshot.data()?['note'] as String?;
  }

  /// スタンプに一言を保存する。空文字(空白のみ含む)の場合は `note` を削除する。
  ///
  /// スタンプが存在しない日に呼ぶと失敗する(update のため)。
  Future<void> setNote({
    required String uid,
    required DateTime date,
    required String note,
  }) {
    final trimmed = note.trim();
    return _stamps.doc('${uid}_${dateKey(date)}').update({
      'note': trimmed.isEmpty ? FieldValue.delete() : trimmed,
    });
  }

  /// スタンプを押す/取り消す。`users.recordDayCount` も同時に増減させる。
  ///
  /// トランザクションで現在の状態を確認するため、二重タップしても
  /// 記録日数が二重に増減しない。
  Future<void> setStamped({
    required String uid,
    required DateTime date,
    required bool stamped,
  }) {
    final key = dateKey(date);
    final stampRef = _stamps.doc('${uid}_$key');
    final userRef = _db.collection('users').doc(uid);

    return _db.runTransaction((tx) async {
      final existing = await tx.get(stampRef);
      if (existing.exists == stamped) return; // すでに望む状態

      if (stamped) {
        tx.set(stampRef, {
          'uid': uid,
          'date': key,
          'templateId': 'default',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.delete(stampRef);
      }
      tx.update(userRef, {'recordDayCount': FieldValue.increment(stamped ? 1 : -1)});
    });
  }
}
