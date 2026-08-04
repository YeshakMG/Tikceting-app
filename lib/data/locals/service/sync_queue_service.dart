import 'package:hive/hive.dart';

class SyncQueueItem {
  final String id;
  final String type; // 'trip' or 'service_charge'
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;
  DateTime? lastAttempt;
  DateTime? nextAttemptAt;

  SyncQueueItem({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttempt,
    this.nextAttemptAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'lastAttempt': lastAttempt?.toIso8601String(),
        'nextAttemptAt': nextAttemptAt?.toIso8601String(),
      };

  static Map<String, dynamic> normalizeJson(Map raw) {
    final normalized = Map<String, dynamic>.from(raw);
    final rawData = normalized['data'];
    if (rawData is Map) {
      normalized['data'] = Map<String, dynamic>.from(rawData);
    }
    return normalized;
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) => SyncQueueItem(
        id: json['id'],
        type: json['type'],
        data: json['data'] is Map
            ? Map<String, dynamic>.from(json['data'])
            : <String, dynamic>{},
        createdAt: DateTime.parse(json['createdAt']),
        retryCount: json['retryCount'] ?? 0,
        lastAttempt: json['lastAttempt'] != null
            ? DateTime.parse(json['lastAttempt'])
            : null,
        nextAttemptAt: json['nextAttemptAt'] != null
            ? DateTime.parse(json['nextAttemptAt'])
            : null,
      );
}

class SyncQueueService {
  static const String _boxName = 'syncQueueBox';
  static const int maxRetries = 5;

  static Duration calculateBackoff({
    required int retryCount,
    int? statusCode,
  }) {
    final baseSeconds = statusCode == 429
        ? 60 + (retryCount * 60)
        : switch (retryCount) {
            0 => 2,
            1 => 5,
            2 => 15,
            _ => 60,
          };

    final cappedSeconds = baseSeconds.clamp(2, 600);
    return Duration(seconds: cappedSeconds);
  }

  Box<Map>? _box;

  Future<Box<Map>> get box async {
    _box ??= await Hive.openBox<Map>(_boxName);
    return _box!;
  }

  Future<void> addToQueue(SyncQueueItem item) async {
    final b = await box;

    final newIdentity = _buildIdentity(item.type, item.data);
    if (newIdentity.isNotEmpty) {
      for (final existingRaw in b.values) {
        final existing = SyncQueueItem.fromJson(
          SyncQueueItem.normalizeJson(existingRaw),
        );
        final existingIdentity = _buildIdentity(existing.type, existing.data);
        if (existingIdentity == newIdentity) {
          print(
              '♻️ Queue duplicate detected for ${item.type}, skipping enqueue');
          return;
        }
      }
    }

    await b.put(item.id, item.toJson());
    print('📤 Added to sync queue: ${item.type} (${item.id})');
  }

  Future<int> removeDuplicateItems() async {
    final b = await box;
    final seen = <String>{};
    final keysToDelete = <dynamic>[];

    for (final entry in b.toMap().entries) {
      final raw = entry.value;
      final item = SyncQueueItem.fromJson(
        SyncQueueItem.normalizeJson(raw),
      );
      final identity = _buildIdentity(item.type, item.data);

      if (identity.isEmpty) {
        continue;
      }

      if (seen.contains(identity)) {
        keysToDelete.add(entry.key);
      } else {
        seen.add(identity);
      }
    }

    for (final key in keysToDelete) {
      await b.delete(key);
    }

    if (keysToDelete.isNotEmpty) {
      print('🧹 Removed ${keysToDelete.length} duplicate item(s) from sync queue');
    }

    return keysToDelete.length;
  }

  String _buildIdentity(String type, Map<String, dynamic> payload) {
    final transactionId =
        (payload['transaction_id'] ?? payload['transactionId'])
            ?.toString()
            .trim();

    if (transactionId != null && transactionId.isNotEmpty) {
      return '$type:tx:$transactionId';
    }

    if (type == 'trip') {
      final vehicleId = payload['vehicle_id']?.toString() ?? '';
      final timestamp = payload['date_and_time']?.toString() ?? '';
      final departure = payload['departure_terminal_id']?.toString() ?? '';
      final arrival = payload['arrival_terminal_id']?.toString() ?? '';
      final company = payload['company_id']?.toString() ?? '';
      final total = payload['total_paid']?.toString() ?? '';

      if (vehicleId.isEmpty || timestamp.isEmpty) {
        return '';
      }

      return '$type:fp:$vehicleId|$timestamp|$departure|$arrival|$company|$total';
    }

    if (type == 'service_charge') {
      final departure = payload['departure_terminal_id']?.toString() ?? '';
      final timestamp = payload['date_and_time']?.toString() ?? '';
      final createdBy = payload['created_by']?.toString() ?? '';
      final company = payload['company_id']?.toString() ?? '';
      final amount = payload['service_charge_amount']?.toString() ?? '';

      if (departure.isEmpty || timestamp.isEmpty || createdBy.isEmpty) {
        return '';
      }

      return '$type:fp:$departure|$timestamp|$createdBy|$company|$amount';
    }

    return '';
  }

  Future<List<SyncQueueItem>> getPendingItems() async {
    final b = await box;
    final now = DateTime.now();

    return b.values
      .map((json) => SyncQueueItem.fromJson(SyncQueueItem.normalizeJson(json)))
        .where((item) => item.retryCount < maxRetries)
        .where((item) => item.nextAttemptAt == null || !item.nextAttemptAt!.isAfter(now))
        .toList();
  }

  Future<void> removeFromQueue(String id) async {
    final b = await box;
    await b.delete(id);
    print('✅ Removed from sync queue: $id');
  }

  Future<void> incrementRetry(String id, {int? statusCode}) async {
    final b = await box;
    final item = b.get(id);
    if (item != null) {
      final syncItem = SyncQueueItem.fromJson(
        SyncQueueItem.normalizeJson(item),
      );
      syncItem.retryCount++;
      syncItem.lastAttempt = DateTime.now();
      syncItem.nextAttemptAt = DateTime.now().add(
        calculateBackoff(retryCount: syncItem.retryCount, statusCode: statusCode),
      );

      // Never delete on failure/timeout — only remove on successful post
      await b.put(id, syncItem.toJson());
    }
  }

  Future<int> get queueSize async {
    final b = await box;
    return b.length;
  }

  Future<void> clearQueue() async {
    final b = await box;
    await b.clear();
  }
}
