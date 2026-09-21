import 'package:cloud_firestore/cloud_firestore.dart';

/// `posts/{postId}` の1件分。
class Post {
  const Post({
    required this.id,
    required this.authorUid,
    required this.text,
    required this.genreTag,
    required this.isPublic,
    required this.reactionCount,
    required this.createdAt,
  });

  final String id;
  final String authorUid;
  final String text;
  final String genreTag;
  final bool isPublic;
  final int reactionCount;
  final DateTime createdAt;

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Post(
      id: doc.id,
      authorUid: data['authorUid'] as String,
      text: data['text'] as String,
      genreTag: (data['genreTag'] as String?) ?? '',
      isPublic: (data['isPublic'] as bool?) ?? true,
      reactionCount: (data['reactionCount'] as num?)?.toInt() ?? 0,
      // 書き込み直後はサーバー時刻がまだ確定せず null になるので、現在時刻で代用する。
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
