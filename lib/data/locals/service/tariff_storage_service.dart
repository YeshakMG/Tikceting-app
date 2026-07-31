import 'package:hive/hive.dart';
import 'package:oro_ticket_app/data/locals/hive_boxes.dart';
import 'package:oro_ticket_app/data/locals/models/tariff_model.dart';

class TariffStorageService {
  static Future<void> saveTariffs(List<TariffModel> tariffs) async {
    final box = await HiveBoxes.getBox<TariffModel>(HiveBoxes.tariffsBox);
    await box.clear();

    int validCount = 0;
    for (final tariff in tariffs) {
      if (tariff.isValid()) {
        await box.put(tariff.id, tariff);
        validCount++;
      } else {
        print('⚠️ Skipping invalid tariff: $tariff');
      }
    }
    print('✅ Saved $validCount valid tariffs out of ${tariffs.length} total');
  }

  static List<TariffModel> getValidTariffs() {
    final box = Hive.box<TariffModel>(HiveBoxes.tariffsBox);
    return box.values.where((t) => t.isValid()).toList();
  }

  // Updated query method with better fleet type matching
  static TariffModel? getTariffByVehicleLevelAndRoadType(
    String vehicleLevelId,
    String roadType, {
    String? terminalDestinationId,
    String? fleetTypeId,
  }) {
    final box = Hive.box<TariffModel>(HiveBoxes.tariffsBox);
    final allTariffs = box.values.toList();

    print('🔍 Searching tariff for:');
    print('   Vehicle Level: $vehicleLevelId');
    print('   Road Type: $roadType');
    print('   Terminal Dest: $terminalDestinationId');
    print('   Fleet Type: $fleetTypeId');
    print('   Total tariffs in box: ${allTariffs.length}');

    // Filter valid tariffs first
    final validTariffs =
        allTariffs.where((t) => t.deletedAt == null && t.isValid()).toList();

    // PRIORITY 1: Exact match - terminal destination + fleet type
    if (terminalDestinationId != null && fleetTypeId != null) {
      final matches = validTariffs.where(
        (t) =>
            t.vehicleLevelId == vehicleLevelId &&
            t.roadType == roadType &&
            t.terminalDestinationId == terminalDestinationId &&
            t.fleetTypeId == fleetTypeId,
      );
      if (matches.isNotEmpty) {
        final exactMatch = matches.first;
        print(
            '✅ PRIORITY 1: Found exact match tariff: ${exactMatch.id} with price ${exactMatch.pricePerKm}');
        return exactMatch;
      }
      print('ℹ️ No exact match found (terminal + fleet)');
    }

    // PRIORITY 2: Match by fleet type only (ignore terminal destination)
    if (fleetTypeId != null) {
      final fleetMatches = validTariffs.where(
        (t) =>
            t.vehicleLevelId == vehicleLevelId &&
            t.roadType == roadType &&
            t.fleetTypeId == fleetTypeId &&
            t.terminalDestinationId == null,
      );
      if (fleetMatches.isNotEmpty) {
        final fleetMatch = fleetMatches.first;
        print(
            '✅ PRIORITY 2: Found fleet-specific tariff: ${fleetMatch.id} with price ${fleetMatch.pricePerKm}');
        return fleetMatch;
      }

      final anyFleetMatches = validTariffs.where(
        (t) =>
            t.vehicleLevelId == vehicleLevelId &&
            t.roadType == roadType &&
            t.fleetTypeId == fleetTypeId,
      );
      if (anyFleetMatches.isNotEmpty) {
        final anyFleetMatch = anyFleetMatches.first;
        print(
            '⚠️ PRIORITY 2b: Found fleet tariff (with terminal): ${anyFleetMatch.id} with price ${anyFleetMatch.pricePerKm}');
        return anyFleetMatch;
      }

      print('ℹ️ No fleet-specific tariff found for fleet: $fleetTypeId');
    }

    // PRIORITY 3: Match by terminal destination only (ignore fleet type)
    if (terminalDestinationId != null) {
      final terminalMatches = validTariffs.where(
        (t) =>
            t.vehicleLevelId == vehicleLevelId &&
            t.roadType == roadType &&
            t.terminalDestinationId == terminalDestinationId &&
            t.fleetTypeId == null,
      );
      if (terminalMatches.isNotEmpty) {
        final terminalMatch = terminalMatches.first;
        print(
            '✅ PRIORITY 3: Found terminal-specific tariff: ${terminalMatch.id} with price ${terminalMatch.pricePerKm}');
        return terminalMatch;
      }
      print('ℹ️ No terminal-specific tariff found');
    }

    // PRIORITY 4: General tariff (no terminal, no fleet type)
    final generalMatches = validTariffs.where(
      (t) =>
          t.vehicleLevelId == vehicleLevelId &&
          t.roadType == roadType &&
          t.terminalDestinationId == null &&
          t.fleetTypeId == null,
    );
    if (generalMatches.isNotEmpty) {
      final generalMatch = generalMatches.first;
      print(
          '✅ PRIORITY 4: Found general tariff: ${generalMatch.id} with price ${generalMatch.pricePerKm}');
      return generalMatch;
    }

    // PRIORITY 5: Any same-road tariff for this vehicle level
    final anyMatches = validTariffs.where(
      (t) => t.vehicleLevelId == vehicleLevelId && t.roadType == roadType,
    );
    if (anyMatches.isNotEmpty) {
      final anyMatch = anyMatches.first;
      print(
          '⚠️ PRIORITY 5: Using lowest-priority same-road tariff: ${anyMatch.id} with price ${anyMatch.pricePerKm}');
      return anyMatch;
    }

    print(
        '❌ No tariff found for vehicle level: $vehicleLevelId, road type: $roadType');

    // Debug: Show what tariffs ARE available for this vehicle level
    final levelTariffs =
        validTariffs.where((t) => t.vehicleLevelId == vehicleLevelId).toList();

    if (levelTariffs.isNotEmpty) {
      print('📋 Available tariffs for this vehicle level:');
      for (var t in levelTariffs) {
        print('   - ID: ${t.id}');
        print('     Road: ${t.roadType}');
        print('     Price: ${t.pricePerKm}');
        print('     Fleet: ${t.fleetTypeId ?? "null"}');
        print('     Terminal: ${t.terminalDestinationId ?? "null"}');
      }
    }

    return null;
  }

  // Debug method to find tariffs by fleet type
  static void debugFindTariffsByFleet(String fleetTypeId) {
    final box = Hive.box<TariffModel>(HiveBoxes.tariffsBox);
    final tariffs = box.values.toList();

    final fleetTariffs = tariffs
        .where((t) => t.fleetTypeId == fleetTypeId && t.deletedAt == null)
        .toList();

    print(
        '🔍 Tariffs for fleet type: $fleetTypeId (${fleetTariffs.length} found)');
    for (var t in fleetTariffs) {
      print('''
  ID: ${t.id}
  Level: ${t.vehicleLevelId} (${t.vehicleLevelName})
  Road: ${t.roadType}
  Price: ${t.pricePerKm}
  Terminal: ${t.terminalDestinationId ?? "null"}
  Valid: ${t.isValid()}
  --------------------------------
''');
    }
  }

  static void debugPrintAllTariffs() {
    final box = Hive.box<TariffModel>(HiveBoxes.tariffsBox);
    final tariffs = box.values.toList();

    print('📊 ALL TARIFFS IN STORAGE (${tariffs.length}):');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Group by fleet type for better visibility
    final Map<String?, List<TariffModel>> byFleet = {};
    for (var t in tariffs) {
      byFleet.putIfAbsent(t.fleetTypeId, () => []).add(t);
    }

    byFleet.forEach((fleetId, fleetTariffs) {
      print('\n🚌 Fleet Type: ${fleetId ?? "GENERAL (No Fleet)"}');
      print('────────────────────────────────────────');
      for (var t in fleetTariffs) {
        print('''
  ID: ${t.id}
  Level: ${t.vehicleLevelId.substring(0, 8)}... (${t.vehicleLevelName})
  Road: ${t.roadType}
  Price: ${t.pricePerKm} ETB/km
  Terminal: ${t.terminalDestinationId?.substring(0, 8) ?? "null"}...
  Valid: ${t.isValid()}
  Deleted: ${t.deletedAt != null}
''');
      }
    });
  }

  static Map<String, List<TariffModel>> getTariffsGroupedByVehicleLevel() {
    final tariffs = getValidTariffs();
    final Map<String, List<TariffModel>> grouped = {};

    for (var tariff in tariffs) {
      grouped.putIfAbsent(tariff.vehicleLevelId, () => []).add(tariff);
    }

    return grouped;
  }

  static Map<String?, List<TariffModel>> getTariffsGroupedByFleetType() {
    final tariffs = getValidTariffs();
    final Map<String?, List<TariffModel>> grouped = {};

    for (var tariff in tariffs) {
      grouped.putIfAbsent(tariff.fleetTypeId, () => []).add(tariff);
    }

    return grouped;
  }

  static void clearTariffs() {
    final box = Hive.box<TariffModel>(HiveBoxes.tariffsBox);
    box.clear();
  }
}
