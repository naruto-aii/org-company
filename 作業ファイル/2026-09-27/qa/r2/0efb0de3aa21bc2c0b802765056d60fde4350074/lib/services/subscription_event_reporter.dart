/// Counts two product events. Each insert is user id, event type, and a
/// server timestamp. No food names, health data, receipts, or free text.
abstract class SubscriptionEventReporter {
  const SubscriptionEventReporter();

  Future<void> recordFreeLimitHit(String? userId);

  Future<void> recordConvertedToPaid(String? userId);
}

class NoOpSubscriptionEventReporter extends SubscriptionEventReporter {
  const NoOpSubscriptionEventReporter();

  @override
  Future<void> recordFreeLimitHit(String? userId) async {}

  @override
  Future<void> recordConvertedToPaid(String? userId) async {}
}

class SubscriptionEventTypes {
  const SubscriptionEventTypes._();

  static const freeLimitHit = 'free_limit_hit';
  static const convertedToPaid = 'converted_to_paid';
}

/// Row written by the client. The database sets `created_at`.
Map<String, String>? subscriptionEventInsert({
  required String? userId,
  required String eventType,
}) {
  final id = userId?.trim() ?? '';
  if (id.isEmpty) {
    return null;
  }
  if (eventType != SubscriptionEventTypes.freeLimitHit &&
      eventType != SubscriptionEventTypes.convertedToPaid) {
    return null;
  }
  return {'user_id': id, 'event_type': eventType};
}

class InsertingSubscriptionEventReporter extends SubscriptionEventReporter {
  InsertingSubscriptionEventReporter({required this.insert});

  final Future<void> Function(Map<String, String> row) insert;

  @override
  Future<void> recordFreeLimitHit(String? userId) {
    return _record(userId, SubscriptionEventTypes.freeLimitHit);
  }

  @override
  Future<void> recordConvertedToPaid(String? userId) {
    return _record(userId, SubscriptionEventTypes.convertedToPaid);
  }

  Future<void> _record(String? userId, String eventType) async {
    final row = subscriptionEventInsert(userId: userId, eventType: eventType);
    if (row == null) {
      return;
    }
    try {
      await insert(row);
    } catch (_) {
      // A duplicate first-event row, or a missing table, must not block the app.
    }
  }
}
