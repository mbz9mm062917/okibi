import 'package:cloud_firestore/cloud_firestore.dart';

/// `reactions/{postId}_{uid}` (炎リアクション) の読み書きを担当する。
///
/// 「反応した/していない」は reactions ドキュメントの有無で判定する(1人1投稿につき1件)。
/// 投稿側の `reactionCount` はこのドキュメントの増減に合わせてトランザクションで
/// ±1 する。表示のたびに数え上げるより速く、リアルタイムに更新できるため。
class ReactionRepository {
  ReactionRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _reactionDoc(String postId, String uid) =>
      _db.collection('reactions').doc('${postId}_$uid');

  /// 自分がこの投稿に反応しているかどうかを監視する。
  Stream<bool> watchHasReacted({required String postId, required String uid}) {
    return _reactionDoc(postId, uid).snapshots().map((doc) => doc.exists);
  }

  /// 炎リアクションを付ける/外す(今の状態を見て自動で切り替える)。
  ///
  /// reactions ドキュメントの作成・削除と、投稿の `reactionCount` の増減を
  /// 同じトランザクションで行うので、二重タップしても数がずれない。
  Future<void> toggleReaction({required String postId, required String uid}) {
    final reactionRef = _reactionDoc(postId, uid);
    final postRef = _db.collection('posts').doc(postId);

    return _db.runTransaction((tx) async {
      final reaction = await tx.get(reactionRef);
      final post = await tx.get(postRef);
      final current = (post.data()?['reactionCount'] as num?)?.toInt() ?? 0;

      if (reaction.exists) {
        tx.delete(reactionRef);
        tx.update(postRef, {'reactionCount': current - 1});
      } else {
        tx.set(reactionRef, {
          'postId': postId,
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {'reactionCount': current + 1});
      }
    });
  }
}
