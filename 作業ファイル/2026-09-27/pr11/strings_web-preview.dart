import '../models/activity_level.dart';
import '../models/goal.dart';

/// Version 1.1 ユーザー向け表示文字列（日本語）。
class AppStrings {
  AppStrings._();

  static const appTitle = 'カロナビ';

  static const loginTagline = '毎日の食事と運動を、やさしく見える化。';

  /// ログイン画面のタグライン（Figma のとおり2行で表示）。
  static const loginTaglineMultiline = '毎日の食事と運動を、\nやさしく見える化。';

  /// ログイン画面の説明文（Figma のとおり3行で表示）。
  static const loginDescription =
      'がんばりすぎず、つづけられる。\nカロナビは、あなたの健康な毎日を\nやさしくサポートします。';

  static const loginWithGoogle = 'Googleでログイン';
  static const loginWithApple = 'Appleでログイン';

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
  static const settingsContactOperator = '運営連絡';
  static const settingsSupport = 'サポート';
  static const settingsTokushoho = '特定商取引法に基づく表記';
  static const settingsAccountDeletion = 'アカウント削除';
  static const settingsAccountDeletionSubtitle = '公開食品は残ります。アプリ内で確認できます';
  static const loginLegalAgreement = 'ログインにより、利用規約とプライバシーポリシーに同意したものとします。';

  /// ログイン画面の同意文言（Figma のとおり2行で固定表示）。
  /// 端末ごとに折り返し位置が変わらないよう、改行位置を明示する。
  static const loginLegalAgreementMultiline =
      'ログインにより、利用規約とプライバシーポリシーに\n同意したものとします。';

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
