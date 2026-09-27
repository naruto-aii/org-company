# 審査用デモアカウント（本番）

この文書は App Review 用です。提出前に運営が本番の Supabase でアカウントを作り、下のサンプルデータを入れてください。

パスワード、Sandbox テスターのパスワード、Apple の秘密鍵は書きません。App Store Connect の審査情報には、運営が直接入力します。

## ログイン方法

このアプリが実装しているログインは次の2つだけです。メールアドレスとパスワードのログインはありません。

- Sign in with Apple（iPhone の標準シート）
- Google ログイン

審査用の共有アカウントは Google で作ります。App Store Connect の「ユーザー名」は、その Google アカウントのメールアドレスです。パスワード欄は App Store Connect に直接入力します。このファイルには書きません。

Sign in with Apple は、審査担当者自身の Apple ID でもログインできます。その場合、運営が渡すパスワードはありません。

| 項目 | 記入 |
| --- | --- |
| ユーザー名（Google のメールアドレス） | （App Store Connect に直接入力。ここには書かない） |
| パスワード | （App Store Connect に直接入力。ここには書かない） |

ストアのアプリ名は `カロナビ - 食事と運動` です。Bundle ID は `com.narutoaii.ayg` です。提出ビルドは iPhone のみです。

## 本番での作り方

1. 本番の Supabase に接続した TestFlight ビルド、または同じ接続のリリースビルドを、審査用の iPhone に入れる。ローカルの Supabase では作らない。
2. 審査専用の Google アカウントで「Googleでログイン」する。初回ログインで本番の `public.users` に行ができる。
3. 初回設定を最後まで終える。下のプロフィールを入れる。Health の許可は、ヘルスケアに値を入れてからオンにする。
4. 下のサンプルを、審査担当者が開く日の「今日」として登録する。過去日だけだとホームの「今日」が空になる。
5. 設定 → カロナビ+ を一度開き、Sandbox の購入と復元ができることを確認する。Sandbox 用 Apple ID のパスワードも、このファイルには書かない。
6. 審査中にこのアカウントを削除しない。削除すると個人の記録は消え、公開した食品だけ残る。

## サンプルデータ

審査担当者が、ログイン後に次の画面を開ける状態にします。

### プロフィールと目標

初回設定、または設定の基本情報と目標。

- 生年月日、性別、身長、体重を入れる（例: 1990-01-01、男性、170 cm、70 kg）
- 目標は維持、目標体重は現在の体重、目標日は数ヶ月先

### ホームの食事とアルコール

ホームに「今日の食事」と「今日のアルコール」がある。アルコールは食事とは別の欄です。

- 食事を1件以上。例: ごはん、その場の栄養値で登録
- アルコールを1件以上。ホームの追加、または食事タブの「アルコールを追加」。例: ビール 350 mL。ホームの「今日のアルコール」に名前と時刻が出ること

### 運動と体重

- 運動を1件。例: ウォーキング 30分
- 体重を1件、手入力

### バーコード

食事の登録画面からカメラで、パッケージの JAN を1件読む。画像は保存しない。バーコードの数字で食品名を引くには通信が必要で、ビルド時の連絡先（Open Food Facts の User-Agent）が入っていること。ヒットしない商品もある。その場合は手入力に戻して、カメラが起動したことだけ確認する。

### HealthKit（読み取りだけ）

アプリは次だけを読む。歩数は読まない。書き込み権限はない。

- 生年月日、性別、身長、体重、アクティブエネルギー、ワークアウト

審査用 iPhone のヘルスケアに、身長・体重・今日のアクティブエネルギー（またはワークアウト）を入れてから、初回設定または設定の Health / 活動量で「利用する」をオンにする。許可シートで読み取りだけを許可する。値が空なら、許可は通っていても表示は空のままなので、手入力のプロフィールで足りる。

### カロナビ+（Sandbox の購入と復元）

設定 → カロナビ+。

- 価格は購入画面に出る StoreKit の表示が正。この文書では金額を固定しない
- Product ID: `calonavi_plus_monthly` と `calonavi_plus_yearly`
- Sandbox の Apple ID で購入し、成功のメッセージを確認する
- 「復元」で、購入が見つかる場合と見つからない場合のメッセージを確認する
- 加入中は、公開食品の検索、食事テンプレート、運動テンプレートが無制限になる

無料のままなのは、食事・運動・体重・アルコールの記録、Health の読み取り、バーコード、公開投稿です。

無料枠（加入前に上限の画面を見るとき）:

- 公開食品の検索 1日 5回
- 食事テンプレート 3件
- 運動テンプレート 3件

上限に達するとカロナビ+ の案内が出ます。この回数と切替の日時は、ユーザーIDに紐づく利用状況としてサーバーに残ります。

## Notes for review（日本語）

カロナビは食事・運動・体重の記録アプリです。診断や治療のアプリではありません。

ログインは Sign in with Apple または Google です。審査用のユーザー名とパスワードは App Store Connect に入力済みです。このメモには書いていません。Sign in with Apple は、審査担当者の Apple ID でもログインできます。

ホームの「今日のアルコール」に、本日のアルコール記録を入れてあります。食事とは別の欄です。

バーコードはカメラで読みます。写真は保存しません。

HealthKit は読み取りだけです。使う項目は生年月日、性別、身長、体重、アクティブエネルギー、ワークアウトです。歩数は読みません。ヘルスケアへの書き込みはありません。許可しなくても、活動量の手選択で目標を計算できます。

カロナビ+ は設定にあります。Sandbox で購入と復元を確認できます。価格は購入画面の表示です。

アカウント削除は設定にあります。個人の記録は消え、公開した食品は残ります。審査中はデモアカウントを削除しないでください。

## Notes for review (English)

Calonavi logs meals, exercise, and weight. It does not diagnose or treat.

Sign-in is Sign in with Apple or Google. The review username and password are entered in App Store Connect and are not written in this note. Reviewers can also sign in with their own Apple ID.

Today’s alcohol log is on the home screen, in the section titled 「今日のアルコール」, separate from meals.

The barcode scanner uses the camera. Photos are not saved.

HealthKit is read-only: date of birth, sex, height, weight, active energy, and workouts. The app does not read steps and does not write to Health. If Health access is declined, targets still work from a manually chosen activity level.

カロナビ+ is under Settings. Sandbox purchase and restore can be checked there. The price is the one shown on the purchase screen.

Account deletion is in Settings. Personal logs are deleted. Foods the user published stay available. Please do not delete the demo account during review.
