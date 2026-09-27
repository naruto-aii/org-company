# カロナビ Supabase 本番 migration 適用手順案（20260927 の3本）

- 作成: 2026-09-27（日）19:00 頃 JST ／ 状態: **下書き（未承認・未実行）**
- 対象 migration: `20260927120000_reject_banned_public_food_names.sql`（PR #26）／ `20260927140000_subscription_events.sql`（PR #27）／ `20260927150000_protect_owner_deleted_and_revoke_sessions.sql`（PR #25）
- 前提資料: `/workspace/rollback/2026-09-27_karonavi_rollback_plan.md`（戻し手順案）
- 調べ方: GitHub `naruto-aii/AYG` を**読み取りのみ**（cursor-github の読み取りツール）。clone・書き込み・コメントなし。**本番 DB・Supabase 管理画面・App Store Connect は一切見ていない／触っていない。** Supabase 公式ドキュメント（Web）も参照。
- 「**未確認**」= リポジトリや文書からの推定で、本番・管理画面・実機ではまだ確かめていない点。
- 下書き SQL はすべて「**下書き・未検証**」。どの DB でも一度も実行していない。
- 秘密情報（DB パスワード、接続文字列、トークン）と利用者の個人データは本書に書かない。接続情報は `<...>` のプレースホルダ。

---

## 0. 要点（先に読む）

1. **ブランチごとに migration の中身が違う（重要）。** 2026-09-27 18:57 JST 時点で:
   - `20260927120000`: PR #26 のブランチ（`cursor/public-food-banned-names-eb80`）は新しい版（blob `9d4ac35`、15,712 byte。`compose_halfwidth_voiced` と `public_food_name_strip_phrase` あり、戻し SQL `supabase/rollback/20260927120000_..._down.sql` あり）。PR #27・#28 のブランチは**古い版**（blob `8819cf3`、12,208 byte。上記2関数なし、**戻し SQL ファイルもない**）。
   - `20260927150000`: PR #25/#26 は blob `6af2d84`（7,154 byte）、PR #27/#28 は blob `351face`（6,952 byte）。差は先頭コメントだけで SQL 本体は同じ（目視比較）。ただしファイルのハッシュは違う。
   - → **#27・#28 は最新の #26 の上に積み直し（rebase）してからマージする必要がある。** 本番に流すのは「`web-preview` にマージされた最終コミット」のファイルだけにし、そのコミット SHA とファイルの SHA-256 を記録する。
2. 3本の間に**直接の依存関係はない**。ただし 150000 を入れると、アカウント削除時に公開食品を UPDATE するようになり、既存トリガー `validate_saved_foods_public_row`（120000 で置き換え）が走る。既存の公開食品に不正値があると**その人のアカウント削除が失敗する**おそれ → 事前チェック SQL（§4-3）で 0 件を確認。
3. 適用はタイムスタンプ順（120000 → 140000 → 150000）に**同じ作業枠で3本まとめて**行う。1本だけ先に入れると、後から古いタイムスタンプを入れる際に `db push --include-all` が必要になる。
4. 新アプリは DB 未適用でも動くように作られている（コード確認）。旧アプリ・Web プレビューも DB 適用後に動く見込み。→ **DB を先に適用 → TestFlight 最終確認 → App Store 申請**の順を推奨。
5. **本番のバックアップ体制（プラン・日次バックアップ・PITR）はリポジトリからは確認できなかった**（§9）。適用直前の手動 pg_dump を必須とする。
6. アカウント削除で `subscription_events` の行が消えない（150000 の削除関数に入っていない）。**要判断**（§5-2）。
7. Sign in with Apple のトークン失効（Apple の revoke API）は、どの migration にも入っていない。積み上げ PR（クラウドエージェント作成中）は 18:57 JST 時点で GitHub 上に**まだ無い**（§6）。

---

## 1. 決める人・動かす人

| 役割 | 担当 | 内容 |
|---|---|---|
| 判断 | **CTO** | 適用するか、いつ・どの順で流すか、失敗時にどこまで戻すかを決める |
| 承認 | **社長** | 実行前に**明示の承認**を文字で残す（Slack 等。置き場所は**未確認**・要決定）。承認がなければ本番に一切触らない |
| 実行 | CTO（または CTO が指名した人） | 社長の承認後に実行。実行時刻（JST）、コミット SHA、ファイル SHA-256、各コマンドの結果を記録する |

- 承認は「どのコミットの、どの3ファイルを、何時に流すか」を明記した形で取る。戻し SQL を流すときも**別途**承認を取る（緊急時は電話等で先に口頭承認→後で文字に残す、の可否も要決定）。
- 本書の作成者（エージェント）は本番に触れていないし、触れない。

---

## 2. 前提条件（すべて満たすまで着手しない）

- [ ] PR #25 → #26 → #27 → #28 が最新の土台に積み直され、`web-preview` にマージ済み（または「マージする最終コミット」が確定済み）。§0-1 のブランチ差が解消されていること
- [ ] ローカル Supabase（Docker）で、**空の DB に全 migration を適用 → 3本の戻し SQL を逆順で適用 → 再度3本を適用**が通ること（PR 本文では psql / Docker がなく**一度も実行されていない**）。`supabase/tests/public_food_banned_name_test.sql` と `flutter test --tags integration` 相当も通すこと
- [ ] 本番の migration 履歴の確認（読み取り）: `supabase migration list --db-url "<接続URL・記録しない>"` で `20260920120000` までが Local/Remote とも揃い、`20260927...` の3本だけが Local のみになっていること
- [ ] Supabase Dashboard で**プラン・日次バックアップ・PITR の有無**を CTO が確認して本書 §9 に記入（**未確認**）
- [ ] 作業端末: Supabase CLI、`pg_dump` / `psql` / `pg_restore`（サーバーと同じ **17** 系推奨。`config.toml` は `major_version = 17`、本番の実バージョンは**未確認**）、`shasum`
- [ ] 作業時間帯: 利用者が少ない時間（例: 平日 10:00〜12:00 JST など、CTO が決める）。作業中はマージ・デプロイを止める
- [ ] テスト用アカウント（本番）を用意。**個人の Apple ID / Google アカウントは使わない**（削除テストで消えるため）
- [ ] 戻し SQL 3本（下書き含む）を手元に用意し、ファイルの SHA-256 を記録
- [ ] 接続情報は環境変数やパスワード入力で渡し、シェル履歴・ログ・本書・Slack に残さない（既存 `tool/prod_*_migration.sh` と同じ扱い）

---

## 3. 適用前バックアップ

### 3-1. 取るもの
| 種類 | 目的 |
|---|---|
| (a) 全体（custom 形式） | 最悪時の全体復元・一部テーブルの取り出し |
| (b) スキーマのみ | 関数・トリガー・権限の「適用前の姿」を残す（戻し SQL の答え合わせ） |
| (c) 影響テーブルのデータ（custom 形式） | 1人分・1テーブル分だけ戻す必要が出たとき用 |
| (d) Supabase CLI の dump（任意・二重化） | pg_dump と別経路のコピー |
| (e) 適用前の件数・定義の記録 | 適用後の比較用 |

影響テーブル（理由）:
- `public.saved_foods`（列追加・権限変更・トリガー追加・関数置換の対象）
- `public.users`（削除関数が更新。`subscription_events` の参照先）
- 削除関数が DELETE するテーブル: `meal_template_items`, `meal_templates`, `workout_template_items`, `workout_templates`, `food_ratings`, `food_rating_stats`（`saved_foods` 削除で連鎖）, `food_reports`, `blocked_food_creators`, `food_entries`, `exercise_entries`, `weight_entries`, `alcohol_entries`, `health_snapshots`, `app_settings`, `nutrition_settings`, `goals`, `profiles`, `rate_limit_buckets`
- `auth.users`, `auth.identities`, `auth.sessions`, `auth.refresh_tokens`（削除関数が更新・削除。postgres ロールで dump できるかは**未確認**）
- `supabase_migrations.schema_migrations`（履歴）

**注意:** これらのファイルには利用者の個人データ（メール、健康記録など）が含まれる。作業端末の権限 700 のフォルダに置き、クラウドストレージ・Slack・GitHub に上げない。保管期間と削除のルールは**要決定**。

### 3-2. コマンド（プレースホルダ。値は記録しない）
```bash
# 接続情報は対話入力や環境変数で渡す。echo しない。
read -s -p "DB password: " PGPASSWORD; export PGPASSWORD; echo
PROJECT_REF="<PROJECT_REF>"
DB_URL="postgresql://postgres@db.${PROJECT_REF}.supabase.co:5432/postgres"   # psql/pg_dump 用（パスワードは PGPASSWORD）
# Supabase CLI 用 URL はパスワードを%エンコードして埋め込む必要がある（既存スクリプトと同じ）。画面・ログに出さない。
CLI_DB_URL="<percent-encoded URL を環境変数で渡す>"

TS="$(TZ=Asia/Tokyo date +%Y%m%dT%H%M%S)JST"
BK="$HOME/Kalonavi_Backups/${TS}_20260927_migrations"
mkdir -p "$BK" && chmod 700 "$BK"

# (a) 全体
pg_dump "$DB_URL" --format=custom --no-owner --file="$BK/full_backup.dump"
# (b) スキーマのみ（public と auth の定義）
pg_dump "$DB_URL" --schema-only --schema=public --file="$BK/schema_public.sql"
pg_dump "$DB_URL" --schema-only --schema=auth --file="$BK/schema_auth.sql"      # 権限不足なら記録して続行可否を CTO 判断
# (c) 影響テーブルのデータ
pg_dump "$DB_URL" --format=custom --data-only \
  -t public.saved_foods -t public.users \
  -t public.meal_template_items -t public.meal_templates \
  -t public.workout_template_items -t public.workout_templates \
  -t public.food_ratings -t public.food_rating_stats -t public.food_reports \
  -t public.blocked_food_creators -t public.food_entries -t public.exercise_entries \
  -t public.weight_entries -t public.alcohol_entries -t public.health_snapshots \
  -t public.app_settings -t public.nutrition_settings -t public.goals \
  -t public.profiles -t public.rate_limit_buckets \
  -t supabase_migrations.schema_migrations \
  --file="$BK/affected_public_data.dump"
pg_dump "$DB_URL" --format=custom --data-only \
  -t auth.users -t auth.identities -t auth.sessions -t auth.refresh_tokens \
  --file="$BK/affected_auth_data.dump"                                          # 権限不足なら記録（未確認）
# (d) Supabase CLI（任意・二重化。db dump は auth/storage を除外する仕様）
supabase db dump --db-url "$CLI_DB_URL" -f "$BK/cli_schema.sql"
supabase db dump --db-url "$CLI_DB_URL" --data-only --use-copy -f "$BK/cli_data.sql"
supabase db dump --db-url "$CLI_DB_URL" --role-only -f "$BK/cli_roles.sql"
```

### 3-3. (e) 適用前の記録（読み取りのみ）
```sql
-- 件数（個人データは出さない。件数だけ）
select 'saved_foods' t, count(*) from public.saved_foods
union all select 'saved_foods_public', count(*) from public.saved_foods where visibility='public'
union all select 'users', count(*) from public.users
union all select 'users_deleted', count(*) from public.users where deleted_at is not null;

-- 関数の定義とハッシュ（戻し SQL と照合する）
select p.oid::regprocedure, p.proowner::regrole, md5(pg_get_functiondef(p.oid))
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in ('delete_own_account','publish_saved_food','validate_saved_foods_public_row')
order by 1;

-- saved_foods の権限
select grantee, privilege_type from information_schema.role_table_grants
 where table_schema='public' and table_name='saved_foods' order by 1,2;
```
結果は `$BK/pre_*.txt` に保存。

### 3-4. バックアップが使えるかの確認
1. 各ファイルが空でないこと、`shasum -a 256 "$BK"/* > "$BK/checksums.sha256"` → `shasum -a 256 -c` が OK。
2. `pg_restore --list "$BK/full_backup.dump" > "$BK/pg_restore_list.txt"` が成功し、`saved_foods` / `users` / `delete_own_account` などの項目が含まれること。`affected_*_data.dump` も同様。
3. （推奨・時間があれば）**ローカル Supabase に復元して件数を照合**する。本番には絶対に流さない。
   ```bash
   supabase start   # ローカル
   pg_restore --no-owner --data-only -d "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
     -t saved_foods "$BK/affected_public_data.dump"
   ```
   （ローカルのスキーマを先に揃える必要がある。手順の細部は**未確認**。復元後は `supabase stop --no-backup` で消す）
4. Dashboard の日次バックアップ／PITR がある場合は、最新のバックアップ時刻（または PITR の復元可能範囲）を JST で記録する。無い場合（Free プラン等）は**この手動バックアップが唯一の戻り先**になる（§9）。

**停止点 B:** 1〜2 のどれかが失敗したら**ここで中止**。何も適用していないので戻す作業はない。

---

## 4. 適用順・依存関係・事前チェック

### 4-1. 適用順
`20260927120000` → `20260927140000` → `20260927150000`（ファイル名＝タイムスタンプ順。`supabase db push` もこの順で流す）

### 4-2. 依存関係（SQL を全文読んだ結果）
| migration | 前提として必要なもの | 他の2本との関係 |
|---|---|---|
| 120000 禁止語 | `publish_saved_food`、`validate_saved_foods_public_row` トリガー、`ensure_publish_rate_limit_headroom` / `increment_publish_rate_limit`（20260723）、`serving_unit_label` 列（20260729）、PostgreSQL 13 以上（`normalize(..., NFKC)`） | 独立。150000 の削除関数が公開食品を UPDATE すると、120000 で置き換えたトリガーが走る（名前は変えないので禁止語判定は走らない） |
| 140000 利用イベント | `public.users`（外部キー）、`auth.uid()` | 独立。**削除関数（150000）はこの表を消さない**（§5-2） |
| 150000 削除強化 | `users.deleted_at` と `delete_own_account`（20260920）、`version` 列（20260727）、`serving_unit_label` 列（20260729）、権限の土台（20260801200000）、`auth.sessions` / `auth.refresh_tokens` | 120000 とトリガー経由で接する（上記）。140000 とは無関係 |

- 3本とも pg_cron・Edge Function・RLS ポリシー変更（140000 の新規ポリシーを除く）は**含まない**。
- 120000 は `begin/commit` を**持たない**。140000・150000 は自前で `begin; ... commit;`。Supabase CLI の `db push` が各ファイルをトランザクションで包むかは**未確認** → 120000 を psql で流す場合は `--single-transaction` を付ける（§4-4 案 B）。

### 4-3. 事前チェック SQL（読み取りのみ。1つでも想定外なら中止）
```sql
-- 1) PostgreSQL バージョン（13 以上。17 のはず・未確認）
show server_version;

-- 2) 履歴: 20260920120000 が入っていて、20260927... が入っていないこと
select version from supabase_migrations.schema_migrations
 where version >= '20260900000000' order by version;

-- 3) owner_deleted が既にあるか（PR #11 版の 20260920 を手で流していると既に有る可能性）
select column_name, data_type, is_nullable, column_default
  from information_schema.columns
 where table_schema='public' and table_name='saved_foods' and column_name='owner_deleted';

-- 4) 現在の delete_own_account の中身（どの版が入っているか）
select position('owner_deleted' in prosrc) > 0 as has_owner_deleted,
       position('auth.sessions' in prosrc) > 0 as has_session_revoke,
       proowner::regrole as owner
  from pg_proc where proname='delete_own_account' and pronamespace='public'::regnamespace;
-- owner が postgres であること（150000 のトリガーは current_user が postgres/supabase_admin/service_role のときだけ通す）

-- 5) saved_foods の列が 150000 の権限リスト（27列）+ owner_deleted 以外に無いこと
--    余分な列が出たら中止（その列が authenticated から書けなくなる）
select column_name from information_schema.columns
 where table_schema='public' and table_name='saved_foods'
   and column_name not in ('user_id','food_id','visibility','status','moderation_status','name',
     'normalized_name','base_amount','unit_type','kcal_per_base','protein_per_base','fat_per_base',
     'carb_per_base','source_type','barcode','brand','supplementary_weight','copied_from_food_id',
     'copied_from_owner_user_id','use_count','last_used_at','report_count','created_at','updated_at',
     'deleted_at','version','serving_unit_label','owner_deleted');   -- 0 行であること

-- 6) 150000 適用後に削除が失敗しうる公開食品（トリガーで弾かれる値）が無いこと
select count(*) from public.saved_foods
 where visibility='public'
   and (btrim(name)='' or btrim(normalized_name)='' or base_amount<=0
        or coalesce(kcal_per_base,0)<0 or coalesce(protein_per_base,0)<0
        or coalesce(fat_per_base,0)<0 or coalesce(carb_per_base,0)<0);   -- 0 であること

-- 7) 名前の衝突が無いこと（新規オブジェクトが既に存在しない）
select to_regclass('public.subscription_events') as subscription_events;          -- null
select proname from pg_proc where pronamespace='public'::regnamespace
   and proname in ('compose_halfwidth_voiced','normalize_public_food_name','public_food_name_is_banned',
                   'public_food_name_strip_phrase','public_food_name_contains_term',
                   'public_food_name_char_is_word','public_food_name_term_uses_substring',
                   'subscription_events_force_row','subscription_event_counts',
                   'saved_foods_reject_owner_deleted_change');                      -- 0 行

-- 8) auth 側の前提
select to_regclass('auth.sessions'), to_regclass('auth.refresh_tokens');
select data_type from information_schema.columns
 where table_schema='auth' and table_name='refresh_tokens' and column_name='user_id';

-- 9) pg_cron の有無（今回の3本は cron を作らない。前後で変化がないことの確認用）
select extname from pg_extension where extname='pg_cron';
-- 有る場合のみ: select jobid, schedule, command from cron.job order by jobid;  （結果は保存するが共有しない）
```
**停止点 P:** 想定外があれば中止。何も適用していない。

### 4-4. 適用コマンド
**案 A（推奨・既存スクリプトと同じ型）: `supabase db push` で3本まとめて**
```bash
# 1. ファイルの確認（マージ済みコミットで）
git rev-parse HEAD                                  # 記録
shasum -a 256 supabase/migrations/20260927*.sql     # 記録。§0-1 の blob と対応する版か確認
# 2. dry-run: この3本「だけ」が、この順で出ること
supabase db push --dry-run --db-url "$CLI_DB_URL" | tee "$BK/db_push_dry_run.txt"
# 3. 社長承認の再確認 → 適用
supabase db push --db-url "$CLI_DB_URL" | tee "$BK/db_push_apply.txt"
```
- dry-run に 3本以外（既存の migration など）が出たら**中止**（履歴のずれ。`migration repair` の要否を CTO が判断）。
- 既存の `tool/prod_*_migration.sh` は「対象以外の保留 migration があると止まる」作りなので、そのままでは使えない。同じ型で3本用のスクリプトを作る場合は、PR でレビューしてから使う（**未作成**）。

**案 B: 1本ずつ psql で流して、その都度確認（停止点を細かく取りたい場合）**
```bash
psql "$DB_URL" -v ON_ERROR_STOP=1 --single-transaction -f supabase/migrations/20260927120000_reject_banned_public_food_names.sql
# → §7 の 120000 分の確認 → OK なら履歴に記録
supabase migration repair 20260927120000 --status applied --db-url "$CLI_DB_URL"

psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20260927140000_subscription_events.sql   # 自前の begin/commit があるので --single-transaction は付けない
supabase migration repair 20260927140000 --status applied --db-url "$CLI_DB_URL"

psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20260927150000_protect_owner_deleted_and_revoke_sessions.sql
supabase migration repair 20260927150000 --status applied --db-url "$CLI_DB_URL"
```
- `repair` は履歴表に行を足すだけで SQL は流さない（Supabase CLI ドキュメント）。流した後に必ず付ける。付け忘れると次の `db push` で再実行される（3本とも再実行しても壊れない作りだが、140000 は `create table if not exists` なので OK、150000 は権限を付け直すだけ。**未検証**）。

---

## 5. migration ごとの中身・戻せるか・戻し SQL

### 5-1. 20260927120000 禁止語（PR #26）
**変えるもの**
- 新規関数7つ: `compose_halfwidth_voiced`, `normalize_public_food_name`, `public_food_name_char_is_word`, `public_food_name_contains_term`, `public_food_name_strip_phrase`, `public_food_name_term_uses_substring`, `public_food_name_is_banned`（すべて immutable。`anon`/`public` から実行権を外し、`authenticated` に付与）。※ #27/#28 の古い版には `compose_halfwidth_voiced` と `public_food_name_strip_phrase` が無い
- 置き換え: `validate_saved_foods_public_row()`（公開済み食品の name / normalized_name / brand / serving_unit_label が**変わったときだけ**禁止語判定。`set search_path = public` が付く）
- 置き換え: `publish_saved_food(text)`（公開時に4項目を禁止語判定。レート制限の加算より前）
- 既存データの書き換え・走査は**しない**（既に公開されている不適切な名前は残る）

**戻せるか:** 戻せる（関数だけでデータ変更なし）。戻すと禁止語チェックがサーバー側で効かなくなる（新アプリはアプリ内でも判定しているので、改造クライアント以外は止まる）。

**戻し SQL:** リポジトリにある（PR #26 ブランチの `supabase/rollback/20260927120000_reject_banned_public_food_names_down.sql`。**#27/#28 ブランチには無い**）。中身: 2関数を 20260723 の本体に戻し、`publish_saved_food` の実行権を付け直し、7関数を削除。
- 確認済み（目視）: 戻し先の本体は 20260723 の定義と同じ。20260723 以降にこの2関数を再定義した migration は無い（20260801200000 は権限のみ）。
- 注意（**未検証**）: `publish_saved_food` の権限は 20260801200000 で `revoke all ... from public, anon, authenticated` → `grant ... to authenticated` になっている。戻し SQL は `revoke all from public` + `grant to authenticated` だけで、`anon` への revoke はしないが、`create or replace` は既存の権限を保つので実害はない見込み。

### 5-2. 20260927140000 利用イベント（PR #27）
**変えるもの**
- 新規テーブル `public.subscription_events`（id, user_id → `public.users` on delete cascade, event_type ∈ {free_limit_hit, converted_to_paid}, created_at。`unique(user_id, event_type)`）、索引
- トリガー関数 `subscription_events_force_row()`（種別チェック、`auth.uid()` と user_id の一致チェック、created_at をサーバー時刻に固定。SECURITY DEFINER ではない）
- RLS 有効、ポリシー `subscription_events_insert_own`（authenticated は自分の行を INSERT のみ）
- 権限: `public, anon, authenticated` から全剥奪 → `authenticated` に INSERT、`service_role` に SELECT
- 集計関数 `subscription_event_counts()`（SECURITY DEFINER、`service_role` のみ実行可）

**戻せるか:** 構造は戻せる。ただし**表のデータ（誰が上限に当たった／課金したかの記録）は消える**。

**戻し SQL:** リポジトリにある（`supabase/rollback/20260927140000_subscription_events_down.sql`: トリガー → 2関数 → 表の順に drop）。戻す前にデータを残す場合（下書き・未検証）:
```sql
-- 下書き・未検証。出力には user_id が含まれるので $BK（権限700）にだけ保存
\copy (select * from public.subscription_events) to '<$BK>/subscription_events_before_down.csv' csv header
```

**要判断（削除との関係）:** 150000 の `delete_own_account` は `subscription_events` を**消さない**。`public.users` の行は匿名化して残す作りなので、外部キーの cascade も発動しない。→ 退会後も「user_id＋種別＋時刻」が残る。PR #28 のプライバシー表示では User ID を分析目的で「紐づく」としている。退会時に消すなら、4本目の migration（タイムスタンプは 20260927150000 より後）で削除関数に次を足す案（下書き・未検証）:
```sql
if pg_catalog.to_regclass('public.subscription_events') is not null then
  execute 'delete from public.subscription_events where user_id = $1' using uid;
end if;
```

### 5-3. 20260927150000 削除強化・セッション失効（PR #25）
**変えるもの**
- `saved_foods.owner_deleted boolean not null default false` を追加（無ければ）。列コメント
- `delete_own_account()` を置き換え: 公開食品に `owner_deleted = true` を付ける／`search_path = ''` と完全修飾名に変更／最後に `auth.refresh_tokens` → `auth.sessions` の本人行を DELETE（例外処理の**外**。失敗すると削除処理全体がロールバック）
- `saved_foods` の権限: `authenticated` のテーブル単位 INSERT/UPDATE を剥奪 → `owner_deleted` 以外の27列に列単位で付与。`service_role` に `owner_deleted` の INSERT/UPDATE を付与。SELECT は変えない
- トリガー `saved_foods_reject_owner_deleted_change`（current_user が postgres / supabase_admin / service_role 以外なら `owner_deleted` の変更を拒否）

**戻せるか:** ほぼ戻せる。失うもの:
- `owner_deleted` の値（列ごと消える）。ただし「作成者が退会済み」は `users.deleted_at` から作り直せる（下の下書き）
- 失効させたセッションは戻らない（退会者なので戻す必要もない）

**戻し SQL:** リポジトリにある（`supabase/rollback/20260927150000_protect_owner_deleted_and_revoke_sessions_down.sql`: 削除関数を 20260920 の本体に戻す → トリガーと補助関数を削除 → 列を削除 → `authenticated` にテーブル単位の select/insert/update を付け直す）。目視で 20260920 の本体と一致。
- 注意: 列単位の権限は列と一緒に消えるが、他の27列の列単位権限は残る（テーブル単位権限と重なるだけで実害なしの見込み・**未検証**）。

**部分的な戻し（下書き・未検証）:** 「セッション削除の部分だけが原因で削除が失敗する」ような場合、列・トリガー・権限は残して関数だけ差し替える案。上の down 全体より影響が小さい。
```sql
-- 下書き・未検証。150000 の delete_own_account から最後の2行（auth.refresh_tokens / auth.sessions の DELETE）だけを除いた版を
-- create or replace で流す。本文は 150000 のファイルからコピーして作る（ここには全文を載せない）。
-- 流した後: select position('auth.sessions' in prosrc) from pg_proc where proname='delete_own_account';  -- 0
```

**戻した後に owner_deleted を作り直す（再適用時・下書き・未検証）:**
```sql
update public.saved_foods sf set owner_deleted = true
  from public.users u
 where u.id = sf.user_id and u.deleted_at is not null and sf.visibility = 'public';
-- postgres で実行（トリガーは postgres を通す）
```

### 5-4. 参考: 既存 20260920120000 には戻し SQL が無い
- 本番適用済みと PR #25 本文にある（**未確認**）。今回は触らない。ファイルも**編集しない**（PR #11 はこのファイルを書き換える差分を持ったまま open。#11 はマージせず閉じる判断が必要・要確認）。
- 必要になった場合の下書き（未検証・非推奨）: `drop function if exists public.delete_own_account();`（`users.deleted_at` 列は残す）。アプリは「利用できません」表示になる（PGRST202 判定）。App Store の審査ガイドライン 5.1.1(v) でアカウント削除は必須なので、使うのは緊急時のみ。

---

## 6. 積み上げ PR（トークン失効・Sign in with Apple）との関係
- 2026-09-27 18:57 JST 時点で、PR #28 の上に積まれた PR は GitHub 上に**見当たらない**（open/closed とも最新は #28）。中身は**未確認**。
- 他の open PR（#1, #11, #15, #16）に新しい migration は無い。ただし #11 は `20260920120000` 自体を書き換える差分（`owner_deleted` 列追加と UPDATE）を含む → マージしないこと。
- 積み上げ PR が DB を変える場合の決めごと（案）:
  1. 新しい migration のタイムスタンプは `20260927150000` より後にする。
  2. `delete_own_account` を再定義するなら、150000 の変更（`owner_deleted`、セッション削除、`search_path=''`）を**含めた**本体にする（150000 を上書きして消さない）。
  3. Apple のリフレッシュトークン等を保存する表を作るなら、RLS・権限（README の方針どおり）・退会時の削除・暗号化の要否を明記し、戻し SQL を `supabase/rollback/` に用意する。
  4. Edge Function で Apple の revoke API を呼ぶ場合: **DB migration → Edge Function デプロイ → アプリ**の順。Apple の鍵（client secret 用の秘密鍵）は Supabase のシークレットに置き、リポジトリに入れない。revoke に失敗したときに削除全体を止めるか続けるかは要判断。
  5. 本書に「4本目以降」として手順・確認・戻しを追記してから適用する。

---

## 7. 適用後の確認

### 7-1. 定義の確認（読み取り SQL）
```sql
-- 履歴
select version from supabase_migrations.schema_migrations where version like '20260927%' order by 1;  -- 3行

-- 120000: 関数
select proname, proowner::regrole from pg_proc
 where pronamespace='public'::regnamespace
   and proname in ('compose_halfwidth_voiced','normalize_public_food_name','public_food_name_char_is_word',
                   'public_food_name_contains_term','public_food_name_strip_phrase',
                   'public_food_name_term_uses_substring','public_food_name_is_banned') order by 1;   -- 7行
select position('public_food_name_is_banned' in prosrc) > 0 from pg_proc where proname='publish_saved_food';            -- true
select position('public_food_name_is_banned' in prosrc) > 0 from pg_proc where proname='validate_saved_foods_public_row'; -- true
select has_function_privilege('anon','public.public_food_name_is_banned(text)','execute');           -- false
select has_function_privilege('authenticated','public.publish_saved_food(text)','execute');          -- true
-- 判定の抜き打ち（固定文字列のみ。利用者データは使わない）
select public.public_food_name_is_banned('カフェラテ') as should_be_false,
       public.public_food_name_is_banned('ポークソテー') as should_be_false2,
       public.public_food_name_is_banned('rape seed oil') as should_be_false3,
       public.public_food_name_is_banned('ｸｿ') as should_be_true;
-- 既存の公開食品に該当が何件あるか（件数だけ。書き換えはしない。対応は別途判断）
select count(*) from public.saved_foods where visibility='public' and public.public_food_name_is_banned(name);

-- 140000: 表・RLS・ポリシー・権限・トリガー・関数
select relrowsecurity from pg_class where oid='public.subscription_events'::regclass;                -- true
select polname, polcmd from pg_policy where polrelid='public.subscription_events'::regclass;          -- subscription_events_insert_own / a
select grantee, privilege_type from information_schema.role_table_grants
 where table_schema='public' and table_name='subscription_events' order by 1,2;
-- authenticated=INSERT のみ、service_role に SELECT、anon なし（service_role の他の既定権限は Supabase 既定に依存・未確認）
select tgname from pg_trigger where tgrelid='public.subscription_events'::regclass and not tgisinternal; -- subscription_events_force_row
select has_function_privilege('authenticated','public.subscription_event_counts()','execute');       -- false
select has_function_privilege('service_role','public.subscription_event_counts()','execute');        -- true

-- 150000: 列・トリガー・権限・関数
select data_type, is_nullable, column_default from information_schema.columns
 where table_schema='public' and table_name='saved_foods' and column_name='owner_deleted';           -- boolean / NO / false
select tgname from pg_trigger where tgrelid='public.saved_foods'::regclass and not tgisinternal order by 1;
-- saved_foods_reject_owner_deleted_change を含み、既存トリガー（enforce_saved_foods_owner_mutation 等）が残っていること
select privilege_type from information_schema.role_table_grants
 where table_schema='public' and table_name='saved_foods' and grantee='authenticated';                -- SELECT のみ（INSERT/UPDATE は列単位に）
select has_column_privilege('authenticated','public.saved_foods','owner_deleted','UPDATE');          -- false
select has_column_privilege('authenticated','public.saved_foods','name','UPDATE');                   -- true
select has_column_privilege('authenticated','public.saved_foods','serving_unit_label','INSERT');     -- true
select position('auth.sessions' in prosrc) > 0, position('owner_deleted' in prosrc) > 0, proowner::regrole
  from pg_proc where proname='delete_own_account';                                                   -- true / true / postgres
select has_function_privilege('authenticated','public.delete_own_account()','execute');              -- true
select has_function_privilege('anon','public.delete_own_account()','execute');                       -- false

-- 件数が変わっていないこと（§3-3 と比較）
select count(*) from public.saved_foods; select count(*) from public.users;

-- cron（有る場合）: §4-3 の結果と同じであること
```

### 7-2. 動作確認（TestFlight の新ビルド＋テスト用アカウント。個人のアカウントは使わない）
1. **食品の保存・編集（権限変更の影響確認）:** 非公開食品を新規作成 → 編集 → 同期が失敗しないこと。公開済み食品の栄養値を編集できること。
2. **禁止語:** 禁止語を含む名前で公開 → 「この食品名は公開できません。別の名前を入力してください。」が出て非公開のまま。「カフェラテ」は公開できる。※公開はレート制限（10件/時・30件/日）を消費する。テストで作った公開食品は後で非公開に戻す。
3. **利用イベント:** 無料枠の上限に当たる操作 → 次で1行増える（SQL は管理者で実行、user_id はテスト用アカウントのもの）
   ```sql
   select event_type, count(*) from public.subscription_events where user_id = '<TEST_USER_ID>' group by 1;
   ```
4. **アカウント削除（本番のテスト用アカウント）:**
   - 事前: テスト用アカウントで非公開食品1件・公開食品1件（無害な名前）・食事1件・体重1件を作る。さらに**別端末（または Web プレビュー）でも同じアカウントでログイン**しておく
   - アプリで削除 → ログイン画面に戻ること
   - SQL（管理者・件数のみ）:
     ```sql
     select
       (select count(*) from public.saved_foods where user_id='<TEST_USER_ID>' and visibility<>'public') as private_foods,   -- 0
       (select count(*) from public.saved_foods where user_id='<TEST_USER_ID>' and visibility='public' and owner_deleted) as public_kept, -- 1
       (select count(*) from public.food_entries where user_id='<TEST_USER_ID>') as food_entries,                           -- 0
       (select count(*) from public.weight_entries where user_id='<TEST_USER_ID>') as weight_entries,                       -- 0
       (select email is null and deleted_at is not null from public.users where id='<TEST_USER_ID>') as user_anonymized,    -- true
       (select count(*) from auth.identities where user_id='<TEST_USER_ID>') as identities,                                  -- 0
       (select count(*) from auth.sessions where user_id='<TEST_USER_ID>') as sessions,                                      -- 0
       (select count(*) from auth.refresh_tokens where user_id::text='<TEST_USER_ID>') as refresh_tokens;                    -- 0
     ```
   - 公開食品検索で、その食品が「削除済みユーザー」表示になること（表示文言は**未確認**）
5. **セッション失効の挙動（期待値）:**
   - もう一方の端末: リフレッシュトークンが消えているので、**アクセストークン（JWT）の期限が切れた時点で**更新に失敗し、ログアウト状態になるはず。期限までは API が通る可能性がある（Supabase の仕様: アクセストークンは exp まで有効）。本番の JWT 有効期限は**未確認**（ローカル設定は 3600 秒）。
   - 確認方法: もう一方の端末で最大「JWT 有効期限＋数分」待ってから操作 → ログイン画面になるか、同期エラーになるか記録（アプリがどう表示するかは**未確認**）。
   - 同じ Apple ID / Google アカウントで再ログインすると**新しい別ユーザー**になること（`auth.identities` を消しているため・**未確認**）。
   - **Sign in with Apple のトークンは Apple 側では失効していない**（本 migration の範囲外）。iPhone の「設定 > Apple ID > Apple でサインイン」にカロナビが残る見込み（**未確認**）。

**停止点 V:** 7-1 / 7-2 で想定外があれば §8 へ。

---

## 8. 失敗時の対応（停止点と戻す順番）

| いつ | 状態 | 対応 |
|---|---|---|
| バックアップ中（停止点 B） | 何も適用していない | 中止。原因を直して別日に |
| 事前チェック（停止点 P） | 何も適用していない | 中止。想定外の内容を CTO が判断（例: 余分な列 → 150000 の権限リスト修正 PR が必要） |
| 120000 の適用でエラー | 120000 は中途半端にならない（案 B は `--single-transaction`、案 A は CLI の扱い**未確認**） | 以降を流さない。エラー内容を記録。履歴表に 120000 が載っていないこと・関数が増えていないことを確認 |
| 140000 の適用でエラー | 120000 は適用済み、140000 はファイル内トランザクションで全体ロールバック | 150000 を流さずに止めるか、120000 だけで運用するかを CTO 判断。120000 は単独で問題ない |
| 150000 の適用でエラー | 120000・140000 は適用済み、150000 はロールバック | 同上。削除機能は 20260920 版のまま動く |
| 適用後の確認で不具合 | 3本とも適用済み | 下の「戻す順番」で、**原因の migration だけ**を戻すのを基本にする |
| 深刻（他人のデータが消えた等） | ― | 戻し SQL では戻らない。§9 のバックアップ／手動 dump からの復元を CTO・社長で判断。全体リストアはその後の**全員の**変更を巻き戻す |

**戻す順番（全部戻す場合）:** 適用の逆 = **150000 → 140000 → 120000**。それぞれ:
1. 社長の承認（戻しにも必要）
2. 戻す直前にもう一度バックアップ（§3-2 の (a)(c) だけでよい）
3. 戻し SQL を流す: `psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/rollback/<該当>_down.sql`
4. 履歴を直す: `supabase migration repair <version> --status reverted --db-url "$CLI_DB_URL"`
5. git 側: migration ファイルを消す revert PR を作るか決める。**ファイルが残ったままだと次の `db push` でまた適用される**
6. 確認: §7-1 の各項目が「適用前」（§3-3 の記録）に戻っていること。`supabase db push --dry-run` の結果を保存
- 1本だけ戻すとき: 3本は独立なので、該当の1本だけ戻してよい。ただし 150000 を戻した後に 120000 だけ残るのは問題ない／140000 を戻してもアプリは insert 失敗を無視する作り（コード確認）。

---

## 9. Supabase のプラン・バックアップ・復元能力

### 9-1. リポジトリで見つかったこと（読み取り・2026-09-27 JST）
- **プラン・日次バックアップ・PITR・リージョンを示す記述は見つからなかった。**
  - 見た場所: `supabase/config.toml`、`tool/prod_goal_pace_migration.sh`（他の `tool/prod_*.sh` はファイル名のみ確認）、`README.md`、`supabase/migrations/README.md`、`docs/01_Project.md`、`docs/02_System_Architecture.md`、`docs/specifications/09_Food_Master_v1_2_Decision_Log.md`、PR #25〜#28 の本文、`web-preview` の `supabase/.temp/`（`cli-latest` と `pgdelta` のみ。`pooler-url` 等の地域が分かるファイルは無い）。
  - `docs/03_DB.md`・`docs/05_DECISION_LOG.md`・`docs/06_CHANGELOG.md`・`docs/07_TODO.md` はツールで中身を取得できなかった（**未確認**）。GitHub のコード検索はこのリポジトリで結果 0 件（索引なし）だったため、全文検索はできていない。
- `config.toml` にある「Pro plan で利用可能」等の文言は、Supabase の雛形のコメントで、**このプロジェクトの契約プランを示すものではない**。
- 既存の本番作業スクリプトは、毎回 `pg_dump` で `~/Kalonavi_Backups/<UTC時刻>_<作業名>/` に full / schema / data を取り、`pg_restore --list` で確認する作り。Dashboard のバックアップに頼らず手動 dump を前提にしていることは分かるが、プランの証拠にはならない。
- 接続先は `db.<project-ref>.supabase.co:5432`（直接接続）。ホスト名にリージョンは含まれない。
- PostgreSQL の版: `config.toml` の `major_version = 17`（「リモートと同じにすること」とコメント）。本番の実際の版は**未確認**。
- **結論: 契約プラン・日次バックアップの有無・PITR の有無と保持期間・リージョンは、Supabase Dashboard（Settings / Billing、Database > Backups、Point in Time）を見ないと確認できない。本書の作成者は Dashboard を見ていないので未確認。**

### 9-2. Supabase 公式ドキュメント上のプラン別の復元能力（2026-09-27 JST 参照）
| プラン | 日次バックアップ | 保持 | PITR |
|---|---|---|---|
| Free | なし（CLI の `db dump` で自分で定期的に取ることを推奨） | ― | 不可 |
| Pro | あり（毎日自動） | 直近 7 日 | アドオン（有料）。Small 以上の compute アドオンが必要 |
| Team | あり | 直近 14 日 | アドオン |
| Enterprise | あり | 最大 30 日 | アドオン |

- PITR の保持期間は 7 / 14 / 28 日から選択（料金はおよそ月 $100 / $200 / $400）。WAL を通常 2 分ごとに保存し、最悪でも約 2 分前まで戻せる（RPO 2 分）。**PITR を有効にすると日次バックアップは取られなくなる。**
- 復元はプロジェクト全体の巻き戻しで、復元中はプロジェクトに接続できない（停止時間あり）。Storage のファイル本体は含まれない。カスタムロールのパスワードは日次バックアップに含まれない。
- 出典: Supabase Docs「Database Backups」 https://supabase.com/docs/guides/platform/backups ／ CLI リファレンス（`db dump` / `db push` / `migration repair`）https://supabase.com/docs/reference/cli/supabase-db-dump ・ https://supabase.com/docs/reference/cli/supabase-db-push ・ https://supabase.com/docs/reference/cli/supabase-migration-repair

### 9-3. 本件への影響
- Free プランなら、**適用直前の手動 pg_dump（§3）が唯一の戻り先**。Pro なら直近の日次バックアップ（最大 1 日分の巻き戻し）も使えるが、全体の巻き戻しになる。
- 1人分・1テーブル分だけ戻したい場合は、どのプランでも手動 dump から該当行を取り出して入れ直す手順が必要（**未作成**）。
- 申請（10/7）前に CTO が Dashboard で確認し、本節の表に「カロナビの実際の状態」を追記すること。

---

## 10. アプリのビルドとの関係・後方互換

### 10-1. 新アプリ（PR #25〜#28 入り）× DB 未適用（コード確認）
- 120000 なし: アプリ内の禁止語チェックは効く。サーバー側では止まらない。
- 140000 なし: `subscription_events` への insert は失敗するが、アプリは例外を握りつぶして続行（`InsertingSubscriptionEventReporter`）。
- 150000 なし: `owner_deleted` が返らない → アプリは `row['owner_deleted'] == true` で判定するので false 扱い（「削除済みユーザー」表示が出ないだけ）。削除は 20260920 版で動くが、セッションは消えない。
- → 新アプリは DB の適用前後どちらでも動く見込み。

### 10-2. 旧アプリ（現在の `web-preview`、既存の TestFlight ビルド）× DB 適用後
- 120000: 旧アプリはアプリ内判定なし。サーバーが拒否し、旧アプリは一般的な公開失敗として表示する見込み（エラー文の対応は #26 で追加。旧アプリの表示は**未確認**）。
- 140000: 旧アプリは使わない。影響なし。
- 150000: 新アプリの保存処理（`savedFoodToRow`）は `owner_deleted`・`moderation_status`・`report_count` を送らない。送る列はすべて列単位権限のリスト内。旧アプリの保存処理も同様と見込むが、`web-preview` 側の送信列は**未確認**（リスト外の列を送ると 42501 権限エラー）。`select()` は全列のままなので読み取りは影響なし。
- Web プレビューと本番アプリが同じ Supabase プロジェクトかは**未確認**。同じなら、Web プレビューにも同時に効く。

### 10-3. 推奨の順番
1. PR を積み直し（§0-1）→ ローカルで up/down/up（§2）
2. **本番 DB に3本を適用**（本書の手順。社長承認後）
3. `web-preview` へのマージ（Web プレビューが自動公開される。社長承認）
4. TestFlight ビルド（10/3〜）で §7-2 を実施。10/6 の最終確認で削除テストを本番のテスト用アカウントで行う
5. App Store 申請（10/7）。審査員は本番の DB を使うので、**申請前に DB 適用が終わっていること**
- DB の変更は旧アプリと両立する見込みのため「DB 先・アプリ後」で問題ない。逆（アプリ先）でも動くが、審査・TestFlight の確認が最終状態の DB で行われないので避ける。

---

## 11. 未確認事項・要判断（まとめ）
1. 本番の契約プラン・日次バックアップ・PITR・リージョン・PostgreSQL の版（§9）
2. `20260920120000` が本当に本番適用済みか、どの版（PR #11 の `owner_deleted` 入り版を手で流していないか）（§4-3 の 2〜4）
3. PR #27/#28 の積み直し（120000 の新旧差、戻し SQL の有無）（§0-1）
4. Supabase CLI の `db push` が各ファイルをトランザクションで包むか（§4-2）
5. postgres ロールで `auth` スキーマを dump できるか（§3-2）
6. 本番の JWT 有効期限（セッション削除後も最大その時間は使える）（§7-2）
7. 退会時に `subscription_events` を消すか（§5-2）— **要判断**
8. Sign in with Apple のトークン失効（Apple revoke API）の実装と、積み上げ PR の中身（§6）— **要判断**
9. 旧アプリ（`web-preview`）の保存処理が送る列、禁止語エラー時の表示（§10-2）
10. Web プレビューと本番アプリが同じ Supabase プロジェクトか（§10-2）
11. 既存の公開食品に禁止語該当があった場合の扱い（§7-1。migration は既存行を書き換えない）
12. バックアップファイル（個人データを含む）の保管期間・削除ルール（§3-1）
13. 承認を残す場所（Slack スレッド等）と、緊急時の口頭承認の可否（§1）
14. 3本用の本番適用スクリプトを既存の型で作るか（**未作成**）（§4-4）

---

## 付録: 確認に使ったファイルとバージョン（読み取りのみ・2026-09-27 18:57 JST 時点）
| ファイル | ブランチ | blob |
|---|---|---|
| `supabase/migrations/20260927120000_reject_banned_public_food_names.sql` | PR #26 `cursor/public-food-banned-names-eb80` | `9d4ac350`（新・全文確認） |
| 同上 | PR #27 / #28 | `8819cf36`（旧・全文確認） |
| `supabase/migrations/20260927140000_subscription_events.sql` | PR #27 / #28 | `31265f2b`（全文確認） |
| `supabase/migrations/20260927150000_protect_owner_deleted_and_revoke_sessions.sql` | PR #25 / #26 | `6af2d84f`（全文確認） |
| 同上 | PR #27 / #28 | `351face7`（全文確認。コメント以外同じ） |
| `supabase/migrations/20260920120000_delete_own_account_keep_public_foods.sql` | 各ブランチ共通 | `7544a630`（全文確認） |
| `supabase/rollback/20260927120000_..._down.sql` | PR #26 のみ | 全文確認 |
| `supabase/rollback/20260927140000_subscription_events_down.sql` | PR #27 / #28 | 全文確認 |
| `supabase/rollback/20260927150000_..._down.sql` | PR #25〜#28 | 全文確認 |
| PR の先頭コミット（参考） | #25 `947a8b13` / #26 `3035c581` / #27 `e81c3200` / #28 `70f0bb0c` | GitHub API の値 |
