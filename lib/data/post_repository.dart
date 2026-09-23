import 'package:cloud_firestore/cloud_firestore.dart';

import 'post.dart';

/// `posts/{postId}` ドキュメント(テキスト投稿)の読み書きを担当する。
class PostRepository {
  PostRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');

  /// タイムライン(「全体」)に出す投稿を新しい順に監視する。
  ///
  /// 「公開された投稿」または「自分の投稿(非公開を含む)」。他人の非公開は含まれない。
  ///
  /// セキュリティルール(非公開は本人のみ閲覧可)を満たすクエリにするため、
  /// 「isPublic == true」か「authorUid == 自分」のどちらかで必ず絞り込む(OR条件)。
  /// 並べ替えと組み合わせるので、それぞれに複合インデックスが要る
  /// (firestore.indexes.json に定義済み)。
  Stream<List<Post>> watchTimeline({required String uid, int limit = 50}) {
    return _posts
        .where(
          Filter.or(
            Filter('isPublic', isEqualTo: true),
            Filter('authorUid', isEqualTo: uid),
          ),
        )
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Post.fromDoc).toList());
  }

  /// 指定した人の公開投稿を新しい順に監視する(他の人のプロフィール用)。
  ///
  /// `isPublic == true` の絞り込みで、非公開は本人しか読めないルールを満たす。
  /// 複合インデックス (authorUid, isPublic, createdAt) が要る。
  Stream<List<Post>> watchPublicPostsBy(String uid, {int limit = 50}) {
    return _posts
        .where('authorUid', isEqualTo: uid)
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Post.fromDoc).toList());
  }

  /// 指定した人たちの公開投稿を新しい順に監視する(タイムラインの「フォロー中」用)。
  ///
  /// Firestoreの `whereIn` は一度に [maxAuthors] 人までしか指定できない。
  /// それを超えるときは、UIDの並び順で先頭の [maxAuthors] 人だけを対象にする。
  /// 複合インデックスは (authorUid, isPublic, createdAt) を使う。
  Stream<List<Post>> watchPostsByAuthors(Set<String> uids, {int limit = 50}) {
    if (uids.isEmpty) return Stream.value(const <Post>[]); // whereIn は空リスト不可

    final authors = (uids.toList()..sort()).take(maxAuthors).toList();
    return _posts
        .where('authorUid', whereIn: authors)
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Post.fromDoc).toList());
  }

  /// `whereIn` に渡せる投稿者の最大数。
  static const maxAuthors = 30;

  /// 自分の投稿を新しい順に監視する(非公開も含む。プロフィールの「自分の投稿」用)。
  ///
  /// `authorUid == 自分` の絞り込みがあるので、セキュリティルール(本人は非公開も
  /// 閲覧可)を満たす。並べ替えと組み合わせるので複合インデックスが要る。
  Stream<List<Post>> watchMyPosts(String uid, {int limit = 100}) {
    return _posts
        .where('authorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Post.fromDoc).toList());
  }

  /// 投稿を作成する。
  ///
  /// 本人にとって初めての投稿なら、`users.firstPostMonth`(月次AI振り返りの起点)に
  /// 今月の1日を記録する。投稿と同じトランザクションで行うので、
  /// 「投稿はあるのに起点が無い」状態にはならない。
  Future<void> createPost({
    required String uid,
    required String text,
    required String genreTag,
    required bool isPublic,
  }) {
    final userRef = _db.collection('users').doc(uid);
    final postRef = _posts.doc();

    return _db.runTransaction((tx) async {
      final user = await tx.get(userRef);

      tx.set(postRef, {
        'authorUid': uid,
        'text': text,
        'photoUrl': null,
        'genreTag': genreTag,
        'isPublic': isPublic,
        'reactionCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (user.data()?['firstPostMonth'] == null) {
        final now = DateTime.now();
        tx.update(userRef, {
          'firstPostMonth': Timestamp.fromDate(DateTime(now.year, now.month)),
        });
      }
    });
  }
}
