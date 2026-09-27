import '../models/activity_level.dart';
import '../models/goal.dart';

/// Version 1.1 ユーザー向け表示文字列（日本語）。
class AppStrings {
  AppStrings._();

  static const appTitle = 'カロナビ';

  static const loginTagline = '毎日の食事と運動を、やさしく見える化。';

  /// 暫定アプリアイコン内の表示文字（正式アセット確定まで）。
  static const provisionalAppIconText = 'カ';

  static const navHome = 'ホーム';
  static const navFood = '食事';
  static const navWorkout = '運動';
  static const navWeight = '体重';
  static const navSettings = '設定';

  static const settingsTitle = '設定';
  static const settingsBasicInfo = '基本情報';
  static const settingsGoal = '目標設定';
  static const settingsHealthActivity = '活動・ヘルスケア';
  static const settingsFoodMaster = 'マイ食品';
  static const settingsAccount = 'アカウント';
  static const settingsLogout = 'ログアウト';
  static const settingsLoggedInAs = 'ログイン中';
  static const settingsContactOperator = '運営への連絡';
  static const settingsSupport = 'サポート';
  static const settingsTokushoho = '特定商取引法に基づく表記';
  static const settingsAccountDeletion = 'アカウント削除';
  static const settingsAccountDeletionSubtitle = '公開食品は残ります。アプリ内で削除できます';
  static const accountDeletionLead =
      '削除するとログインできなくなります。公開食品は残ります。作成者欄は「削除済みユーザー」になります。';
  static const accountDeletionRemoves = '削除されるもの';
  static const accountDeletionKeeps = '残るもの';
  static const accountDeletionBilling =
      'ストアの定期購入は、この操作では止まりません。先に各ストアで解約してください。';
  static const accountDeletionConfirmTitle = 'アカウントを削除しますか？';
  static const accountDeletionConfirmBody =
      'この操作は取り消せません。個人の記録は消えます。公開食品は残り、作成者は「削除済みユーザー」と表示されます。';
  static const accountDeletionExecute = 'アカウントを削除する';
  static const accountDeletionUnavailable =
      '自動削除はまだ使えません。サポートメールから削除を依頼できます。';
  static const accountDeletionMailSubject = 'アカウント削除';
  static const accountDeletionFailed = '削除に失敗しました';
  static const accountDeletionReadPolicy = '詳しい説明を読む';
  static const loginLegalAgreement = 'ログインにより、利用規約とプライバシーポリシーに同意したものとします。';
  static const loginAppleUnavailableOnWeb = 'このプレビューでは Apple ログインは使えません。';
  static const plusTitle = 'カロナビ+';
  static const plusLead =
      '公開食品検索とテンプレートの上限を外します。記録・Health・バーコードはこれまでどおり無料です。';
  static const plusFreeQuota =
      '無料枠: 公開食品検索 5回/日、食事テンプレート 3件、運動テンプレート 3件。';
  static const plusRestore = '購入を復元';
  static const plusPurchaseUnavailable = 'この画面では購入できません。iPhone のアプリから購入してください。';
  static const plusLegalNote =
      '価格は税込です。購入画面の表示が正です。定期購入の解約は App Store の設定から行います。';
  static const plusActive = '加入中';
  static const plusInactive = '無料枠あり';

  static const birthDate = '生年月日';
  static const gender = '性別';
  static const heightCm = '身長 (cm)';
  static const currentWeightKg = '現在体重 (kg)';
  static const goalType = '目標区分';
  static const targetWeightKg = '目標体重 (kg)';
  static const targetDate = '目標日';
  static const activityLevel = '活動量';
  static const healthIntegration = 'Health連携';
  static const healthResync = 'Healthから再取得';
  static const healthUsingActiveEnergy = 'Healthのアクティブエネルギーを使用中';
  static const healthUnavailableOnDevice = 'この端末では Health 連携に対応していません。';
  static const webHealthUnavailable = 'このプレビューでは Health 連携は利用できません。';
  static const webPreviewTitle = '開発用プレビュー';
  static const webPreviewUnavailableIntro = 'この Web では次の機能は使えません。';
  static const webPreviewUnavailableList =
      '・Health 連携\n・Sign in with Apple\n・アプリ内課金';
  static const webPreviewUnavailableSummary =
      '開発用プレビューです。Health 連携、Sign in with Apple、アプリ内課金は使えません。';
  static const webPreviewUseApp = '使えない機能は、アプリで利用できます。';

  static const save = '保存';
  static const cancel = 'キャンセル';
  static const delete = '削除';
  static const next = '次へ';
  static const notSelected = '未選択';

  static const macroProtein = 'タンパク質';
  static const macroCarb = '炭水化物';
  static const macroFat = '脂質';
  static const macroKcal = 'カロリー';

  static const macroNutrientsRequired = 'カロリー・タンパク質・脂質・炭水化物はすべて必須です';
  static const macroNutrientsRequiredShort = 'カロリー・タンパク質・脂質・炭水化物は必須です';
  static const macroManualConsistencyRequired =
      '手入力食品は カロリー = タンパク質×4 + 脂質×9 + 炭水化物×4 に整合している必要があります';
  static const macroExternalMismatchTitle = '表示カロリーと栄養素換算値が異なる場合があります。';
  static const macroDisplayedKcalLabel = '表示カロリー';
  static const macroDerivedKcalLabel = '栄養素換算';
  static const macroExternalMismatchFootnote =
      '食物繊維・糖アルコール・有機酸・表示丸め等により一致しない場合があります。';
  static const macroIntakePreviewPrefix = '今回の摂取';
  static const macroNutritionInfoLabel = '栄養情報';
  static const macroRecordNutritionLabel = '記録する栄養';
  static const quantityLabel = '数量';
  static const remainingToday = '今日あと';
  static const remainingKcalSuffix = '食べられます';

  static const weightSourceManual = '手入力';
  static const weightSourceHealth = 'Healthから取得';
  static const weightSourceHealthPending = 'Health（未取得）';
  static const weightManualOverwriteNotice =
      'Health連携中に手入力した体重は、再同期でHealthの値に更新される場合があります。';

  static const goalWarningLoseAboveCurrent = '減量なのに目標体重が現在体重以上です。';
  static const goalWarningGainBelowCurrent = '増量なのに目標体重が現在体重以下です。';
  static const goalWarningShortPeriod = '目標日までの期間が短い可能性があります。';
  static const goalWarningMaintainMismatch = '維持なのに目標体重と現在体重に差があります。';
  static const goalWarningTitle = '目標設定の確認';

  static String activityLevelLabel(ActivityLevel level) => level.everydayLabel;

  static String activityLevelDescription(ActivityLevel level) =>
      level.everydayDescription;

  static String goalTypeLabel(GoalType type) => type.label;
}
