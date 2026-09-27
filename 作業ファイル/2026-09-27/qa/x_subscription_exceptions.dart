import '../config/subscription_catalog.dart';

enum SubscriptionLimitKind { publicFoodSearch, mealTemplate, workoutTemplate }

class SubscriptionLimitExceededException implements Exception {
  SubscriptionLimitExceededException(this.kind);

  final SubscriptionLimitKind kind;

  @override
  String toString() {
    return switch (kind) {
      SubscriptionLimitKind.publicFoodSearch =>
        '公開食品検索は1日${SubscriptionCatalog.publicFoodSearchesPerDay}回までです。',
      SubscriptionLimitKind.mealTemplate =>
        '食事テンプレートは${SubscriptionCatalog.mealTemplateLimit}件までです。',
      SubscriptionLimitKind.workoutTemplate =>
        '運動テンプレートは${SubscriptionCatalog.workoutTemplateLimit}件までです。',
    };
  }
}

class SubscriptionPurchaseUnavailableException implements Exception {
  @override
  String toString() => 'この環境ではアプリ内課金を使えません。';
}

class SubscriptionPurchaseFailedException implements Exception {
  SubscriptionPurchaseFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}
