import '../../models/alcohol_entry.dart';
import '../../models/food_entry.dart';
import '../../models/food_entry_source.dart';
import '../../models/food_rating.dart';
import '../../models/food_report.dart';
import '../../models/food_source_type.dart';
import '../../models/food_status.dart';
import '../../models/food_unit_type.dart';
import '../../models/food_visibility.dart';
import '../../models/meal_template.dart';
import '../../models/moderation_status.dart';
import '../../models/saved_food.dart';

class FoodMasterRowMapper {
  const FoodMasterRowMapper._();

  static SavedFood savedFoodFromRow(Map<String, dynamic> row) {
    return SavedFood(
      foodId: row['food_id'] as String,
      ownerUserId: row['user_id'] as String,
      visibility:
          FoodVisibilityX.tryParse(row['visibility'] as String?) ??
          FoodVisibility.private,
      status:
          FoodStatusX.tryParse(row['status'] as String?) ?? FoodStatus.active,
      moderationStatus:
          ModerationStatusX.tryParse(row['moderation_status'] as String?) ??
          ModerationStatus.none,
      name: row['name'] as String,
      normalizedName: row['normalized_name'] as String,
      baseAmount: (row['base_amount'] as num).toDouble(),
      unitType:
          FoodUnitTypeX.tryParse(row['unit_type'] as String?) ??
          FoodUnitType.serving,
      servingUnitLabel: row['serving_unit_label'] as String?,
      kcalPerBase: (row['kcal_per_base'] as num?)?.toDouble(),
      proteinPerBase: (row['protein_per_base'] as num?)?.toDouble(),
      fatPerBase: (row['fat_per_base'] as num?)?.toDouble(),
      carbPerBase: (row['carb_per_base'] as num?)?.toDouble(),
      sourceType:
          FoodSourceTypeX.tryParse(row['source_type'] as String?) ??
          FoodSourceType.manual,
      barcode: row['barcode'] as String?,
      brand: row['brand'] as String?,
      supplementaryWeight: row['supplementary_weight'] as String?,
      copiedFromFoodId: row['copied_from_food_id'] as String?,
      copiedFromOwnerUserId: row['copied_from_owner_user_id'] as String?,
      useCount: (row['use_count'] as num?)?.toInt() ?? 0,
      lastUsedAt: _parseDateTime(row['last_used_at']),
      reportCount: (row['report_count'] as num?)?.toInt() ?? 0,
      version: (row['version'] as num?)?.toInt() ?? 1,
      ownerDeleted: row['owner_deleted'] == true,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: _parseDateTime(row['deleted_at']),
    );
  }

  static Map<String, dynamic> savedFoodToRow(
    SavedFood food, {
    required String userId,
  }) {
    return {
      'user_id': userId,
      'food_id': food.foodId,
      'visibility': food.visibility.name,
      'status': food.status.name,
      'name': food.name,
      'normalized_name': food.normalizedName,
      'base_amount': food.baseAmount,
      'unit_type': food.unitType.storageValue,
      'serving_unit_label': food.servingUnitLabel,
      'kcal_per_base': food.kcalPerBase,
      'protein_per_base': food.proteinPerBase,
      'fat_per_base': food.fatPerBase,
      'carb_per_base': food.carbPerBase,
      'source_type': food.sourceType.storageValue,
      'barcode': food.barcode,
      'brand': food.brand,
      'supplementary_weight': food.supplementaryWeight,
      'copied_from_food_id': food.copiedFromFoodId,
      'copied_from_owner_user_id': food.copiedFromOwnerUserId,
      'use_count': food.useCount,
      'last_used_at': food.lastUsedAt?.toIso8601String(),
      'version': food.version,
      'created_at': food.createdAt.toIso8601String(),
      'updated_at': food.updatedAt.toIso8601String(),
      'deleted_at': food.deletedAt?.toIso8601String(),
    };
  }

  static MealTemplate mealTemplateFromRow(Map<String, dynamic> row) {
    return MealTemplate(
      templateId: row['template_id'] as String,
      ownerUserId: row['user_id'] as String,
      name: row['name'] as String,
      normalizedName: row['normalized_name'] as String,
      visibility:
          FoodVisibilityX.tryParse(row['visibility'] as String?) ??
          FoodVisibility.private,
      status:
          TemplateStatusX.tryParse(row['status'] as String?) ??
          TemplateStatus.active,
      totalKcal: (row['total_kcal'] as num?)?.toDouble() ?? 0,
      totalProteinG: (row['total_protein_g'] as num?)?.toDouble() ?? 0,
      totalFatG: (row['total_fat_g'] as num?)?.toDouble() ?? 0,
      totalCarbG: (row['total_carb_g'] as num?)?.toDouble() ?? 0,
      dependencyStatus:
          TemplateDependencyStatusX.tryParse(
            row['dependency_status'] as String?,
          ) ??
          TemplateDependencyStatus.ok,
      lastValidatedAt: _parseDateTime(row['last_validated_at']),
      useCount: (row['use_count'] as num?)?.toInt() ?? 0,
      lastUsedAt: _parseDateTime(row['last_used_at']),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: _parseDateTime(row['deleted_at']),
    );
  }

  static Map<String, dynamic> mealTemplateToRow(
    MealTemplate template, {
    required String userId,
  }) {
    return {
      'user_id': userId,
      'template_id': template.templateId,
      'name': template.name,
      'normalized_name': template.normalizedName,
      'visibility': template.visibility.name,
      'status': template.status.storageValue,
      'total_kcal': template.totalKcal,
      'total_protein_g': template.totalProteinG,
      'total_fat_g': template.totalFatG,
      'total_carb_g': template.totalCarbG,
      'dependency_status': template.dependencyStatus.storageValue,
      'last_validated_at': template.lastValidatedAt?.toIso8601String(),
      'use_count': template.useCount,
      'last_used_at': template.lastUsedAt?.toIso8601String(),
      'updated_at': template.updatedAt.toIso8601String(),
      'deleted_at': template.deletedAt?.toIso8601String(),
    };
  }

  static MealTemplateItem mealTemplateItemFromRow(Map<String, dynamic> row) {
    return MealTemplateItem(
      itemId: row['item_id'] as String,
      savedFoodId: row['saved_food_id'] as String?,
      sourceOwnerUserId: row['source_owner_user_id'] as String?,
      name: row['name'] as String,
      baseAmount: (row['base_amount'] as num).toDouble(),
      unitType:
          FoodUnitTypeX.tryParse(row['unit_type'] as String?) ??
          FoodUnitType.serving,
      kcalPerBase: (row['kcal_per_base'] as num?)?.toDouble(),
      proteinPerBase: (row['protein_per_base'] as num?)?.toDouble(),
      fatPerBase: (row['fat_per_base'] as num?)?.toDouble(),
      carbPerBase: (row['carb_per_base'] as num?)?.toDouble(),
      consumedAmount: (row['consumed_amount'] as num).toDouble(),
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      itemDependencyStatus:
          ItemDependencyStatusX.tryParse(
            row['item_dependency_status'] as String?,
          ) ??
          ItemDependencyStatus.available,
      snapshotSavedAt: DateTime.parse(row['snapshot_saved_at'] as String),
    );
  }

  static Map<String, dynamic> mealTemplateItemToRow(
    MealTemplateItem item, {
    required String userId,
    required String templateId,
  }) {
    return {
      'user_id': userId,
      'item_id': item.itemId,
      'template_id': templateId,
      'saved_food_id': item.savedFoodId,
      'source_owner_user_id': item.sourceOwnerUserId,
      'name': item.name,
      'base_amount': item.baseAmount,
      'unit_type': item.unitType.storageValue,
      'kcal_per_base': item.kcalPerBase,
      'protein_per_base': item.proteinPerBase,
      'fat_per_base': item.fatPerBase,
      'carb_per_base': item.carbPerBase,
      'consumed_amount': item.consumedAmount,
      'sort_order': item.sortOrder,
      'item_dependency_status': item.itemDependencyStatus.storageValue,
      'snapshot_saved_at': item.snapshotSavedAt.toIso8601String(),
    };
  }

  static FoodEntry foodEntryFromRow(Map<String, dynamic> row) {
    final baseAmount = (row['base_amount'] as num?)?.toDouble();
    final consumedAmount = (row['consumed_amount'] as num?)?.toDouble();
    final quantity = (row['quantity'] as num?)?.toDouble();

    return FoodEntry(
      id: row['entry_id'] as String,
      name: row['name'] as String,
      kcalPerBase: (row['kcal_per_unit'] as num?)?.toDouble(),
      proteinPerBase: (row['protein_per_unit'] as num?)?.toDouble(),
      fatPerBase: (row['fat_per_unit'] as num?)?.toDouble(),
      carbPerBase: (row['carb_per_unit'] as num?)?.toDouble(),
      baseAmount: baseAmount ?? 1,
      unitType:
          FoodUnitTypeX.tryParse(row['unit_type'] as String?) ??
          FoodUnitType.serving,
      consumedAmount: consumedAmount ?? quantity ?? 1,
      sourceType:
          FoodEntrySourceX.tryParse(row['source_type'] as String?) ??
          FoodEntrySource.manual,
      savedFoodId: row['saved_food_id'] as String?,
      sourceFoodOwnerUserId: row['source_food_owner_user_id'] as String?,
      mealGroupId: row['meal_group_id'] as String?,
      mealGroupName: row['meal_group_name'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt(),
      loggedAt: DateTime.parse(row['logged_at'] as String),
    );
  }

  static Map<String, dynamic> foodEntryToRow(
    FoodEntry entry, {
    required String userId,
  }) {
    return {
      'user_id': userId,
      'entry_id': entry.id,
      'name': entry.name,
      'kcal_per_unit': entry.kcalPerBase,
      'protein_per_unit': entry.proteinPerBase,
      'fat_per_unit': entry.fatPerBase,
      'carb_per_unit': entry.carbPerBase,
      'quantity': entry.quantity,
      'base_amount': entry.baseAmount,
      'unit_type': entry.unitType.storageValue,
      'consumed_amount': entry.consumedAmount,
      'source_type': entry.sourceType.storageValue,
      'saved_food_id': entry.savedFoodId,
      'source_food_owner_user_id': entry.sourceFoodOwnerUserId,
      'meal_group_id': entry.mealGroupId,
      'meal_group_name': entry.mealGroupName,
      'sort_order': entry.sortOrder,
      'logged_at': entry.loggedAt.toIso8601String(),
    };
  }

  static FoodRatingSummary ratingSummaryFromRow(Map<String, dynamic> row) {
    return FoodRatingSummary(
      foodOwnerUserId: row['food_owner_user_id'] as String,
      foodId: row['food_id'] as String,
      goodCount: (row['good_count'] as num?)?.toInt() ?? 0,
      badCount: (row['bad_count'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  static MyFoodRating myRatingFromRow(Map<String, dynamic> row) {
    return MyFoodRating(
      ratingId: row['rating_id'] as String,
      foodOwnerUserId: row['food_owner_user_id'] as String,
      foodId: row['food_id'] as String,
      ratingType:
          FoodRatingTypeX.tryParse(row['rating_type'] as String?) ??
          FoodRatingType.good,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  static FoodReport foodReportFromRow(Map<String, dynamic> row) {
    return FoodReport(
      reportId: row['report_id'] as String,
      reporterUserId: row['reporter_user_id'] as String,
      targetFoodOwnerUserId: row['target_food_owner_user_id'] as String,
      targetFoodId: row['target_food_id'] as String,
      reasonCode:
          FoodReportReasonCodeX.tryParse(row['reason_code'] as String?) ??
          FoodReportReasonCode.other,
      detailText: row['detail_text'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  static AlcoholEntry alcoholEntryFromRow(Map<String, dynamic> row) {
    return AlcoholEntry(
      id: row['entry_id'] as String,
      beverageName: row['beverage_name'] as String,
      amount: (row['amount'] as num).toDouble(),
      unit: row['unit'] as String,
      alcoholPercentage: (row['alcohol_percentage'] as num).toDouble(),
      totalCalories: (row['total_calories'] as num).toDouble(),
      pureAlcoholGrams: (row['pure_alcohol_grams'] as num).toDouble(),
      alcoholCalories: (row['alcohol_calories'] as num).toDouble(),
      consumedAt: DateTime.parse(row['consumed_at'] as String),
    );
  }

  static Map<String, dynamic> alcoholEntryToRow(
    AlcoholEntry entry, {
    required String userId,
  }) {
    return {
      'user_id': userId,
      'entry_id': entry.id,
      'beverage_name': entry.beverageName,
      'amount': entry.amount,
      'unit': entry.unit,
      'alcohol_percentage': entry.alcoholPercentage,
      'total_calories': entry.totalCalories,
      'pure_alcohol_grams': entry.pureAlcoholGrams,
      'alcohol_calories': entry.alcoholCalories,
      'consumed_at': entry.consumedAt.toIso8601String(),
    };
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw == null) {
      return null;
    }
    return DateTime.parse(raw as String);
  }
}
