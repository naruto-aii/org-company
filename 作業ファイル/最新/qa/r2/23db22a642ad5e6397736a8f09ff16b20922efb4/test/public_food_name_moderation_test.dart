import 'dart:io';

import 'package:ayg/moderation/public_food_banned_words.dart';
import 'package:ayg/moderation/public_food_name_moderation.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/exceptions/food_master_exceptions.dart';
import 'package:ayg/repositories/supabase/supabase_error_mapper.dart';
import 'package:ayg/services/publish_error_messages.dart';
import 'package:ayg/services/saved_food_publish_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('PublicFoodNameModeration', () {
    test('halfwidth katakana maps are the same length', () {
      expect(
        publicFoodHalfwidthKatakanaFrom.runes.length,
        publicFoodHalfwidthKatakanaTo.runes.length,
      );
    });

    test('allows ordinary food names', () {
      const names = [
        'キャベツ',
        '鶏むね肉',
        '味噌汁',
        'バナナ',
        'イエロー',
        'shiitake',
        'sea bass',
        'grape',
        'cocktail',
        'classic',
        'カフェラテ',
        'ポークソテー',
        'ポークソーセージ',
        'ミルクソフト',
        'スモークソルト',
        'サンマンコ',
        'Cock tail',
        'rape seed oil',
        'ブラックソース',
        'やくそう',
      ];
      for (final name in names) {
        expect(PublicFoodNameModeration.isBanned(name), isFalse, reason: name);
      }
    });

    test('rejects normalized latin, kana, and spacing', () {
      expect(PublicFoodNameModeration.isBanned('  FUCK '), isTrue);
      expect(PublicFoodNameModeration.isBanned('ｆｕｃｋ'), isTrue);
      expect(PublicFoodNameModeration.isBanned('f u c k'), isTrue);
      expect(PublicFoodNameModeration.isBanned('ﾌｧｯｸ'), isTrue);
      expect(PublicFoodNameModeration.isBanned('ファック'), isTrue);
      expect(PublicFoodNameModeration.isBanned('うんこカレー'), isTrue);
      expect(PublicFoodNameModeration.isBanned('チンコ'), isTrue);
    });

    test(
      'rejects accent, combining, lookalike, digit, and symbol bypasses',
      () {
        expect(PublicFoodNameModeration.isBanned('fúck'), isTrue);
        expect(PublicFoodNameModeration.isBanned('fu\u0301ck'), isTrue);
        expect(PublicFoodNameModeration.isBanned('fu\u0441k'), isTrue);
        expect(PublicFoodNameModeration.isBanned('5h1t'), isTrue);
        expect(PublicFoodNameModeration.isBanned('c0ck'), isTrue);
        expect(PublicFoodNameModeration.isBanned(r'$hit'), isTrue);
        expect(PublicFoodNameModeration.isBanned('sh!t'), isTrue);
        // ｷﾁｶﾞｲ — halfwidth ka plus voiced mark becomes が after NFKC.
        expect(
          PublicFoodNameModeration.isBanned('\uFF77\uFF81\uFF76\uFF9E\uFF72'),
          isTrue,
        );
        // ﾁﾝﾎﾟ — halfwidth ho plus handakuten (U+FF9F) becomes ぽ.
        expect(
          PublicFoodNameModeration.isBanned('\uFF81\uFF9D\uFF8E\uFF9F'),
          isTrue,
        );
      },
    );

    test(
      'still rejects a whole short term and a term beside an allowed phrase',
      () {
        expect(PublicFoodNameModeration.isBanned('くそ'), isTrue);
        expect(PublicFoodNameModeration.isBanned('フェラ'), isTrue);
        expect(PublicFoodNameModeration.isBanned('まんこ'), isTrue);
        expect(PublicFoodNameModeration.isBanned('cock'), isTrue);
        expect(PublicFoodNameModeration.isBanned('rape'), isTrue);
        expect(PublicFoodNameModeration.isBanned('fuck rape seed oil'), isTrue);
        expect(PublicFoodNameModeration.isBanned('Cock tail sauce'), isFalse);
      },
    );

    test('rejects explicit compounds and still allows ordinary foods', () {
      const allowed = [
        'カフェラテ',
        'ポークソテー',
        'スモークソルト',
        'Cock tail',
        'rape seed oil',
        'ブラックソース',
        'やくそう',
        'サンマンコ',
      ];
      const rejected = [
        'おまんこ',
        'オマンコ',
        'フェラチオ',
        'ふぇらちお',
        'イラマチオ',
        'クンニ',
        'パイズリ',
        'おまんこカレー',
        'fellatio',
        'cunnilingus',
      ];
      for (final name in allowed) {
        expect(PublicFoodNameModeration.isBanned(name), isFalse, reason: name);
      }
      for (final name in rejected) {
        expect(PublicFoodNameModeration.isBanned(name), isTrue, reason: name);
      }
    });

    test('does not treat an unchanged public name as a new rejection', () {
      expect(
        PublicFoodNameModeration.rejectsPublicUpdate(
          previousName: 'fuck',
          nextName: 'fuck',
        ),
        isFalse,
      );
      expect(
        PublicFoodNameModeration.rejectsPublicUpdate(
          previousName: 'キャベツ',
          nextName: 'うんこ',
        ),
        isTrue,
      );
      expect(
        PublicFoodNameModeration.rejectsPublicUpdate(
          previousName: 'キャベツ',
          nextName: 'キャベツ',
          previousBrand: 'fuck',
          nextBrand: 'fuck',
        ),
        isFalse,
      );
      expect(
        PublicFoodNameModeration.rejectsPublicUpdate(
          previousName: 'キャベツ',
          nextName: 'キャベツ',
          previousBrand: 'acme',
          nextBrand: 'fúck',
        ),
        isTrue,
      );
    });
  });

  group('SavedFoodPublishValidator banned names', () {
    const validator = SavedFoodPublishValidator();

    test('adds the Japanese message for a banned public name', () {
      final result = validator.validate(
        food: _food('fuck rice'),
        ownerUserId: 'user-a',
      );
      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains(PublicFoodNameModeration.rejectionMessage),
      );
    });

    test(
      'rejects a clean name when brand, normalized name, or unit is banned',
      () {
        for (final food in [
          _food('キャベツ').copyWith(brand: 'fuck'),
          _food('キャベツ').copyWith(normalizedName: '5h1t'),
          _food('キャベツ').copyWith(servingUnitLabel: r'$hit'),
        ]) {
          final result = validator.validate(food: food, ownerUserId: 'user-a');
          expect(
            result.isValid,
            isFalse,
            reason: food.brand ?? food.normalizedName,
          );
          expect(
            result.errors,
            contains(PublicFoodNameModeration.rejectionMessage),
          );
        }
      },
    );
  });

  group('banned name errors', () {
    test('maps the database exception to the Japanese message', () {
      final mapped = SupabaseErrorMapper.mapPublishFailure(
        const PostgrestException(message: 'public food name is not allowed'),
      );
      expect(mapped.kind, PublishFailureKind.bannedName);
      expect(
        PublishErrorMessages.messageFor(mapped),
        PublicFoodNameModeration.rejectionMessage,
      );
      expect(
        PublishErrorMessages.messageFor(
          const PublicFoodNameRejectedException(),
        ),
        PublicFoodNameModeration.rejectionMessage,
      );
    });
  });

  group('banned word list parity', () {
    late String migration;

    setUpAll(() {
      migration = File(
        'supabase/migrations/20260927120000_reject_banned_public_food_names.sql',
      ).readAsStringSync();
    });

    test('SQL list matches the Dart list', () {
      expect(
        _sqlMarkedList(migration, 'PUBLIC_FOOD_BANNED_WORDS'),
        publicFoodBannedWords,
      );
    });

    test('SQL boundary terms and allowed phrases match Dart', () {
      expect(
        publicFoodHalfwidthDakutenBase.runes.length,
        publicFoodHalfwidthDakutenTo.runes.length,
      );
      expect(
        publicFoodHalfwidthHandakutenBase.runes.length,
        publicFoodHalfwidthHandakutenTo.runes.length,
      );
      expect(
        _sqlMarkedList(migration, 'PUBLIC_FOOD_BOUNDARY_ONLY'),
        publicFoodBoundaryOnlyTerms,
      );
      expect(
        _sqlMarkedList(migration, 'PUBLIC_FOOD_ALLOWED_PHRASES'),
        publicFoodAllowedPhrases,
      );
      expect(migration, contains(publicFoodHalfwidthDakutenBase));
      expect(migration, contains(publicFoodHalfwidthDakutenTo));
      expect(migration, contains(publicFoodHalfwidthHandakutenBase));
      expect(migration, contains(publicFoodHalfwidthHandakutenTo));
      expect(
        migration,
        contains(
          'public.compose_halfwidth_voiced(pg_catalog.coalesce(p_name, \'\'))',
        ),
      );
    });

    test('rollback file restores publish without dropping the trigger', () {
      final downPath =
          'supabase/rollback/20260927120000_reject_banned_public_food_names_down.sql';
      final down = File(downPath).readAsStringSync();
      expect(
        File(
          'supabase/migrations/20260927120000_reject_banned_public_food_names_down.sql',
        ).existsSync(),
        isFalse,
      );
      expect(
        down,
        contains('create or replace function public.publish_saved_food'),
      );
      expect(
        down,
        contains(
          'create or replace function public.validate_saved_foods_public_row',
        ),
      );
      expect(down, isNot(contains('public food name is not allowed')));
      expect(
        down,
        contains(
          'drop function if exists public.compose_halfwidth_voiced(text)',
        ),
      );
      expect(
        down,
        contains(
          'drop function if exists public.public_food_name_strip_phrase(text, text)',
        ),
      );
      expect(
        down,
        contains(
          'grant execute on function public.publish_saved_food(text) to authenticated',
        ),
      );
      expect(down.toLowerCase(), isNot(contains('drop trigger')));
    });

    test('SQL uses the same halfwidth katakana map', () {
      expect(migration, contains(publicFoodHalfwidthKatakanaFrom));
      expect(migration, contains(publicFoodHalfwidthKatakanaTo));
    });

    test('SQL folds NFKC and the same confusable map', () {
      expect(
        publicFoodConfusableFrom.runes.length,
        publicFoodConfusableTo.runes.length,
      );
      expect(migration, contains('pg_catalog.normalize'));
      expect(migration, contains('NFKC'));
      expect(migration, contains('major_version = 17'));
      expect(migration, contains('cp between 768 and 879'));
      expect(migration, contains(publicFoodConfusableFrom));
      expect(migration, contains(publicFoodConfusableTo));
      expect(migration, contains("pg_catalog.replace(v, 'ß', 'ss')"));
      expect(migration, contains("pg_catalog.replace(v, 'œ', 'oe')"));
    });

    test('functions use an empty search_path and schema-qualified names', () {
      expect("set search_path = ''".allMatches(migration).length, 9);
      expect(migration.contains('set search_path = public'), isFalse);
      final publish = migration.indexOf(
        'function public.publish_saved_food',
      );
      expect(publish, greaterThanOrEqualTo(0));
      final publishSql = migration.substring(publish);
      expect(publishSql, contains('security definer'));
      expect(publishSql, contains("set search_path = ''"));
      expect(publishSql, contains('auth.uid()'));
      expect(publishSql, contains('pg_catalog.set_config('));
      expect(publishSql.contains('set search_path = public'), isFalse);
    });

    test('publish and public-field updates call the check', () {
      expect(
        migration,
        contains('public.public_food_name_is_banned(v_row.name)'),
      );
      expect(
        migration,
        contains('public.public_food_name_is_banned(v_row.normalized_name)'),
      );
      expect(
        migration,
        contains(
          "public.public_food_name_is_banned(pg_catalog.coalesce(v_row.brand, ''))",
        ),
      );
      expect(
        migration,
        contains(
          "public.public_food_name_is_banned(pg_catalog.coalesce(v_row.serving_unit_label, ''))",
        ),
      );
      expect(migration, contains('new.name is distinct from old.name'));
      expect(
        migration,
        contains('new.normalized_name is distinct from old.normalized_name'),
      );
      expect(migration, contains('new.brand is distinct from old.brand'));
      expect(
        migration,
        contains(
          'new.serving_unit_label is distinct from old.serving_unit_label',
        ),
      );
      expect(migration, contains('public food name is not allowed'));
      expect('update public.saved_foods'.allMatches(migration).length, 1);
      expect(migration, contains("set visibility = 'public'"));
    });
  });
}

List<String> _sqlMarkedList(String migration, String name) {
  final start = migration.indexOf('-- $name');
  final end = migration.indexOf('-- /$name');
  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));
  final block = migration.substring(start, end);
  return RegExp(
    "'([^']*)'",
  ).allMatches(block).map((match) => match.group(1)!).toList();
}

SavedFood _food(String name) {
  return SavedFood(
    foodId: 'food-1',
    ownerUserId: 'user-a',
    name: name,
    normalizedName: name.toLowerCase(),
    baseAmount: 100,
    unitType: FoodUnitType.g,
    servingUnitLabel: 'g',
    visibility: FoodVisibility.private,
    status: FoodStatus.active,
    kcalPerBase: 165,
    proteinPerBase: 10,
    fatPerBase: 5,
    carbPerBase: 20,
    sourceType: FoodSourceType.manual,
    createdAt: DateTime(2026, 7, 20),
    updatedAt: DateTime(2026, 7, 20),
  );
}
