# カロナビ 法務・サポート

公開 HTML（`legal/*.html`）が正です。App Store の URL と、アプリ内の全画面表示は同じ原稿です。
弁護士確認は未実施です。

運営・販売業者の氏名: 麹池成 / 所在地: 東京都 / 連絡先: calonavi.ayg.support@gmail.com

| 文書 | 公開 URL |
| --- | --- |
| 目次 | https://naruto-aii.github.io/AYG/legal/ |
| プライバシーポリシー | https://naruto-aii.github.io/AYG/legal/privacy.html |
| 利用規約 | https://naruto-aii.github.io/AYG/legal/terms.html |
| 特定商取引法に基づく表記 | https://naruto-aii.github.io/AYG/legal/tokushoho.html |
| サポート | https://naruto-aii.github.io/AYG/legal/support.html |
| アカウント削除 | https://naruto-aii.github.io/AYG/legal/account-deletion.html |

参照した公開書類: あすけん利用規約・特商法、カロミル利用規約、FiNC 特商法、消費者庁・特商法11条、個人情報保護法の公表事項。文面はカロナビ用に書き直しています。

## 今回埋めた項目

利用規約: 適用、定義、非医療、アカウント、未成年、課金・定期購入の解約、公開食品の利用許諾、禁止、知財、退会、非保証、損害賠償の上限、反社、地位譲渡、分離可能性、変更、準拠法。

プライバシー: 事業者の氏名、取得項目、利用目的、Health の広告不使用、第三者提供、委託、国外取扱い、安全管理、保管期間、開示・訂正・利用停止、未成年。

特商法11条: 氏名、住所、電話（請求開示）、メール、価格、数量、送料、通信料、支払方法・時期、提供時期、申込期限、返品、定期購入の解約、動作環境。

## アカウント削除 RPC（本番適用済み）

`supabase/migrations/20260920120000_delete_own_account_keep_public_foods.sql`（本番適用済み。このファイルは変えない）

本番に `public.delete_own_account()` があり、`authenticated` から execute できる。
設定 → アカウント削除で個人データが消え、公開食品は残る。

`owner_deleted` とセッション失効は別マイグレーション
`supabase/migrations/20260927150000_protect_owner_deleted_and_revoke_sessions.sql`
（未適用）。適用後、作成者欄は「削除済みユーザー」になる。

## 決まったこと（2026-09-20）

- 初回公開は App Store のみ。Google Play は出さない
- 運営名義は法人化まで個人・麹池成
- アカウント削除後の公開食品は残し、作成者欄は「削除済みユーザー」
- 法務文面は、弁護士未確認のまま出す（残余リスクは薄いと判断した場合）

## 課金（2026-09-20 決定）

商品名: カロナビ+
- 月額 380円 / 年額 4,180円（月額×11、1ヶ月分お得）
- Product ID: `calonavi_plus_monthly` / `calonavi_plus_yearly`
- 無料枠: 公開食品検索 5回/日、食事テンプレート 3件、運動テンプレート 3件
- 加入中は3つとも無制限
- 記録・Health・バーコード・公開投稿は無料のまま

App Store Connect の商品は作成済み。初回提出はアプリのバージョンと一緒。ストアのアプリ名は `カロナビ - 食事と運動`（`カロナビ` 単体は使用済み）。ホーム画面とアプリ内はカロナビのまま。

## 済んでいるもの

- 法務 HTML とアプリ内全画面表示
- Sign in with Apple（Developer Key、Supabase Apple Enabled、アプリ配線）。Web プレビューでは使えない
- アカウント削除 UI と本番 RPC（`delete_own_account`、authenticated から実行可）
- カロナビ+ のアプリ側と App Store Connect 商品（`calonavi_plus_monthly` 380円 / `calonavi_plus_yearly` 4,180円、同じ Level 1）
- ストアのアプリ枠（名前は `カロナビ - 食事と運動`）
- 公開食品の作成者欄「削除済みユーザー」
- 通報・作成者ブロック

基本タスクが終わるごとに、下の「今できる」「デザイン後」と推奨順を出し直す。デザイナーへ見た目を依頼中。機能は凍結済み。

## 今できる残タスク（推奨着手順）

見た目の納品を待たなくてよい。括弧は主担当。次は 1。

1. **Google ログインと Health を実機で通す**（Owner のコンソール作業 + 実機。手順は `docs/setup/ios_google_health.md`）
   - Google Cloud で iOS OAuth クライアント（Bundle ID `com.narutoaii.ayg`）を作り、`GOOGLE_IOS_CLIENT_ID` に入れる
   - Supabase Redirect URLs に `com.narutoaii.ayg://login-callback` を足す
   - Xcode の Signing & Capabilities に HealthKit があることを確認し、USB で入れ直す
2. **残りの実機確認**（Owner、不具合はエージェント）
   - Apple ログイン、キーボード、筋トレ複数種目、バーコードカメラ
   - アカウント削除、公開食品の「削除済みユーザー」、検索5回とテンプレ3件の上限
   - カロナビ+ の購入と復元（Sandbox。Add for Review はまだ押さない）
3. **掲載のテキストだけ先に入れる**（Owner）
   - プライバシー / 利用規約 / アカウント削除 URL
   - Privacy Nutrition Labels（Health は目標計算のみ。広告・マーケティングに使わない）
   - 年齢、審査メモ（公開食品が残ること、削除手順、Health の用途）
   - スクリーンショットとアイコンは空のまま。ストア名は `カロナビ - 食事と運動`

公開窓口は `calonavi.ayg.support@gmail.com`。新しい仕組みは作らない。その Gmail を見られればよい。

## デザインが戻ってから着手

Figma / アイコン / スプラッシュ / 店頭スクショが揃ってから。

1. **見た目の実装**（エージェント）
   - ログイン、初回設定、ホーム、食事、運動、体重、設定、空 / 読込 / エラー
   - カロナビ+ 画面はブリーフ後に足したので、納品に無ければ現行のまま出すか追加依頼
2. **アプリアイコンとスプラッシュ**（エージェント）
3. **App Store スクリーンショット**（Owner、素材はデザイナー）
4. **見た目込みの実機確認**（Owner、不具合はエージェント）
5. **TestFlight → 審査提出**（Owner）
   - アイコンとスクショが揃ってから出す

初回にやらなくてよい: Google Play、法人名義、体重タブの機能追加、Health Workout の運動反映、写真解析、Apple token 失効、レシートのサーバ検証。
