# カロナビ：PR #29 再判定（r2）privacy.html／App Privacy回答案／PrivacyInfo.xcprivacy

- 作成：2026-09-27 JST／法務・リスク下調べ（Bot）。法的な最終判断ではありません。確かめられない点は「未確認」と書いています。
- 対象：https://github.com/naruto-aii/AYG/pull/29 （Draft、head `23db22a`、base `e7e4d5c`）。前回判定：`2026-09-27_karonavi_pr29_review.md`（head `0efb0de`）
- 読んだもの（読み取りのみ。書き込みはしていません）：PR本文、`legal/privacy.html`、`docs/app-review/app-privacy-draft.md`、`ios/Runner/PrivacyInfo.xcprivacy`、`legal/account-deletion.html`、`docs/app-review/demo-account.md`、`ios/Runner/Info.plist`、`supabase/migrations/20260927140000_subscription_events.sql`、`…20260927180000_delete_own_account_service_role_only.sql`、`…20260723120000_add_food_master_public_v1_1.sql`、`lib/services/open_food_facts_service.dart`、`lib/config/open_food_facts_config.dart`、`lib/services/subscription_event_reporter.dart`（いずれも ref `23db22a`）

## 0. 判定

**条件付き可。** 文章の構成と App Privacy の申告は、前回の指摘をほぼ反映しています。PrivacyInfo.xcprivacy とも一致しています。
公表・マージの前に、次の2点を片付ける必要があります。

1. **空欄6つを埋めること。** 特に Supabase の国名と、その国の制度を踏まえた措置の2つです。これが埋まらないと、前回の必須①③は完了しません。
2. **利用者向けの本文から、作業用の文を消すこと。** 7章(1)と9章に残っています（§3 N1・N2）。

## 1. 前回の必須4点

| # | 項目 | 判定 | 根拠（23db22a） |
|---|---|---|---|
| ① | 保存地域の国名（Q&A 10-25） | **一部** | 「ソースに書かれていないため特定しません」は削除済みです。7章(1)で、クラウド事業者の所在国とサーバの所在国を分けて書く形になりました。ただし、どちらも【国名：社長確認後に記入】のままです |
| ② | Sign in with Apple のリフレッシュトークン | **直った** | 3章（取得・暗号化保存）、4章（連携解除の目的）、9章（暗号化保存）、10章（削除完了時に削除）に書かれています。account-deletion.html にも「Sign in with Apple の連携」が加わりました |
| ③ | 9章 安全管理措置（外的環境の把握を含む） | **一部** | 組織的・人的措置、技術的措置、外的環境の把握の3区分に書き直されています。ただし、外的環境の把握の国名と措置が空欄です。また「国名を記入したあと…に記載します」という作業用の文が残っています。物理的安全管理措置の記載はありません（任意ですが、あるほうが望ましいです） |
| ④ | App Privacy の Fitness 漏れ、xcprivacy との食い違い | **直った** | 回答案に Fitness（App Functionality）が追加されています。xcprivacy の収集データは Email・User ID・Health・Fitness・Product Interaction・Purchase History・Other User Content・Other Data Types の8種類です。回答案と、種類・関連付け・トラッキング・目的のすべてで一致しています。食事・アルコールは Health、評価・通報・ブロックは Other User Content、リフレッシュトークンは Other Data Types に振り分けられています |

## 2. 前回の「できれば」の状況

| 項目 | 判定 | メモ |
|---|---|---|
| 3章：利用状況に「初めて」と「含まないもの」を書く | 直った | 残る軽微な点：DB に `unique (user_id, event_type)` があるため、有料への切替も**最初の1回だけ**が記録されます。「最初に切り替えた日時」と書くと、実態とより正確に一致します |
| 4章：利用目的の補強、勧誘に使わない旨 | 直った | 「広告配信・個別の勧誘に使わない」が実態どおりかは未確認です（CTOの回答に含まれていません） |
| 7章：委託の書き分け | 直った | 保存・ログインと課金・バーコード照会の3つに分けています。Supabase を委託先とは書いていません。ただし、その理由の文は削除が必要です（N1） |
| account-deletion.html の削除対象 | 直った | アカウント情報・利用状況・Apple連携が加わりました。最終更新日は 2026-09-20 のままです（N3） |
| 11章：開示手続（利用目的の通知、記録の開示、メール非公開の場合） | 直った | 手数料は空欄です |
| 外部通信（Apple への連携解除の通信、OFF に送る内容） | 直った | 7章(2)(3)に書かれています |
| Health Connect | 直った | privacy.html から削除されています。回答案にも「iPhone提出では使わない」とあります（CTO回答3と一致） |
| Info.plist の文言 | 直った | 「カロリー目標の計算と記録の表示に使います」 |
| 購入状態（修正案C） | 直った | |
| demo-account.md の「回数」 | 直った | 「回数そのものはサーバーに保存しません」 |
| 改定日・改定履歴 | 一部 | 形は入りました。日付は空欄です |
| SIWA の fullName スコープ（データ最小化） | 未対応 | 回答案には「保存しない」とあります。任意の指摘です |

## 3. CTO回答との整合と、新しく見つかった点

**CTO回答1（購入情報）：矛盾なし。** Apple は「収集」を「端末外に送信し、リクエストの処理に必要な時間を超えて読める形で保存すること」と定義しています。端末内だけで処理するデータは収集に当たりません。
- レシートは端末内で処理しているので、収集ではありません。
- 一方、`converted_to_paid` の行（user_id と日時）はサーバーに送って保存します。これは「収集」に当たります。Purchase History の定義「An account’s or individual’s purchases or purchase tendencies」にも当たると読めます。
- したがって、Purchase History（Analytics）を申告するのは妥当です。
- subscription_events の区分は次のとおりです：`free_limit_hit` → Product Interaction（Analytics）、`converted_to_paid` → Purchase History（Analytics）、`user_id` → User ID。
- ポリシー3章（「購入状態は端末内で確認」「レシート・取引番号は含まない」）とも矛盾しません。

**CTO回答2（回数）：矛盾なし。** 回数はサーバーに送っていないので、申告も記載も不要です。

**CTO回答5（評価・通報・ブロック）：矛盾なし。** 回答案では Other User Content の根拠にこの3つの表が挙がっています。ポリシー3章にも「公開食品への評価、通報、ブロック」があります。削除関数でも、この3つは削除されます。ポリシー10章にこの3つの削除が書かれていない点は、できれば直す点です。

**リフレッシュトークン：矛盾なし。** Apple は、保存しないトークンなら申告不要としています。今回は保存するので、Other Data Types（App Functionality）として申告するのが整合的です。

**新しく見つかった点**

- **N1（必須）** 7章(1)の「同社が保存データを取り扱うかどうかは契約の確認後に決まるため、確認が終わるまで委託先とは記載しません」は、社内向けの作業メモです。公表版からは削除してください。
- **N2（必須）** 9章の「国名を記入したあと、…講じた措置を、【…】に記載します」も作業用の文です。空欄を埋めるときに、完成した文に置き換えてください（例は前回の修正案F）。
- N3 account-deletion.html は内容が変わったのに、最終更新日が 2026-09-20 のままです。公表日に揃えてください。
- N4 account-deletion.html の「Apple 側の連携を解除します」について。実装では、解除に失敗しても削除は続き、画面で手順を案内します。「解除できなかった場合は、画面で解除の手順をご案内します」と添えると、実態と一致します。
- N5 削除関数では、auth.users のメールアドレスを匿名化する処理が、例外を無視するブロックの中にあります。この処理に失敗すると、auth.users にメールアドレスが残る可能性があります。そうなると10章・account-deletion.html の「削除」と食い違います。失敗を検知して再処理できるかどうかは未確認です（CTO確認事項）。
- N6 削除後も、公開食品を紐づけるために、ユーザーID（匿名化済み）と削除日時が public.users に残ります。10章の「公開食品は上記のとおり残します」の近くに一言あるとより正確です（任意）。
- N7 Open Food Facts の公式プライバシーポリシーには、訪問者のIPアドレスとログを3年間保存すると書かれています。カロナビからの照会でも、端末のIPアドレスは同団体に届きます。このため「メールアドレスやユーザーIDは送りません」は正確ですが、「個人情報は一切送りません」とは書かないでください（§4）。App Privacy については、Apple のいう third-party partners は「アプリに組み込んだコード」を指します。OFF は API を呼ぶだけで SDK ではないので、申告対象外と読めます。ただし、この点は未確認で、判断事項です。

## 4. Open Food Facts 文面案（7章(3)の差し替え）

> (3) バーコード照会。バーコードから食品名と栄養成分を調べるため、フランスの非営利団体 Open Food Facts（フランス法（1901年7月1日法）に基づくアソシエーション、所在地：フランス）が運営するデータベースに、バーコードの数字だけを送ります。メールアドレス、ユーザーID、食事などの記録は送りません。通信の仕組み上、端末のIPアドレスなどの通信情報は同団体に届き、同団体のプライバシーポリシー（https://world.openfoodfacts.org/privacy）に従って取り扱われます。

- 出典（2026-09-27 JST 確認）
  - https://world.openfoodfacts.org/legal：「published by the non-profit organization Open Food Facts (French "Loi 1901" Association). Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France」。サーバは Fondation Free と OVH Foundation（いずれもフランス）が提供していると書かれています。
  - https://world.openfoodfacts.org/privacy：「association within the meaning of the law of 1st July whose head office is located at … Saint-Maur-des-Fossés (France)」。訪問者の IP とログは3年間保存するとされています。
- 送る内容（コードで確認済み、`23db22a`）：`lib/services/open_food_facts_service.dart` は `GET https://world.openfoodfacts.org/api/v3/product/{バーコード}?fields=code,product_name,nutriments,quantity,serving_size` だけを送ります。ヘッダーの User-Agent は `AYG/0.1 (OFF_CONTACT_EMAIL)` です。このメールアドレスはビルド時に決める運営の連絡先で、利用者のものではありません（`lib/config/open_food_facts_config.dart`）。ユーザーIDやトークンは送っていません。
- 書き方の注意
  - バーコードの数字だけなら個人データの提供には当たらない、と考えられます。そう考えるなら、OFF を「委託」や「第三者提供」の文脈（6章の例外列挙など）に入れないでください。一方で、「第三者提供・外国への移転には当たりません」と本文で断定することも避けてください。IPアドレスは相手に届きますし、その法的評価は未確認です。
  - 住所まで載せるかどうかは任意です。載せるなら出典どおり「21 rue des Iles, 94100 Saint-Maur-des-Fossés, France」とします。
  - 7章の見出しは「委託、外部サービスへの送信、外国での取扱い」のままで問題ありません。

## 5. 社長確認事項（残る空欄5つ）

1. **Supabase の国**（プロジェクトのリージョンはダッシュボードで確認。Supabase, Inc. の所在国は契約書・DPAで確認）と、**その国の制度を踏まえた措置**。
   - サーバが外国にある場合：Q&A 10-25 により、9章「外的環境の把握」に、国名とその国の制度を踏まえた措置を書く必要があります。
   - 契約上、Supabase が個人データを「取り扱う」立場にある場合：国内サーバであっても28条の問題になります（同意取得の場合は外国の制度等の情報提供、または体制整備の確認）。取り扱わない立場であれば28条には当たりません（Q&A 7-53・12-3）。
   - この判断と9章の最終文面は、弁護士への相談を推奨します（前回と同じです）。
2. **バックアップの保持日数**（Supabase のプランによります）。
3. **手数料**（無料か、金額はいくらか）。
4. **公表日**（利用状況の記録を始める前、つまりこの機能を含むアプリの公開前に、公表を済ませてください）。
※ Open Food Facts の運営主体と所在国は §4 で埋められます。

## 6. 出典

- Apple App privacy details（2026-09-27 JST 確認）：https://developer.apple.com/app-store/app-privacy-details/
  - 「"Collect" refers to transmitting data off the device …」
  - 「Data that is processed only on device is not "collected"」
  - 「if an authentication token or IP address is sent on a server call and not retained … you do not need to disclose」
  - Purchase History・Product Interaction・Other User Content・Fitness・Other Data Types の定義
  - 「"Third-party partners" refers to … external vendors whose code you've added to your app」
- 個人情報保護委員会Q&A 7-53、10-25、12-3、12-4（前回確認分。今回は再取得していません）
- Open Food Facts：https://world.openfoodfacts.org/legal 、https://world.openfoodfacts.org/privacy
- 個人情報保護法 17条・21条・23条・27条5項・28条・32条・33条5項
