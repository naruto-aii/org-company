# AYG（カロナビ）PR #25〜#29 セキュリティ再検査3

- 実施: 2026-09-27 21:10〜 JST（読み取りのみ。コメント・レビュー・マージ・ブランチ作成・clone・コード変更は一切なし）
- 手段: cursor-github MCP（get_commit / get_file_contents / list_check_runs_for_ref / get_job_logs ほか）、box上の使い捨て PostgreSQL 17.11（自作の小さなSQLのみ実行。リポジトリのファイルは実行していない。終了後に削除済み）
- 秘密情報は値を書かず、場所と種類だけを書く。運営者の個人名、共著者のメールアドレスは転記しない。

## 総合結論（1行）

前回の指摘はほぼ解消し、CIも PG17 で実SQLを流して成功した。残りは Android の Health 権限、9か所の穴埋め、本番での localhost 許可の3点。#27・#29 は条件付き。

## 0. 対象コミットの確認（「最新」か「修正そのもの」か）

| PR | head（現在） | base | 指定SHAの位置づけ |
|---|---|---|---|
| #25 | 5375576 | web-preview 9b4c961 | **head であり修正そのもの**。150000 のトリガの `pg_catalog.current_user` を `current_user` に戻す修正 |
| #26 | 6c63693 | 5375576 | **head だが修正の本体ではない**。SQL構文の修正本体は1つ前の **e2c04c8**。6c63693 は禁止語の追加・削除と `repro_pg17.sh` の追加 |
| #27 | 1168802 | 6c63693 | 作り直しのみ（後述 8） |
| #28 | 848c492 | 1168802 | 作り直しのみ（後述 8） |
| #29 | 199f23c | 848c492 | **head であり修正そのもの**（CORS）。順番の修正は1つ前の b0f6c1a、文言とメール書換失敗の修正はその前の 53c794d |

コミット時刻は 2026-09-27 21:01〜21:04 JST（GitHub の値は 12:01〜12:04Z）。

## 項目ごとの判定

| # | 項目 | 判定 | 要点 |
|---|---|---|---|
| 1 | #26 の SQL 構文と search_path | **直った** | coalesce / greatest / 'NFKC' は元の書き方に戻っている。9関数とも `set search_path = ''`。本物の関数と型は `public.` / `pg_catalog.` / `auth.` 付き。PG17 で再現確認済み |
| 2 | CI | **直った**（限界あり） | `postgres:17` サービスで全マイグレーションを適用し、公開・通報・削除を実行している。#26 と #29 の head で flutter と sql の両ジョブが success。#25 の head は flutter のみ |
| 3 | #29 の削除→解除の順番 | **直った** | トークンの読み出しと Apple 連携の照会 → 削除 → 解除 → Vault 行の削除、の順。削除に失敗したら Apple を呼ばず、Vault も消さない。トークンはログにもレスポンスにも出ない |
| 4 | CORS | **直った**（本番の localhost は要検討） | `*` はない。GitHub Pages は完全一致で比べている。localhost は URL を解析して hostname を完全一致で比べる。preflight は許可外に 403。verify_jwt と `/auth/v1/user` による検証は残っている |
| 5 | トークンのない既存 Apple ユーザー | **直った**（画面で案内する方式） | 削除の前に Auth 管理 API で Apple の identity を確認し、あれば `apple_revoke_failed` を返す。アプリは設定で解除する手順をダイアログで示してからログアウトする。事前のメール通知や、再認証してトークンを取り直す仕組みはない |
| 6 | privacy / account-deletion / xcprivacy | **一部** | ずれ1（トークン行が残りうる）とずれ2（トークンがない人への説明）は直った。ずれ3（Android の Health Connect）は未修正で、AndroidManifest に `health.READ_*` が4つ残っている。【…社長確認後に記入】は privacy.html に9か所（5種類）残っている |
| 7 | 秘密情報 | **混入なし** | 作り直した全20コミットを調べた（前回見ていない8件を含む）。本物の鍵やトークンはない |
| 8 | #25 の追加と #27/#28 | **#25 の追加は妥当。#27/#28 は前回と同一** | 5375576 は実行時バグの修正。#27/#28 の4コミットは、パッチまたはファイルの blob SHA が第1回のものと完全に一致した |

## PRごとの判定

| PR | 判定 | 理由 |
|---|---|---|
| #25 | **条件付き** | 5375576 で、saved_foods の insert/update が全部失敗する実行時バグを修正した。ただし #25 単体の CI は flutter だけで、SQL の実行確認は #26 以降の head で行われている。有料機能（Plus）の判定がクライアント側だけ、という前回からの条件は #27 と一緒に残る |
| #26 | **問題なし** | 構文を戻したことを PG17 で確認した。CI の sql ジョブも success（公開・通報・削除を実行）。本番 Supabase への適用は運用の手順として別に確認が必要 |
| #27 | **条件付き** | 中身は前回と同じ。StoreKit の購入判定が端末側だけ、という前回の条件はそのまま |
| #28 | **問題なし** | 中身は前回と同じ（blob SHA が一致） |
| #29 | **条件付き** | 順番、CORS、既存 Apple ユーザーの扱いは直った。残る条件は4つ。(a) privacy.html の穴埋め9か所、(b) Android の Health Connect 権限と説明のずれ、(c) 本番で localhost を許可するかの判断、(d) デプロイの順番（マイグレーション→シークレット→関数→アプリ）と本番での動作確認 |

「出してはいけない」に当たるものはない。

---

## 1. #26: SQL構文の戻しと search_path（判定: 直った）

確認したファイル: `supabase/migrations/20260927120000_reject_banned_public_food_names.sql` @ 6c63693

- 修正本体は e2c04c8。ba867be（search_path を空にしたコミット）で付けた次の3つを戻している。
  - `pg_catalog.coalesce` → `coalesce`
  - `pg_catalog.greatest` → `greatest`
  - `'NFKC'::pg_catalog.normalization_form` → `'NFKC'`
- 6c63693 時点のファイル全体で、この3つに `pg_catalog.` は付いていない。ヘッダーのコメントには「この3つは SQL の構文であり、カタログのオブジェクトではない。スキーマを付けない」と明記されている。
- `set search_path = ''` は次の9関数すべてにある。
  - compose_halfwidth_voiced
  - normalize_public_food_name
  - public_food_name_char_is_word
  - public_food_name_contains_term
  - public_food_name_strip_phrase
  - public_food_name_term_uses_substring
  - public_food_name_is_banned
  - validate_saved_foods_public_row
  - publish_saved_food（SECURITY DEFINER）
  - `set search_path = public` は残っていない。
- 本体の関数名は次のとおりスキーマ付きで、壊れていない。
  - `pg_catalog.normalize` / `char_length` / `substr` / `strpos` / `chr` / `replace` / `translate` / `ascii` / `right` / `btrim` / `regexp_like` / `regexp_replace` / `set_config`
  - `pg_catalog.uuid`
  - `public.*`
  - `auth.uid()`
  - 演算子（`||`, `<>`, `not in`, `between`）は、search_path が空でも pg_catalog から暗黙に解決される。
- `pg_catalog.regexp_like` は PG15 以降。config.toml の `major_version = 17` と合っている。

PostgreSQL 17.11 での再現（box。自作SQLのみ）:

| 試した書き方（`search_path=''` の plpgsql / sql 関数内） | 結果 |
|---|---|
| `pg_catalog.normalize(coalesce(p,''),'NFKC')`、`greatest(...)`、`pg_catalog.substr/char_length/btrim` | 成功（`ｶﾞＡＢ１` → `ガAB` + `x`。NULL 入力も成功） |
| `not pg_catalog.regexp_like(t,'[a-z]') and t not in (...)` | 成功 |
| BEFORE UPDATE トリガで `current_user not in ('postgres','supabase_admin')`（スキーマなし） | 成功。許可外のロールでは意図どおり例外になり、他の列の更新は通る |
| `pg_catalog.current_user` | 失敗（`missing FROM-clause entry for table "pg_catalog"`） |
| `pg_catalog.coalesce(null,'x')` | 失敗（`function pg_catalog.coalesce(unknown, unknown) does not exist`） |

→ 修正後の書き方は動く。修正前の書き方は実行時に落ちる。CI の `repro_pg17.sh` も同じ4つの失敗を確認している。

## 2. CI（判定: 直った。限界あり）

ワークフロー: `.github/workflows/ci.yml`。トリガは pull_request と、web-preview / main への push。

- **flutter ジョブ**: `flutter pub get` → `flutter analyze lib test --no-fatal-infos --no-fatal-warnings` → `flutter test`。analyze は警告では失敗しない。
- **sql ジョブ**（e2c04c8 で追加し、6c63693 で改訂）:
  1. `services: postgres:17` を起動する。認証は trust。`POSTGRES_PASSWORD` は CI 専用の使い捨ての値で、秘密ではない。
  2. Vault の代替拡張（`supabase/tests/pg_ext/`）をコンテナにコピーし、postgresql-client を入れて `supabase/tests/run_sql_smoke.sh` を実行する。
  3. `run_sql_smoke.sh` の中身は次の順。
     - `repro_pg17.sh`: 4つの誤った書き方が失敗することを確認
     - `pg_bootstrap.sql`: auth スキーマ、ロール、`auth.uid()` / `auth.role()` の代替を用意
     - `supabase/migrations/*.sql` を全部、順番に ON_ERROR_STOP で適用
     - テスト用ヘルパ
     - SECURITY DEFINER 関数の所有者を postgres に変更
     - `public_food_banned_name_test.sql`
     - `sql_runtime_smoke.sql`

最新 head のチェック結果（list_check_runs_for_ref。時刻は JST）:

| ref | ジョブ | 結果 | 実行時刻 |
|---|---|---|---|
| 5375576（#25） | flutter | success | 21:01:06〜21:03:00 |
| 5375576（#25） | sql | **なし**（#25 の ci.yml に sql ジョブがない） | — |
| 6c63693（#26） | flutter | success | 21:02:36〜21:04:30 |
| 6c63693（#26） | sql | success | 21:02:36〜21:03:22 |
| 199f23c（#29） | flutter | success | 21:04:20〜21:06:14 |
| 199f23c（#29） | sql | success | 21:04:20〜21:04:47 |

注釈は各ジョブ2件で、Node.js 20 の非推奨警告。失敗ではない。

#29 の sql ジョブのログ（get_job_logs）で確認したこと:
- `pg17 syntax repro passed`
- 20260722130000 から 20260927180000 までの全16マイグレーションに `apply ...` が出ている
- `sql smoke passed`
- サーバー側のログにある ERROR 4件は、repro で意図的に起こした4つ（coalesce / greatest / current_user / normalization_form）だけ

テストが通っている経路（`sql_runtime_smoke.sql`）:
- **公開**: 所有者として `publish_saved_food` を実行（search_path が空の SECURITY DEFINER 関数と、150000 のトリガを通る）
- **通報**: 別のユーザーとして `food_reports` に insert（report_count を同期する経路）
- **削除**: service_role として `delete_own_account(uuid)` を実行。auth.users のメールが書き換わったこと、公開食品が `owner_deleted=true` で残ることを確認
- 禁止語: 関数全般の真偽を確認

限界（未確認として扱う）:
- auth と Vault はスタブで、本物の Supabase ではない。GoTrue、PostgREST、Vault の暗号化は通っていない。
- 公開行を直接 UPDATE して禁止語を弾く経路は `public_food_banned_name_test.sql` にある。ただし smoke 側で、RLS 付きの authenticated ロールによる直接編集までは確認していない。ヘルパ（`ayg_test.set_auth` など）がロールを切り替えていることは名前と呼び出し方から読み取れるが、中身は今回精読していない。
- Edge Function の Deno テスト（`apple_account_test.ts`）は CI で実行されていない。ワークフローに deno の手順がない。Dart テストはソースの文字列を検査しているだけ。
- #25 単体では SQL が CI で実行されない。5375576 の修正は、#26 以降の head の sql ジョブで間接的に確認されている。

## 3. #29 の順番（b0f6c1a）（判定: 直った）

`supabase/functions/_shared/apple_account.ts` の `deleteThenRevokeAccount`（旧 `revokeThenDeleteAccount`）の処理順:

1. `readToken(userId)`: Vault からトークンを読み、**メモリに持つ**（削除の前）。
2. トークンがなければ `appleLinked(userId)`: `/auth/v1/admin/users/{id}` を service role で照会し、Apple の identity があるかを調べる（**削除の前**）。`delete_own_account` が `auth.identities` を消すので、この順は正しい。テストで「lookup before delete」を確認している。
3. `deleteAccount(userId)`: `delete_own_account(uuid)` を service role で呼ぶ。**失敗したら `delete_failed` を返し、Apple は呼ばず、Vault の行も消さない**。テスト「account deletion failure does not revoke / keeps the stored token」で確認している。
4. 削除に成功したときだけ、メモリのトークンで `revoke`。失敗したら `revokeFailed=true`。
5. `deleteStoredToken(userId)`: 解除に失敗しても Vault の行は消す。この削除に失敗したら行が残る。後で掃除するジョブはない。README と各文書に明記されている。

カスケードの確認:
- `delete_own_account`（20260927180000 @ 199f23c）は `vault.secrets` に触れない。`auth.users` は削除せず匿名化するだけ（メールを `deleted+<uid>@invalid.local` に書き換え）。
- `vault.secrets` の行（名前 `apple_refresh_token:<uid>`）には users への外部キーがない（20260927170000）。
- したがって、削除で Vault の行が連鎖して消えることはない。いずれにしてもトークンは削除の前に読んでいるので、解除には影響しない。

漏えい:
- ログは固定の文言と `logWithoutSecrets(status, code)` だけ。テストで「token not logged」と「token not in response」を確認している。
- レスポンスは `{ok:true}` / `{ok:true, apple_revoke_failed:true}` / `{ok:false}` だけで、Apple や DB のエラー本文は含まない。
- index.ts の例外処理も `{ok:false}` 500 を返すだけ。

残るリスク（低）:
- 削除に成功した直後に関数が異常終了した場合（タイムアウトなど）、Apple の連携とトークンの行が残る。このときクライアントは 500 を受けて「削除に失敗」と表示するが、実際には削除済み。
- 解除の fetch にタイムアウトの指定があるかは今回確認していない（未確認）。

## 4. CORS（199f23c）（判定: 直った。本番の localhost は要検討）

- 許可する Origin:
  - `https://naruto-aii.github.io` と文字列で完全一致（`===`）
  - `http:` で hostname が `localhost` か `127.0.0.1` と完全一致するもの（ポートは任意）
- `*` はない。Dart テストでも `Access-Control-Allow-Origin: *` がないことを検査している。
- 比べ方: 前方一致や部分一致ではない。localhost は `new URL(origin)` で解析し、hostname を完全一致で比べる。ユーザー情報（`user:pass@`）付きは拒否する。したがって次は通らない。
  - `http://localhost.evil.com`
  - `https://localhost`
  - `null`（URL として解析できない）
  - `https://naruto-aii.github.io.evil.com`
- 返すヘッダー: 許可したときだけ Origin をそのまま返し、`Vary: Origin` を付ける。`Allow-Methods: POST, OPTIONS`、`Allow-Headers: authorization, x-client-info, apikey, content-type`。`Access-Control-Allow-Credentials` は付けないので、Cookie では送られない。認証は Bearer ヘッダー。
- preflight: `OPTIONS` は許可された Origin なら 204（`Max-Age 86400`）、それ以外は 403 でヘッダーなし。preflight のあいだ DB や Apple は呼ばない（テストで calls が0件）。Authorization 付きの POST は必ず preflight を伴うので、許可外の Origin からは本体のリクエストが送られない。
- JWT: `supabase/config.toml` の `[functions.delete-account]` と `[functions.store-apple-refresh-token]` は、どちらも `verify_jwt = true` のまま。関数の中でも `/auth/v1/user` で本人を特定し、特定できなければ 401 を返す処理は変わっていない（CORS は応答を包むだけ）。CORS は認証の代わりになっていない。
- 本番のゲートウェイ（verify_jwt）が OPTIONS を関数まで通すかは、デプロイ前なので**未確認**。
- 共有される Origin: `naruto-aii.github.io` はそのアカウントの全 GitHub Pages サイトで同じ Origin になる。ただし Web プレビューのセッション保存領域も同じ Origin なので、CORS で新しく広がるリスクではない。

本番で localhost を許可することの危険度: **低**。
- 利用者の端末で `http://localhost:*` から配信されるページ（開発サーバー、悪意あるローカルソフトなど）は、この2関数を CORS 付きで呼べる。
- ただし利用者の JWT は `naruto-aii.github.io` の Origin に保存されている。localhost の Origin からは読めない（Origin はポートまで含めて別）。
- JWT を既に持っている攻撃者なら、CORS と関係なく curl で呼べる。
- したがって実害が増える場面は限られる。
- それでも本番では不要な許可なので、環境変数で本番では localhost を外す運用を勧める。

## 5. トークンを持たない既存の Apple ユーザー（判定: 直った。画面で案内する方式）

- サーバー側の処理:
  - Vault にトークンがない場合、削除の前に Auth 管理 API で Apple の identity を確認する（`identities[].provider` か `app_metadata.provider(s)` が `apple`）。
  - Apple と連携しているのにトークンがない場合: Apple は呼ばず、削除は完了させ、`{ok:true, apple_revoke_failed:true}` を返す。ログは「apple token missing for linked account」。
  - 照会に失敗した場合: フラグは付けず、ログに「apple identity lookup failed」を残す。この場合、本人には案内されない。
- アプリ側: `apple_revoke_failed` を受けると、ログアウトの前にダイアログ「アカウントは削除しました／Appleとの連携を自動では解除できませんでした。設定 > Apple ID > サインインとセキュリティ から解除できます」を出す（閉じるまでログアウトしない）。
- 文書: account-deletion.html に、トークンを保存していない場合（この機能より前のログイン、Web、Android）はサーバーから解除しないこと、設定から解除する手順が書かれている。
- 行っていないこと:
  - 既存ユーザーへの事前の通知（メールなど）
  - 削除のときに Sign in with Apple で再認証させ、認可コードを取り直して解除する仕組み
  - 改善するなら、この再認証方式が確実。

## 6. privacy.html / account-deletion.html / PrivacyInfo.xcprivacy（判定: 一部）

技術的な事実だけを書く。法的に妥当かどうかは、法務・リスク側の確認が必要。

| 前回のずれ | 今回 | 根拠 |
|---|---|---|
| ずれ1: トークンの削除はベストエフォートで、Vault の行が残りうる | **直った**（記載で解消） | privacy.html §10「その削除に失敗したときは、トークンの行が残ることがあります」。account-deletion.html と app-privacy-draft.md にも同じ趣旨。コード上も行が残る可能性はあり、掃除のジョブはない（記載と一致） |
| ずれ2: トークンがない人にも「Apple の連携を解除します」と書いていた | **直った** | account-deletion.html は保存している場合と保存していない場合に分けて書いている。privacy.html §3・§7(2)・§10 も「トークンを保存している場合だけ Apple に通信」「無い場合は通信しない」。コードの動作（トークンがないと Apple を呼ばない）と一致 |
| ずれ3: Health Connect の記載を消したが、Android のコードが残る | **未修正** | privacy.html に Health Connect の記載はない（「iPhone の設定から」とだけ書いている）。一方、`android/app/src/main/AndroidManifest.xml` @ 199f23c に `android.permission.health.READ_ACTIVE_CALORIES_BURNED` / `READ_HEIGHT` / `READ_WEIGHT` / `READ_EXERCISE` と `ACTIVITY_RECOGNITION` が残っている。提出は iPhone のみ（#28）だが、Android 版を配布すると文書とずれる |

PrivacyInfo.xcprivacy @ 199f23c:
- Tracking は false、トラッキングドメインは空。
- 収集データは9種類: EmailAddress、UserID（AppFunctionality と Analytics）、Health、Fitness、ProductInteraction（Analytics）、PurchaseHistory（Analytics）、OtherUserContent、OtherDataTypes（Apple のトークン）。すべて Linked、Tracking なし。
- privacy.html の記載（利用状況、トークン、Health の読み取りだけ）と技術的に矛盾する点は見つからなかった。
- 53c794d で Sign in with Apple の scope が email だけになった（fullName を削除）。Name を収集しない申告と合っている。

【…社長確認後に記入】が残っている箇所（privacy.html。9か所、5種類）:
- 【公表日】×2（見出しの最終更新日、§13 の改定履歴）
- 【国名】×4（§7(1) に2か所、§9 に2か所）
- 【その国の制度を踏まえた措置】×1（§9）
- 【バックアップの保持日数】×1（§10）
- 【手数料】×1（§11）

前回あった Open Food Facts の【運営主体と所在国】は埋まった。account-deletion.html には穴埋めがない（最終更新日は 2026-09-27）。

その他（参考。前回の3つのずれとは別）:
- account-deletion.html の「削除されるもの」には、評価、通報、ブロックの削除が書かれていない。privacy.html §10 には書かれていて、コード（`delete_own_account`）でも削除している。

## 7. 秘密情報（判定: 混入なし）

調べたコミット（作り直し後の全20件）:
- #25: 9c57a42, 12485a8, 5375576
- #26: 28572b7, e7b2f4e, 1382e4c, ba867be, e597cb4, e2c04c8, 6c63693
- #27: f2be49c, 240bd1c, 1168802
- #28: 848c492
- #29: 15b829b, a450ed7, 9df0dce, aef4659, 40db0f7, 53c794d, b0f6c1a, 199f23c

調べ方:
- 追加行を次のパターンで検索し、目でも確認した: `PRIVATE KEY` / `-----BEGIN` / `eyJ…` / `sk_live` / `sk_test` / `password[:=]` / `postgres(ql)://` / `AKIA` / `ghp_` / Google OAuth クライアントID / service_role key の代入 / 60文字以上の base64 風の文字列

一致したが秘密ではないもの:
- `supabase/functions/_shared/apple_account.ts`（15b829b）: PEM ヘッダーの文字列を取り除く `replaceAll("-----BEGIN PRIVATE KEY-----", "")`。コードの定数。
- `supabase/functions/_shared/apple_account_test.ts`（15b829b）: `crypto.subtle.generateKey` でテストのたびに生成した鍵を PEM にする処理。鍵そのものは埋め込まれていない。
- `test/apple_token_revocation_test.dart` / `test/apple_refresh_token_migration_test.dart`: 「秘密鍵が含まれていないこと」を検査する否定のテスト。
- CI の `DATABASE_URL=postgres://postgres@127.0.0.1:5432/postgres` と `POSTGRES_PASSWORD`: CI 専用のコンテナで使う固定の値。
- テスト用のダミー（`service-key`、`anon-key`、`TEAMID1234`、ダミーの JWT `…sig`）、公開しているサポートメール。
- コミットの SSH 署名（`-----BEGIN SSH SIGNATURE-----`）は公開の署名で、秘密ではない。

→ 本物のキー、トークン、パスワード、接続文字列はなかった。

## 8. #25 の追加分と、#27/#28 が同じかどうか

#25 の新しいコミット 5375576:
- `20260927150000_protect_owner_deleted_and_revoke_sessions.sql` のトリガ `saved_foods_reject_owner_deleted_change` で、`pg_catalog.current_user in (...)` を `current_user in (...)` に変えた。
- 修正前は、saved_foods への insert/update がすべて実行時エラーになっていた（上の PG17 再現と同じエラー）。
- **第1回の検査ではこのバグを見逃していた**。今回の修正は妥当で、秘密情報もない。
- #25 の CI（9c57a42, 12485a8）は flutter のジョブだけを追加している。

#27/#28（作り直しのみ、という説明の確認）:

| 今回 | 第1回 | 比べ方 | 結果 |
|---|---|---|---|
| f2be49c（StoreKit の価格と期限、利用状況の記録） | eb47e7b | ファイルごとのパッチ（行位置のヘッダーを除く） | 差分0行 |
| 240bd1c（subscription counts の search_path） | b20a880 | ファイルの blob SHA | 2ファイルとも一致 |
| 1168802（利用状況の削除、Plus の購入の流れ） | c03dd07 | ファイルごとのパッチ | 差分0行 |
| 848c492（PrivacyInfo、iPhone のみ） | bd3d3cb | ファイルの blob SHA | 4ファイルとも一致 |

→ #27/#28 は作り直しただけで、中身は同じ。変わったのは親コミットとコミットの時刻だけ。

## 直すとよいこと（優先順）

1. （#29）privacy.html の【…社長確認後に記入】9か所を埋める。
2. （#29/全体）Android 版を出す予定があるなら、Health Connect の権限と説明を合わせる。出さないなら、AndroidManifest の `health.*` 権限を外す。
3. （#29）本番では localhost の Origin を許可しない（環境変数で切り替える）。
4. （#29）削除の前に Sign in with Apple で再認証させて認可コードを取り直し、トークンがない既存ユーザーも解除できるようにする（任意）。Apple 連携の照会に失敗したときも、案内を出す側に倒す。
5. （CI）deno test（`apple_account_test.ts`）を CI に加える。#25 単体でも sql ジョブが回るようにする（または #26 と一緒にマージする）。
6. （#27）購入の判定をサーバー側で検証する（前回からの条件）。
7. account-deletion.html にも、評価、通報、ブロックの削除を書く。

## 未確認

- 本番 Supabase への適用、Edge Function のデプロイ、本物の Vault と GoTrue での動作（CI はスタブ）
- 本番のゲートウェイが OPTIONS の preflight を関数まで通すか
- 解除の fetch のタイムアウト
- Android 側の Dart コードが Health Connect を実際に呼んでいるか（今回はマニフェストだけ確認）
- #27/#28 の head（1168802, 848c492）のチェック結果（取得していない。中身は第1回と同じ）
- 実機での動作
- 法的に妥当かどうか: 法務・リスク側の確認が必要
