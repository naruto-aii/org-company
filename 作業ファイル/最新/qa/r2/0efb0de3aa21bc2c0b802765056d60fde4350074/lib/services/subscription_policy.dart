import '../config/subscription_catalog.dart';

/// 無料枠の判定だけを持つ。UI や StoreKit には依存しない。
class SubscriptionPolicy {
  const SubscriptionPolicy();

  bool canUse({
    required bool isPlus,
    required int used,
    required int limit,
  }) {
    return isPlus || used < limit;
  }

  bool canSearchPublicFood({required bool isPlus, required int usedToday}) {
    return canUse(
      isPlus: isPlus,
      used: usedToday,
      limit: SubscriptionCatalog.publicFoodSearchesPerDay,
    );
  }

  bool canCreateMealTemplate({required bool isPlus, required int currentCount}) {
    return canUse(
      isPlus: isPlus,
      used: currentCount,
      limit: SubscriptionCatalog.mealTemplateLimit,
    );
  }

  bool canCreateWorkoutTemplate({
    required bool isPlus,
    required int currentCount,
  }) {
    return canUse(
      isPlus: isPlus,
      used: currentCount,
      limit: SubscriptionCatalog.workoutTemplateLimit,
    );
  }
}
