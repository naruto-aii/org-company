/// カロナビ+ の商品と無料枠。App Store Connect の Product ID と揃える。
class SubscriptionCatalog {
  SubscriptionCatalog._();

  static const productName = 'カロナビ+';
  static const monthlyProductId = 'calonavi_plus_monthly';
  static const yearlyProductId = 'calonavi_plus_yearly';

  static const publicFoodSearchesPerDay = 5;
  static const mealTemplateLimit = 3;
  static const workoutTemplateLimit = 3;

  static bool isPlusProduct(String productId) {
    return productId == monthlyProductId || productId == yearlyProductId;
  }
}
