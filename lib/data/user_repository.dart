import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'avatar_options.dart';

/// `users/{uid}` の中身のうち、画面に表示・編集する項目。
class UserProfile {
  const UserProfile({
    required this.displayName,
    this.avatarType = 'icon',
    this.avatarIconId,
    this.avatarColorId,
    this.avatarPhotoUrl,
    this.statusMessage = '',
    this.genreTags = const [],
    this.recordDayCount = 0,
  });

  /// Firestoreのデータから作る。ドキュメントが無い・項目が欠けている場合は既定値で補う。
  factory UserProfile.fromData(Map<String, dynamic>? data) {
    return UserProfile(
      displayName: (data?['displayName'] as String?) ?? 'ユーザー',
      avatarType: (data?['avatarType'] as String?) ?? 'icon',
      avatarIconId: data?['avatarIconId'] as String?,
      avatarColorId: data?['avatarColorId'] as String?,
      avatarPhotoUrl: data?['avatarPhotoUrl'] as String?,
      statusMessage: (data?['statusMessage'] as String?) ?? '',
      genreTags: List<String>.from((data?['genreTags'] as List?) ?? const []),
      recordDayCount: (data?['recordDayCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String displayName;

  /// "icon" | "photo"。写真アバターはFirebase Storageが使えるようになってから対応する。
  final String avatarType;
  final String? avatarIconId;
  final String? avatarColorId;
  final String? avatarPhotoUrl;
  final String statusMessage;
  final List<String> genreTags;

  /// 記録日数。本人にだけ表示する。
  final int recordDayCount;
}

/// `users/{uid}` ドキュメントの読み書きを担当する。
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _users = (firestore ?? FirebaseFirestore.instance).collection('users');

  final CollectionReference<Map<String, dynamic>> _users;

  /// 取得済みのプロフィール。タイムラインで同じ人が何度も出ても読み込みは1回で済ませる。
  final Map<String, Future<UserProfile>> _profiles = {};

  /// 指定したユーザーのプロフィールを取得する。ドキュメントが無ければ仮の名前を返す。
  Future<UserProfile> fetchProfile(String uid) {
    return _profiles.putIfAbsent(uid, () async {
      try {
        return UserProfile.fromData((await _users.doc(uid).get()).data());
      } catch (_) {
        _profiles.remove(uid); // 失敗した結果は覚えず、次回また取りに行く
        rethrow;
      }
    });
  }

  /// 指定したユーザーのプロフィールを監視する(自分のプロフィール画面用)。
  Stream<UserProfile> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((s) => UserProfile.fromData(s.data()));
  }

  /// 初回ログイン時にプロフィールを作成する。すでに存在する場合は何もしない。
  Future<void> ensureUserDocument(User user) async {
    final ref = _users.doc(user.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) return;

    await ref.set({
      'displayName': user.displayName ?? 'ユーザー',
      'avatarType': 'icon',
      'avatarIconId': defaultAvatarIconId,
      'avatarColorId': defaultAvatarColorId,
      'avatarPhotoUrl': null,
      'statusMessage': '',
      'genreTags': <String>[],
      'visibility': 'public',
      'firstPostMonth': null,
      'recordDayCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// プロフィールを更新する。写真アバターは未対応なので、アイコン方式で保存する。
  Future<void> updateProfile(
    String uid, {
    required String displayName,
    required String statusMessage,
    required String avatarIconId,
    required String avatarColorId,
    required List<String> genreTags,
  }) async {
    await _users.doc(uid).update({
      'displayName': displayName,
      'statusMessage': statusMessage,
      'avatarType': 'icon',
      'avatarIconId': avatarIconId,
      'avatarColorId': avatarColorId,
      'genreTags': genreTags,
    });
    // 名前やアイコンが変わったので、タイムライン用のキャッシュを捨てて次回取り直す。
    _profiles.remove(uid);
  }
}
