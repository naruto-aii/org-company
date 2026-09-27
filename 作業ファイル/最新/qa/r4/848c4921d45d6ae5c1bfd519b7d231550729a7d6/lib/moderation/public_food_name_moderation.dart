import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../utils/food_name_normalizer.dart';
import 'public_food_banned_words.dart';

/// Client check for public food text.
///
/// Order: compose halfwidth voiced marks (U+FF9E / U+FF9F), Unicode NFKC,
/// strip combining marks U+0300–U+036F (kana voicing U+3099/U+309A stays),
/// accent / lookalike / digit-symbol fold, then case fold, kana fold, and
/// separator folding. Allowed food phrases are removed before the scan.
/// Latin terms and [publicFoodBoundaryOnlyTerms] match on a word boundary.
/// Other Japanese terms of length >= 2 match as substrings.
class PublicFoodNameModeration {
  const PublicFoodNameModeration._();

  static const rejectionMessage = 'この食品名は公開できません。別の名前を入力してください。';

  static final RegExp _combiningMarks = RegExp(r'[\u0300-\u036F]');

  static bool isBanned(String raw) {
    final spaced = _stripAllowedPhrases(
      normalizeForMatch(prepareForMatch(raw)),
    );
    if (spaced.isEmpty) {
      return false;
    }
    final compact = spaced.replaceAll(' ', '');
    for (final term in publicFoodBannedWords) {
      final normalizedTerm = normalizeForMatch(
        prepareForMatch(term),
      ).replaceAll(' ', '');
      if (normalizedTerm.isEmpty) {
        continue;
      }
      if (_useSubstring(normalizedTerm)) {
        if (compact.contains(normalizedTerm)) {
          return true;
        }
      } else if (_containsBounded(spaced, normalizedTerm) ||
          _containsBounded(compact, normalizedTerm)) {
        return true;
      }
    }
    return false;
  }

  /// True when a public field is changing into a banned value.
  /// An unchanged field is left alone so older rows can still edit other fields.
  static bool rejectsPublicUpdate({
    required String previousName,
    required String nextName,
    String? previousBrand,
    String? nextBrand,
    String? previousNormalizedName,
    String? nextNormalizedName,
    String? previousServingUnitLabel,
    String? nextServingUnitLabel,
  }) {
    return _changedIntoBanned(previousName, nextName) ||
        _changedIntoBanned(previousBrand, nextBrand) ||
        _changedIntoBanned(previousNormalizedName, nextNormalizedName) ||
        _changedIntoBanned(previousServingUnitLabel, nextServingUnitLabel);
  }

  static bool anyFieldBanned({
    required String name,
    String? normalizedName,
    String? brand,
    String? servingUnitLabel,
  }) {
    return isBanned(name) ||
        isBanned(normalizedName ?? '') ||
        isBanned(brand ?? '') ||
        isBanned(servingUnitLabel ?? '');
  }

  static bool _changedIntoBanned(String? previous, String? next) {
    final before = previous ?? '';
    final after = next ?? '';
    if (FoodNameNormalizer.normalize(before) ==
        FoodNameNormalizer.normalize(after)) {
      return false;
    }
    return isBanned(after);
  }

  /// Halfwidth voiced marks, then NFKC, then confusable folding.
  /// Separator folding happens afterwards.
  static String prepareForMatch(String raw) {
    final voiced = _composeHalfwidthVoiced(raw);
    final composed = unorm.nfkc(voiced).replaceAll(_combiningMarks, '');
    return _foldConfusables(composed);
  }

  static String _composeHalfwidthVoiced(String raw) {
    final runes = raw.runes.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < runes.length; i++) {
      if (i + 1 < runes.length) {
        final mark = runes[i + 1];
        final Map<int, int>? table = switch (mark) {
          0xFF9E => _dakuten,
          0xFF9F => _handakuten,
          _ => null,
        };
        final mapped = table?[runes[i]];
        if (mapped != null) {
          buffer.writeCharCode(mapped);
          i++;
          continue;
        }
      }
      buffer.writeCharCode(runes[i]);
    }
    return buffer.toString();
  }

  static String _stripAllowedPhrases(String spaced) {
    var current = spaced;
    for (final phrase in publicFoodAllowedPhrases) {
      current = _removeBounded(current, phrase);
    }
    return current.replaceAll(RegExp(r' +'), ' ').trim();
  }

  /// Removes bounded [phrase] occurrences, leaving a space in their place.
  static String _removeBounded(String haystack, String phrase) {
    if (phrase.isEmpty || haystack.isEmpty) {
      return haystack;
    }
    final buffer = StringBuffer();
    var read = 0;
    var from = 0;
    while (from <= haystack.length) {
      final index = haystack.indexOf(phrase, from);
      if (index < 0) {
        buffer.write(haystack.substring(read));
        break;
      }
      final beforeOk =
          index == 0 || !_isWordCode(haystack.codeUnitAt(index - 1));
      final afterIndex = index + phrase.length;
      final afterOk =
          afterIndex >= haystack.length ||
          !_isWordCode(haystack.codeUnitAt(afterIndex));
      if (beforeOk && afterOk) {
        buffer.write(haystack.substring(read, index));
        buffer.write(' ');
        read = afterIndex;
        from = afterIndex;
      } else {
        from = index + 1;
      }
    }
    return buffer.toString();
  }

  static String _foldConfusables(String value) {
    final expanded = value
        .replaceAll('ß', 'ss')
        .replaceAll('æ', 'ae')
        .replaceAll('Æ', 'ae')
        .replaceAll('œ', 'oe')
        .replaceAll('Œ', 'oe');
    final buffer = StringBuffer();
    for (final rune in expanded.runes) {
      final mapped = _confusableMap[rune];
      if (mapped == null) {
        buffer.writeCharCode(rune);
      } else {
        buffer.writeCharCode(mapped);
      }
    }
    return buffer.toString();
  }

  static String normalizeForMatch(String raw) {
    final buffer = StringBuffer();
    var pendingSpace = false;
    for (final rune in raw.runes) {
      final mapped = _mapRune(rune);
      if (mapped == null) {
        if (buffer.isNotEmpty) {
          pendingSpace = true;
        }
        continue;
      }
      if (pendingSpace) {
        buffer.write(' ');
        pendingSpace = false;
      }
      buffer.writeCharCode(mapped);
    }
    return buffer.toString();
  }

  static bool _useSubstring(String term) {
    if (RegExp('[a-z0-9]').hasMatch(term)) {
      return false;
    }
    if (publicFoodBoundaryOnlyTerms.contains(term)) {
      return false;
    }
    return term.runes.length >= 2;
  }

  static bool _containsBounded(String haystack, String term) {
    var start = 0;
    while (true) {
      final index = haystack.indexOf(term, start);
      if (index < 0) {
        return false;
      }
      final beforeOk =
          index == 0 || !_isWordCode(haystack.codeUnitAt(index - 1));
      final afterIndex = index + term.length;
      final afterOk =
          afterIndex >= haystack.length ||
          !_isWordCode(haystack.codeUnitAt(afterIndex));
      if (beforeOk && afterOk) {
        return true;
      }
      start = index + 1;
    }
  }

  static int? _mapRune(int rune) {
    if (rune == 0x3000 ||
        rune == 0x20 ||
        rune == 0x09 ||
        rune == 0x0A ||
        rune == 0x0D) {
      return null;
    }

    var code = rune;
    if (code >= 0xFF10 && code <= 0xFF19) {
      code = 0x30 + (code - 0xFF10);
    } else if (code >= 0xFF21 && code <= 0xFF3A) {
      code = 0x61 + (code - 0xFF21);
    } else if (code >= 0xFF41 && code <= 0xFF5A) {
      code = 0x61 + (code - 0xFF41);
    } else {
      final halfwidth = _halfwidthKatakana[code];
      if (halfwidth != null) {
        code = halfwidth;
      }
    }

    if (code >= 0x30A1 && code <= 0x30F3) {
      code -= 0x60;
    }
    if (code >= 0x41 && code <= 0x5A) {
      code = 0x61 + (code - 0x41);
    }
    if (_isWordCode(code)) {
      return code;
    }
    return null;
  }

  static bool _isWordCode(int code) {
    if (code >= 0x30 && code <= 0x39) {
      return true;
    }
    if (code >= 0x61 && code <= 0x7A) {
      return true;
    }
    if (code >= 0x3041 && code <= 0x3096) {
      return true;
    }
    if (code >= 0x30A1 && code <= 0x30FA) {
      return true;
    }
    if (code >= 0x4E00 && code <= 0x9FFF) {
      return true;
    }
    return code == 0x30FC;
  }

  static final Map<int, int> _confusableMap = _buildConfusableMap();
  static final Map<int, int> _halfwidthKatakana = _buildHalfwidthMap();
  static final Map<int, int> _dakuten = _pairMap(
    publicFoodHalfwidthDakutenBase,
    publicFoodHalfwidthDakutenTo,
  );
  static final Map<int, int> _handakuten = _pairMap(
    publicFoodHalfwidthHandakutenBase,
    publicFoodHalfwidthHandakutenTo,
  );

  static Map<int, int> _buildConfusableMap() {
    return _pairMap(publicFoodConfusableFrom, publicFoodConfusableTo);
  }

  static Map<int, int> _buildHalfwidthMap() {
    return _pairMap(
      publicFoodHalfwidthKatakanaFrom,
      publicFoodHalfwidthKatakanaTo,
    );
  }

  static Map<int, int> _pairMap(String fromText, String toText) {
    final from = fromText.runes.toList();
    final to = toText.runes.toList();
    final map = <int, int>{};
    for (var i = 0; i < from.length && i < to.length; i++) {
      map[from[i]] = to[i];
    }
    return map;
  }
}
