# カロナビ（naruto-aii/AYG）Draft PR #25〜#29 セキュリティ再検査レポート

**総合結論：条件付き。直ったもの4件、一部のもの2件（④Plus利用権が端末だけで判定される／⑥#26のSQL関数が search_path=public）。秘密情報の混入はなし。**

- 検査日時：2026-09-27 19:50 JST ごろ
- 方法：GitHub コネクタ（cursor-github）で読み取りのみ。コメント・レビュー・マージ・ブランチ作成・コード変更・clone はしていない。
- 対象 HEAD：#25 `947a8b1` / #26 `3035c58` / #27 `c03dd07` / #28 `bd3d3cb` / #29 `0efb0de`
- 秘密情報や個人情報は、値を書かずに場所と種類だけを書く。

---

## 0. PRの積み重なり（base と差分の関係）

| PR | head ブランチ | head SHA | base | base SHA | 差分 |
|---|---|---|---|---|---|
| #25 | cursor/integrate-pr11-web-preview-eb80 | 947a8b1 | web-preview | 9b4c961 | 25 commits（PR #11 系列の 5f6e87a を merge commit e0f62f4 で取り込み。独自コミットは e0f62f4, 317bfaf, 2b60aa7, 58e0221, 947a8b1） |
| #26 | cursor/public-food-banned-names-eb80 | 3035c58 | #25 head | 947a8b1 | 0b59956, 94ab79c, 3035c58 |
| #27 | cursor/calonavi-plus-paywall-eb80 | c03dd07 | #26 head | 3035c58 | eb47e7b, b20a880, c03dd07 |
| #28 | cursor/ios-privacy-iphone-only-eb80 | bd3d3cb | #27 head | c03dd07 | bd3d3cb |
| #29 | cursor/apple-token-revoke-on-delete-eb80 | 0efb0de | #28 head | bd3d3cb | 48c4255, 0efb0de |

- 5本は一直線に積み重なっている。どのPRも base SHA ＝ 1つ前のPRの head SHA。
- マージは #25→#29 の順でしか安全にならない。各PRの差分は「1つ前のPRからの差分」だけを表す。
- #25 の base は `main` ではなく `web-preview`。対象の旧マイグレーション `20260920120000_...sql` は `main` には存在しない（`main` で get_file_contents すると 404）。存在するのは `web-preview`（9b4c961）以降だけ。

---

## 1. 項目別の判定

| # | 項目 | 判定 | 根拠（ファイル／行／コミット） |
|---|---|---|---|
| 1 | #25：本番適用済みの旧マイグレーションを書き換えていた | **直った** | `supabase/migrations/20260920120000_delete_own_account_keep_public_foods.sql` を base 9b4c961 と #29 head 0efb0de で取得して比べ、同一だった（owner_deleted も auth.sessions も含まない）。b971e8f（PR11系列）で入った +8 行（owner_deleted 更新）は、58e0221 で取り除かれている。変更は新しい `supabase/migrations/20260927150000_protect_owner_deleted_and_revoke_sessions.sql`（58e0221）に分かれ、down SQL は `supabase/rollback/20260927150000_..._down.sql`。`test/account_deletion_migration_test.dart` も、旧ファイルに owner_deleted／auth.sessions が無いことを確かめている。 |
| 2 | #25：saved_foods.owner_deleted を利用者が自分で更新できた | **直った**（SQLは未実行） | 150000 migration（58e0221）で次のように防いでいる。①テーブル全体の insert/update 権限を authenticated から取り上げ（`revoke insert, update on table public.saved_foods from authenticated`）、owner_deleted 列の権限も authenticated/anon/public から取り上げた。②owner_deleted を除いた列だけに insert/update を付け直した。③BEFORE INSERT OR UPDATE トリガー `saved_foods_reject_owner_deleted_change` を追加した（SECURITY DEFINER なし、`search_path=''`）。このトリガーは、current_user が postgres/supabase_admin/service_role のどれでもない場合に、**INSERT で true を入れる操作**と **UPDATE で値を変える操作**の両方を例外で拒否する。INSERT で true を入れる経路も塞がれている。 |
| 3 | #25：delete_own_account がセッション・リフレッシュトークンを消していなかった | **直った**（SQLは未実行） | 150000 migration（58e0221）と、それを置き換える `20260927160000_delete_subscription_events_on_account_deletion.sql`（c03dd07、同ファイル 90〜91 行付近）の関数の最後で、`delete from auth.refresh_tokens where user_id::text = uid::text;` と `delete from auth.sessions where user_id::text = uid::text;` を実行している。どちらも、エラーを握りつぶす exception ブロックの外にある。auth.users は削除せず匿名化しているので、カスケード削除には頼っておらず、直接削除している。**ただし発行済みのアクセスJWTは有効期限（exp）まで使える**（即時失効ではない）。#29 の 170000 は delete_own_account を再定義していないので、最終版は 160000 の関数。 |
| 4 | #25＋#27：Plus 利用権が期限切れ後も続く | **一部** | #27 で期限ベースに変わった。`lib/repositories/storekit_subscription_repository.dart`：旧キー `calonavi_plus_active` を廃止し、期限を `calonavi_plus_expires_at_ms` に保存（eb47e7b、38〜39行）。`SK2Transaction.transactions()` で取り直し（eb47e7b、215行）、期限時刻でタイマー再判定（c03dd07 `_scheduleExpiryCheck`）、返金された取引は付与しない（c03dd07、193〜194行・234行）。期限切れ後も続く問題はコード上は解消した。一方で次の2点が残る。①判定が**端末内だけ**で行われ、期限は SharedPreferences に入っている（改ざんした端末では回避できる）。#27 本文の Known risk にも記載がある。②**#25 だけをマージすると旧挙動（bool フラグ）のまま**。 |
| 5 | #26：brand／normalized_name／serving_unit_label が判定の対象外だった、NFKC がなかった | **直った**（SQLは未実行、Dart テストは自己申告） | **SQL**（`supabase/migrations/20260927120000_reject_banned_public_food_names.sql` @0efb0de）：`normalize_public_food_name` で `pg_catalog.normalize(public.compose_halfwidth_voiced(...), NFKC)` を使う。`publish_saved_food` は name/normalized_name/brand/serving_unit_label の4列を判定する。`validate_saved_foods_public_row` は、公開中の行でこの4列のどれかが変わったときに判定する。**Dart**（94ab79c／3035c58）：`lib/moderation/public_food_name_moderation.dart` は `unorm.nfkc` → 結合文字の除去 → 紛らわしい文字の置き換え、の順に処理し、半角の濁点・半濁点は NFKC の前に合成する。`lib/services/saved_food_publish_validator.dart` の `anyFieldBanned(name, normalizedName, brand, servingUnitLabel)` と、`lib/state/app_controller.dart` の `rejectsPublicUpdate` はどちらも4列を対象にしている。 |
| 6 | #27：古い `request.jwt.claim.role` を参照、不要な SECURITY DEFINER、search_path 未設定 | **一部** | #27 の分は直った。初版 eb47e7b は `subscription_event_counts` で `current_setting('request.jwt.claim.role')` を読み（140000 の 68 行）、SECURITY DEFINER で `search_path = public` だった。これが b20a880 で次のように直っている。①JWT claim の判定を削除し、権限は GRANT（service_role のみ）で制御。②`search_path=''`。③トリガー `subscription_events_force_row` から SECURITY DEFINER を外し、`search_path=''`。**残っているのは #26 の分**：新規・変更した8関数がすべて `set search_path = public`。そのうち `publish_saved_food` は **SECURITY DEFINER かつ search_path=public**（一覧は §2）。 |
| A | #29：Apple トークン失効 | **概ね良好（条件付き）** | 詳細は §3。保管はサーバー側だけ、秘密情報は環境変数からだけ読み、他人のアカウントを消せる経路もない。ただし、旧クライアントや直接 RPC で呼ぶと revoke を通らない、revoke してから削除する順序、既存 Apple 利用者にはトークンが無い、の3点が残る。 |
| B | #27：StoreKit 2 の署名検証 | **使っていない（アプリのコードでは）** | 詳細は §4。アプリのコードに `VerificationResult`／`.verified`／`currentEntitlements`／`jwsRepresentation`／`signedTransactionInfo` は出てこない。サーバー側で JWS を検証する仕組みや App Store Server API もない。revocationDate は端末で見ている。 |

---

## 2. 新規・変更した SQL 関数の一覧（SECURITY DEFINER と search_path）

| 関数 | PR / コミット | ファイル | SECURITY DEFINER | search_path | 実行権限 | 評価 |
|---|---|---|---|---|---|---|
| delete_own_account() | #25 58e0221 → #27 c03dd07 で置き換え | 150000 → 160000 | あり | `''` | authenticated のみ | 必要（他のテーブルと auth スキーマを消すため）。OK |
| saved_foods_reject_owner_deleted_change()（トリガー） | #25 58e0221 | 150000 | なし | `''` | ― | OK |
| compose_halfwidth_voiced(text) | #26 3035c58 | 120000 | なし | **public** | authenticated（public/anon からは取り上げ） | `''` に直すのが望ましい |
| normalize_public_food_name(text) | #26 | 120000 | なし | **public** | 同上 | 同上 |
| public_food_name_char_is_word(text) | #26 | 120000 | なし | **public** | 同上 | 同上 |
| public_food_name_contains_term(text,text) | #26 | 120000 | なし | **public** | 同上 | 同上 |
| public_food_name_strip_phrase(text,text) | #26 3035c58 | 120000 | なし | **public** | 同上 | 同上 |
| public_food_name_term_uses_substring(text) | #26 | 120000 | なし | **public** | 同上 | 同上 |
| public_food_name_is_banned(text) | #26 | 120000 | なし | **public** | 同上 | 同上 |
| validate_saved_foods_public_row()（トリガー） | #26（置き換え） | 120000 | なし | **public** | ― | `''` 推奨 |
| publish_saved_food(text) | #26（置き換え） | 120000 | **あり** | **public** | 既存の付与どおり（このマイグレーションでは付与を変えていない） | SECURITY DEFINER 自体は必要（visibility を変えるため）。**search_path は `''` に固定すべき** |
| subscription_events_force_row()（トリガー） | #27 eb47e7b → b20a880 | 140000 | なし（b20a880 で外した） | `''` | 全ロールから取り上げ | OK |
| subscription_event_counts() | #27 eb47e7b → b20a880 | 140000 | あり | `''` | service_role のみ | 必要（RLS で見えない行を集計するため）。OK |
| store_apple_refresh_token(uuid,text) | #29 48c4255 | 170000（36〜37行） | あり | `''` | service_role のみ（129〜132行） | 必要（Vault を使うため）。OK |
| read_apple_refresh_token(uuid) | #29 | 170000（93〜94行） | あり | `''` | service_role のみ（134〜137行） | OK |
| delete_apple_refresh_token(uuid) | #29 | 170000（116〜117行） | あり | `''` | service_role のみ（139〜142行） | OK |

補足：
- #26 の関数本体で使う組み込み関数（replace/translate/strpos/ascii/chr 等）は pg_catalog が先に探されるので、実際に乗っ取られる危険は低い。ただ、SECURITY DEFINER の `publish_saved_food` を含めて、固定の方針（`''` と完全修飾名）にそろえるべき。
- 利用者が public スキーマにオブジェクトを作れるかどうか（CREATE 権限）は本番DBで**未確認**。
- rollback ファイルが以前の `search_path=public` 版に戻すのは、ロールバックなので許容。

---

## 3. A：#29 Apple トークン失効の詳細

| 観点 | 結果 | 根拠 |
|---|---|---|
| リフレッシュトークンの保管場所 | **サーバー側だけ** | 端末は `credential.authorizationCode` だけを Edge Function `store-apple-refresh-token` に送る（`lib/repositories/supabase_authentication_repository.dart` 212〜216行、`lib/repositories/apple_refresh_token.dart`）。Dart 側がリフレッシュトークンを受け取ったり保存したりすることはない。関数が Apple でトークンに交換し、Supabase Vault に保存する（`public.store_apple_refresh_token`）。 |
| 端末でのログ出力 | 問題なし | `apple_refresh_token.dart` 27行・43行の `debugPrint` は固定の文言だけで、コードもトークンも出さない。 |
| クライアントからの読み取り | できない | 3関数とも authenticated/anon/public から EXECUTE を取り上げ、service_role にだけ付与している（170000、129〜142行）。クライアントから読めるテーブルは作っていない。vault スキーマは API に公開されていない前提（本番の Exposed schemas 設定は**未確認**）。 |
| Apple 用の秘密情報 | **環境変数からだけ読む** | `supabase/functions/_shared/apple_account.ts` 660行・664行で `Deno.env.toObject()` を読み、APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY / APPLE_CLIENT_ID を取り出す。`supabase/config.toml`（389・392行）は `verify_jwt = true` だけ。`supabase/functions/README.md` の設定例は `...` のプレースホルダ。テストの `apple_account_test.ts` は実行時に鍵ペアを生成し、ダミーの ID（例：TEAMID1234）を使うので、秘密情報ではない。 |
| 関数の認証 | 良好 | 両関数とも `verify_jwt = true`。`resolveSupabaseUserId` が呼び出し元の Bearer で `/auth/v1/user` を呼んで user id を決める（apple_account.ts 339行）。本文の user id は使わない。`delete_own_account` は**利用者の JWT と anon key** で呼ぶ（634行付近）ので、`auth.uid()` によって本人に限定される。Vault の読み取り・削除は、解決済みの UUID を検証してから service_role で行う。**他人のアカウントは消せない**。 |
| revoke が失敗したとき | 削除は続ける | 失敗はステータスと短いエラーコードだけを記録する（`logWithoutSecrets`、70行）。削除が失敗すると 500 を返し、トークンは残す。削除に成功したあと Vault の行を消すが、そこで失敗しても記録するだけなので、行が残ることがある。返すのは `{ok}` だけで、エラー本文は返さない（`lib/repositories/account_deletion_rpc.dart` も固定の文言だけ）。 |
| 直接 RPC を呼ぶ経路 | **残っている** | Dart 側は Edge Function `delete-account` だけを呼び、失敗しても直接 RPC に切り替えない（account_deletion_rpc.dart）。ただし `delete_own_account` は authenticated に EXECUTE が付いたまま（160000）。旧バージョンのアプリや直接 RPC で呼ぶと revoke を通らず、Vault にトークンが残る。 |
| 順序 | revoke してから削除 | revoke に成功したあと削除が失敗すると、Apple 側の連携だけが切れた状態になる（利用者は再ログインすれば新しいトークンで復旧できる見込み。動作は**未確認**）。 |
| 既存の Apple 利用者 | revoke できない | このリリースより前にログインした利用者にはトークンが保存されていないので、revoke は飛ばされる。Web/Android の Apple OAuth も同様。 |
| client secret の有効期間 | 150日 | apple_account.ts 16行・147行。Apple の上限（6か月）の範囲内。毎回生成するので保存はしない。 |

---

## 4. B：#27 StoreKit 2 の署名検証（事実だけ）

- 使っているパッケージ：`in_app_purchase ^3.2.3` と `in_app_purchase_storekit ^0.4.13`（eb47e7b で direct 依存に変更、`pubspec.yaml`/`pubspec.lock`）。
- 取引の取得：`lib/repositories/storekit_subscription_repository.dart` で `SK2Transaction.transactions()` を使う（eb47e7b、215行）。購入ストリームでは `SK2PurchaseDetails.expirationDate` を使う（同ファイルの `_expiryOf`）。
- **`Transaction.currentEntitlements`／`VerificationResult`／`.verified` の判定はアプリの Dart コードに無い。** eb47e7b と c03dd07 の差分を検索して確認した。プラグインの内部（Swift 側）で未検証の取引を除外しているかどうかは、プラグインのソースを見ていないので**未確認**。
- **サーバー側の JWS 検証（signedTransactionInfo／App Store Server API／App Store Server Notifications）は無い。** Edge Function にも SQL にも該当する実装がない。`subscription_events` はイベントの記録だけで、利用権の判定には使っていない。
- **端末だけで完結している。** 期限は SharedPreferences の `calonavi_plus_expires_at_ms`（eb47e7b、38行）。
- **返金（revocationDate）は見ている**（c03dd07）。`lib/services/subscription_entitlement.dart` の `parseStoreRevocationDate`（70〜104行付近）が `purchase.verificationData.localVerificationData`（リポジトリの 193〜194行）と `transaction.jsonRepresentation`（234行）から revocationDate を読み、値があれば Plus を付与しない。ただしこれも端末上の JSON を読んでいるだけで、署名は検証していない。

---

## 5. 秘密情報の混入チェック（全コミットの差分）

- 対象：#25 の 25 コミット、#26〜#29 の全コミット（計34）の追加行と削除行。削除済みの履歴も含む。
- 検索パターン：秘密鍵ヘッダ、JWT（eyJ…）、`sk_`、service_role key、DB 接続URL（postgres://）、password、Google OAuth クライアントID、AWS/GitHub トークン形式など。
- **結果：秘密情報（秘密鍵、API キー、service_role key、anon key の実値、パスワード、Apple の Key ID／Team ID の実値）は見つからなかった。**
- 秘密情報ではないが、報告しておく識別子：
  - Supabase プロジェクトの URL（プロジェクト ref）が次の場所に直書きされている。種類はプロジェクト識別子。クライアントに同梱される公開値なので秘密には当たらない。
    - `tool/setup_local_defines.command`（c8056f9 で追加、10行付近）
    - `tool/repair_local_defines.py`（83d1320 で追加、DEFAULTS 21行付近）
    - 696bb70 で別の ref に変更され、旧 ref を置き換える処理も入っている。
  - 同じファイルと docs に、アプリの公開サポート用メールアドレスがある（公開連絡先）。
  - anon key と Google クライアント ID は、`PASTE_ANON_KEY_HERE` や空文字などのプレースホルダだけ。
  - #29 のテストに出てくる `BEGIN PRIVATE KEY` は、実行時に生成した鍵を PEM 形式にするコードと、「本番コードに秘密鍵が入っていないこと」を確かめるテストの正規表現だけ。
- e0f62f4（merge）で `supabase/.temp/`（`cli-latest` と `pgdelta/catalog-local-migrations-*.json` の2件、各64,601行）が削除された。catalog の JSON は大きすぎて API が差分を返さず、中身は**未確認**。名前からはローカルマイグレーションのスキーマのカタログと推測される。このファイルは base（web-preview）の履歴に残る。`.gitignore` に3行が追加された。
- commit メッセージの Co-authored-by に個人のメールアドレスが含まれるコミットがある（このレポートには転記しない）。

---

## 6. PR別の判定

| PR | 判定 | 理由 |
|---|---|---|
| #25 | **条件付き** | 項目1〜3は直った。ただし**単体でマージすると Plus が旧挙動のまま**なので、#27 と一緒に出すことが条件。SQL（150000）はまだ一度も実行されていない。 |
| #26 | **条件付き** | 禁止語の判定（NFKC と4列）は直った。**8関数が search_path=public のまま**で、そのうち `publish_saved_food` は SECURITY DEFINER。`''` に固定する修正を推奨。SQL は未実行。 |
| #27 | **条件付き** | 期限切れと返金への対応、JWT claim の削除、トリガー関数の修正は直った。**利用権の判定は端末だけで、署名もサーバーも使わない**。有料機能の不正利用を受け入れる前提になる。 |
| #28 | **問題なし**（実機では未確認） | 差分にセキュリティ上の問題や秘密情報は無い。 |
| #29 | **条件付き** | 保管・秘密情報・認証は良好。ただし、直接 RPC の経路で revoke を通らない、revoke してから削除する順序、既存 Apple 利用者を revoke できない、の3点が残る。Edge Function のデプロイと Supabase secrets の設定はまだ。 |

---

## 7. 対処案

1. **#26：** 新規・変更した関数をすべて `set search_path = ''` にし、関数本体の参照を完全修飾名（`public.` / `pg_catalog.`）にする。最優先は `publish_saved_food`（SECURITY DEFINER）。同じPR内なら、本番未適用の 120000 を直してよい。適用済みなら新しいマイグレーションで直す。
2. **#25/#27：** マージは必ず #25→#27 の順で一緒に行う。#25 だけを出すリリースは作らない。
3. **#27：** App Store Server API（または App Store Server Notifications V2）で signedTransactionInfo をサーバー側で検証し、利用権をサーバー（DB）で持つ設計を検討する。少なくとも Plus でサーバー側の資源を使う機能には、サーバーで判定を入れる。端末側では Swift の `Transaction.currentEntitlements` と `.verified` を使う方法も検討する。
4. **#29：**
   - (a) `delete_own_account` の authenticated への EXECUTE を段階的に取り上げ、service_role（Edge Function）だけにする。または、関数の中で Vault の行を削除し、revoke が必要なら記録を残す（例：保留キューに入れる）。
   - (b) 削除に失敗したときの扱いを決める（削除を先に行い、revoke は後で再試行できる形にする）。
   - (c) 既存の Apple 利用者は、次回ログイン時に authorizationCode を取り直して保存するようにする。
   - (d) Vault に残った行を定期的に片づける。
5. **#25：** saved_foods に列を追加したら GRANT の列リストも更新するよう、チェックリストかテストに入れる（今の実装は列リストが固定）。
6. **全体：** ローカル Supabase（`supabase db reset`）で 120000〜170000 を実際に実行し、RLS と GRANT のテスト（owner_deleted を INSERT/UPDATE で変えられないこと、他人の行を操作できないこと、セッションが消えること）を通してから本番に出す。

---

## 8. 未確認事項

- 本番DBの状態（どのマイグレーションが適用済みか、20260920120000 が本当に本番で適用済みか、public スキーマの CREATE 権限、vault の公開設定）：**未確認**
- SQL の実行（120000〜170000 はどれも一度も実行されていない。PR 本文にも「psql/Docker なし」とある）：**未確認**
- テストの結果（PR本文の自己申告：Flutter 517 passed/24 skipped、#29 では 530 passed、Deno 11 passed）：**自分では実行していない。未確認**
- 実機（iOS）での Sign in with Apple、課金、返金、期限切れ、アカウント削除の動作：**未確認**
- Edge Function のデプロイと Supabase secrets の設定：**未確認**（未実施と思われる）
- in_app_purchase_storekit 0.4.13 が、プラグインの内部で未検証の取引を除外しているか：**未確認**
- e0f62f4 で削除された `supabase/.temp/pgdelta/*.json`（差分を取得できなかった）の中身：**未確認**
- 発行済みのアクセスJWTを削除後すぐに無効にすること：仕組み上は exp まで有効（JWT の有効期間の設定は**未確認**）
