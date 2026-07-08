// lib/data/repositories/enhanced_sync_repository.dart
import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:oro_ticket_app/app/modules/sign_in/services/auth_service.dart';
import 'package:oro_ticket_app/data/locals/hive_boxes.dart';
import 'package:oro_ticket_app/data/locals/models/trip_model.dart';
import 'package:oro_ticket_app/data/locals/models/service_charge_model.dart';
import 'package:oro_ticket_app/data/locals/service/backup_service.dart';
import 'package:oro_ticket_app/data/locals/service/connectivity_service.dart';
import 'package:oro_ticket_app/data/locals/service/sync_queue_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum SyncResult {
  postedToServer,   // Successfully posted live during print (no Hive entry)
  savedOffline,     // Saved to Hive (offline or post failed)
  partialSuccess,   // One posted, one failed (will retry the failed one)
}

class EnhancedSyncRepository {
  final String baseUrl = dotenv.env['API_BASE_URL'] ?? '';
  final ConnectivityService _connectivityService =
      Get.find<ConnectivityService>();
  final SyncQueueService _syncQueueService = SyncQueueService();

  Timer? _periodicSyncTimer;

  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(interval, (_) => _trySyncPendingData());

    ever(_connectivityService.isConnected, (connected) {
      if (connected) {
        print('🌐 Connectivity restored, attempting to sync pending data...');
        _trySyncPendingData();
      }
    });
  }

  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
  }

  Future<void> _trySyncPendingData() async {
    if (!_connectivityService.isConnected.value) {
      print('📴 Device is offline, skipping automatic background sync');
      return;
    }

    print('🔄 Starting automatic background sync (internet is available)...');

    // 1. Process items waiting in the retry queue
    await _processSyncQueue();

    // 2. Actively scan main local storage for any unsynced trips and pending service charges
    //    This ensures data posts automatically in background without needing the print button
    await _syncUnsyncedTripsFromStorage();
    await _syncPendingServiceChargesFromStorage();

    print('✅ Automatic background sync cycle finished.');
  }

  // Process the dedicated sync queue (items that failed immediate sync or were queued while offline)
  Future<void> _processSyncQueue() async {
    final pendingItems = await _syncQueueService.getPendingItems();
    if (pendingItems.isEmpty) {
      print('   - Sync queue is empty');
      return;
    }

    print('   - Processing ${pendingItems.length} items from sync queue...');

    for (final item in pendingItems) {
      try {
        final success = item.type == 'trip'
            ? await _syncTrip(item.data)
            : await _syncServiceCharge(item.data);

        if (success) {
          await _syncQueueService.removeFromQueue(item.id);

          // If we have the original Hive key stored, delete the trip from main storage
          // so successful syncs are not kept in Hive
          if (item.type == 'trip' && item.data['_local_key'] != null) {
            try {
              final tripBox = Hive.box<TripModel>(HiveBoxes.tripBox);
              final key = int.tryParse(item.data['_local_key'].toString());
              if (key != null) {
                await tripBox.delete(key);
                print('   🗑️ Removed successfully synced trip from Hive (key: $key)');
              }
            } catch (_) {}
          }

          print('   ✅ Queue item synced successfully: ${item.type}');
        } else {
          await _syncQueueService.incrementRetry(item.id);
          print('   ⚠️ Queue item failed (will retry later): ${item.type}');
        }
      } catch (e) {
        await _syncQueueService.incrementRetry(item.id);
        print('   ❌ Error processing queue item ${item.type}: $e');
      }
    }
  }

  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      print('⚠️ Could not resolve app version: $e');
      return 'unknown';
    }
  }

  Future<Map<String, dynamic>> _withAppVersion(Map<String, dynamic> data) async {
    final appVersion = await _getAppVersion();
    final payload = Map<String, dynamic>.from(data);
    payload['version'] = payload['version'] ?? appVersion;
    payload['app_version'] = payload['app_version'] ?? payload['version'];
    return payload;
  }

  Future<bool> _syncTrip(Map<String, dynamic> tripData) async {
    try {
      final authService = Get.find<AuthService>();
      final token = await authService.getToken();

      if (token == null) {
        print('❌ No auth token available');
        return false;
      }

      final payload = await _withAppVersion(tripData);

      final response = await http
          .post(
            Uri.parse('$baseUrl/trips'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      final ok = response.statusCode == 200 || response.statusCode == 201;
      if (!ok) print('❌ Server rejected trip ${response.statusCode}');
      return ok;
    } catch (e) {
      final err = e.toString();
      if (err.contains('HandshakeException') || err.contains('CERTIFICATE_VERIFY_FAILED')) {
        print('❌ Trip sync TLS error (CERTIFICATE_VERIFY_FAILED). Device date/time is likely incorrect — set to automatic/network time.');
      } else {
        print('❌ Trip sync error: $e');
      }
      return false;
    }
  }

  // Sync a single service charge to server
  Future<bool> _syncServiceCharge(Map<String, dynamic> chargeData) async {
    try {
      final authService = Get.find<AuthService>();
      final token = await authService.getToken();

      if (token == null) {
        print('❌ No auth token available');
        return false;
      }

      final payload = await _withAppVersion(chargeData);

      final response = await http
          .post(
            Uri.parse('$baseUrl/service-charges'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      final ok = response.statusCode == 200 || response.statusCode == 201;
      if (!ok) {
        print('❌ Server rejected service-charge ${response.statusCode}');
        // Show user-facing error if app UI is available
        try {
          if (Get.context != null) {
            final msg = 'Failed to sync service charge (${response.statusCode})';
            ScaffoldMessenger.of(Get.context!).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } catch (_) {}
      }
      return ok;
    } catch (e) {
      final err = e.toString();
      if (err.contains('HandshakeException') || err.contains('CERTIFICATE_VERIFY_FAILED')) {
        print('❌ Service charge sync TLS error (CERTIFICATE_VERIFY_FAILED). Device date/time is likely incorrect — set to automatic/network time.');
        try {
          if (Get.context != null) {
            ScaffoldMessenger.of(Get.context!).showSnackBar(
              SnackBar(
                content: Text('Network TLS error during sync. Check device date/time.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } catch (_) {}
       } else {
         print('❌ Service charge sync error: $e');
         try {
           if (Get.context != null) {
             ScaffoldMessenger.of(Get.context!).showSnackBar(
               SnackBar(
                 content: Text('Error syncing service charge. Please try again.'),
                 backgroundColor: Colors.red,
                 duration: Duration(seconds: 4),
               ),
             );
           }
         } catch (_) {}
       }
      return false;
    }
  }

  // === NEW: Automatic background sync from main local storage ===
  // These methods run in the background whenever internet is available.
  // They ensure trips and service charges get posted without requiring the print button.

  Future<void> _syncUnsyncedTripsFromStorage() async {
    final tripBox = Hive.box<TripModel>(HiveBoxes.tripBox);
    final now = DateTime.now();

    // Skip items created in the last 10 seconds to avoid race with the immediate print sync path
    final unsyncedTrips = tripBox.values
        .where((t) => !t.isSynced && now.difference(t.dateAndTime).inSeconds > 10)
        .toList();

    if (unsyncedTrips.isEmpty) {
      print('   - No unsynced trips found in local storage (recent ones skipped to prevent duplication)');
      return;
    }

    print('   - Found ${unsyncedTrips.length} unsynced trips in storage → posting to server...');

    for (final trip in unsyncedTrips) {
      final success = await _syncTrip(trip.toJson());
      if (success) {
        // Successful server sync — do not keep in local Hive
        await trip.delete();
        print('   ✅ Trip posted from storage and removed from Hive: ${trip.vehicleId}');
      } else {
        print('   ⚠️ Failed to post trip from storage (will retry next cycle): ${trip.vehicleId}');
      }
    }
  }

  Future<void> _syncPendingServiceChargesFromStorage() async {
    final chargeBox = Hive.box<ServiceChargeModel>(HiveBoxes.serviceChargeBox);
    final now = DateTime.now();

    // Skip charges created in the last 10 seconds — prevents the background scanner
    // from posting the same charge that the print action is currently posting.
    final pendingCharges = chargeBox.values
        .where((c) => now.difference(c.dateTime).inSeconds > 10)
        .toList();

    if (pendingCharges.isEmpty) {
      print('   - No pending service charges found in local storage (recent ones skipped to prevent duplication)');
      return;
    }

    print('   - Found ${pendingCharges.length} pending service charges in storage → posting to server...');

    for (final charge in pendingCharges) {
      final success = await _syncServiceCharge(charge.toJson());
      if (success) {
        // Remove the successfully posted service charge
        final keys = chargeBox.keys.toList();
        for (final key in keys) {
          final c = chargeBox.get(key);
          if (c != null &&
              c.employeeId == charge.employeeId &&
              c.dateTime.millisecondsSinceEpoch == charge.dateTime.millisecondsSinceEpoch) {
            await chargeBox.delete(key);
            print('   ✅ Service charge posted from storage and removed');
            break;
          }
        }
      } else {
        print('   ⚠️ Failed to post service charge from storage (will retry next cycle)');
      }
    }
  }

  Future<SyncResult> saveDataWithSync({
    required TripModel trip,
    required ServiceChargeModel serviceCharge,
  }) async {
    final liveResult = await Connectivity().checkConnectivity();
    final isOnlineNow = liveResult != ConnectivityResult.none;

    if (isOnlineNow) {
      print('🌐 [PRINT] Online — attempting direct post to server');

      final tripPayload = await _withAppVersion(trip.toJson());
      final chargePayload = await _withAppVersion(serviceCharge.toJson());
      final tripSuccess = await _syncTrip(tripPayload);
      final chargeSuccess = await _syncServiceCharge(chargePayload);

      if (tripSuccess && chargeSuccess) {
        await _removeExistingTripFromHive(trip);
        await _removeExistingServiceChargeFromHive(serviceCharge, trip);
        await BackupService.backupData();
        print('✅ [PRINT] Successfully posted both to server. Local duplicates removed.');
        return SyncResult.postedToServer;
      }

      print('⚠️ [PRINT] Partial server post (trip:$tripSuccess, charge:$chargeSuccess) — saving failed items once');

      if (!tripSuccess) {
        await _saveTripToHiveIfNeeded(trip);
        await _queueForRetry('trip', tripPayload);
      }
      if (!chargeSuccess) {
        await _saveServiceChargeToHiveIfNeeded(serviceCharge, trip);
        await _queueForRetry('service_charge', chargePayload);
      }

      return SyncResult.partialSuccess;
    }

    print('📴 [PRINT] No internet — saving to Hive once for later sync');
    await _saveTripToHiveIfNeeded(trip);
    await _saveServiceChargeToHiveIfNeeded(serviceCharge, trip);
    await BackupService.backupData();

    await _queueForRetry('trip', await _withAppVersion(trip.toJson()));
    await _queueForRetry('service_charge', await _withAppVersion(serviceCharge.toJson()));

    return SyncResult.savedOffline;
  }

  Future<void> _queueForRetry(String type, Map<String, dynamic> data) async {
    final item = SyncQueueItem(
      id: '${type}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );

    await _syncQueueService.addToQueue(item);
  }

  Future<void> _saveTripToHiveIfNeeded(TripModel trip) async {
    final tripBox = Hive.box<TripModel>(HiveBoxes.tripBox);

    final alreadyExists = tripBox.values.any((existing) {
      if (trip.transactionId.isNotEmpty &&
          existing.transactionId.isNotEmpty &&
          existing.transactionId == trip.transactionId) {
        return true;
      }

      return existing.vehicleId == trip.vehicleId &&
          existing.dateAndTime.millisecondsSinceEpoch ==
              trip.dateAndTime.millisecondsSinceEpoch &&
          existing.km == trip.km &&
          existing.tariff == trip.tariff &&
          existing.serviceCharge == trip.serviceCharge &&
          existing.totalPaid == trip.totalPaid &&
          existing.departureTerminalId == trip.departureTerminalId &&
          existing.arrivalTerminalId == trip.arrivalTerminalId &&
          existing.companyId == trip.companyId &&
          existing.employeeId == trip.employeeId &&
          existing.departureName == trip.departureName &&
          existing.arrivalName == trip.arrivalName;
    });

    if (alreadyExists) {
      print('ℹ️ Trip already exists locally; skipping duplicate save');
      return;
    }

    final tripKey = await tripBox.add(trip);
    print('💾 Trip saved locally with key: $tripKey');
  }

  Future<void> _saveServiceChargeToHiveIfNeeded(
    ServiceChargeModel serviceCharge,
    TripModel trip,
  ) async {
    final chargeBox = Hive.box<ServiceChargeModel>(HiveBoxes.serviceChargeBox);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final existingEntry = chargeBox.values.firstWhereOrNull((entry) {
      if (serviceCharge.transactionId.isNotEmpty &&
          entry.transactionId.isNotEmpty &&
          entry.transactionId == serviceCharge.transactionId) {
        return true;
      }

      final entryDate = DateTime(
        entry.dateTime.year,
        entry.dateTime.month,
        entry.dateTime.day,
      );
      return entry.departureTerminal == trip.departureTerminalId &&
          entry.employeeId == trip.employeeId &&
          entryDate == today;
    });

    if (existingEntry != null) {
      existingEntry.serviceChargeAmount += serviceCharge.serviceChargeAmount;
      await existingEntry.save();
      print('💾 Updated existing service charge for employee ${trip.employeeId}');
    } else {
      final chargeKey = await chargeBox.add(serviceCharge);
      print('💾 Service charge saved locally with key: $chargeKey');
    }
  }

  Future<void> _removeExistingTripFromHive(TripModel trip) async {
    final tripBox = Hive.box<TripModel>(HiveBoxes.tripBox);
    final matches = tripBox.values.where((existing) {
      if (trip.transactionId.isNotEmpty &&
          existing.transactionId.isNotEmpty &&
          existing.transactionId == trip.transactionId) {
        return true;
      }

      return existing.vehicleId == trip.vehicleId &&
          existing.dateAndTime.millisecondsSinceEpoch ==
              trip.dateAndTime.millisecondsSinceEpoch &&
          existing.km == trip.km &&
          existing.tariff == trip.tariff &&
          existing.serviceCharge == trip.serviceCharge &&
          existing.totalPaid == trip.totalPaid &&
          existing.departureTerminalId == trip.departureTerminalId &&
          existing.arrivalTerminalId == trip.arrivalTerminalId &&
          existing.companyId == trip.companyId &&
          existing.employeeId == trip.employeeId;
    }).toList();

    for (final match in matches) {
      await match.delete();
    }

    if (matches.isNotEmpty) {
      print('🧹 Removed ${matches.length} matching local trip duplicate(s) after successful sync');
    }
  }

  Future<void> _removeExistingServiceChargeFromHive(
    ServiceChargeModel serviceCharge,
    TripModel trip,
  ) async {
    final chargeBox = Hive.box<ServiceChargeModel>(HiveBoxes.serviceChargeBox);
    final matches = chargeBox.values.where((existing) {
      if (serviceCharge.transactionId.isNotEmpty &&
          existing.transactionId.isNotEmpty &&
          existing.transactionId == serviceCharge.transactionId) {
        return true;
      }

      final existingDate = DateTime(
        existing.dateTime.year,
        existing.dateTime.month,
        existing.dateTime.day,
      );
      final currentDate = DateTime(
        serviceCharge.dateTime.year,
        serviceCharge.dateTime.month,
        serviceCharge.dateTime.day,
      );

      return existing.departureTerminal == trip.departureTerminalId &&
          existing.employeeId == trip.employeeId &&
          existingDate == currentDate &&
          existing.companyId == serviceCharge.companyId;
    }).toList();

    for (final match in matches) {
      await match.delete();
    }

    if (matches.isNotEmpty) {
      print('🧹 Removed ${matches.length} matching local service charge duplicate(s) after successful sync');
    }
  }

  Future<int> get pendingSyncCount => _syncQueueService.queueSize;
}
