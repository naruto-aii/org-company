import 'package:shared_preferences/shared_preferences.dart';

import '../utils/local_date.dart';

/// 公開食品検索の1日あたり回数。加入状態は [SubscriptionRepository] が持つ。
class LocalSubscriptionUsageStore {
  LocalSubscriptionUsageStore({SharedPreferences? preferences})
    : _preferences = preferences,
      _memory = preferences == null ? <String, int>{} : null;

  final SharedPreferences? _preferences;
  final Map<String, int>? _memory;

  String _searchKey(String userId, DateTime day) {
    final date = localDayStart(day);
    final stamp =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return 'public_food_search_count:$userId:$stamp';
  }

  Future<int> publicSearchCount({
    required String userId,
    required DateTime day,
  }) async {
    final key = _searchKey(userId, day);
    final prefs = _preferences;
    if (prefs != null) {
      return prefs.getInt(key) ?? 0;
    }
    return _memory![key] ?? 0;
  }

  Future<int> incrementPublicSearch({
    required String userId,
    required DateTime day,
  }) async {
    final next = await publicSearchCount(userId: userId, day: day) + 1;
    final key = _searchKey(userId, day);
    final prefs = _preferences;
    if (prefs != null) {
      await prefs.setInt(key, next);
    } else {
      _memory![key] = next;
    }
    return next;
  }
}
