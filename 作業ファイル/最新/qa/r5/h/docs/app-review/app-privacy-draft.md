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

Sign in with Apple の refresh token は User ID ではありません。下の Other Data Types に申告します。

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

有料プランへ最初に切り替えた日時は、同じ表の別イベントです。下の Purchase History に書きます。

### Purchases > Purchase History

| 項目 | 回答 |
| --- | --- |
| 収集する | はい |
| ユーザーに紐づく | はい |
| トラッキング | いいえ |
| 目的 | Analytics |

根拠:

- 有料プランへ最初に切り替えた日時。`event_type = converted_to_paid`。同じ `public.subscription_events` の `user_id` と `created_at`。`(user_id, event_type)` は一意なので、2回目以降の行は入りません
- レシート、取引 ID、商品 ID はこの表に入らない（マイグレーション先頭のコメント、および `lib/services/subscription_event_reporter.dart`）
- 加入の期限は端末の SharedPreferences `calonavi_plus_expires_at_ms`（`lib/repositories/storekit_subscription_repository.dart`）。`purchase.verificationData.localVerificationData` は端末内で失効日を読むためだけに使い、サーバーへは送りません
- 購入そのものは StoreKit（`in_app_purchase` / `in_app_purchase_storekit`）経由で Apple が処理する。Product ID は `calonavi_plus_monthly` と `calonavi_plus_yearly`（`lib/config/subscription_catalog.dart`）
- マニフェスト: `NSPrivacyCollectedDataTypePurchaseHistory`。目的は Analytics のみ

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
- Sign in with Apple は氏名を要求しない。`lib/repositories/supabase_authentication_repository.dart` の `SignInWithApple.getAppleIDCredential` の scopes は `AppleIDAuthorizationScopes.email` のみ。givenName / familyName は受け取らず、Apple のログインでは氏名を保存しない
- Google ログインでサーバーに残る氏名は、下の Contact Info > Name で申告する。アプリの画面はその氏名を使わない

### Contact Info > Name

App Store Connect では、この表のとおり Contact Info > Name を申告する。

| 項目 | 回答 |
| --- | --- |
| 収集する | はい |
| ユーザーに紐づく | はい |
| トラッキング | いいえ |
| 目的 | App Functionality |

申告する理由: アプリは Google の氏名もプロフィール画像も表示しない。`AuthUser` は `id` と `email` だけ（`lib/repositories/supabase_authentication_repository.dart` の `_mapUser`）。`public.profiles` は生年月日・性別・身長・体重で、Google の氏名ではない。それでも Supabase Auth は Google ログインのとき、氏名と画像 URL を `auth.users.raw_user_meta_data` に入れる。既定のキーは `full_name`、`name`、`avatar_url`、`picture` で、同じ内容は `auth.identities.identity_data` にも残る。アカウント削除が成功すると、`delete_own_account` が `raw_user_meta_data` を `{}` にし、`auth.identities` の行を消す。

保存を避けなかった理由:

- ネイティブの Google ログインは `lib/repositories/google_sign_in_factory.dart` の `GoogleSignIn` で、追加スコープを渡していない。`google_sign_in` 6.3.0 の `scopes` は追加分だけ。iOS 実装（`google_sign_in_ios` 5.9.0 の `signInWithHint:additionalScopes:`）も、渡した配列を additional scopes として渡す。Google の Sign-In SDK は `openid`、`email`、`profile` を常に要求する。ID トークンには `name` と `picture` が入る
- その ID トークンと access token を `signInWithIdToken`（`OAuthProvider.google`）で Supabase に渡す。氏名を落とす処理はアプリ側にない。次のログインで Supabase が同じクレームを書き戻すので、ログイン直後に `updateUser` で空にしても残る
- Web と、iOS クライアント ID が無いときの Safari 経路は `signInWithOAuth` で、`scopes` を渡していない。`supabase/config.toml` に Google プロバイダのスコープ上書きはない。Supabase の Google プロバイダ既定は profile を含む
- `auth.users` だけをトリガーで削っても `auth.identities.identity_data` に氏名が残る。auth スキーマへのトリガーは Supabase がサポートする保存方法ではなく、この変更では入れない。両方をログイン時に消すには、ダッシュボードの Auth Hook と関数のデプロイが要る。この PR はデプロイしない

Sign in with Apple は上のとおり email のみで、こちらの Name には含めない。画像のファイルは受け取らない。Photos or Videos は収集しない、のままにする。残るのは URL の文字列だけ。

`legal/privacy.html` 第3章に入れた文:

> Google ログインに伴い保存される、Google アカウントの氏名とプロフィール画像の URL。アプリの画面では使わない。ログインの処理としてサーバーのアカウント情報に保存し、アカウントの削除が完了したときに消去する。

### Health & Fitness > Health

| 項目 | 回答 |
| --- | --- |
| 収集する | はい。HealthKit の読み取りは許可したとき。食事・アルコール・手入力の体重などは、記録したときに保存します |
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

保存先（Health として申告するもの）:

- プロフィール（手入力も同じ列）: `public.profiles` の `birth_date`、`gender`、`height_cm`、`weight_kg`
- 体重のスナップショット: `public.health_snapshots` の `weight_kg`
- 体重の履歴: `public.weight_entries`（`source` は `health` または `manual`）
- 食事とアルコール（保守的に Health として申告する）: `public.food_entries`、`public.alcohol_entries`（`supabase/migrations/20260801120000_create_alcohol_entries.sql`）。Apple は、特定の種類の入力をその種類として申告するよう求めており、Health には利用者が入力した健康データも含まれます。食事とアルコールは Other User Content には入れません

端末内だけで処理し、収集には当たらないもの:

- HealthKit のワークアウト行は Isar だけ（`lib/repositories/health_workout_local_store.dart`）。Supabase の表はありません。端末内だけで処理するデータは収集ではないため、収集データとしては宣言しません

アクティブエネルギー（`public.health_snapshots.active_energy_burned_kcal`）と運動の記録は、下の Fitness で申告します。

マニフェスト: `NSPrivacyCollectedDataTypeHealth`、目的は App Functionality。広告やマーケティングの目的は宣言していません。

許可しなくてもアプリは使える。活動量は手選択になる。

### Health & Fitness > Fitness

| 項目 | 回答 |
| --- | --- |
| 収集する | はい |
| ユーザーに紐づく | はい |
| トラッキング | いいえ |
| 目的 | App Functionality |

根拠:

- サーバーに保存するアクティブエネルギー: `public.health_snapshots.active_energy_burned_kcal`
- 運動の記録: `public.exercise_entries`（`user_id` を持つ）
- HealthKit のワークアウト行は上のとおり端末内の Isar だけなので、収集する Fitness には含めません。収集として宣言するのは、サーバーに残るアクティブエネルギーと運動記録です
- マニフェスト: `NSPrivacyCollectedDataTypeFitness`。関連付けあり、トラッキングなし、目的は App Functionality のみ

### User Content > Other User Content

| 項目 | 回答 |
| --- | --- |
| 収集する | はい |
| ユーザーに紐づく | はい |
| トラッキング | いいえ |
| 目的 | App Functionality |

食事・アルコールは Health、運動記録は Fitness で申告します。ここには入れません。

根拠（いずれも `user_id` を持つ）:

- 保存食品と公開食品: `public.saved_foods`（公開にしたものは他の利用者から検索できる）
- 食事テンプレート、運動テンプレート: それぞれのマイグレーション
- 目標: `public.goals`
- 公開食品への評価: `public.food_ratings`（`supabase/migrations/20260723120000_add_food_master_public_v1_1.sql`）
- 公開食品への通報: `public.food_reports`（同じマイグレーション）
- 作成者のブロック: `public.blocked_food_creators`（同じマイグレーション）

マニフェスト: `NSPrivacyCollectedDataTypeOtherUserContent`。関連付けあり、トラッキングなし、目的は App Functionality のみ。

写真・動画・音声は保存しない。カメラはバーコード読み取りだけ（`ios/Runner/Info.plist` の `NSCameraUsageDescription`、`lib/screens/food/barcode_scanner_screen.dart`）。読んだ数字は食品のバーコードとして保存することがある。画像そのものは残さない。Photos or Videos は収集しない。

公開食品の検索語を、検索履歴の表には書いていない。Search History は収集しない、がこのコードからの答え。

### Other Data > Other Data Types

| 項目 | 回答 |
| --- | --- |
| 収集する | はい |
| ユーザーに紐づく | はい |
| トラッキング | いいえ |
| 目的 | App Functionality |

これは Sign in with Apple の refresh token です。

申告する理由: Apple は、認証トークンをサーバー呼び出しで送るだけで保存しない場合は申告不要としています。このトークンは保存します。ネイティブの Sign in with Apple のあと、Edge Function `store-apple-refresh-token` が認可コードを refresh token に交換し、`public.store_apple_refresh_token` で Vault（`vault.secrets`、名前の接頭辞 `apple_refresh_token:`）に入れます。アカウント削除が完了したあと `delete_apple_refresh_token` で消します（`supabase/functions/delete-account`）。その削除に失敗したときはトークンが残ることがあります。保存しているので、「保存しないトークン」の例外には当たりません。

用途は、アカウント削除が成功したあと `https://appleid.apple.com/auth/revoke` で Apple との連携を解除することだけです。削除に失敗したときは Apple を呼びません。トークンを保存していない Apple ログイン（この機能より前、または認可コードを受け取れないログイン）は revoke せず、アプリが設定画面での解除を案内します。Analytics には使いません。User ID としても申告しません。

マニフェスト: `NSPrivacyCollectedDataTypeOtherDataTypes`。関連付けあり、トラッキングなし、目的は App Functionality のみ。

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
