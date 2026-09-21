# OKIBI

> 静かに燃えてる人たちの、進捗ノート

「意識高い/低い」を分けずに、淡々と続けている人たちが、緩やかに視界に入り合うためのモバイルアプリです。
目的は「継続させること」ではなく、**ベクトルは違えど同じ志を持つ人同士が、お互いを見つけられること**。
そのために、**ランキングや比較の演出を作らない**ことを最も大切な設計原則にしています。

個人開発のアプリで、Flutter(Dart)は今回が初めての経験です。学習しながら、設計 → 実装 → テストまでを一人で進めています。

## 機能

| | 機能 | 内容 |
|---|---|---|
| ✅ | Googleログイン | Firebase Authentication。ログイン状態でホーム/ログイン画面を出し分け |
| ✅ | ホーム(カレンダー) | 月間カレンダーでワンタップ記録。記録した日はグレー塗り、今日はネイビーの枠 |
| ✅ | 記録に一言を添える | 記録の直後に「一言添える?」と軽く促す。後から編集・取り消しもできる |
| ✅ | テキスト投稿 | ジャンルタグ、公開/非公開の切り替え |
| ✅ | タイムライン | 公開投稿と自分の投稿(非公開含む)を新しい順に表示 |
| ✅ | プロフィール | アイコン12種 × 色8色、名前、一言、ジャンル、記録日数(本人のみ表示)、自分の投稿 |
| 🚧 | フォロー | 他の人のプロフィール、フォロー中タブ |
| 🚧 | リアクション | 「いいね」の代わりの炎ボタン |
| 🚧 | 月次AI振り返り | 月に一度、AIが振り返りの問いを生成 |
| 🚧 | レイアウトの刷新 | 時間帯で背景色が変わる日記風のUI |

## 技術スタック

- **Flutter / Dart**(Android)
- **Firebase**: Authentication(Googleログイン)、Cloud Firestore(東京リージョン)
- **無料枠(Sparkプラン)の範囲で運用**: Cloud StorageとCloud Functionsは使っていません。写真アバターや月次AI振り返りは、料金プランを決めてから対応する予定です

## 設計上の工夫

- **比較を生まない設計**: 記録日数などの数値は本人にだけ表示し、他人には見せません。ランキングや連続日数(ストリーク)は作りません
- **誤操作を防ぐ**: 記録の取り消しは日付を1回タップしただけでは実行されず、シートの中の専用ボタンにしています。ログアウトも確認ダイアログを挟みます
- **Firestoreの使い方を工夫**
  - スタンプのドキュメントIDを `uid_YYYY-MM-DD` にして、**IDの範囲指定で1か月分を取得**。複合インデックスなしで済ませています
  - 記録の付与/取り消しと `recordDayCount` の増減を**トランザクション**で行い、二重タップしても数がずれません
  - タイムラインは「公開の投稿 **または** 自分の投稿」を**OR条件**で取得します。セキュリティルールは「非公開は本人のみ閲覧可」で、クエリがルールを満たす形になっています(`firestore.rules` / `firestore.indexes.json`)
- **テストしやすい構造**: 画面はFirestoreに直接依存せず、データの取得元や保存処理を引数で受け取ります。そのため**Firebaseなしでウィジェットテストが書けます**

設計の詳細は [docs/DESIGN.md](docs/DESIGN.md)(画面遷移・データモデル)を参照してください。

## ディレクトリ構成

```
lib/
├── main.dart               # 起動処理、ログイン状態による画面の出し分け
├── main_shell.dart         # 下のナビゲーション(ホーム / タイムライン)
├── login_page.dart         # Googleログイン
├── home_page.dart          # ホーム(カレンダー + 記録)
├── post_compose_page.dart  # 投稿作成
├── timeline_page.dart      # タイムライン
├── profile_page.dart       # プロフィール
├── profile_edit_page.dart  # プロフィール編集
├── my_posts_page.dart      # 自分の投稿
├── data/                   # Firestoreの読み書き(UserRepository など)と、データ型
└── widgets/                # カレンダー、投稿カード、アバターなどの部品
test/                       # ウィジェットテスト
firestore.rules             # セキュリティルール
firestore.indexes.json      # 複合インデックス
```

## セットアップ

Firebaseの設定ファイル(`android/app/google-services.json` と `lib/firebase_options.dart`)には、
プロジェクト固有のAPIキーが含まれるため、**このリポジトリには含めていません**。動かすには自分のFirebaseプロジェクトが必要です。

1. [Flutter](https://docs.flutter.dev/get-started/install)、[Firebase CLI](https://firebase.google.com/docs/cli)、[FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) をインストールする
2. Firebase Consoleでプロジェクトを作り、次を有効にする
   - **Authentication** → ログイン方法で **Google**
   - **Cloud Firestore**(ネイティブモード)
3. 設定ファイルを生成する
   ```bash
   flutterfire configure --platforms=android
   ```
4. Androidのデバッグ用SHA-1を登録する(Googleログインに必要)
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
   firebase apps:android:sha:create <アプリID> <SHA-1>
   ```
   登録後にもう一度 `flutterfire configure` を実行し、`google-services.json` を更新する
5. セキュリティルールとインデックスを反映する
   ```bash
   firebase deploy --only firestore
   ```
6. 起動する
   ```bash
   flutter pub get
   flutter run
   ```

Windowsでは、プラグインのビルドに**開発者モード**(設定 → システム → 開発者向け)が必要です。

## テスト

```bash
flutter test
```

カレンダー、記録に添える一言のシート、投稿作成、タイムライン、プロフィール(表示・編集・ログアウト確認)、アバターのウィジェットテストがあります。
Firebaseなしで動きます。
