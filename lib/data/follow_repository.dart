import 'package:cloud_firestore/cloud_firestore.dart';

/// `follows/{followerUid_followeeUid}` ドキュメント(フォロー関係)の読み書きを担当する。
class FollowRepository {
  FollowRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _follows =>
      _db.collection('follows');

  /// [uid] がフォローしている人のUIDの集合を監視する。
  Stream<Set<String>> watchFollowingUids(String uid) {
    return _follows
        .where('followerUid', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()['followeeUid'] as String).toSet());
  }

  /// [uid] のフォロワー数を監視する。
  Stream<int> watchFollowerCount(String uid) {
    return _follows
        .where('followeeUid', isEqualTo: uid)
        .snapshots()
        .map((s) => s.size);
  }

  /// [me] が [other] をフォローしているかを監視する。
  Stream<bool> watchIsFollowing(String me, String other) {
    return _follows.doc('${me}_$other').snapshots().map((s) => s.exists);
  }

  /// フォローする/やめる。自分自身はフォローできない。
  ///
  /// トランザクションで現在の状態を確認するので、二重に押しても問題ない。
  /// (フォローしていない相手の削除は、セキュリティルールで拒否されてしまうため)
  Future<void> setFollowing({
    required String me,
    required String other,
    required bool following,
  }) {
    if (me == other) {
      throw ArgumentError('自分自身はフォローできません');
    }
    final ref = _follows.doc('${me}_$other');

    return _db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists == following) return; // すでに望む状態

      if (following) {
        tx.set(ref, {
          'followerUid': me,
          'followeeUid': other,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.delete(ref);
      }
    });
  }
}
