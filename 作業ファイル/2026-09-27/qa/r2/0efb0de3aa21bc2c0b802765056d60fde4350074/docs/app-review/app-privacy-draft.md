# App Store Connect App Privacy 回答案

案です。App Store Connect にはまだ入力していません。このブランチのコードとマイグレーションから書いています。弁護士確認はしていません。

共通:

- トラッキング: しない。`ios/Runner/PrivacyInfo.xcprivacy` の `NSPrivacyTracking` は false。トラッキングドメインは空。ATT の利用、広告識別子、広告 SDK はない
- 下の収集項目は、ログインしたユーザーの ID に紐づく（Linked to the user’s identity: Yes）
- Tracking: No
- 利用状況の目的は Analytics。Product Personalization にはしない

`NSPrivacyAccessedAPITypes`（UserDefaults、ファイルのタイムスタンプ、起動時間、ディスク容量）は、収集データの申告ではなく、必須理由 API の宣言です。

## 回答

### Identifiers > User ID

| 項目 | 回答 |
| --- | --- |
| 収集する | はい |
| ユーザーに紐づく | はい |
| トラッキング | いいえ |
| 目的 | App Functionality、Analytics |

根拠:

- アカウント ID は Supabase Auth の `auth.users.id` と `public.users.id`（`supabase/migrations/20260722130000_create_v1_1_schema.sql`）
- 利用状況の行は `public.subscription_events.user_id`（`supabase/migrations/20260927140000_subscription_events.sql`）
- マニフェスト: `NSPrivacyCollectedDataTypeUserID`。目的は App Functionality と Analytics（`ios/Runner/PrivacyInfo.xcprivacy`）

Sign in with Apple の refresh token は、ネイティブログインのあと Edge Function が Vault に保存します（`supabase/functions/store-apple-refresh-token`、`public.store_apple_refresh_token`）。アカウント削除時の失効にだけ使い、Analytics には使いません。App Store Connect に同じ名前の項目はないため、User ID とは別だと注記します。入力時の分類は運営が確認してください。

### Usage Data > Product Interaction

| 項目 | 回答 |
| --- | --- |
| 収集する | はい |
| ユーザーに紐づく | はい |
| トラッキング | いいえ |
| 目的 | Analytics |

Product Personalization は選ばない。

根拠:

- 無料枠の上限に初めて達した日時。`event_type = free_limit_hit`。列は `user_id`、`event_type`、サーバーの `created_at` だけ
- 挿入は `lib/services/subscription_event_reporter.dart` と `lib/repositories/supabase_subscription_event_reporter.dart`
- 表の定義と「食品名・計測値・レシート・自由文は入れない」は `supabase/migrations/20260927140000_subscription_events.sql`
- マニフェスト: `NSPrivacyCollectedDataTypeProductInteraction` の目的は Analytics のみ

有料プランへの切替日時は、同じ表の別イベントです。下の Purchase History に書きます。

### Purchases > Purchase History

| 項目 | 回答 |
| --- | --- |
| 収集する | はい |
| ユーザーに紐づく | はい |
| トラッキング | いいえ |
| 目的 | Analytics |

根拠:

- 有料プランへ切り替えた日時。`event_type = converted_to_paid`。同じ `public.subscription_events` の `user_id` と `created_at`
- レシート、取引 ID、商品 ID はこの表に入らない（マイグレーション先頭のコメント、および `lib/services/subscription_event_reporter.dart`）
- 加入の期限は端末の SharedPreferences `calonavi_plus_expires_at_ms`（`lib/repositories/storekit_subscription_repository.dart`）。サーバーでは検証していない
- 購入そのものは StoreKit（`in_app_purchase` / `in_app_purchase_storekit`）経由で Apple が処理する。Product ID は `calonavi_plus_monthly` と `calonavi_plus_yearly`（`lib/config/subscription_catalog.dart`）

カード番号はアプリが受け取りません。

### Contact Info > Email Address

| 項目 | 回答 |
| --- | --- |
| 収集する | はい |
| ユーザーに紐づく | はい |
| トラッキング | いいえ |
| 目的 | App Functionality |

根拠:

- Google または Sign in with Apple がメールを渡した場合、`public.users.email`（`supabase/migrations/20260722130000_create_v1_1_schema.sql`）
- マニフェスト: `NSPrivacyCollectedDataTypeEmailAddress`、目的は App Functionality
- 氏名は Sign in with Apple のスコープに含まれる（`lib/repositories/supabase_authentication_repository.dart` の `AppleIDAuthorizationScopes.fullName`）が、アプリはその givenName / familyName を保存しない。Name は収集しない、がこのコードからの答え

### Health & Fitness > Health

| 項目 | 回答 |
| --- | --- |
| 収集する | はい（利用者が許可したとき） |
| ユーザーに紐づく | はい |
| トラッキング | いいえ |
| 目的 | App Functionality |

読み取る型（`lib/repositories/platform_health_repository.dart` の `_readTypes`）:

- 生年月日 `BIRTH_DATE`
- 性別 `GENDER`
- 身長 `HEIGHT`
- 体重 `WEIGHT`
- アクティブエネルギー `ACTIVE_ENERGY_BURNED`
- ワークアウト `WORKOUT`

歩数はリストにない。書き込み用の `NSHealthUpdateUsageDescription` は `ios/Runner/Info.plist` にない。権限要求は `HealthDataAccess.READ` だけ。

保存先:

- プロフィール（手入力も同じ列）: `public.profiles` の `birth_date`、`gender`、`height_cm`、`weight_kg`
- 当日の活動量と体重: `public.health_snapshots` の `active_energy_burned_kcal`、`weight_kg`
- 体重の履歴: `public.weight_entries`（`source` は `health` または `manual`）
- ワークアウトの記録: 端末内の Isar（`lib/repositories/health_workout_local_store.dart`）。Supabase の表はない

マニフェスト: `NSPrivacyCollectedDataTypeHealth`、目的は App Functionality。広告やマーケティングの目的は宣言していない。

許可しなくてもアプリは使える。活動量は手選択になる。

### User Content > Other User Content

| 項目 | 回答 |
| --- | --- |
| 収集する | はい |
| ユーザーに紐づく | はい |
| トラッキング | いいえ |
| 目的 | App Functionality |

根拠（いずれも `user_id` を持つ）:

- 食事: `public.food_entries`
- アルコール: `public.alcohol_entries`（`supabase/migrations/20260801120000_create_alcohol_entries.sql`）
- 運動: `public.exercise_entries`
- 保存食品と公開食品: `public.saved_foods`（公開にしたものは他の利用者から検索できる）
- 食事テンプレート、運動テンプレート: それぞれのマイグレーション
- 目標: `public.goals`

写真・動画・音声は保存しない。カメラはバーコード読み取りだけ（`ios/Runner/Info.plist` の `NSCameraUsageDescription`、`lib/screens/food/barcode_scanner_screen.dart`）。読んだ数字は食品のバーコードとして保存することがある。画像そのものは残さない。Photos or Videos は収集しない。

公開食品の検索語を、検索履歴の表には書いていない。Search History は収集しない、がこのコードからの答え。

### 収集しないもの

- Precise / Coarse Location。位置情報の許可キーはない
- Contacts、Browsing History
- Payment Info（カード番号）。課金は Apple の画面
- Crash Data、Performance Data。クラッシュ送信の SDK はない
- Advertising Data、Device ID。IDFA は取らない
- Product Personalization を目的にしたデータはない

## 第三者に送るもの（SDK 以外も含む）

App Privacy の「データが第三者に送られるか」は、運営のプロジェクトに保存する Supabase と、ログイン・課金の Apple / Google、バーコード照会の Open Food Facts を分けて考える。

- Supabase: 上の表の保存先。このアプリが指定したプロジェクトだけ。他社のアプリと突き合わせるコードはない
- Apple: Sign in with Apple、HealthKit、StoreKit
- Google: Google ログイン。Health Connect は iPhone 提出では使わない
- Open Food Facts: `https://world.openfoodfacts.org` へバーコードを GET する（`lib/services/open_food_facts_service.dart`）。User-Agent は `AYG/0.1 (連絡先メール)`（`lib/config/open_food_facts_config.dart`）。連絡先はビルド時の定数で、ログイン中のユーザーのメールではない

保存先リージョンは、リポジトリの `SUPABASE_URL` がプレースホルダで、`supabase/config.toml` の region は別サービス向けのコメントなので、特定できない。
