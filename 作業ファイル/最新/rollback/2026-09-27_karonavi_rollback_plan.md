# カロナビ 戻し手順案（初回 App Store 申請 2026-10-07 向け）

- 作成: 2026-09-27（日）JST ／ 状態: **下書き（未承認）**
- 対象: iOS アプリ「カロナビ」1.0.0（初回リリース）、Supabase 本番 DB、Web プレビュー（GitHub Pages）
- 調べ方: GitHub `naruto-aii/AYG` を読み取りのみで確認（clone・書き込み・コメントなし）＋ Apple / Supabase の公開ドキュメント。本番 DB・App Store Connect・Supabase 管理画面は**見ていない**。
- 「**未確認**」= 文書やコードからの推定で、実物（管理画面・本番 DB・実機）ではまだ確かめていない点。

---

## 1. 目的と前提

### 目的
初回申請から公開後しばらくの間に問題が起きたとき、「誰が決めて」「何をどの順で戻すか」「戻ったことをどう確かめるか」を事前に決めておく。

### 大前提（これを知らないと判断を誤る）
1. **App Store では「前のバイナリに戻す」ことはできない。** 直すには「修正版を新しいビルドとして出し直す（審査あり）」しかない。初回リリースなので、そもそも戻る先の旧バージョンもない。止める手段は「公開しない（手動リリースのまま待つ）」か「販売停止（Remove from Sale）」だけ。
2. **段階的リリース（Phased Release）は初回には使えない見込み。** Apple のヘルプは「バージョンアップデート」向けの機能として説明している（出典 A2）。→ 初回は「手動でリリース」を選び、公開の瞬間を自分たちで決めるのが唯一のブレーキ。（ASC 画面上で初回に項目が出ないことは**未確認**）
3. **不具合の自動検知手段がない。** Sentry / Crashlytics は入っていない。頼れるのは App Store Connect / Xcode Organizer のクラッシュ情報（反映に時間差あり・**未確認**）、TestFlight のフィードバック、問い合わせ、Supabase の Logs。
4. **削除した個人データは、バックアップ以外からは戻せない。** アカウント削除処理は物理削除（DELETE）。
5. **課金の「使える/使えない」はアプリ内（端末側）だけで判定している。** サーバー側のレシート検証なし（PR #27 本文に明記）。

### リポジトリで確認できた事実（2026-09-27 時点・読み取りのみ）
| 項目 | 内容 |
|---|---|
| アプリのコード | ブランチ `web-preview`（Flutter / Isar / Supabase）。バージョン `1.0.0+1`、タグ・リリースなし |
| 申請に入る予定の PR | #25（PR #11 を web-preview に統合: カロナビ+、アカウント削除、Health 読み取り）→ #26（公開食品名の禁止語）→ #27（購入画面の価格・更新条件・期限）→ #28（プライバシーマニフェスト・iPhone のみ）。すべて **draft・未マージ**。#25 と #27 は同時に出す前提と PR 本文にある |
| アカウント削除（既存） | `supabase/migrations/20260920120000_delete_own_account_keep_public_foods.sql`。RPC `public.delete_own_account()`。PR #25 本文・SQL コメントでは「**本番適用済み**」と書かれている（本番での確認は**未確認**） |
| トークン失効（新規） | `supabase/migrations/20260927150000_protect_owner_deleted_and_revoke_sessions.sql`（**本番未適用**）。`delete_own_account` の最後で `auth.refresh_tokens` と `auth.sessions` の該当ユーザー行を削除する。あわせて `saved_foods.owner_deleted` 列、クライアントが書けないようにする列権限とトリガーを追加 |
| 戻し用 SQL（新規） | `supabase/rollback/20260927150000_protect_owner_deleted_and_revoke_sessions_down.sql`、`supabase/rollback/20260927140000_subscription_events_down.sql`。`supabase/migrations` の外にあるので `db push` では流れない（手で流す） |
| その他の新規 migration（本番未適用） | `20260927120000_reject_banned_public_food_names.sql`（#26）、`20260927140000_subscription_events.sql`（#27） |
| 既存の戻し資料 | `tool/prod_alcohol_entries_rollback.sql`、`supabase/tests/food_master_v1_1_rollback_test.sql` |
| 本番 DB 適用の型 | `tool/prod_*_migration.sh`。pg_dump で `~/Kalonavi_Backups/<UTC時刻>_<名前>/` に full / schema / data を保存 → `supabase migration list` と `db push --dry-run` で確認 → 環境変数による二重確認で `db push` → 適用後の読み取り検証。**トークン失効 migration 用のスクリプトはまだ無い** |
| Edge Functions | `supabase/functions/` は存在しない（止める対象の Edge Function はない） |
| Web プレビュー | `web-preview` への push（または手動実行）で `.github/workflows/deploy-web-preview.yml` → `publish-pages.yml@main` が動き GitHub Pages に公開。`publish-pages.yml` は main 側にある |
| アプリ側の挙動 | `lib/repositories/account_deletion_rpc.dart`: RPC が存在しない（PGRST202 / 42883）と「利用できません」扱い、それ以外のエラーは「失敗」扱い |

---

## 2. 決める人・動かす人

| 役割 | 担当 | 内容 |
|---|---|---|
| 判断 | **CTO** | 止めるか・どこまで戻すかを決める。下の「目安」に当たったら、その場で判断する |
| 承認 | **社長** | 実行前に**明示の承認**（Slack 等で文字に残す）を出す。承認なしで本番・ストアを触らない |
| 実行 | CTO（または CTO が指名した人） | 社長の承認後に実行し、実行時刻（JST）・コマンド・確認結果を記録する |

- 承認が必要な操作: App Store Connect でのリリース/取り消し/販売停止/課金アイテムの販売停止、本番 DB への SQL・migration・リストア、Supabase の認証設定変更、`web-preview` へのマージ・push（Web プレビューが自動で公開されるため）、ユーザーへの告知。
- 記録の置き場所: **未確認**（例: Slack の専用スレッド）。連絡先・連絡手段の一覧も**未作成**。

---

## 3. 止める判断の目安

「迷ったら止める」を基本にする。止める（公開しない・販売停止・機能を閉じる）は後から戻せるが、データ消失・個人情報の漏えいは戻せない。

| レベル | 例 | 動き |
|---|---|---|
| **即時停止**（CTO 判断→社長承認を最優先で取る） | 他人のデータが見える／書ける（RLS 不備）。アカウント削除で**本人以外**のデータが消える、または消すべきデータが残る。起動直後に大半の端末で落ちる。課金されたのに使えない人が複数。ログインが全員できない | 公開前なら公開しない（4-a）。公開後は販売停止を検討（4-b）＋該当のサーバー側を止める（4-c〜4-f） |
| **当日中に判断** | 一部機能の不具合（特定画面で落ちる、同期が失敗する）、Google か Apple の片方だけログイン不可、Web プレビューだけ壊れた | 修正版の準備（必要なら審査の優先依頼）。サーバー側で回避できるなら先に回避 |
| **次の版で直す** | 表示崩れ、文言ミスなど、データ・お金・ログインに影響しないもの | 通常の PR → TestFlight → 申請 |

監視手段が弱いので、公開後 72 時間は次を1日2回（例: 10:00 / 20:00 JST）見る案: App Store Connect（クラッシュ・評価・レビュー）、問い合わせ窓口、Supabase Dashboard の Logs（Auth / Postgres / API のエラー）、`public.users.deleted_at` の件数推移（削除が異常に多い・0件のまま等）。（頻度・担当は**未確認**、要決定）

---

## 4. ケース別手順

### (a) 審査中・公開前

**事前設定（申請時）**
1. やること: リリース方法を「**手動でリリース**（Manually release this version）」にする。
   - どこで: App Store Connect → アプリ → 1.0.0 のバージョンページ →「App Store バージョンのリリース」欄（出典 A1）
   - 確認: 保存後、同じ欄で「手動」が選ばれていること。承認後の状態が「デベロッパによるリリース待ち（Pending Developer Release）」になること。
2. 課金アイテム（カロナビ+ 月額・年額）が申請に含まれていることを確認（初回の課金アイテムはアプリのバージョンと一緒に審査に出す必要がある ― **未確認**、ASC で要確認）。

**審査中に問題が見つかった場合**
1. やること: 審査への提出を取り消す（Remove from Review / 提出の取り消し）→ 修正 → 新しいビルド番号でアップロード → 再提出。
   - どこで: App Store Connect → バージョンページ（取り消しボタンの正確な名称・位置は**未確認**）
   - 確認: 状態が「提出準備中」等に戻ること。新ビルドのビルド番号が前より大きいこと、git タグが打たれていること。
2. 本番 DB の migration を申請前に流している場合は、アプリ側を戻すかどうかと DB を戻すかどうかを分けて判断する（下の (e)(f)）。

**承認後・公開前に問題が見つかった場合**
1. やること: 「このバージョンをリリース」を押さない。そのまま修正版を用意する。
   - 確認: バージョンページの状態が「デベロッパによるリリース待ち」のままであること。App Store で検索して出てこないこと。
2. リリースを押してしまった直後なら、バージョンページに出る「このリリースをキャンセル（Cancel This Release）」で取り消せる（Apple ヘルプ記載・出典 A1。公開反映は最大24時間かかるとある。実際にどの時点まで取り消せるかは**未確認**）。

---

### (b) 公開後のアプリ不具合

前提: 前のバイナリへは戻せない。初回なので旧版もない。

1. **被害を止める**（即時停止レベルのとき）
   - やること: アプリを販売停止（Remove from Sale）する。新規ダウンロードが止まる。**すでに入れている人の端末からは消えない・動き続ける**。
   - どこで: App Store Connect → アプリ →「価格および配信状況（Pricing and Availability）」→ 配信状況で販売停止（出典 A3）
   - 確認: App Store でアプリページが出なくなること（反映の時間差あり・**未確認**）。ASC 上の状態が「デベロッパにより削除済み」等になること。
   - 注意: すでに使っている人への影響は止まらない。サーバー側で止められるものは (c)〜(f) で止める。
2. **サーバー側で回避できるか確認**
   - 例: DB 関数の不具合なら SQL で直す／戻す（(e)(f)）。ログイン設定の問題なら Supabase 側で直す（(d)）。
3. **修正版を出す**
   - やること: 問題の出たビルドの git タグから修正ブランチを作り、PR → マージ → ビルド番号 +1 → タグ → TestFlight で確認 → 新しいバージョン（例 1.0.1）として申請。
   - どこで: GitHub（`web-preview` ブランチとタグ）、Xcode / TestFlight、App Store Connect
   - 確認: TestFlight で問題の再現手順が直っていること、ビルド番号とタグが一致していること。
4. **審査の優先依頼（Expedited Review）**
   - やること: 重大な不具合の修正なら、Apple の依頼フォームから優先審査を頼む。**現行版での再現手順を書く**。認められるかは Apple 次第（出典 A4）。
   - どこで: https://developer.apple.com/contact/app-store/?topic=expedite （フォームの URL は**未確認**、出典 A4 のページのリンクから入る）
5. 修正版が承認されたら販売停止を解除する（配信状況を戻す）。再開後の反映時間は**未確認**。

---

### (c) 課金（カロナビ+）

前提（PR #27 本文より）: 価格は StoreKit から取得。商品が読み込めないと購入画面は「価格を読み込めませんでした」と再試行ボタンを出し、購入ボタンは出ない。「購入の復元」は常に出る。利用権は端末に保存した有効期限で判定。サーバー検証・返金（revocation）処理なし。

| 症状 | やること | どこで | 確認 |
|---|---|---|---|
| 新規購入で問題（二重課金・誤った価格など） | 課金アイテムを販売停止にする。アプリは「価格を読み込めませんでした」表示になり購入できなくなる想定 | App Store Connect → アプリ → アプリ内課金 / サブスクリプション → 各アイテム → 配信状況（出典 A5）。月額・年額それぞれ行う | TestFlight/実機で購入画面に購入ボタンが出ないこと（反映の時間差・Sandbox と本番の違いは**未確認**） |
| 買ったのに使えない | 利用者に「購入の復元」を案内。直らなければ修正版（(b)-3） | アプリの カロナビ+ 画面 | 復元後に無料枠の制限が外れること |
| 返金の要望 | 開発者側では返金できない。Apple への返金申請（reportaproblem.apple.com）を案内 | ― | ― |
| 無料枠の判定ミス（無料なのに全部使える／有料なのに制限される） | 判定が端末内のみなので、サーバー側では止められない。修正版で対応 | ― | ― |

- 価格の変更は App Store Connect だけで済む（コードに円の金額は持っていない、PR #27）。
- `subscription_events`（#27 の migration）を戻す場合: `supabase/rollback/20260927140000_subscription_events_down.sql` を手で流す。流す前に (e) の「DB 作業の共通手順」でバックアップを取る。戻すと利用状況の件数（free_limit_hit / converted_to_paid）の記録は消える。アプリ側が insert に失敗したときの挙動（エラー表示が出ないか）は**未確認**。
- 課金アイテムの販売停止中に既存の購読者がどうなるか（更新が止まるか）は**未確認**。

---

### (d) ログイン（Google / Apple）

1. 片方だけ不調なら、もう片方でログインしてもらうよう案内し、原因を調べる。
2. 確認する場所:
   - Supabase Dashboard → Authentication → Providers（Google / Apple が有効か、Client ID 等の設定）
   - Supabase Dashboard → Authentication → URL Configuration の Redirect URLs に `com.narutoaii.ayg://login-callback` があるか（PR #11 の手順）
   - Supabase Dashboard → Logs → Auth ログのエラー
   - Apple Developer → Certificates, Identifiers & Profiles（Sign in with Apple の Services ID・Key）
   - Google Cloud Console → 認証情報（iOS OAuth クライアント。`GOOGLE_IOS_CLIENT_ID` が空だと Web クライアント経由になる、PR #11）
3. 設定を変える前に、変更前の値を（秘密情報は除いて）記録する。戻すときはその値に戻す。
4. 確認: TestFlight / 実機で Google・Apple の両方でログイン → ログアウト → 再ログインできること。
5. 注意点（**未確認**）: Apple の Web 用 OAuth で使う client secret には有効期限がある（Supabase の Apple 設定の説明）。iOS ネイティブの ID トークン方式には影響しない見込みだが、Web プレビューの Apple ログインは期限切れで止まる可能性がある。期限の日付を確認しておく。
6. アプリ側の不具合なら修正版（(b)-3）。サーバー側で「新規ログインだけ止める」手段は、プロバイダの無効化しかない（既存セッションは残る）。

---

### (e) Supabase アカウント削除処理の停止・戻し

**現状（コードより）**
- `delete_own_account()`（本番適用済みと記載・**未確認**）は、本人の食事・運動・体重・飲酒・テンプレート・評価・通報・ブロック・非公開の食品・設定・目標・プロフィール・レート制限の行を **DELETE** し、`public.users` の email を消して `deleted_at` を入れる。公開した食品は残す（作成者は匿名化）。`auth.identities` を削除し、`auth.users` のメールを `deleted+<id>@invalid.local` に書き換える（`auth.users` 行自体は消さない）。
- 20260927150000 を適用すると、公開食品に `owner_deleted = true` を付け、セッションも消す（(f)）。

**削除済みデータは戻せるか**
- **アプリや SQL の「取り消し」では戻せない。** 戻せる可能性があるのはバックアップからだけ。
  - Supabase の日次バックアップ: Pro は直近7日、Team は14日（出典 S1）。Free プランには使えるバックアップがない（出典 S1）。PITR（秒単位で戻せる）は有料アドオンで、有効にした時点より前には戻せない（出典 S1）。**カロナビの契約プラン・PITR の有無は未確認。**
  - 注意: バックアップへの**プロジェクト全体リストア**は、その時点以降の**全員の**変更を巻き戻す。1人分だけ戻すには、pg_dump 等の別コピーから該当ユーザーの行だけ取り出して入れ直す必要がある（手順は未作成・**未確認**）。
  - プライバシーの観点: 本人が削除を求めたデータを戻すのは原則しない。「誤って本人以外が消えた」場合に限る想定（方針は社長・CTO で要決定）。
  - `auth.identities` を消しているので、同じ Google / Apple アカウントで再ログインすると**新しい別ユーザー**になる想定（**未確認**）。

**削除処理を一時的に止める（本人以外のデータが消える等の即時停止レベルのときだけ）**
- 注意: App Store の審査ガイドライン 5.1.1(v) でアプリ内のアカウント削除は必須（出典 A6）。止めるのは短時間の緊急措置に限る。止めている間は問い合わせでの削除受付に切り替える。
1. DB 作業の共通手順（すべての本番 SQL の前に必ず）
   - 社長の承認を得る。
   - バックアップ: 既存スクリプトと同じく `pg_dump` で full / schema-only / data-only を `~/Kalonavi_Backups/<時刻>_<作業名>/`（権限 700）に保存し、`pg_restore --list` で読めることを確認。接続情報・パスワードはログや記録に残さない。
   - 実行時刻（JST）と SQL ファイルのハッシュを記録。
2. 止める SQL（案）:
   ```sql
   revoke execute on function public.delete_own_account() from authenticated;
   ```
   - どこで: 本番 DB に psql（または Supabase Dashboard → SQL Editor）
   - 確認:
     ```sql
     select has_function_privilege('authenticated', 'public.delete_own_account()', 'execute');  -- false になること
     ```
     あわせて TestFlight で削除を押すとエラー表示になり、データが消えないこと。
   - 注意: 権限なしのエラー（42501）はアプリで「利用できません」ではなく「失敗」扱いになる見込み（`account_deletion_rpc.dart` の判定より・**未確認**）。
3. 再開する SQL:
   ```sql
   grant execute on function public.delete_own_account() to authenticated;
   ```
   - 確認: 上の `has_function_privilege` が true。テスト用アカウントで削除が最後まで通ること。

**関数の中身を元に戻す**
- 20260927150000 を適用した後に問題が出た場合: `supabase/rollback/20260927150000_protect_owner_deleted_and_revoke_sessions_down.sql` を手で流す（(f) と同じ手順）。
- 20260920120000（既存）自体の戻し SQL は**リポジトリに無い**。必要なら事前に作る（`public.users.deleted_at` 列は戻しても残る、PR #25 本文）。
- 適用済みの migration ファイルは**編集・削除しない**（PR #25 本文の注意）。

---

### (f) トークン失効の仕組みの停止・戻し

**仕組み（20260927150000・本番未適用）**
- `delete_own_account()` の最後で、そのユーザーの `auth.refresh_tokens` → `auth.sessions` の行を削除する。例外処理の外なので、失敗すると**削除処理全体がエラーになりロールバックされる**（個人データも消えない）。
- Supabase の仕様上、消せるのはリフレッシュトークンとセッションで、**発行済みのアクセストークン（JWT）は有効期限（exp）まで使える**（出典 S3）。つまり「すぐ全部ログアウト」ではなく「最大で JWT の有効期限（既定は通常1時間・**本番の設定値は未確認**）以内に切れる」。
- **Sign in with Apple のトークン失効（Apple の revoke API 呼び出し）は、この仕組みには含まれていない。** Apple はアカウント削除時に Sign in with Apple のトークンを REST API で失効させるよう求めている（出典 A6・A7）。リポジトリ内に該当処理は見当たらない（Edge Function もなし）。審査で指摘される可能性がある → **未確認・要判断**。

**適用前の準備（申請前）**
1. `tool/prod_*_migration.sh` と同じ型の適用スクリプト（バックアップ → dry-run → 二重確認 → 適用 → 検証）を用意する（**未作成**）。
2. 20260927120000・20260927140000 との適用順を決める（`db push` はファイル名順にまとめて流すので、「その1本だけ」を流したいときの手順が必要。既存スクリプトは他の保留 migration があると止まる作り）。
3. ローカル Supabase で up → down → up を試す（PR 本文では psql / Docker が無く **SQL は未実行**）。

**止める・戻す手順**
1. 社長の承認 → (e) の「DB 作業の共通手順」でバックアップ。
2. やること: 戻し SQL を流す。
   ```bash
   psql "<本番DB接続。記録に残さない>" -v ON_ERROR_STOP=1 \
     -f supabase/rollback/20260927150000_protect_owner_deleted_and_revoke_sessions_down.sql
   ```
   中身: `delete_own_account` を 20260920120000 の内容（セッション削除なし・owner_deleted なし）に戻し、トリガーと補助関数を削除、`saved_foods.owner_deleted` 列を削除、`authenticated` のテーブル単位の insert/update 権限を戻す。
   - **影響**: `owner_deleted` 列を消すので、公開食品の「削除済みユーザー」表示の情報が失われる（PR #25 本文）。アプリがこの列を読んでいる場合の挙動は**未確認**。
3. 履歴表の整合: 戻し SQL は migration 履歴表を変えない。`supabase migration list` で 20260927150000 が Remote に残っているなら、
   ```bash
   supabase migration repair 20260927150000 --status reverted --db-url "<記録に残さない>"
   ```
   で「未適用」扱いに直す（repair は履歴表だけを直し、SQL は実行しない・出典 S2）。直さないと、次の `db push` で再適用されない／ずれる。
   - その後 git 側でも migration ファイルを戻す（revert PR）かどうかを決める。ファイルが残っていると次の `db push` でまた適用される。
4. 確認:
   ```sql
   select column_name from information_schema.columns
    where table_schema='public' and table_name='saved_foods' and column_name='owner_deleted';  -- 0行
   select tgname from pg_trigger where tgname='saved_foods_reject_owner_deleted_change';        -- 0行
   select privilege_type from information_schema.role_table_grants
    where table_schema='public' and table_name='saved_foods' and grantee='authenticated';       -- INSERT, SELECT, UPDATE
   select prosrc like '%auth.sessions%' from pg_proc where proname='delete_own_account';        -- false
   ```
   あわせて `supabase migration list` と `supabase db push --dry-run` の結果を保存し、TestFlight で削除が通ること・食品の公開/編集ができることを確認。
5. 「特定ユーザーを今すぐログアウトさせたい」緊急時（削除とは別）: 同じ2行の DELETE を管理者として流す案。
   ```sql
   delete from auth.refresh_tokens where user_id::text = '<対象ユーザーID>';
   delete from auth.sessions where user_id::text = '<対象ユーザーID>';
   ```
   JWT の有効期限までは使える点は同じ。Supabase の管理 API での代替手段は**未確認**。

---

### (g) Web プレビュー（GitHub Pages）

前提: `web-preview` に push / マージすると自動で公開される（`deploy-web-preview.yml` → `publish-pages.yml@main`）。LP と Web プレビューは1つの Pages サイトを合成して出している（PR #23 / #24）。

1. 壊れた版が出た場合
   - やること: 原因のマージを `web-preview` 上で revert する PR を作り、社長の承認後にマージ → 自動で再公開。
   - どこで: GitHub → PR（Revert ボタン）→ Actions の「Deploy Web Preview」実行結果
   - 確認: Actions が成功（緑）。公開 URL で Web プレビューと LP（`/lp`）の両方が表示されること。
2. すぐ止めたいだけの場合
   - GitHub → Settings → Pages で公開を止める（LP も一緒に止まる）か、Actions の手動実行で前の状態を出し直す（`publish-pages.yml` がどのコミットを使うかは**未確認**）。
3. 注意
   - PR #25 以降を `web-preview` にマージした時点で、Web 版にもアカウント削除・カロナビ+ 画面が出る（StoreKit はネイティブのみと PR 本文にある）。Web からの削除も同じ本番 DB を使う（**未確認**）。
   - Web プレビューと本番アプリが同じ Supabase プロジェクトを使っているかは**未確認**。同じなら、DB を戻すと Web にも影響する。

---

## 5. 申請前に用意すべきもののチェックリスト

期限の目安: PR は 10/2 まで、TestFlight は 10/3 から、最終確認 10/6、申請 10/7（JST）。

- [ ] 社長・CTO の連絡手段と、承認を残す場所（Slack スレッド等）を決める
- [ ] App Store Connect で「手動でリリース」を選ぶ（申請時）
- [ ] 課金アイテム（月額・年額）が申請に含まれていること、販売停止の画面の場所を確認
- [ ] 10/3 以降の各 TestFlight ビルドに git タグ（ビルド番号と一致）を付ける。申請に出すビルドのタグを記録
- [ ] Supabase の契約プラン・日次バックアップの有無・PITR の有無を Dashboard → Database → Backups で確認。Free なら手動 pg_dump を必須にする
- [ ] 本番 migration 適用の直前に pg_dump で手動バックアップを取り、`pg_restore --list` で読めることを確認
- [ ] 20260927120000 / 140000 / 150000 の本番適用スクリプト（既存の型）と適用順を用意
- [ ] ローカル Supabase で 150000 と 140000 の up → down → up を実行して確認
- [ ] 20260920120000 が本番に入っていることを `supabase migration list` で確認（読み取り）
- [ ] Sign in with Apple のトークン失効（Apple revoke API）が必要か決める。必要なら実装方法（Edge Function 等）と、その止め方も本書に追記
- [ ] 本番の JWT 有効期限（Authentication の設定）を確認して本書に記入
- [ ] Apple の Web 用 client secret の有効期限を確認して記入
- [ ] テスト用アカウント（本番）で「ログイン → データ作成 → 削除 → 再ログインで別ユーザーになる」を 10/6 に確認
- [ ] 公開後 72 時間の見回り担当と時刻を決める
- [ ] 問い合わせでアカウント削除を受け付ける手順（削除処理を止めた場合の代わり）を決める
- [ ] 優先審査（Expedited Review）の依頼文のひな形（再現手順の書き方）を用意

---

## 6. 未確認事項

1. **Sign in with Apple のトークン失効（Apple revoke API）が未実装に見える。** 今回の「トークン失効」は Supabase のセッション削除のみ。審査ガイドライン 5.1.1(v) 関連で指摘される可能性。
2. **Supabase の契約プラン・バックアップ・PITR の有無。** 削除済みデータを戻せるかはこれ次第。1人分だけ戻す手順は無い。
3. 20260920120000 が本当に本番適用済みか（PR 本文の記載のみ）。
4. 150000 / 140000 / 120000 の SQL は一度もデータベースで実行されていない（PR 本文）。本番適用スクリプトも未作成。
5. 初回バージョンで段階的リリースが選べないこと、「このリリースをキャンセル」が使える期間、販売停止・再開の反映時間（ASC 画面で未確認）。
6. 初回の課金アイテムをバージョンと一緒に審査に出す必要があるか、課金アイテム販売停止中の既存購読者への影響。
7. 本番の JWT 有効期限（セッション削除後も最大その時間は使える）。
8. `delete_own_account` の実行権限を外したときのアプリ表示（「失敗」扱いになる見込み）。`owner_deleted` 列を消したときのアプリ側の挙動。
9. Web プレビューと本番アプリが同じ Supabase プロジェクトか。`publish-pages.yml` での戻し方。
10. クラッシュ情報の入手経路（Sentry / Crashlytics なし。ASC / Xcode Organizer の反映時間）。
11. 優先審査フォームの正確な URL、審査提出の取り消しボタンの名称。

---

## 出典（2026-09-27 JST 参照）

- A1 Apple: Select an App Store version release option — https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option
- A2 Apple: Release a version update in phases（7日間・一時停止は合計30日まで・販売停止でその版の段階的リリースは終了）— https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases/
- A3 Apple: Manage availability for your app on the App Store — https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store/
- A4 Apple: App Review（Expedited reviews）— https://developer.apple.com/distribute/app-review/
- A5 Apple: Set availability for In-App Purchases — https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-availability-for-in-app-purchases/
- A6 Apple: Offering account deletion in your app — https://developer.apple.com/support/offering-account-deletion-in-your-app
- A7 Apple: TN3194 Handling account deletions and revoking tokens for Sign in with Apple — https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple （URL は検索結果のミラーから推定・**未確認**）
- S1 Supabase: Database Backups（Pro 7日 / Team 14日 / PITR はアドオン）— https://supabase.com/docs/guides/platform/backups
- S2 Supabase: CLI migration repair / Database Migrations — https://supabase.com/docs/reference/cli/supabase-migration-repair ・ https://supabase.com/docs/guides/deployment/database-migrations
- S3 Supabase: Signing out（アクセストークンは exp まで有効）・User sessions — https://supabase.com/docs/guides/auth/signout ・ https://supabase.com/docs/guides/auth/sessions
- 参考: App Store での戻し手段の整理 — https://patchrelease.com/blog/ios-hotfix-playbook
