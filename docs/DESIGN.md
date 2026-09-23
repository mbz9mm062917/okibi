# OKIBI 設計メモ

画面遷移とデータモデルの設計です。実装の状況は [README](../README.md) を参照してください。

## 設計の原則

- **ランキング・比較の演出を作らない**(最重要)
- 数値(記録日数など)は**本人にだけ**表示する。他人には見た目だけを見せる
- 連続日数(ストリーク)によるプレッシャーを作らない。週に一度でも続けていれば十分、という頻度に寛容な設計にする
- 誤操作で記録が消えないようにする

## 画面遷移

日々使うのは、ホーム・タイムライン・投稿作成・プロフィールの4画面です。

```mermaid
flowchart LR
    Login[Googleログイン] --> Home[ホーム<br/>カレンダー + 記録]
    Home <-->|ボトムナビ| Timeline[タイムライン]
    Home -->|投稿する| Compose[投稿作成]
    Home -->|アバター| Profile[プロフィール]
    Profile --> Edit[プロフィール編集]
    Profile --> MyPosts[自分の投稿]
    Profile -->|ログアウト| Login
    Timeline -->|投稿者の名前| Other[他の人のプロフィール<br/>フォロー]
```

## データモデル(Cloud Firestore)

✅ は実装済み、🚧 は未実装です。

### `users/{uid}` ✅

| フィールド | 型 | 説明 |
|---|---|---|
| `displayName` | string | 表示名 |
| `avatarType` | string | `"icon"` \| `"photo"`。写真は未対応(Cloud Storageが必要) |
| `avatarIconId` | string? | アイコンID(12種) |
| `avatarColorId` | string? | 色ID(8色)。アイコンと組み合わせて96通り |
| `avatarPhotoUrl` | string? | 写真のURL(将来用) |
| `statusMessage` | string | 一言ステータス |
| `genreTags` | array\<string\> | 選択中のジャンル(3つまで) |
| `visibility` | string | 投稿の公開範囲の既定値(将来用) |
| `firstPostMonth` | timestamp? | 初回投稿の月。月次AI振り返りの起点に使う |
| `recordDayCount` | number | 記録日数。**本人にのみ表示** |
| `createdAt` | timestamp | 作成日時 |

### `stamps/{uid_YYYY-MM-DD}` ✅

カレンダーのワンタップ記録。1日1件で、ドキュメントIDに日付を含めます。

| フィールド | 型 | 説明 |
|---|---|---|
| `uid` | string | 押した本人 |
| `date` | string | `"YYYY-MM-DD"` |
| `templateId` | string | 定型項目のID(今は `"default"` のみ) |
| `note` | string? | 「一言添える?」への回答(140字まで) |
| `createdAt` | timestamp | 押した日時 |

### `posts/{postId}` ✅

| フィールド | 型 | 説明 |
|---|---|---|
| `authorUid` | string | 投稿者 |
| `text` | string | 本文(500字まで) |
| `photoUrl` | string? | 添付写真(将来用) |
| `genreTag` | string | ジャンルタグ(1件) |
| `isPublic` | boolean | 公開/非公開。既定は公開 |
| `reactionCount` | number | 炎リアクションの数 |
| `createdAt` | timestamp | 投稿日時 |

### `follows/{followerUid_followeeUid}` ✅

| フィールド | 型 | 説明 |
|---|---|---|
| `followerUid` | string | フォローする側 |
| `followeeUid` | string | フォローされる側 |
| `createdAt` | timestamp | フォローした日時 |

ドキュメントIDは `フォローする人_される人` に固定します。フォロー数・フォロワー数は、このコレクションの件数から数えます。

### `reactions/{postId_uid}` 🚧

`postId`、`uid`(反応した人)、`createdAt`

### `monthlyReflections/{uid_YYYY-MM}` 🚧

`uid`、`month`、`promptQuestion`(AIが生成した問い)、`answerText`、`isPublic`、`createdAt`

## セキュリティルール

`firestore.rules` に定義しています。基本は「ログイン済みユーザーだけが読める。書き込めるのは自分のデータだけ」です。

- `users`: 誰でも読める。書けるのは本人だけ
- `stamps`: 書き込み・削除は本人だけ
- `posts`: **非公開の投稿は本人だけが読める**。書き込み・削除は投稿者だけ
- `follows`: 作成・削除は、フォローする本人だけ。**自分自身はフォローできない**。ドキュメントIDは `フォローする人_される人` でなければ作れない
- `reactions`: 作成・削除は、その操作をする本人だけ

## クエリとインデックス

| 用途 | クエリ | インデックス |
|---|---|---|
| カレンダー(1か月分) | ドキュメントIDの範囲 `uid_YYYY-MM-01` 〜 `uid_YYYY-MM-31` | 不要 |
| タイムライン | `isPublic == true` **OR** `authorUid == 自分`、`createdAt` の降順 | `posts`: (`isPublic`, `createdAt`) と (`authorUid`, `createdAt`) |
| 自分の投稿 | `authorUid == 自分`、`createdAt` の降順 | `posts`: (`authorUid`, `createdAt`) |
| 他の人の公開投稿 | `authorUid == その人` かつ `isPublic == true`、`createdAt` の降順 | `posts`: (`authorUid`, `isPublic`, `createdAt`) |
| タイムライン「フォロー中」 | `authorUid in [フォロー中の人]` かつ `isPublic == true`、`createdAt` の降順 | 同上 |

「フォロー中」は、Firestoreの `in` が一度に30件までしか指定できないため、フォローが30人を超えると、
UIDの並び順で先頭の30人だけが対象になります。検証の段階では問題にならない人数なので、この上限のままにしています。

セキュリティルールは「クエリの結果が必ずルールを満たす」ことを求めます。タイムラインの取得は、
「公開」か「自分」のどちらかで必ず絞り込むことで、他人の非公開の投稿が読めないルールを満たしています。

## 未決定の事項

- ホーム画面の見出しの文言(「今頑張ってる人」はランキングのように見えるおそれがある)
- 写真アバター・写真添付(Cloud Storageの料金プランを決めてから)
- 月次AI振り返り(Cloud Functionsの料金プランを決めてから)
- リアクションの集計方法(`reactionCount` を非正規化するか、`reactions` を数えるか)
