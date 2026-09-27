import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/food_unit_type.dart';
import '../../models/food_visibility.dart';
import '../../models/saved_food.dart';
import '../../models/food_source_type.dart';
import '../../models/saved_food_persistence_error.dart';
import '../../services/saved_food_version_policy.dart';
import '../../utils/base_amount_normalizer.dart';
import '../../utils/food_name_normalizer.dart';
import '../contracts/saved_food_remote_store.dart';
import '../exceptions/food_master_exceptions.dart';
import 'supabase_error_mapper.dart';
import 'food_master_row_mapper.dart';

/// Supabase 上の saved_foods 操作（public 取得・publish RPC 含む）。
class SupabaseSavedFoodRepository implements SavedFoodRemoteStore {
  SupabaseSavedFoodRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<SavedFood> upsertOwnPrivate({
    required String userId,
    required SavedFood food,
  }) async {
    const step = 'SupabaseSavedFoodRepository.upsertOwnPrivate';
    try {
      final payload = FoodMasterRowMapper.savedFoodToRow(
        food.copyWith(
          visibility: FoodVisibility.private,
          updatedAt: food.updatedAt,
        ),
        userId: userId,
      );
      final row = await _client
          .from('saved_foods')
          .upsert(payload, onConflict: 'user_id,food_id')
          .select()
          .single();
      return FoodMasterRowMapper.savedFoodFromRow(row);
    } on PostgrestException catch (error) {
      final mapped = SavedFoodPersistenceException.fromPostgrest(
        error: error,
        repositoryStep: step,
        operation: 'upsert',
      )..logDebug();
      throw mapped;
    } catch (error) {
      if (error is SavedFoodPersistenceException) {
        rethrow;
      }
      if (error is FoodMasterException) {
        final mapped = SavedFoodPersistenceException.fromFoodMaster(
          error: error,
          repositoryStep: step,
          operation: 'upsert',
        )..logDebug();
        throw mapped;
      }
      throw SupabaseErrorMapper.map(error, context: 'saved_foods upsert');
    }
  }

  Future<SavedFood> updateOwnRow({
    required String userId,
    required SavedFood food,
  }) async {
    try {
      final payload = FoodMasterRowMapper.savedFoodToRow(food, userId: userId);
      final row = await _client
          .from('saved_foods')
          .update(payload)
          .eq('user_id', userId)
          .eq('food_id', food.foodId)
          .select()
          .single();
      return FoodMasterRowMapper.savedFoodFromRow(row);
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'saved_foods update');
    }
  }

  Future<SavedFood> publish({
    required String userId,
    required String foodId,
  }) async {
    try {
      final row = await _client.rpc(
        'publish_saved_food',
        params: {'p_food_id': foodId},
      );
      if (row is! Map<String, dynamic>) {
        throw const PublishSavedFoodException(
          kind: PublishFailureKind.unknown,
          message: 'Unexpected publish response.',
        );
      }
      return FoodMasterRowMapper.savedFoodFromRow(row);
    } catch (error) {
      throw SupabaseErrorMapper.mapPublishFailure(error);
    }
  }

  Future<SavedFood> unpublish({
    required String userId,
    required String foodId,
  }) async {
    try {
      final row = await _client
          .from('saved_foods')
          .update({'visibility': FoodVisibility.private.name})
          .eq('user_id', userId)
          .eq('food_id', foodId)
          .select()
          .single();
      return FoodMasterRowMapper.savedFoodFromRow(row);
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'saved_foods unpublish');
    }
  }

  Future<List<SavedFood>> pullAllOwn(String userId) async {
    try {
      final rows = await _client
          .from('saved_foods')
          .select()
          .eq('user_id', userId);
      return rows
          .map((row) => FoodMasterRowMapper.savedFoodFromRow(row))
          .toList();
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'saved_foods pull');
    }
  }

  Future<void> pushAllOwn(String userId, List<SavedFood> foods) async {
    if (foods.isEmpty) {
      return;
    }
    try {
      await _client
          .from('saved_foods')
          .upsert(
            foods
                .map(
                  (food) =>
                      FoodMasterRowMapper.savedFoodToRow(food, userId: userId),
                )
                .toList(),
            onConflict: 'user_id,food_id',
          );
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'saved_foods push');
    }
  }

  Future<List<SavedFood>> searchPublic({
    required String query,
    int limit = 50,
  }) async {
    final normalized = FoodNameNormalizer.normalize(query);
    final trimmedBarcode = query.trim();
    if (normalized.isEmpty && trimmedBarcode.isEmpty) {
      return const [];
    }
    try {
      final candidates = <SavedFood>[];
      final seen = <String>{};

      void addRows(List<dynamic> rows) {
        for (final row in rows) {
          final mapped = FoodMasterRowMapper.savedFoodFromRow(row);
          final key = '${mapped.ownerUserId}:${mapped.foodId}';
          if (seen.add(key)) {
            candidates.add(mapped);
          }
        }
      }

      if (normalized.isNotEmpty) {
        addRows(
          await _client
              .from('saved_foods')
              .select()
              .eq('visibility', FoodVisibility.public.name)
              .eq('status', 'active')
              .eq('normalized_name', normalized)
              .limit(limit),
        );

        addRows(
          await _client
              .from('saved_foods')
              .select()
              .eq('visibility', FoodVisibility.public.name)
              .eq('status', 'active')
              .ilike('normalized_name', '$normalized%')
              .limit(limit),
        );

        addRows(
          await _client
              .from('saved_foods')
              .select()
              .eq('visibility', FoodVisibility.public.name)
              .eq('status', 'active')
              .ilike('normalized_name', '%$normalized%')
              .limit(limit),
        );
      }

      if (trimmedBarcode.isNotEmpty) {
        addRows(
          await _client
              .from('saved_foods')
              .select()
              .eq('visibility', FoodVisibility.public.name)
              .eq('status', 'active')
              .eq('barcode', trimmedBarcode)
              .limit(limit),
        );
      }

      return candidates.take(limit).toList();
    } catch (error) {
      throw SupabaseErrorMapper.map(
        error,
        context: 'saved_foods search public',
      );
    }
  }

  Future<SavedFood?> getPublicById({
    required String ownerUserId,
    required String foodId,
  }) async {
    try {
      final row = await _client
          .from('saved_foods')
          .select()
          .eq('user_id', ownerUserId)
          .eq('food_id', foodId)
          .eq('visibility', FoodVisibility.public.name)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return FoodMasterRowMapper.savedFoodFromRow(row);
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'saved_foods get public');
    }
  }

  Future<SavedFood?> findExactPublicDuplicate({
    required String normalizedName,
    required double baseAmount,
    required FoodUnitType unitType,
    String? excludeOwnerUserId,
    String? excludeFoodId,
  }) async {
    try {
      final rows = await _client
          .from('saved_foods')
          .select()
          .eq('visibility', FoodVisibility.public.name)
          .eq('status', 'active')
          .eq('normalized_name', normalizedName)
          .eq('base_amount', baseAmount)
          .eq('unit_type', unitType.storageValue)
          .limit(5);
      for (final row in rows) {
        final food = FoodMasterRowMapper.savedFoodFromRow(row);
        if (excludeOwnerUserId != null &&
            excludeFoodId != null &&
            food.ownerUserId == excludeOwnerUserId &&
            food.foodId == excludeFoodId) {
          continue;
        }
        return food;
      }
      return null;
    } catch (error) {
      throw SupabaseErrorMapper.map(
        error,
        context: 'saved_foods find exact duplicate',
      );
    }
  }

  Future<List<SavedFood>> findSimilarPublicFoods({
    required SavedFood food,
    int limit = 20,
  }) async {
    try {
      final candidates = <SavedFood>[];
      final seen = <String>{};

      void addRows(List<dynamic> rows) {
        for (final row in rows) {
          final mapped = FoodMasterRowMapper.savedFoodFromRow(row);
          final key = '${mapped.ownerUserId}:${mapped.foodId}';
          if (seen.add(key)) {
            candidates.add(mapped);
          }
        }
      }

      if (food.normalizedName.isNotEmpty) {
        addRows(
          await _client
              .from('saved_foods')
              .select()
              .eq('visibility', FoodVisibility.public.name)
              .eq('status', 'active')
              .eq('normalized_name', food.normalizedName)
              .limit(limit),
        );

        addRows(
          await _client
              .from('saved_foods')
              .select()
              .eq('visibility', FoodVisibility.public.name)
              .eq('status', 'active')
              .ilike('normalized_name', '${food.normalizedName}%')
              .limit(limit),
        );
      }

      final barcode = food.barcode;
      if (barcode != null && barcode.isNotEmpty) {
        addRows(
          await _client
              .from('saved_foods')
              .select()
              .eq('visibility', FoodVisibility.public.name)
              .eq('status', 'active')
              .eq('barcode', barcode)
              .limit(limit),
        );
      }

      return candidates.take(limit).toList();
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'saved_foods find similar');
    }
  }

  SavedFood buildPrivateCopy({
    required SavedFood source,
    required String newFoodId,
    required String ownerUserId,
    required DateTime now,
  }) {
    return source.copyWith(
      foodId: newFoodId,
      ownerUserId: ownerUserId,
      visibility: FoodVisibility.private,
      status: source.status,
      moderationStatus: source.moderationStatus,
      name: source.name,
      normalizedName: FoodNameNormalizer.normalize(source.name),
      baseAmount: BaseAmountNormalizer.normalize(source.baseAmount),
      sourceType: FoodSourceType.copied,
      copiedFromFoodId: source.foodId,
      copiedFromOwnerUserId: source.ownerUserId,
      reportCount: 0,
      useCount: 0,
      lastUsedAt: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      version: SavedFoodVersionPolicy.initialVersion,
      ownerDeleted: false,
    );
  }
}
