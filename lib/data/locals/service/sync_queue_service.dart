import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:oro_ticket_app/data/locals/hive_boxes.dart';

class SyncQueueItem {
  final String id;
  final String type; // 'trip' or 'service_charge'
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;
  DateTime? lastAttempt;

  SyncQueueItem({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttempt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'lastAttempt': lastAttempt?.toIso8601String(),
      };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) => SyncQueueItem(
        id: json['id'],
        type: json['type'],
        data: json['data'],
        createdAt: DateTime.parse(json['createdAt']),
        retryCount: json['retryCount'] ?? 0,
        lastAttempt: json['lastAttempt'] != null
            ? DateTime.parse(json['lastAttempt'])
            : null,
      );
}

class SyncQueueService {
  static const String _boxName = 'syncQueueBox';
  static const int maxRetries = 5;

  Box<Map>? _box;

  Future<Box<Map>> get box async {
    _box ??= await Hive.openBox<Map>(_boxName);
    return _box!;
  }

  Future<void> addToQueue(SyncQueueItem item) async {
    final b = await box;
    await b.put(item.id, item.toJson());
    print('📤 Added to sync queue: ${item.type} (${item.id})');
  }

  Future<List<SyncQueueItem>> getPendingItems() async {
    final b = await box;
    return b.values
        .map((json) => SyncQueueItem.fromJson(Map<String, dynamic>.from(json)))
        .where((item) => item.retryCount < maxRetries)
        .toList();
  }

  Future<void> removeFromQueue(String id) async {
    final b = await box;
    await b.delete(id);
    print('✅ Removed from sync queue: $id');
  }

  Future<void> incrementRetry(String id) async {
    final b = await box;
    final item = b.get(id);
    if (item != null) {
      final syncItem = SyncQueueItem.fromJson(Map<String, dynamic>.from(item));
      syncItem.retryCount++;
      syncItem.lastAttempt = DateTime.now();

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
