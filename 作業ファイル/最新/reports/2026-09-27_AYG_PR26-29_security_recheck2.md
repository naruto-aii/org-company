# カロナビ（naruto-aii/AYG）PR #26〜#29 再検査（2回目）

**総合結論：出してはいけない。** #26 の search_path 修正は、書き方そのものは直っている。しかし修正で入った `pg_catalog.coalesce`、`pg_catalog.greatest`、`::pg_catalog.normalization_form` は PostgreSQL に存在しない。そのため関数を実行すると必ずエラーになり、公開・編集・通報・アカウント削除が壊れる。#29 の service_role 限定は直った。秘密情報の混入はなし。

- 検査日時：2026-09-27 20:40 JST ごろ
- 方法：GitHub コネクタで読み取りのみ。書き込み、clone、コメントはしていない。
- 挙動の確認：ボックス内の使い捨て PostgreSQL 17 で、該当する構文だけを自分で書いた短い SQL で確かめた。リポジトリのコードそのものは実行していない。確認後、そのDBは削除した。

---

## 0. 前提：ブランチが作り直されている（rebase / force push）

| PR | 現在の head | base | 前回（19:50 JST ごろ）の head |
|---|---|---|---|
| #25 | 12485a8 | web-preview 9b4c961 | 947a8b1（CIの2コミット 9c57a42 と 12485a8 が追加された） |
| #26 | **f01d3d8** | 12485a8 | 3035c58 |
| #27 | 7dec3d9 | f01d3d8 | c03dd07 |
| #28 | e7e4d5c | 7dec3d9 | bd3d3cb |
| #29 | **23db22a** | e7e4d5c | 0efb0de |

- #26〜#29 のコミットは、すべて 20:11 JST（11:11:34Z）の committer 日時で作り直され、SHA が変わっている。前回のレポートに書いた SHA（3035c58、c03dd07、0efb0de など）は、もう各ブランチ上にない。
- **依頼にあった SHA と、実際の修正コミットが違う。**
  - search_path の修正は **c4e0246**（#26。f01d3d8 の親）。f01d3d8 は禁止語（露骨な複合語）を追加するコミット。
  - service_role 限定の修正は **94a8190**（#29）。23db22a は、Apple 連携解除に失敗したときの表示を変えるコミット。
  - このレポートでは4つとも確認した。

---

## 1. 項目別の判定

| # | 項目 | 判定 | 根拠 |
|---|---|---|---|
| 1-a | #26：9関数の search_path | **直った**（書き方として） | c4e0246 で `supabase/migrations/20260927120000_reject_banned_public_food_names.sql` の `set search_path = public` をすべて `''` に変えた。対象はヘルパー7つ（compose_halfwidth_voiced、normalize_public_food_name、public_food_name_char_is_word、public_food_name_contains_term、public_food_name_strip_phrase、public_food_name_term_uses_substring、public_food_name_is_banned）と、トリガー validate_saved_foods_public_row、SECURITY DEFINER の publish_saved_food。合計は依頼の「8」ではなく **9**。テストでも9件を数えている（`test/public_food_name_moderation_test.dart`）。 |
| 1-b | #26：関数本体をスキーマ付きで書いているか。search_path='' で壊れていないか | **未修正（新しい不具合、重大）** | 本体をスキーマ付きに書き換える際に、PostgreSQL の関数ではない構文にまで `pg_catalog.` を付けている。詳細は §2。**CREATE は成功するが、実行すると必ずエラーになる**（plpgsql は作成時に型や関数を解決しないため）。 |
| 1-c | #26：publish_saved_food（SECURITY DEFINER）は安全か | **一部** | 呼び出し側の search_path を使われる危険はなくなった（`search_path=''`、`auth.uid()`、`public.saved_foods%rowtype`、`pg_catalog.set_config` はどれもスキーマ付き）。ただし本体から `public.public_food_name_is_banned` → `normalize_public_food_name` → `compose_halfwidth_voiced` を呼ぶところで必ずエラーになり、**公開が一切できない**（安全側に倒れる壊れ方）。中から呼ぶ `public.ensure_publish_rate_limit_headroom` と `public.increment_publish_rate_limit` は既存の関数（`20260723120000_add_food_master_public_v1_1.sql`）で、各自が `search_path = public` を持つので、この変更では壊れない。 |
| 1-d | 書き換えたファイルは web-preview/main に無い新しいファイルか | **確認した（新しいファイル）** | `20260927120000_reject_banned_public_food_names.sql` を `web-preview` と `main` で取得すると、どちらも 404 だった。#26 のブランチ（ad750ba 以降）にしかない。本番DBに適用されていないことは、**DBを見ていないので未確認**。 |
| 2-a | #29：delete_own_account を service_role だけが実行できるか | **直った** | 94a8190 で追加した `supabase/migrations/20260927180000_delete_own_account_service_role_only.sql` の内容は次のとおり。①引数なしの旧関数を `drop function if exists public.delete_own_account()` で削除。②`delete_own_account(p_user_id pg_catalog.uuid)` を SECURITY DEFINER、`search_path=''` で作成。③最初に `auth.role() is distinct from 'service_role'` なら例外（二重の防御）。④public/anon/authenticated から `revoke all`、`grant execute ... to service_role` だけを付与。セッションとリフレッシュトークンの削除も引き継いでいる。 |
| 2-b | Edge Function が service role で呼び、JWT の本人だけを消すか | **直った** | `supabase/functions/_shared/apple_account.ts`（94a8190）の動き：`deleteAccount(userId)` は `apiKey` と `authorization` に service role key を使い、`body: { p_user_id: userId }` で呼ぶ。userId は `/auth/v1/user` に呼び出し元の JWT を渡して得た値で、`isUuid` で形式も検査する。リクエスト本文の `p_user_id` は使わない（Deno テスト「a body user id does not replace the authenticated user」）。アプリ側に `.rpc('delete_own_account')` は無く、それを確かめるテストもある（`test/apple_token_revocation_test.dart`）。 |
| 2-c | 前回の残課題：revoke を先に出すので、削除が失敗すると取り消しだけが残る | **未修正** | 23db22a で扱いが変わったのは「**削除は成功したが revoke が失敗した**」場合だけ（`{ok:true, apple_revoke_failed:true}` を返し、画面で案内する）。順序は revoke → 削除のまま（`revokeThenDeleteAccount`）なので、**削除に失敗すると Apple 連携だけが切れた状態**は残る。しかも 1-b の不具合があるため、**公開食品を持つ利用者は、今のコードでは削除が必ず失敗する**（§2-3）。 |
| 2-d | 前回の残課題：既存の Apple 利用者にはトークンが無い | **未修正**（仕様として受け入れている） | `supabase/functions/README.md`（23db22a）に「保存したトークンが無ければ revoke を飛ばし、`apple_revoke_failed` も付けない」とある。**利用者には何も案内されない**。Web/Android の Apple OAuth も同じ。 |
| 2-e | 失敗時の表示で、内部エラーや秘密を見せていないか | **問題なし** | `lib/constants/app_strings.dart`（23db22a）の文言は固定の日本語だけ（「アカウント削除を完了できませんでした。削除は行われていません。…」「Appleとの連携解除に失敗しました。設定 > Apple ID > …から解除できます」）。`account_deletion_rpc.dart` は、応答の本文を捨てて固定メッセージで例外を投げる。404 のとき（関数が無い）は「削除は行われていません」と表示し、ログアウトしない。Edge Function の応答は `{ok}` と `{apple_revoke_failed}` だけ。 |
| 2-f | privacy.html と PrivacyInfo.xcprivacy：技術的な事実がコードと合っているか | **概ね合っている（ずれ3点）** | 詳細は §3。**法的に妥当かどうかは判断していない。法務・リスク側の確認が必要。** |
| 3 | 秘密情報の混入 | **なし** | §4。 |

---

## 2. #26 の実行時エラー（詳細）

### 2-1. 存在しないものを呼んでいる

`COALESCE` と `GREATEST` は PostgreSQL の**構文**で、pg_catalog の関数ではない。`normalize(text, NFKC)` の第2引数は、構文の中で文字列 `'NFKC'` に変わるだけで、`normalization_form` という型は存在しない。

| 書き方（f01d3d8 時点） | 出てくる場所 |
|---|---|
| `pg_catalog.coalesce(...)` | compose_halfwidth_voiced（declare の中、21行付近）、normalize_public_food_name（68行付近）、public_food_name_strip_phrase（declare の中）、validate_saved_foods_public_row（brand、serving_unit_label、**栄養値のチェック**）、publish_saved_food（brand、serving_unit_label、栄養値） |
| `pg_catalog.greatest(...)` | public_food_name_strip_phrase |
| `'NFKC'::pg_catalog.normalization_form` | normalize_public_food_name（69行付近） |

### 2-2. 再現結果（ボックスの PostgreSQL 17.11）

- `select pg_catalog.normalize('ｱ','NFKC');` → 正常（`ア`）。
- `'NFKC'::pg_catalog.normalization_form` → `ERROR: type "pg_catalog.normalization_form" does not exist`
- `pg_catalog.coalesce(...)` → `ERROR: function pg_catalog.coalesce(...) does not exist`
- `pg_catalog.greatest(1,2)` → `ERROR: function pg_catalog.greatest(integer, integer) does not exist`
- `pg_catalog.regexp_like`（PG15 以降）と `pg_catalog.right` は正常。
- `search_path=''` の plpgsql 関数に `pg_catalog.coalesce` を入れると、**CREATE FUNCTION は成功し、呼び出したときにだけエラーになる**ことを確認した。
- `search_path=''` のまま、スキーマを付けない `coalesce` / `greatest` と `normalize(v,'NFKC')` は正常に動いた（pg_catalog は常に暗黙に検索される）。
- validate_saved_foods_public_row の栄養値チェック部分を同じ形で再現し、`before update` トリガーとして付けた。そのうえで `update saved_foods set owner_deleted = true where visibility = 'public'` を実行すると、`ERROR: function pg_catalog.coalesce(double precision, integer) does not exist` で失敗した。非公開の行は通る。

### 2-3. 影響（コードから導いた推論。実際のDBでは確かめていない）

- **公開食品の投稿：** `publish_saved_food` → `public_food_name_is_banned` → `normalize_public_food_name` で必ずエラーになり、公開できない。
- **公開済み食品の編集：** `validate_saved_foods_public_row` は `before update on public.saved_foods`（全列、`20260723120000_...sql`）。公開→公開の更新では、栄養値のチェックで必ずエラーになる。
- **通報：** `food_reports` に INSERT すると `sync_saved_foods_report_count` が `saved_foods.report_count` を更新し、上のトリガーが動いてエラーになる。通報の登録ごと失敗する見込み（App Store の UGC 要件にも関わる）。
- **アカウント削除：** `delete_own_account`（150000/160000/180000 のどれも）の中にある `update public.saved_foods set owner_deleted = true where ... visibility = 'public'` が上のトリガーで失敗し、**関数全体がロールバックされる**。公開食品を1件でも持つ利用者は削除できない。#29 の順序（revoke が先）と組み合わさると、**Apple 連携だけ解除されてアカウントは残る**。
- **見つからなかった理由：** Dart のテストは SQL の文字列を検査するだけ。`supabase/tests/public_food_banned_name_test.sql` は実行されていない（PR 本文でも「SQLは未実行」）。CI（9c57a42 / 12485a8 の `.github/workflows/ci.yml`）は `flutter analyze` と `flutter test` だけで、SQL を実行しない。

---

## 3. privacy.html / PrivacyInfo.xcprivacy：技術的な事実の抜き出し（3a141d6、84314e0）

**法的に妥当かどうかは判断していない。法務・リスク側の確認が必要。**

| 記述（要旨） | コードとの照合 |
|---|---|
| Sign in with Apple の更新用トークンを「暗号化してサーバーに保存」し、「アカウント削除時の連携解除だけに使う」 | 一致。Edge Function `store-apple-refresh-token` → `public.store_apple_refresh_token` → Supabase Vault に保存し、使うのは `delete-account` の revoke だけ。本番の Vault 暗号化の設定は未確認。 |
| トークンは「アカウントの削除が完了したときに削除」 | **ほぼ一致（ずれ1）**。削除に成功したあと `delete_apple_refresh_token` を呼ぶが、そこで失敗してもログを残すだけなので、Vault に行が残ることがある。 |
| account-deletion.html：「Sign in with Apple の連携（Apple 側の連携を解除します）」 | **ずれ2**。解除するのはトークンが保存されている利用者だけ。このリリースより前にログインした利用者と、Web/Android の Apple OAuth の利用者は解除されない（README に記載あり）。 |
| 購入状態は「端末内で確認し、購入の有無と期限だけを使う」 | 一致。期限は SharedPreferences `calonavi_plus_expires_at_ms`、`localVerificationData` は端末内で失効日を読むだけ。サーバーでの検証はない。 |
| 利用状況＝上限に初めて達した日時と、有料へ切り替えた日時。ユーザーIDに紐づける | draft と一致（`public.subscription_events`：user_id、event_type、created_at）。「初めて」だけを記録しているかは、コードを追っていないので未確認。 |
| Health は Apple Health の読み取りだけ（Health Connect の記述は削除） | iOS 版とは一致（`NSHealthUpdateUsageDescription` なし）。**ずれ3**：Android の Health Connect 用コードはリポジトリに残っている。Android 版を出す場合は記述と合わなくなる。 |
| Open Food Facts にはバーコードの数字だけを送る | 一致。User-Agent に入る連絡先は運営の定数で、利用者のメールではない。 |
| 公表日、保存国、バックアップ保持日数、手数料、OFF の運営主体が【…社長確認後に記入】のまま | 空欄のプレースホルダ。公開前に埋める必要がある。 |
| マニフェストに Fitness（App Functionality）、PurchaseHistory（Analytics）、OtherUserContent（App Functionality）、OtherDataTypes（App Functionality、Apple トークン）を追加 | `docs/app-review/app-privacy-draft.md` と一致。どれも Linked=true、Tracking=false。既にある EmailAddress、UserID、Health、ProductInteraction はそのまま。 |

---

## 4. 秘密情報の混入チェック

- **確認したコミット：** f01d3d8、23db22a、c4e0246、94a8190、3a141d6、84314e0、9c57a42、12485a8 の追加行と削除行。
- **結果：秘密情報はなし。**
  - Edge Function のテストにある `"service-key"` などはダミー値。
  - CI の workflow は secrets を参照していない。
  - `docs/app-review/demo-account.md` は「パスワードは書かない」方針で、実際に書かれていない。
- 秘密情報ではないが、報告しておくもの：
  - 公開用のサポート窓口メールアドレス（テストと docs）。
  - privacy.html の運営者名（個人情報に当たる可能性があるので、ここには転記しない）。
- **未確認：** rebase で作り直された他のコミット（ad750ba、eaa2816、43cdda3、ac34343、95f0528、7dec3d9、e7e4d5c、00e6410）は、今回は中身を取得していない。

---

## 5. PR別の判定

| PR | 判定 | 理由 |
|---|---|---|
| #25 | 条件付き（前回と同じ） | 追加は CI の2コミットだけで、秘密情報も問題もない。#27 と一緒に出すことが条件なのは変わらない。 |
| #26 | **出してはいけない** | §2 のとおり、関数を実行すると必ずエラーになり、公開・編集・通報・アカウント削除が壊れる。 |
| #27 | 条件付き（前回と同じ。今回は再検査していない） | 端末だけで利用権を判定する点が残る。 |
| #28 | 問題なし（今回は再検査していない。実機は未確認） | ― |
| #29 | 条件付き（#26 を直すまではマージしない） | service_role 限定と JWT の本人確認は直った。revoke を先に出す順序と、既存 Apple 利用者の扱いは未修正。スタックの下にある #26 の不具合で、公開食品を持つ利用者の削除が失敗する。 |

---

## 6. 対処案

1. **#26（必須）：** `pg_catalog.coalesce` → `coalesce`、`pg_catalog.greatest` → `greatest` に戻す（構文なのでスキーマを付けない。`search_path=''` でも pg_catalog は暗黙に検索される）。`'NFKC'::pg_catalog.normalization_form` → `'NFKC'`（または `normalize(x, NFKC)` の構文）に直す。本番に未適用で main/web-preview にも無い新しいファイルなので、その場で直してよい。
2. **SQL を実際に実行する検証を入れる：**
   - ローカルで `supabase db reset` のあと `supabase/tests/public_food_banned_name_test.sql` を流す。
   - 公開→公開の UPDATE、通報の INSERT、`delete_own_account(uuid)` を、公開食品を持つ利用者で実行する。
   - できれば CI に Postgres を使うジョブを追加する。Dart の文字列テストだけでは今回のような不具合は見つからない。
3. **#29：**
   - 削除を先に行い、成功してから revoke する（または、revoke の失敗や未実施を後から再試行できるキューに入れる）。
   - トークンが無い Apple 利用者にも、設定から解除する方法を案内する表示を出すか検討する。
   - Vault の行が残った場合の定期削除を用意する。
4. **文面：** account-deletion.html の「Apple 側の連携を解除します」は、実際に解除できる条件に合わせた表現にするか検討する。法務・リスク側の確認が必要。

---

## 7. 未確認事項

- 本番DBの状態（どのマイグレーションが適用済みか、PostgreSQL のバージョン、Vault の設定）。
- SQL をリポジトリのファイルそのままで実行すること（今回確かめたのは、該当する構文を抜き出した最小限の再現だけ）。
- Flutter/Deno のテスト（実行していない）と、実機での動作。
- Edge Function のデプロイと secrets の設定。
- rebase で作り直された他のコミットの中身と、前回のコミットとの差（取得していない）。
- publish の RPC が失敗したとき、アプリが PostgREST のエラー文言をそのまま画面に出すかどうか。
