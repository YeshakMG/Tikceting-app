import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:oro_ticket_app/app/modules/sign_in/services/auth_service.dart';
import 'package:oro_ticket_app/core/utils/security_utils.dart';
import 'package:oro_ticket_app/data/locals/models/arrival_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/models/commission_rule_model.dart';
import 'package:oro_ticket_app/data/locals/models/departure_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/models/tariff_model.dart';
import 'package:oro_ticket_app/data/locals/models/trip_model.dart';
import 'package:oro_ticket_app/data/locals/service/arrival_storage_service.dart';
import 'package:oro_ticket_app/data/locals/service/commission_rule_storage_service.dart';
import 'package:oro_ticket_app/data/locals/service/departure_terminal_storage_service.dart';
import 'package:oro_ticket_app/data/locals/service/tariff_storage_service.dart';
import 'package:oro_ticket_app/data/locals/service/backup_service.dart';

import 'package:oro_ticket_app/data/locals/models/service_charge_model.dart';

import '../locals/models/vehicle_model.dart';
import '../locals/hive_boxes.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SyncRepository {
  final String baseUrl = dotenv.env['API_BASE_URL'] ?? '';

  final storage = FlutterSecureStorage();
  final Connectivity _connectivity = Connectivity();
  final _vehicleChanges = StreamController<void>.broadcast();
  Stream<void> get vehicleChanges => _vehicleChanges.stream;
  bool _isVehicleSyncInProgress = false;
  DateTime? _lastVehicleSyncAt;
  DateTime? _lastVehicleBackupAt;
  static const Duration _vehicleSyncCooldown = Duration(seconds: 20);
  static const Duration _vehicleBackupCooldown = Duration(minutes: 10);
  static const bool _verboseVehicleLogs = false;

  // Use secure HTTP client for all network requests
  late final http.Client _secureClient;
  bool _secureClientInitialized = false;

  // Initialize secure client
  Future<void> _initSecureClient() async {
    _secureClient = await SecurityUtils.createSecureHttpClient();
  }

  // Helper method to check network connectivity
  Future<bool> get _isOnline async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<bool> get isOnline async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('⚠️ Connectivity check error: $e');
      return false;
    }
  }

  // ========== VEHICLES ========== //
  Future<List<VehicleModel>> getVehicles() async {
    try {
      // Always return local storage immediately
      final localVehicles = getLocalVehicles();
      if (localVehicles.isNotEmpty) {
        print('📦 Returning vehicles from local storage');
        for (var vehicle in localVehicles) {
          print('number of vehicle stored in local: ${localVehicles.length}');
          print('${vehicle.toJson()}');
        }

        final hasMissingTariffs = localVehicles.any(_isTariffDataMissing);
        if (hasMissingTariffs && await _isOnline) {
          print('♻️ Local vehicle tariff details are incomplete. Refreshing from API...');
          await syncAllCompanyUserVehicles();
          return getLocalVehicles();
        }

        return localVehicles;
      }

      // Only attempt API if online
      if (await _isOnline) {
        print('🌐 Attempting to fetch vehicles from API');
        await syncAllCompanyUserVehicles();
        return getLocalVehicles();
      }

      return localVehicles;
    } catch (e) {
      print('⚠️ Error in getVehicles(), falling back to local: $e');
      return getLocalVehicles(); // Always fall back to local
    }
  }

  bool _isTariffDataMissing(VehicleModel vehicle) {
    final tariffs = vehicle.tariffs;
    if (tariffs == null || tariffs.isEmpty) {
      return true;
    }

    for (final entry in tariffs) {
      final raw = entry.trim();
      if (!raw.startsWith('{') || !raw.endsWith('}')) {
        continue;
      }

      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) {
          final hasRate = parsed['price_per_km'] != null || parsed['tariff'] != null;
          final hasRoadType = parsed['road_type'] != null;
          if (hasRate && hasRoadType) {
            return false;
          }
        }
      } catch (_) {
        // ignore malformed entries and continue checking others
      }
    }

    return true;
  }

  Future<void> syncAllCompanyUserVehicles({bool forceSync = false}) async {
    if (_isVehicleSyncInProgress) {
      print('⏳ Vehicle sync already in progress; skipping duplicate request');
      return;
    }

    if (!forceSync && _lastVehicleSyncAt != null) {
      final elapsed = DateTime.now().difference(_lastVehicleSyncAt!);
      if (elapsed < _vehicleSyncCooldown) {
        print('⏭️ Vehicle sync skipped (cooldown ${elapsed.inSeconds}s)');
        return;
      }
    }

    _isVehicleSyncInProgress = true;

    // Initialize secure client if not already done
    if (!_secureClientInitialized) {
      await _initSecureClient();
      _secureClientInitialized = true;
    }

    if (!await _isOnline && !forceSync) {
      print('🚫 Offline - Skipping vehicle sync');
      return;
    }

    try {
      final authService = Get.find<AuthService>();
      final token = await authService.getToken();
      if (token == null) {
        print('❌ No token available for sync');
        return;
      }
      final box = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);

      int currentPage = 1;
      bool hasMorePages = true;
      int totalSynced = 0;
      final Set<String> apiVehicleIds = {};

      while (hasMorePages) {
        print('🔄 Fetching vehicles page $currentPage...');
        final requestUrl =
            '$baseUrl/tms-api/vehicles/test?page=$currentPage&limit=50';
        if (_verboseVehicleLogs) {
          print('🌐 Vehicle API Request URL: $requestUrl');
        }

        final response = await _secureClient.get(
          Uri.parse(requestUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 30));

        print('📥 Vehicle API Status: ${response.statusCode}');
        if (_verboseVehicleLogs) {
          print('📋 Vehicle API Headers: ${response.headers}');
          _logResponsePreview(response.body);
        }

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);

          // ✅ CORRECTED: vehicles are in data.vehicles
          final vehicles = json['data']['vehicles'] as List<dynamic>;

          // ✅ CORRECTED: pagination is at root level, not inside data
          final pagination = json['pagination'];

          if (_verboseVehicleLogs) {
            print('📊 Pagination info: $pagination');
          }

          final validVehicles = vehicles
              .where((e) => e['deleted_at'] == null)
              .map((e) => VehicleModel.fromJson(e))
              .toList();

          if (_verboseVehicleLogs) {
            for (var i = 0; i < validVehicles.length; i++) {
              _logVehicleDetails(validVehicles[i], index: i + 1, page: currentPage);
            }
          }

          // Save vehicles
          for (final vehicle in validVehicles) {
            await box.put(vehicle.id, vehicle);
            apiVehicleIds.add(vehicle.id);
          }

          totalSynced += validVehicles.length;
          print(
              '📦 Synced ${validVehicles.length} vehicles from page $currentPage (Total so far: $totalSynced)');

          // ✅ CORRECTED: Use pagination from root level with correct field names
          if (pagination != null) {
            // Your API uses: page, totalPages, pageSize, total
            final currentPageNum = pagination['page'] as int?;
            final totalPages = pagination['totalPages'] as int?;

            if (currentPageNum != null && totalPages != null) {
              print('📄 Page $currentPageNum of $totalPages');
              hasMorePages = currentPageNum < totalPages;

              if (hasMorePages) {
                currentPage++;
              } else {
                print('✅ Reached last page ($totalPages)');
              }
            } else {
              // Fallback: check if we received a full page
              final pageSize = pagination['pageSize'] as int? ?? 10;
              hasMorePages = vehicles.length >= pageSize;
              if (hasMorePages) {
                currentPage++;
                print(
                    '⚠️ Using fallback pagination - received ${vehicles.length} vehicles, continuing...');
              } else {
                print('✅ No more pages (received ${vehicles.length} vehicles)');
              }
            }
          } else {
            // No pagination info - fallback to checking page size
            const defaultPageSize = 10;
            hasMorePages = vehicles.length >= defaultPageSize;

            if (hasMorePages) {
              print(
                  '⚠️ No pagination info - received ${vehicles.length} vehicles, trying next page...');
              currentPage++;
            } else {
              print(
                  '⚠️ No pagination info - received ${vehicles.length} vehicles, stopping');
            }
          }
        } else {
          print('❌ API returned ${response.statusCode}, stopping sync');
          print('Response body: ${response.body}');
          break;
        }
      }

      print('🎯 Sync completed. Total vehicles synced: $totalSynced');

      if (totalSynced > 0) {
        final localIds = box.keys.cast<String>().toSet();
        final idsToRemove = localIds.difference(apiVehicleIds);

        if (idsToRemove.isNotEmpty) {
          await box.deleteAll(idsToRemove);
          print(
              '🧹 Removed ${idsToRemove.length} deleted vehicles from local storage');
        }

        _vehicleChanges.add(null);
        print(
            '✅ Successfully synced $totalSynced vehicles across ${currentPage} pages');

        final now = DateTime.now();
        final shouldBackup = _lastVehicleBackupAt == null ||
            now.difference(_lastVehicleBackupAt!) >= _vehicleBackupCooldown;
        if (shouldBackup) {
          await BackupService.backupData();
          _lastVehicleBackupAt = now;
        } else {
          final remaining = _vehicleBackupCooldown -
              now.difference(_lastVehicleBackupAt!);
          print('⏭️ Skipped vehicle backup (cooldown ${remaining.inMinutes}m left)');
        }
      }

      _lastVehicleSyncAt = DateTime.now();
    } catch (e, stackTrace) {
      print('❌ Sync error: $e');
      print('Stack trace: $stackTrace');
    } finally {
      _isVehicleSyncInProgress = false;
    }
  }

  List<VehicleModel> getLocalVehicles() {
    try {
      final box = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);
      return box.values.toList();
    } catch (e) {
      print('❌ Error getting local vehicles: $e');
      return [];
    }
  }

  Future<void> syncVehicles(List<Map<String, dynamic>> jsonVehicles) async {
    // Delete the old box data
    await Hive.deleteBoxFromDisk(HiveBoxes.vehiclesBox);

    // Reopen the box
    final box = await Hive.openBox<VehicleModel>(HiveBoxes.vehiclesBox);

    // Filter out deleted vehicles and convert to model
    final vehicles = jsonVehicles
        .where((e) => e['deleted_at'] == null)
        .map((e) => VehicleModel.fromJson(e))
        .toList();

    // Sync only non-deleted vehicles
    await box.addAll(vehicles);
  }
  /*Future<void> syncCompanyUserVehicles() async {
    final authService = Get.find<AuthService>();
    final token = await authService.getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/vehicles/company-user/terminals/my-vehicles'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      final vehicles = json['data']['vehicles'] as List<dynamic>;

      final box = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);
      await box.clear();
      await box.addAll(
        vehicles.map((v) => VehicleModel.fromJson(v)).toList(),
      );
    } else {
      throw Exception('Failed to sync vehicles: ${response.body}');
    }
  }
*/

  // List<VehicleModel> getLocalVehicles() {
  //   final box = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);
  //   return box.values.toList();
  // }

  List<ArrivalTerminalModel> getLocalArrivalTerminals() {
    return ArrivalTerminalStorageService.getTerminals();
  }

  void _logVehicleDetails(
    VehicleModel vehicle, {
    required int index,
    required int page,
  }) {
    final route = vehicle.currentRoute;
    final terminalDestination = route?.terminalDestination;

    print('🚗 Vehicle #$index (page $page)');
    print('   id: ${vehicle.id}');
    print('   plate_number: ${vehicle.plateNumber}');
    print('   plate_region: ${vehicle.plateRegion}');
    print('   fleetType: ${vehicle.fleetType.isEmpty ? 'empty' : vehicle.fleetType}');
    print('   fleetTypeId: ${vehicle.fleetTypeId ?? 'null'}');
    print('   vehicleLevel: ${vehicle.vehicleLevel.isEmpty ? 'empty' : vehicle.vehicleLevel}');
    print('   vehicleLevelId: ${vehicle.vehicleLevelId ?? 'null'}');
    print('   association: ${vehicle.associationName.isEmpty ? 'empty' : vehicle.associationName}');
    print('   seat_capacity: ${vehicle.seatCapacity}');
    print('   status: ${vehicle.status}');
    print('   assigned_terminal_id: ${vehicle.assignedTerminalId ?? 'null'}');
    print('   created_at: ${vehicle.createdAt ?? 'null'}');
    print('   updated_at: ${vehicle.updatedAt ?? 'null'}');
    print('   arrival_terminals: ${vehicle.arrivalTerminals ?? []}');
    print('   tariffs: ${vehicle.tariffs ?? []}');

    if (route == null) {
      print('   vehicleTerminalDestinations: []');
      return;
    }

    print('   vehicleTerminalDestinations: [');
    print('     id: ${route.id}');
    print('     vehicle_id: ${route.vehicleId}');
    print('     terminal_destination_id: ${route.terminalDestinationId}');
    print('     assigned_at: ${route.assignedAt?.toIso8601String() ?? 'null'}');
    print('     unassigned_at: ${route.unassignedAt?.toIso8601String() ?? 'null'}');
    print('     is_on_temporary: ${route.isOnTemporary}');

    if (terminalDestination == null) {
      print('     terminalDestination: null');
      print('   ]');
      return;
    }

    print('     terminalDestination: {');
    print('       id: ${terminalDestination.id}');
    print('       departure_terminal_id: ${terminalDestination.departureTerminalId}');
    print('       arrival_terminal_id: ${terminalDestination.arrivalTerminalId}');
    print('       distance: ${terminalDestination.distance}');
    print('       road_type: ${terminalDestination.roadType}');
    print('       departureTerminal: {name: ${terminalDestination.departureTerminalName ?? 'null'}}');
    print('       arrivalTerminal: {name: ${terminalDestination.arrivalTerminalName ?? 'null'}}');
    print('     }');
    print('   ]');
  }

  void _logResponsePreview(String body, {int maxChars = 1200}) {
    if (body.isEmpty) {
      print('📄 Vehicle API Body: <empty>');
      return;
    }

    if (body.length <= maxChars) {
      print('📄 Vehicle API Body: $body');
      return;
    }

    print('📄 Vehicle API Body (truncated to $maxChars chars):');
    print(body.substring(0, maxChars));
    print('... <truncated ${body.length - maxChars} chars>');
  }

// For Departure
  Future<void> syncDepartureTerminal(Map<String, dynamic> terminalJson) async {
    final terminal = DepartureTerminalModel.fromJson(terminalJson);
    await DepartureTerminalStorageService.saveTerminal(terminal);
  }

  DepartureTerminalModel? getLocalDepartureTerminal() {
    return DepartureTerminalStorageService.getTerminal();
  }

// For Arrivals
  Future<void> syncArrivalTerminals(
      List<Map<String, dynamic>> jsonTerminals) async {
    final seenNames = <String>{};
    final uniqueTerminals = jsonTerminals
        .where((e) {
          final name = e['name']?.toString().trim().toLowerCase();
          if (name == null || seenNames.contains(name)) {
            return false;
          } else {
            seenNames.add(name);
            return true;
          }
        })
        .map((e) => ArrivalTerminalModel.fromJson(e))
        .toList();

    await ArrivalTerminalStorageService.saveTerminals(uniqueTerminals);
  }

  Future<void> syncCompanyUserArrivalTerminals() async {
    if (!_secureClientInitialized) {
      await _initSecureClient();
      _secureClientInitialized = true;
    }
    final authService = Get.find<AuthService>();
    final token = await authService.getToken();

    if (token == null) {
      print('❌ No token available for sync');
      return;
    }

    try {
      final response = await _secureClient.get(
        Uri.parse('$baseUrl/terminals/company-user/arrival-terminals'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final data = json['data'];

        if (data == null) {
          print('⚠️ No data field in response');
          return;
        }

        final arrivalTerminalsData =
            data['arrival_terminals'] as List<dynamic>?;
        final departureTerminalData = data['departure_terminal'];
        final companyInfo = data['company_info'];

        if (arrivalTerminalsData == null || arrivalTerminalsData.isEmpty) {
          print('📭 No arrival terminals found');
          return;
        }

        // Save departure terminal ID from this endpoint too
        if (departureTerminalData != null) {
          final depId = departureTerminalData['id']?.toString();
          print('📍 Departure terminal ID from API: $depId');
        }

        // Log company info
        if (companyInfo != null) {
          print(
              '🏢 Company: ${companyInfo['name']} (ID: ${companyInfo['id']})');
        }

        print('📦 Received ${arrivalTerminalsData.length} arrival terminals');

        // Get current departure terminal for filtering
        final currentDepartureTerminal =
            DepartureTerminalStorageService.getTerminal();
        final String? currentDepartureId = currentDepartureTerminal?.id;

        print(
            '📍 Current departure terminal: ${currentDepartureTerminal?.name} (ID: $currentDepartureId)');

        // Map to store unique arrival terminals
        final Map<String, ArrivalTerminalModel> uniqueArrivals = {};

        for (final terminal in arrivalTerminalsData) {
          final terminalId = terminal['terminal_id']?.toString() ?? '';
          final terminalName = terminal['terminal_name']?.toString() ?? '';

          // Skip if no valid ID or name
          if (terminalId.isEmpty || terminalName.isEmpty) {
            print('⚠️ Skipping terminal with missing id/name');
            continue;
          }

          // Skip if same as departure terminal
          if (currentDepartureId != null && terminalId == currentDepartureId) {
            print('⛔ Skipping: $terminalName - Same as departure terminal');
            continue;
          }

          // Parse distance
          double parsedDistance = 0.0;
          dynamic distanceValue = terminal['distance'] ?? 0.0;
          if (distanceValue is String) {
            parsedDistance = double.tryParse(distanceValue) ?? 0.0;
          } else if (distanceValue is num) {
            parsedDistance = distanceValue.toDouble();
          }

          // Parse tariff
          double parsedTariff = 0.0;
          dynamic tariffValue = terminal['tariff'] ?? 0.0;
          if (tariffValue is String) {
            parsedTariff = double.tryParse(tariffValue) ?? 0.0;
          } else if (tariffValue is num) {
            parsedTariff = tariffValue.toDouble();
          }

          // Determine road type
          String roadType;
          final roadDistances = terminal['road_distances'];

          if (roadDistances != null &&
              roadDistances is Map &&
              roadDistances.isNotEmpty) {
            final roadTypes = roadDistances.keys.toList();
            if (roadTypes.length > 1) {
              roadType = 'Hybrid';
              print('🛤️ Hybrid road detected for $terminalName: $roadTypes');
            } else {
              roadType = _formatRoadType(roadTypes.first);
            }
          } else {
            // Use single road_type from response
            final apiRoadType = terminal['road_type']?.toString() ?? '';
            roadType = _formatRoadType(apiRoadType);
          }

          // Parse road distances if hybrid
          Map<String, double>? parsedRoadDistances;
          if (roadDistances != null && roadDistances is Map) {
            parsedRoadDistances = {};
            roadDistances.forEach((key, value) {
              parsedRoadDistances![key.toString()] = (value is num)
                  ? value.toDouble()
                  : double.tryParse(value.toString()) ?? 0.0;
            });
          }

          // Add arrival terminal (only if not already added)
          if (!uniqueArrivals.containsKey(terminalId)) {
            uniqueArrivals[terminalId] = ArrivalTerminalModel.fromJson({
              'id': terminalId,
              'name': terminalName,
              'distance': parsedDistance,
              'tariff': parsedTariff,
              'road_type': roadType,
              'road_distances': parsedRoadDistances,
            });

            final hybridInfo =
                parsedRoadDistances != null && parsedRoadDistances.isNotEmpty
                    ? ' [Hybrid: $parsedRoadDistances]'
                    : '';
            print(
                '   ✅ ${terminalName} - ${parsedDistance}km - $roadType$hybridInfo');
          }
        }

        final arrivalTerminalsList = uniqueArrivals.values.toList();

        print('\n📊 SYNC SUMMARY:');
        print('   Total from API: ${arrivalTerminalsData.length}');
        print('   After filtering: ${arrivalTerminalsList.length}');

        // Print final list
        print('\n📋 ALL ARRIVAL TERMINALS:');
        for (var t in arrivalTerminalsList) {
          final hybridInfo =
              t.roadDistances != null && t.roadDistances!.isNotEmpty
                  ? ' [Hybrid: ${t.roadDistances}]'
                  : '';
          print('   ➡️ ${t.name} (${t.distance}km - ${t.roadType}$hybridInfo)');
        }

        // Save to Hive
        if (arrivalTerminalsList.isNotEmpty) {
          await syncArrivalTerminals(
            arrivalTerminalsList.map((e) => e.toJson()).toList(),
          );
          print(
              '\n✅ Saved ${arrivalTerminalsList.length} arrival terminals to Hive');
        } else {
          print('\n⚠️ No arrival terminals to save');
        }
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized - Token may be expired');
      } else {
        print('❌ API returned ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error syncing arrival terminals: $e');
    }
  }

// 👇 Helper method to format road type
  String _formatRoadType(String roadType) {
    if (roadType.isEmpty) return 'Unknown';

    switch (roadType.toLowerCase()) {
      case 'asphalt':
        return 'Asphalt';
      case 'mud_road':
      case 'mud':
        return 'Mud Road';
      case 'gravel':
        return 'Gravel';
      case 'hybrid':
        return 'Hybrid';
      default:
        // Capitalize first letter
        return roadType[0].toUpperCase() + roadType.substring(1);
    }
  }

// For Commission
  Future<void> syncCommissionRules() async {
    final authService = Get.find<AuthService>();
    final token = await authService.getToken();

    final response = await _secureClient.get(
      Uri.parse('$baseUrl/commission-rules'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final data = json['data'] as List<dynamic>;

      // ✅ Filter out deleted rules (adjust key name as per your API)
      final activeRules = data
          .where((ruleJson) =>
              ruleJson['deleted'] == null || ruleJson['deleted'] == false)
          .map((ruleJson) => CommissionRuleModel.fromJson(ruleJson))
          .toList();

      await CommissionRuleStorageService.saveCommissionRules(activeRules);

      print('Commission rules fetched: ${activeRules.length}');
      for (var rule in activeRules) {
        print(
            'Rule ${rule.id}: companyId=${rule.companyId}, rate=${rule.commissionRate}');
      }

      final stored = CommissionRuleStorageService.getCommissionRules();
      print('Commission rules stored locally: ${stored.length}');
    } else {
      print('Failed to fetch commission rules: ${response.body}');
      throw Exception('Failed to sync commission rules');
    }
  }

  Future<void> syncTripsToServer() async {
    // Initialize secure client if not already done
    if (!_secureClientInitialized) {
      await _initSecureClient();
      _secureClientInitialized = true;
    }

    try {
      final authService = Get.find<AuthService>();
      final token = await authService.getToken();
      final tripBox = Hive.box<TripModel>(HiveBoxes.tripBox);

      // Get all trips with their keys for individual deletion
      final tripEntries = tripBox.toMap().entries.toList();

      if (tripEntries.isEmpty) {
        print('No trips to sync');
        return;
      }

      // Track keys to delete after all syncs complete
      final keysToDelete = <int>[];

      // Send each trip individually
      for (final entry in tripEntries) {
        final key = entry.key as int;
        final trip = entry.value;

        try {
          final payload = _sanitizePayloadForServer('trip', trip.toJson());
      print('📦 Sending trip payload: ${jsonEncode(payload)}');

      final response = await _secureClient.post(
            Uri.parse('$baseUrl/trips'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            trip.isSynced = true;
            keysToDelete.add(key);
            print('Trip synced successfully: ${trip.vehicleId}');
            print('Sent payload: ${jsonEncode(trip.toJson())}');
          } else {
            print('Failed to sync trip: ${response.body}');
            print('Sent payload: ${jsonEncode(trip.toJson())}');
          }
        } catch (e) {
          print('Error syncing individual trip: $e');
          continue;
        }
      }

      // Delete only successfully synced trips
      for (final key in keysToDelete) {
        await tripBox.delete(key);
      }
      print('Deleted ${keysToDelete.length} synced trips from Hive');
    } catch (e) {
      print('Error in sync process: $e');
      throw Exception('Error syncing trips: $e');
    }
  }

  Future<void> syncServiceChargeToServer() async {
     if (!_secureClientInitialized) {
      await _initSecureClient();
      _secureClientInitialized = true;
    }
    final authService = Get.find<AuthService>();
    final token = await authService.getToken();
    final box = Hive.box<ServiceChargeModel>(HiveBoxes.serviceChargeBox);

    if (box.isEmpty) {
      print('No service charges to sync');
      return;
    }

    final entries = box.toMap();

    for (final entry in entries.entries) {
      final key = entry.key;
      final serviceCharge = entry.value;

      try {
        final payload = _sanitizePayloadForServer('service_charge', serviceCharge.toJson());
      print('📦 Sending service-charge payload: ${jsonEncode(payload)}');

      final response = await _secureClient.post(
          Uri.parse("$baseUrl/service-charges"), // 👈 replace with real URL
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        );

          if (response.statusCode == 200 || response.statusCode == 201) {
           print('✅ Synced: ${serviceCharge.departureTerminal}');
           await box.delete(key);
         } else {
           print('❌ Failed (${response.statusCode}): ${response.body}');
         }
       } catch (e) {
         print('❗ Sync error: $e');
         if (Get.context != null) {
           Get.snackbar("Error", "Sync error occurred. Please try again later.");
         }
       }
    }
  }

  Map<String, dynamic> _sanitizePayloadForServer(
    String type,
    Map<String, dynamic> data,
  ) {
    final payload = Map<String, dynamic>.from(data);
    if (type != 'trip' && type != 'service_charge') {
      payload.remove('transaction_id');
      payload.remove('transactionId');
    }
    return payload;
  }

  Future<void> syncTariffs() async {
    if (!_secureClientInitialized) {
      await _initSecureClient();
      _secureClientInitialized = true;
    }

    if (!await _isOnline) {
      print('🚫 Offline - Skipping tariff sync');
      return;
    }

    try {
      final authService = Get.find<AuthService>();
      final token = await authService.getToken();
      if (token == null) {
        print('❌ No token available for tariff sync');
        return;
      }

      List<TariffModel> allTariffs = [];
      int currentPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        final response = await _secureClient.get(
          Uri.parse('$baseUrl/tariffs?page=$currentPage'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);

          if (json['data'] == null) {
            print('⚠️ No data field in tariff response');
            break;
          }

          final tariffsData = json['data']['tariffs'] as List<dynamic>?;
          if (tariffsData == null || tariffsData.isEmpty) {
            print('📭 No tariffs on page $currentPage');
            break;
          }

          print(
              '📦 Received ${tariffsData.length} tariffs from page $currentPage');

          final validTariffs = tariffsData
              .where((e) => e['deleted_at'] == null)
              .map((e) => TariffModel.fromJson(e))
              .where((t) => t.isValid())
              .toList();

          allTariffs.addAll(validTariffs);
          print(
              '✅ Added ${validTariffs.length} valid tariffs from page $currentPage');

          final pagination = json['data']['pagination'];
          if (pagination != null) {
            final currentPageNum = pagination['current_page'];
            final lastPageNum = pagination['last_page'];

            if (currentPageNum != null && lastPageNum != null) {
              hasMorePages = currentPageNum < lastPageNum;
              currentPage++;
            } else {
              hasMorePages = false;
            }
          } else {
            hasMorePages = false;
          }

          print('📄 Page $currentPage of ${pagination?['last_page'] ?? '?'}');
        } else {
          print('⚠️ Tariff API returned ${response.statusCode}');
          break;
        }
      }

      if (allTariffs.isNotEmpty) {
        await TariffStorageService.saveTariffs(allTariffs);
        print('✅ Total tariffs synced and saved: ${allTariffs.length}');

        TariffStorageService.debugPrintAllTariffs();
      } else {
        print('⚠️ No valid tariffs found to sync');
      }
    } catch (e, stackTrace) {
      print('⚠️ Tariff sync error: $e');
      print('Stack trace: $stackTrace');
    }
  }
}
