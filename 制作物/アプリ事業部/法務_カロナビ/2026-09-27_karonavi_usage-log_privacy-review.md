# カロナビ：利用ログ（無料枠上限到達・有料切替日時）の記録開始に関するプライバシー下調べ

- 作成日：2026-09-27（JST）／作成：法務・リスク下調べ（Bot）
- 位置づけ：公式の原文をもとにした下調べです。法的な最終判断ではありません。
- 確認した原文（2026-09-27 JST 取得）
  - Apple「App privacy details on the App Store」 https://developer.apple.com/app-store/app-privacy-details/
  - 個人情報保護法（e-Gov） https://laws.e-gov.go.jp/law/415AC0000000057 （17・18・21・22・23・25・27・28・32・35条）
  - 同法施行令10条（e-Gov） https://laws.e-gov.go.jp/law/415CO0000000507
  - 個人情報保護委員会「ガイドライン（通則編）」（令和8年6月一部改正版と表示） https://www.ppc.go.jp/personalinfo/legal/guidelines_tsusoku/

---

## 1. CTO宛て回答文案

〇〇さん

カロナビで「無料枠の上限に達した日時」と「カロナビ+に切り替えた日時」を利用者IDに紐づけて記録する件について、Appleの公式ページと個人情報保護法を確認しました。

### 結論

1. 「利用データ／ユーザに関連付けられる／トラッキングなし」という大きな方向は妥当と考えます。ただし、次の3点は修正または確認が必要です。
2. 1点目として、有料に切り替えた日時は「購入 > 購入履歴（Purchase History）」としても申告するのが安全です。Appleは購入履歴を「アカウントや個人の購入、または購入傾向」と定義しています。
3. 2点目として、目的は「分析（Analytics）」だけにし、「製品のパーソナライズ（Product Personalization）」は外すのが正確です。Appleの区分に「製品改善」という項目はありません。Appleの定義では、既存機能の効果を把握したり新機能を計画したりすることは「分析」に含まれます。「製品のパーソナライズ」は、おすすめを出すなど、利用者に表示する内容を変える場合に限られます。
4. 3点目として、利用者IDをサーバーに送って保存する以上、「識別子 > ユーザID（User ID）」の申告も必要です。すでに申告済みかどうかは未確認のため、App Store Connectで確認してください。
5. 任意開示の例外には当たらないため、申告は省略できません。個人情報保護法の面では、プライバシーポリシーの利用目的が「製品改善のため」だけでは、特定が足りないと判断されるおそれがあります。何の情報をどう分析して何に使うのかを書き足してください。

### 申告の修正案

| データ種別 | 対象 | ユーザに関連付けられる | 目的 | トラッキング |
|---|---|---|---|---|
| 使用状況データ > 製品の操作（Usage Data > Product Interaction） | (a) 無料枠の上限に達した日時 | はい | 分析（Analytics） | なし |
| 購入 > 購入履歴（Purchases > Purchase History） | (b) 有料に切り替えた日時 | はい | 分析（Analytics） | なし |
| 識別子 > ユーザID（Identifiers > User ID） | (a)(b)を紐づける利用者ID | はい | 分析（Analytics）を追加。既存の申告に「App Functionality」などがあれば残します | なし |

条件によって変わる点は次のとおりです。

- (a)の記録を無料枠の上限判定そのもの（機能の制御）にも使う場合は、「App Functionality」も追加します。
- 記録を使って特定の利用者に表示を変える場合は、「Product Personalization」を追加します。有料プランへの勧誘を表示したり、マーケティング連絡を送ったりする場合は、「Developer's Advertising or Marketing」も追加します。どちらも現時点では予定していない前提ですが、この点は未確認です。
- (b)について、Appleは「Other Usage Data」を「アプリ内の利用者の行動に関するその他のデータ」と定義しているため、利用データとして扱う読み方もあり得ます。ただし「購入履歴」の定義の方が直接当てはまるため、購入履歴として申告する方が過少申告のリスクは小さいと考えます。

### 根拠（Apple公式ページの原文）

URLはすべて https://developer.apple.com/app-store/app-privacy-details/ です。

- 申告の義務："You need to identify all of the data you or your third-party partners collect, unless the data meets all of the criteria for optional disclosure"。「分析」や「広告」以外の目的で集める場合も、次のとおり申告が必要です："even if you collect the data for reasons other than analytics or advertising, it still needs to be declared."
- 「収集」の定義："transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time." 今回はサーバーに保存し、アカウント削除まで保持するため、これに当たります。
- (a)が「製品の操作」に当たる理由：Product Interactionの定義は "Such as app launches, taps, clicks, scrolling information, ... or other information about how the user interacts with the app" です。上限に達したという事実は、アプリの使われ方に関する情報です。
- (b)が「購入履歴」に当たる理由：Purchase Historyの定義は "An account's or individual's purchases or purchase tendencies" です。有料プランに切り替えた日時は、そのアカウントの購入の記録です。なお、支払手段そのもの（Payment Info）については、"If your app uses a payment service ... and you as the developer never have access to the payment information, it is not collected" とされています。App内課金だけを使う場合、Payment Infoの申告は不要と読めます。
- ユーザIDの申告：User IDの定義は "Such as screen name, handle, account ID, assigned user ID, customer number, or other user- or account-level ID that can be used to identify a particular user or account" です。
- 目的の定義
  - Analytics："Using data to evaluate user behavior, including to understand the effectiveness of existing product features, plan new features, or measure audience size or characteristics"
  - Product Personalization："Customizing what the user sees, such as a list of recommended products, posts, or suggestions"
  - App Functionality："Such as to authenticate the user, enable features, prevent fraud, ... or perform customer support"
  - Developer's Advertising or Marketing："Such as displaying first-party ads in your app, sending marketing communications directly to your users..."
- ユーザに関連付けられる："identify whether each data type is linked to the user's identity (via their account, device, or other details)"。関連付けないと言えるのは、収集前に "Stripping data of any direct identifiers, such as user ID or name, before collection" などの措置をとった場合に限られます。さらに "'Personal Information' and 'Personal Data', as defined under relevant privacy laws, are considered linked to the user." とされています。今回は利用者IDで紐づけるため、「関連付けられる」に当たります。
- トラッキング："linking data collected from your app about a particular end-user or device ... with Third-Party Data for targeted advertising or advertising measurement purposes, or sharing data ... with a data broker." 第三者提供・広告・データブローカーへの提供をしないという前提なら、トラッキングには当たりません。ただし、組み込んだSDKが他社アプリのデータと結びつける場合は、自社が広告に使っていなくてもトラッキングに当たります："Placing a third-party SDK in your app that combines user data from your app with user data from other developers' apps ... even if you don't use the SDK for these purposes."
- 任意開示の例外に当たらない理由：例外は全ての条件を満たす場合に限られます（"Data types must meet all criteria"）。今回の記録は自動的かつ継続的に行うものです。そのため、"Collection of the data occurs only in infrequent cases that are not part of your app's primary functionality, and which are optional for the user" と、"the user affirmatively chooses to provide the data for collection each time" のどちらも満たしません。
- 既存の申告への追加："If your practices change, update your responses in App Store Connect. ... you do not need to submit an app update in order to change your answers." Appleは既存の回答を最新に保つことを求めています。記録を始める前か、始めると同時に回答を更新してください。
- 無料・有料で集めるデータが違う場合の扱い："You collect different types of data from users depending on ... whether they are a free or paid user ... Please disclose all data collected from your app"

### 個人情報保護法の要点

- 利用目的はできる限り特定する必要があります（17条1項）。ガイドライン（通則編）3-1-1は、「お客様のサービスの向上」のような抽象的・一般的な書き方では、できる限り具体的に特定したことにはならないとしています。また、利用者の行動を分析する場合は、どのような取扱いをするのかを本人が予測・想定できる程度に特定するよう求めています。したがって、「製品改善のため」だけでは足りないと判断されるおそれがあります。
- 既存のプライバシーポリシーに今回の目的が含まれない場合は、利用目的の変更に当たります。変更は、変更前の目的と関連性があると合理的に認められる範囲内でなければならず（17条2項）、変更後の目的を本人に通知または公表する必要があります（21条3項）。記録を始める前にポリシーを改定して公表しておくのが確実です（21条1項）。
- 利用者IDが、メールアドレスなどのアカウント登録情報と容易に照合できる場合、今回の記録は個人情報になります（2条1項）。アカウントにどの情報を登録しているかは未確認です。

### 未確認点

1. 第三者提供・広告・トラッキングをしないという前提。解析SDK（Firebase等）を使うか、他社の広告SDKを組み込んでいるかも確認が必要です。
2. 現在のApp Store Connectの申告内容。特に、User IDと「購入履歴」を申告済みかどうかです。
3. 現在のプライバシーポリシーの利用目的と、ほかの記載の内容。
4. (a)を上限判定などの機能にも使うか。また、勧誘表示などで利用者ごとに表示を変える用途があるか。
5. 保存先がどこか（外部クラウドか、サーバーの所在国はどこか）。解析を外部に委託するか。
6. アカウント削除時のバックアップの扱いと、消去までにかかる期間。統計データとして残すものがあるか。
7. アカウント登録情報の範囲。利用者IDが個人情報に当たるかどうかに関わります。

### 社長判断・弁護士相談の推奨

- 保存先が外国のクラウドや解析サービスで、事業者が外国にある第三者に個人データを「提供」すると評価される場合は、28条の対応（本人の同意、または基準に適合する体制の確認）が問題になります。この場合は弁護士に相談することをおすすめします。条文上、28条1項が適用される場面では27条（5項の委託の例外を含む）は適用されません。クラウド利用が「提供」に当たるかについて委員会Q&Aは確認していないため、未確認です。
- プライバシーポリシーの改定文の最終版と公表日は、社長の承認をいただくのが適切です。

以上です。

---

## 2. プライバシーポリシー追記チェックリスト（PRの文面照合用）

| # | 項目 | 確認内容 | 根拠 |
|---|---|---|---|
| 1 | 取得する情報の明記 | 「無料プランの利用上限に達した日時」と「カロナビ+へ切り替えた日時」を、利用者ID（アカウント）に紐づけて記録することを書いているか | 17条1項／ガイドライン3-1-1 |
| 2 | 利用目的の具体性 | 「製品改善のため」「サービス向上のため」だけで終わっていないか。何を分析し、何に使うのかを書いているか。例：「無料プランの上限到達状況と有料プランへの切替状況を分析し、機能や料金プランの見直し、新機能の検討に利用します」 | 17条1項／ガイドライン3-1-1（「お客様のサービスの向上」等の抽象的な目的は不可。行動・関心を分析する場合は本人が予測できる程度に特定する） |
| 3 | 実際の用途との一致 | 勧誘表示、メール配信、機能の制御などに使うなら、その用途も書いているか。書いていない用途に使わないこと | 18条1項 |
| 4 | 目的変更の扱い | 既存の目的に含まれない場合、変更として公表しているか（公表日・改定日の記載）。記録開始より前に公表しているか | 17条2項／21条1項・3項 |
| 5 | 事業者情報 | 名称、住所、代表者氏名 | 32条1項1号 |
| 6 | 全保有個人データの利用目的 | 今回の項目がポリシー全体の利用目的一覧に反映されているか | 32条1項2号 |
| 7 | 開示等の手続 | 利用目的の通知、開示・訂正・利用停止・消去の請求の窓口と方法、手数料（定める場合） | 32条1項3号・35条 |
| 8 | 安全管理措置 | 講じた措置を具体的に書いているか。「ガイドラインに沿って実施」だけでは不適切とされています。外国で保存する場合は、国名とその国の制度を把握したうえでの措置（外的環境の把握）も書いているか | 23条／施行令10条1号／ガイドライン3-8-1・10-7 |
| 9 | 苦情の申出先 | 窓口名、連絡先 | 施行令10条2号 |
| 10 | 第三者提供 | 第三者提供をしない旨を書いているか。前提は未確認です。提供する場合は利用目的にその旨を書き、同意を取得しているか | 27条1項／ガイドライン3-1-1・3-8-1（※3） |
| 11 | 委託（外部の解析・クラウド） | 委託先を使う場合、委託の範囲内に限っているか、委託先を監督しているか。解析SDKの提供者が自社目的でデータを使う場合は委託の範囲を超えるおそれがあり、要確認 | 27条5項1号・25条／ガイドライン3-6-3 |
| 12 | 外国にある第三者 | 外国の事業者に提供する場合、28条の同意（事前の情報提供を含む）または体制整備の確認があるか | 28条1項〜3項 |
| 13 | アカウント削除時の消去 | 「アカウント削除時に、上記の記録を消去します」と明記しているか。バックアップから消えるまでの期間があるなら、「バックアップからは最長〇日以内に消去」のように実態どおり書いているか。個人を識別できない統計データを残すなら、その旨も書いているか。「直ちに完全に消去」など実態を超える表現になっていないか | 22条（利用する必要がなくなったときは遅滞なく消去する努力義務） |
| 14 | Appleの申告との整合 | ポリシーの記載とApp Store Connectの申告（種別・関連付け・目的・トラッキング）が食い違っていないか | Apple App Privacy Details（"Your app's privacy practices should follow ... all applicable laws"） |

---

## 3. リスク一覧用1行

| 対象 | 内容 | 根拠 | 影響 | 起きやすさ | 対応案 | 状態 |
|---|---|---|---|---|---|---|
| カロナビ：無料枠上限到達・有料切替日時の記録 | App Privacyの申告不足（購入履歴・ユーザIDが漏れる、目的の区分が誤る）と、ポリシーの利用目的が抽象的（「製品改善のため」のみ） | Apple App Privacy Details（Purchase History・User ID・Analyticsの定義）／個人情報保護法17条・21条・32条、ガイドライン通則編3-1-1 | 中（審査での指摘・修正対応、利用者の信頼低下、委員会の指導の可能性） | 中（修正しないまま記録を始めた場合） | 申告を「Product Interaction＋Purchase History＋User ID／関連付けあり／Analytics／トラッキングなし」に修正する。ポリシーに具体的な目的と削除時の扱いを追記し、記録開始前に公表する。SDKと保存先を確認する | 未着手（CTO確認待ち・前提は未確認） |
