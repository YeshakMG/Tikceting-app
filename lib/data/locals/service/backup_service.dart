import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:oro_ticket_app/data/locals/hive_boxes.dart';
import 'package:oro_ticket_app/data/locals/models/trip_model.dart';
import 'package:oro_ticket_app/data/locals/models/service_charge_model.dart';
import 'package:oro_ticket_app/data/locals/models/departure_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/models/arrival_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/models/vehicle_model.dart';
import 'package:oro_ticket_app/data/locals/models/tariff_model.dart';
import 'package:oro_ticket_app/data/locals/models/commission_rule_model.dart';
import 'package:oro_ticket_app/data/locals/models/terminal_destination.dart';
import 'package:oro_ticket_app/data/locals/models/vehicle_route.dart';
import 'package:collection/collection.dart';
import 'package:oro_ticket_app/core/utils/security_utils.dart';
import 'package:oro_ticket_app/data/locals/service/token_storage_service.dart';
import 'package:oro_ticket_app/data/locals/service/user_storage_service.dart';
import 'package:oro_ticket_app/data/repositories/sync_repository.dart';

class BackupService {
  static const String _backupFileName = '.x7k9p3m2.dat';
  static const String _key = 'oro_ticket_secure_key_2026_v1'; // 32 chars
  static final _fixedIV = IV.fromUtf8('oro_ticket_iv_16'); // must be exactly 16 chars

  static Future<Directory> _getBackupDirectory() async {
    Directory? documentsDir;

    final candidates = <String>[
      '/storage/emulated/0/Documents',
      '/sdcard/Documents',
    ];

    try {
      final externalDocs = await getExternalStorageDirectories(type: StorageDirectory.documents);
      if (externalDocs != null && externalDocs.isNotEmpty) {
        candidates.addAll(externalDocs.map((d) => d.path));
      }
    } catch (_) {}

    for (final path in candidates) {
      try {
        final dir = Directory(path);
        if (await dir.exists()) {
          documentsDir = dir;
          break;
        }
      } catch (_) {}
    }

    if (documentsDir == null) {
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) documentsDir = extDir;
      } catch (_) {}
    }

    documentsDir ??= Directory('/storage/emulated/0');

    final backupDir = Directory('${documentsDir.path}/.sys_9p7k');
    if (!await backupDir.exists()) {
      try {
        await backupDir.create(recursive: true);
      } catch (_) {}
    }

    print('📂 Backup directory: ${backupDir.path}');
    return backupDir;
  }

  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // First try normal storage permission
      var status = await Permission.storage.request();
      if (status.isGranted) {
        print('✅ Storage permission granted');
        return true;
      }

      // For Android 11+ (API 30+), request All Files Access
      status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        print('✅ Manage External Storage permission granted');
        return true;
      }

      print('❌ Storage permission denied. User must enable "All files access" in Settings > Apps > Oro Ticket App > Permissions');
      return false;
    }
    return true;
  }

  static Future<void> backupData() async {
    print('💾 Starting automatic backup...');
    
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      print('❌ Storage permission denied for backup');
      return;
    }

    try {
      final backupDir = await _getBackupDirectory();
      final file = File('${backupDir.path}/$_backupFileName');

      // Decrypt current token and user so we can re-encrypt on restore
      final rawToken = await TokenStorageService.getToken();
      final rawUser = await UserStorageService.getUser();

      final tripBox = Hive.box<TripModel>(HiveBoxes.tripBox);
      final serviceBox = Hive.box<ServiceChargeModel>(HiveBoxes.serviceChargeBox);
      final departureBox = Hive.box<DepartureTerminalModel>(HiveBoxes.departureTerminalsBox);
      final arrivalBox = Hive.box<ArrivalTerminalModel>(HiveBoxes.arrivalTerminalsBox);
      final vehicleBox = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);
      final tariffBox = Hive.box<TariffModel>(HiveBoxes.tariffsBox);
      final commissionBox = Hive.box<CommissionRuleModel>(HiveBoxes.commissionRulesBox);

      print('📝 Token exists: ${rawToken != null}');
      print('👤 User exists: ${rawUser != null}');
      print('🚌 Vehicles in local: ${vehicleBox.values.length}');
      print('🚏 Departures in local: ${departureBox.values.length}');
      print('📍 Arrivals in local: ${arrivalBox.values.length}');
      print('💰 Tariffs in local: ${tariffBox.values.length}');
      print('📋 Commission Rules in local: ${commissionBox.values.length}');

      final tripsList = tripBox.values.map((e) => e.toJson()).toList();
      final serviceList = serviceBox.values.map((e) => e.toJson()).toList();
      final depList = departureBox.values.map((e) => e.toJson()).toList();
      final arrList = arrivalBox.values.map((e) => e.toJson()).toList();
      final vehicleList = vehicleBox.values.map((e) => e.toJson()).toList();
      final tariffList = tariffBox.values.map((e) => e.toJson()).toList();
      final commissionList = commissionBox.values.map((e) => e.toJson()).toList();

      final data = {
        'rawToken': rawToken,
        'rawUser': rawUser?.toJson(),
        'trips': tripsList,
        'serviceCharges': serviceList,
        'departureTerminals': depList,
        'arrivalTerminals': arrList,
        'vehicles': vehicleList,
        'tariffs': tariffList,
        'commissionRules': commissionList,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Detailed debug print of backup contents (summaries)
      try {
        print('🔎 Backup content summary:');
        print('  Environment details:');
        print('    - Current time: ${DateTime.now().toIso8601String()}');
        try { print('    - Platform: ${Platform.operatingSystem}'); } catch (_) {}
        try { print('    - Backup Dir: ${backupDir.path}'); } catch (_) {}
        try { print('    - File path: ${file.path}'); } catch (_) {}
        try { print('    - Working dir: ${Directory.current.path}'); } catch (_) {}
        try { print('    - Active file: oro_ticket_app/lib/app/modules/ticket/view/ticket_view.dart'); } catch (_) {}

        print('  - Token present: ${rawToken != null}');
        print('  - User present: ${rawUser != null}');
        print('  - Trips count: ${tripsList.length}');
        if (tripsList.isNotEmpty) {
          print('    • First 5 trips:');
          for (var i = 0; i < (tripsList.length > 5 ? 5 : tripsList.length); i++) {
            final t = tripsList[i];
            print('      ${i + 1}. vehicleId=${t['vehicleId'] ?? t['vehicle_id']}, date=${t['dateAndTime'] ?? t['date_and_time']}');
          }
        }
        print('  - Token present: ${rawToken != null}');
        print('  - User present: ${rawUser != null}');
        print('  - Trips count: ${tripsList.length}');
        if (tripsList.isNotEmpty) {
          print('    • First 5 trips:');
          for (var i = 0; i < (tripsList.length > 5 ? 5 : tripsList.length); i++) {
            final t = tripsList[i];
            print('      ${i + 1}. vehicleId=${t['vehicleId'] ?? t['vehicle_id']}, date=${t['dateAndTime'] ?? t['date_and_time']}');
          }
        }

        print('  - ServiceCharges count: ${serviceList.length}');
        if (serviceList.isNotEmpty) {
          print('    • First 5 service charges:');
          for (var i = 0; i < (serviceList.length > 5 ? 5 : serviceList.length); i++) {
            final s = serviceList[i];
            print('      ${i + 1}. employeeId=${s['employeeId'] ?? s['employee_id']}, amount=${s['serviceChargeAmount'] ?? s['service_charge_amount']}');
          }
        }

        print('  - Departure terminals count: ${depList.length}');
        print('    • Names: ${depList.take(10).map((d) => d['name'] ?? d['terminal_name'] ?? d['id']).toList()}');

        print('  - Arrival terminals count: ${arrList.length}');
        print('    • Names: ${arrList.take(10).map((a) => a['name'] ?? a['terminal_name'] ?? a['id']).toList()}');

        print('  - Vehicles count: ${vehicleList.length}');
        print('    • Plates: ${vehicleList.take(20).map((v) => v['plate_number'] ?? v['plateNumber'] ?? v['id']).toList()}');

        print('  - Tariffs count: ${tariffList.length}');
        print('  - Commission rules count: ${commissionList.length}');
      } catch (e) {
        print('⚠️ Failed to print detailed backup summary: $e');
      }

      final jsonString = jsonEncode(data);
      final encrypted = _encrypt(jsonString);

      await file.writeAsString(encrypted);
      print('✅ Encrypted backup saved successfully to: ${file.path}');
    } catch (e) {
      print('❌ Backup failed: $e');
    }
  }

  static Future<bool> restoreIfNeeded() async {
    print('🔄 Checking for backup restore...');
    
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      print('❌ Storage permission not granted');
      return false;
    }

    try {
      final backupDir = await _getBackupDirectory();
      final file = File('${backupDir.path}/$_backupFileName');

      print('📁 Looking for backup at: ${file.path}');

      if (!await file.exists()) {
        print('ℹ️ No backup file found at ${file.path}');
        return false;
      }

      print('📦 Backup file found, restoring...');
       final encrypted = await file.readAsString();
       final decrypted = _decrypt(encrypted);
       print('🔍 Decrypted backup size: ${decrypted.length} chars');
       try {
         final parsedTop = jsonDecode(decrypted);
         if (parsedTop is Map<String, dynamic>) {
           print('🔑 Top-level keys in backup: ${parsedTop.keys.toList()}');
         } else {
           print('⚠️ Backup JSON top-level is not an object: ${parsedTop.runtimeType}');
         }
       } catch (e) {
         print('❗ Could not parse decrypted backup JSON preview: $e');
       }
       final data = jsonDecode(decrypted) as Map<String, dynamic>;
 
       // Re-encrypt and restore token using current device key"}
      if (data['rawToken'] != null) {
        final encrypted = await SecurityUtils.encryptData(data['rawToken'], 'auth_token');
        if (encrypted != null) {
          final tokenBox = await Hive.openBox<String>('encryptedTokenData');
          await tokenBox.put('authToken', encrypted);
          print('✅ Restored and re-encrypted auth token from backup');
        }
      }

      // Re-encrypt and restore user using current device key
      if (data['rawUser'] != null) {
        final userJson = jsonEncode(data['rawUser']);
        final encrypted = await SecurityUtils.encryptData(userJson, 'user_data');
        if (encrypted != null) {
          final userBox = await Hive.openBox<String>('encryptedUserData');
          await userBox.put('currentUser', encrypted);
          print('✅ Restored and re-encrypted user login information from backup');
        }
      }

      // After restoring login + reference data from backup: do NOT perform network refresh here.
      // Network refresh should occur after the app UI is up and connectivity is available.
      if (data['rawToken'] != null || data['rawUser'] != null) {
        print('ℹ️ Server refresh deferred until app startup and network availability');
      }

      // Only restore trips if current is empty and backup has data
      try {
        final tripBox = Hive.box<TripModel>(HiveBoxes.tripBox);
        final rawTrips = data['trips'] as List? ?? [];
        print('  • Backup trips items: ${rawTrips.runtimeType}, count=${rawTrips.length}');
        final backupTrips = <Map<String, dynamic>>[];
        for (var i = 0; i < rawTrips.length; i++) {
          final item = rawTrips[i];
          if (item is Map) {
            try {
              backupTrips.add(Map<String, dynamic>.from(item));
            } catch (e) {
              print('⚠️ Could not normalize trip item at index $i: $e');
            }
          } else {
            print('⚠️ Unexpected trip item type at index $i: ${item.runtimeType}');
          }
        }

        if (tripBox.isEmpty && backupTrips.isNotEmpty) {
          int restored = 0;
          for (var i = 0; i < backupTrips.length; i++) {
            final t = backupTrips[i];
            try {
              await tripBox.add(TripModel.fromJson(t));
              restored++;
            } catch (e) {
              print('⚠️ Skipped one bad trip during restore at index $i: $e -- item=${t.toString().substring(0, t.toString().length > 200 ? 200 : t.toString().length)}');
            }
          }
          print('✅ Restored $restored trips from backup (out of ${backupTrips.length})');
        }
      } catch (e) {
        print('⚠️ Could not restore trips (may be empty or corrupted): $e');
      }

      // Only restore service charges if current is empty and backup has data
      try {
        final serviceBox = Hive.box<ServiceChargeModel>(HiveBoxes.serviceChargeBox);
        final rawCharges = data['serviceCharges'] as List? ?? [];
        print('  • Backup service charges items: ${rawCharges.runtimeType}, count=${rawCharges.length}');
        final backupCharges = <Map<String, dynamic>>[];
        for (var i = 0; i < rawCharges.length; i++) {
          final item = rawCharges[i];
          if (item is Map) {
            try {
              backupCharges.add(Map<String, dynamic>.from(item));
            } catch (e) {
              print('⚠️ Could not normalize service charge item at index $i: $e');
            }
          } else {
            print('⚠️ Unexpected service charge item type at index $i: ${item.runtimeType}');
          }
        }

        if (serviceBox.isEmpty && backupCharges.isNotEmpty) {
          int restored = 0;
          for (var i = 0; i < backupCharges.length; i++) {
            final c = backupCharges[i];
            try {
              await serviceBox.add(ServiceChargeModel.fromJson(c));
              restored++;
            } catch (e) {
              print('⚠️ Skipped one bad service charge during restore at index $i: $e -- item=${c.toString().substring(0, c.toString().length > 200 ? 200 : c.toString().length)}');
            }
          }
          print('✅ Restored $restored service charges from backup (out of ${backupCharges.length})');
        }
      } catch (e) {
        print('⚠️ Could not restore service charges (may be empty or corrupted): $e');
      }

      // Only restore departure terminals if current is empty and backup has data
      try {
        final depBox = Hive.box<DepartureTerminalModel>(HiveBoxes.departureTerminalsBox);
        final backupDeps = (data['departureTerminals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (depBox.isEmpty && backupDeps.isNotEmpty) {
          for (final d in backupDeps) {
            if (d != null) {
              await depBox.add(DepartureTerminalModel.fromJson(d));
            }
          }
          print('✅ Restored ${backupDeps.length} departure terminals from backup');
        }
      } catch (e) {
        print('⚠️ Could not restore departure terminals (may be empty or corrupted): $e');
      }

      // Only restore arrival terminals if current is empty and backup has data
      try {
        final arrBox = Hive.box<ArrivalTerminalModel>(HiveBoxes.arrivalTerminalsBox);
        final backupArrs = (data['arrivalTerminals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (arrBox.isEmpty && backupArrs.isNotEmpty) {
          for (final a in backupArrs) {
            if (a != null) {
              await arrBox.add(ArrivalTerminalModel.fromJson(a));
            }
          }
          print('✅ Restored ${backupArrs.length} arrival terminals from backup');
        }
      } catch (e) {
        print('⚠️ Could not restore arrival terminals (may be empty or corrupted): $e');
      }

      // Only restore vehicles if current is empty and backup has data
      try {
        final vehicleBox = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);
        final rawVehicles = data['vehicles'] as List? ?? [];
        print('  • Backup vehicles items: ${rawVehicles.runtimeType}, count=${rawVehicles.length}');

        if (rawVehicles.isEmpty) {
          print('ℹ️ No vehicles found in backup file');
        } else {
          int upserted = 0;

          for (var i = 0; i < rawVehicles.length; i++) {
            final item = rawVehicles[i];
            if (item is! Map) {
              print('⚠️ Unexpected vehicle item type at index $i: ${item.runtimeType}');
              continue;
            }

            try {
              final vm = VehicleModel.fromJson(Map<String, dynamic>.from(item));

              // If vehicle has no route info, try to synthesize from assignedTerminalId + arrivalTerminals
              VehicleModel vmToSave = vm;
              try {
                if (vm.currentRoute == null) {
                  final depId = vm.assignedTerminalId?.toString() ?? '';
                  final firstArrivalId = (vm.arrivalTerminals != null && vm.arrivalTerminals!.isNotEmpty)
                      ? vm.arrivalTerminals!.first.toString()
                      : '';

                  if (depId.isNotEmpty && firstArrivalId.isNotEmpty) {
                    // Lookup arrival terminal details and departure terminal name if available
                    String depName = '';
                    String arrName = '';
                    double dist = 0.0;
                    try {
                      final depBox = Hive.box<DepartureTerminalModel>(HiveBoxes.departureTerminalsBox);
                      final arrBox = Hive.box<ArrivalTerminalModel>(HiveBoxes.arrivalTerminalsBox);
                      DepartureTerminalModel? dep;
                      ArrivalTerminalModel? arr;

                      for (final d in depBox.values) {
                        if (d.id == depId) {
                          dep = d;
                          break;
                        }
                      }

                      for (final a in arrBox.values) {
                        if (a.id == firstArrivalId) {
                          arr = a;
                          break;
                        }
                      }
                    } catch (_) {}

                      // if (dep != null) depName = dep.name;
                      // if (arr != null) {
                      //   arrName = arr.name;
                      //   try { dist = double.tryParse(arr.distance.toString()) ?? 0.0; } catch (_) {}
                      // }
 
                    final td = TerminalDestination(
                      id: '${depId}_$firstArrivalId',
                      departureTerminalId: depId,
                      arrivalTerminalId: firstArrivalId,
                      distance: dist,
                      roadType: 'asphalt',
                      departureTerminalName: depName.isNotEmpty ? depName : null,
                      arrivalTerminalName: arrName.isNotEmpty ? arrName : null,
                    );

                    final vr = VehicleRoute(
                      id: '${vm.id}_route',
                      vehicleId: vm.id,
                      terminalDestinationId: td.id,
                      isOnTemporary: false,
                      terminalDestination: td,
                    );

                    // Build a new VehicleModel with the synthesized route
                    vmToSave = VehicleModel(
                      id: vm.id,
                      plateNumber: vm.plateNumber,
                      plateRegion: vm.plateRegion,
                      fleetType: vm.fleetType,
                      vehicleLevel: vm.vehicleLevel,
                      associationName: vm.associationName,
                      seatCapacity: vm.seatCapacity,
                      status: vm.status,
                      assignedTerminalId: vm.assignedTerminalId,
                      arrivalTerminals: vm.arrivalTerminals,
                      tariffs: vm.tariffs,
                      createdBy: vm.createdBy,
                      updatedBy: vm.updatedBy,
                      createdAt: vm.createdAt,
                      updatedAt: vm.updatedAt,
                      vehicleLevelId: vm.vehicleLevelId,
                      fleetTypeId: vm.fleetTypeId,
                      currentRoute: vr,
                    );
                  }
                }
              } catch (e) {
                print('⚠️ Failed to synthesize route for vehicle ${vm.id}: $e');
              }

              // Find existing by id and upsert vmToSave
              dynamic foundKey;
              for (final k in vehicleBox.keys) {
                final entry = vehicleBox.get(k);
                if (entry != null && entry.id == vmToSave.id) {
                  foundKey = k;
                  break;
                }
              }

              if (foundKey != null) {
                await vehicleBox.put(foundKey, vmToSave);
              } else {
                await vehicleBox.add(vmToSave);
              }

              upserted++;
            } catch (e) {
              print('⚠️ Skipped one bad vehicle during restore at index $i: $e');
            }
          }

          print('✅ Upserted $upserted vehicles into local Hive (out of ${rawVehicles.length})');
        }
      } catch (e) {
        print('⚠️ Could not restore vehicles (may be empty or corrupted): $e');
      }

      // Only restore tariffs if current is empty and backup has data
      try {
        final tariffBox = Hive.box<TariffModel>(HiveBoxes.tariffsBox);
        final backupTariffs = (data['tariffs'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        if (tariffBox.isEmpty && backupTariffs.isNotEmpty) {
          int restoredCount = 0;
          for (final t in backupTariffs) {
            if (t != null) {
              try {
                await tariffBox.add(TariffModel.fromJson(t));
                restoredCount++;
              } catch (e) {
                print('⚠️ Skipped one bad tariff during restore: $e');
              }
            }
          }
          print('✅ Restored $restoredCount tariffs from backup (out of ${backupTariffs.length})');
        } else if (!tariffBox.isEmpty) {
          print('ℹ️ Tariffs already exist locally — skipping tariff restore from backup');
        } else {
          print('ℹ️ No tariffs found in backup file');
        }
      } catch (e) {
        print('⚠️ Could not restore tariffs (may be empty or corrupted): $e');
      }

      // Only restore commission rules if current is empty and backup has data
      try {
        final commissionBox = Hive.box<CommissionRuleModel>(HiveBoxes.commissionRulesBox);
        final backupRules = (data['commissionRules'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        if (commissionBox.isEmpty && backupRules.isNotEmpty) {
          int restoredCount = 0;
          for (final r in backupRules) {
            if (r != null) {
              try {
                await commissionBox.add(CommissionRuleModel.fromJson(r));
                restoredCount++;
              } catch (e) {
                print('⚠️ Skipped one bad commission rule during restore: $e');
              }
            }
          }
          print('✅ Restored $restoredCount commission rules from backup (out of ${backupRules.length})');
        } else if (!commissionBox.isEmpty) {
          print('ℹ️ Commission rules already exist locally — skipping commission rule restore from backup');
        } else {
          print('ℹ️ No commission rules found in backup file');
        }
      } catch (e) {
        print('⚠️ Could not restore commission rules (may be empty or corrupted): $e');
      }

      print('🎉 Restore completed successfully');
      return true;
    } catch (e) {
      print('❌ Restore failed: $e');
      return false;
    }
  }

  static String _encrypt(String text) {
    final key = Key.fromUtf8(_key.padRight(32));
    final encrypter = Encrypter(AES(key));
    return encrypter.encrypt(text, iv: _fixedIV).base64;
  }

  static String _decrypt(String encrypted) {
    final key = Key.fromUtf8(_key.padRight(32));
    final encrypter = Encrypter(AES(key));
    return encrypter.decrypt64(encrypted, iv: _fixedIV);
  }

  /// Clear the backup file (used on logout)
  static Future<bool> clearBackup() async {
    try {
      final backupDir = await _getBackupDirectory();
      final file = File('${backupDir.path}/$_backupFileName');

      if (await file.exists()) {
        await file.delete();
        print('🗑️ Backup file deleted successfully');
        return true;
      }
      print('ℹ️ No backup file to delete');
      return true;
    } catch (e) {
      print('❌ Failed to clear backup: $e');
      return false;
    }
  }
}
