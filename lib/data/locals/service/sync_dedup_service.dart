import 'package:hive/hive.dart';

enum SyncDedupStatus { reserved, alreadySynced, inFlight }

class SyncDedupReservation {
  final SyncDedupStatus status;
  final String? key;

  const SyncDedupReservation({required this.status, this.key});
}

class SyncDedupService {
  static const String _boxName = 'syncDedupBox';
  static const String _statusPending = 'pending';
  static const String _statusSynced = 'synced';
  static const Duration _pendingTtl = Duration(minutes: 2);

  Box<Map>? _box;

  Future<Box<Map>> get box async {
    _box ??= await Hive.openBox<Map>(_boxName);
    return _box!;
  }

  Future<SyncDedupReservation> reserve(
    String type,
    Map<String, dynamic> payload,
  ) async {
    final key = _buildIdentity(type, payload);
    if (key.isEmpty) {
      return const SyncDedupReservation(status: SyncDedupStatus.reserved);
    }

    final b = await box;
    final existingRaw = b.get(key);
    if (existingRaw != null) {
      final existing = Map<String, dynamic>.from(existingRaw);
      final status = existing['status']?.toString();
      if (status == _statusSynced) {
        return SyncDedupReservation(
          status: SyncDedupStatus.alreadySynced,
          key: key,
        );
      }

      if (status == _statusPending) {
        final updatedAtStr = existing['updatedAt']?.toString();
        final updatedAt = updatedAtStr != null
            ? DateTime.tryParse(updatedAtStr)
            : null;

        if (updatedAt != null &&
            DateTime.now().difference(updatedAt) < _pendingTtl) {
          return SyncDedupReservation(
            status: SyncDedupStatus.inFlight,
            key: key,
          );
        }
      }
    }

    await b.put(key, {
      'status': _statusPending,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    return SyncDedupReservation(status: SyncDedupStatus.reserved, key: key);
  }

  Future<void> markSynced(String reservationKey) async {
    final b = await box;
    await b.put(reservationKey, {
      'status': _statusSynced,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> release(String reservationKey) async {
    final b = await box;
    final existingRaw = b.get(reservationKey);
    if (existingRaw == null) {
      return;
    }

    final existing = Map<String, dynamic>.from(existingRaw);
    if (existing['status'] == _statusPending) {
      await b.delete(reservationKey);
    }
  }

  String _buildIdentity(String type, Map<String, dynamic> payload) {
    final transactionId = (payload['transaction_id'] ?? payload['transactionId'])
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
}
