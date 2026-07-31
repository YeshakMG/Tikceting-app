import 'package:oro_ticket_app/data/locals/models/tariff_model.dart';
import 'package:oro_ticket_app/data/locals/models/vehicle_model.dart';
import 'package:oro_ticket_app/data/locals/service/tariff_storage_service.dart';

class TariffCalculationResult {
  final double baseTariff;
  final double serviceCharge;
  final double totalAmount;
  final Map<String, double> roadTypeBreakdown;
  final double commissionRate;
  final bool isEstimated;
  final String? error;

  TariffCalculationResult({
    required this.baseTariff,
    required this.serviceCharge,
    required this.totalAmount,
    required this.roadTypeBreakdown,
    required this.commissionRate,
    this.isEstimated = false,
    this.error,
  });

  bool get hasError => error != null;
}

class TariffCalculatorService {
  static TariffCalculationResult calculateTariff({
    required VehicleModel vehicle,
    required double commissionRate,
  }) {
    if (vehicle.currentRoute == null) {
      return TariffCalculationResult(
        baseTariff: 0.0,
        serviceCharge: 0.0,
        totalAmount: 0.0,
        roadTypeBreakdown: {},
        commissionRate: commissionRate,
        isEstimated: true,
        error: 'Vehicle is not assigned to any route',
      );
    }

    final route = vehicle.currentRoute!;
    final terminalDest = route.terminalDestination;
    
    if (terminalDest == null) {
      return TariffCalculationResult(
        baseTariff: 0.0,
        serviceCharge: 0.0,
        totalAmount: 0.0,
        roadTypeBreakdown: {},
        commissionRate: commissionRate,
        isEstimated: true,
        error: 'No terminal destination information available',
      );
    }

    final vehicleLevelId = vehicle.vehicleLevelId;
    if (vehicleLevelId == null || vehicleLevelId.isEmpty) {
      return TariffCalculationResult(
        baseTariff: 0.0,
        serviceCharge: 0.0,
        totalAmount: 0.0,
        roadTypeBreakdown: {},
        commissionRate: commissionRate,
        isEstimated: true,
        error: 'Vehicle level ID not found',
      );
    }

    double totalBaseTariff = 0.0;
    Map<String, double> breakdown = {};
    bool usedEstimation = false;
    final missingTariffRoadTypes = <String>[];

    final roadSegments = terminalDest.getRoadSegments();

    print('''
    🚌 Calculating tariff for vehicle ${vehicle.plateNumber}:
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    From: ${terminalDest.departureTerminalName}
    To: ${terminalDest.arrivalTerminalName}
    Vehicle Level: ${vehicle.vehicleLevel} (ID: $vehicleLevelId)
    Fleet Type: ${vehicle.fleetType}
    ''');

    for (var segment in roadSegments) {
      final segmentPrice = _calculateSegmentPrice(
        vehicleLevelId: vehicleLevelId,
        roadType: segment.roadType,
        distance: segment.distance,
        terminalDestinationId: terminalDest.id,
        fleetTypeId: vehicle.fleetTypeId,
      );

      if (segmentPrice == null) {
        missingTariffRoadTypes.add(segment.roadType);
        print(
            '❌ Missing tariff for road segment ${segment.roadType}. Stopping strict calculation.');
        continue;
      }
      
      totalBaseTariff += segmentPrice;
      breakdown[segment.roadType] = (breakdown[segment.roadType] ?? 0.0) + segmentPrice;
      
      print('📍 ${segment.roadType}: ${segment.distance.toStringAsFixed(2)}km × rate = ${segmentPrice.toStringAsFixed(2)} ETB');
    }

    if (missingTariffRoadTypes.isNotEmpty) {
      usedEstimation = true;
      final uniqueRoadTypes = missingTariffRoadTypes.toSet().join(', ');
      return TariffCalculationResult(
        baseTariff: 0.0,
        serviceCharge: 0.0,
        totalAmount: 0.0,
        roadTypeBreakdown: {},
        commissionRate: commissionRate,
        isEstimated: usedEstimation,
        error:
            'Missing tariff for road type(s): $uniqueRoadTypes. Please configure tariffs before issuing this ticket.',
      );
    }

    if (totalBaseTariff == 0.0) {
      usedEstimation = true;
      print('⚠️ Warning: No valid tariffs found, using 0.00');
    }

    double serviceCharge = totalBaseTariff * commissionRate;
    double totalAmount = totalBaseTariff + serviceCharge;

    print('''
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    💰 CALCULATION SUMMARY:
    Base Tariff: ${totalBaseTariff.toStringAsFixed(2)} ETB
    Commission Rate: ${(commissionRate * 100).toStringAsFixed(1)}%
    Service Charge: ${serviceCharge.toStringAsFixed(2)} ETB
    Total Amount: ${totalAmount.toStringAsFixed(2)} ETB
    
    ${breakdown.length > 1 ? 'Mixed Road Types Detected:' : 'Road Type:'}
    ${breakdown.entries.map((e) => '  • ${e.key}: ${e.value.toStringAsFixed(2)} ETB').join('\n')}
    
    Status: ${usedEstimation ? '⚠️ ESTIMATED (Missing Tariffs)' : '✅ VERIFIED'}
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ''');

    return TariffCalculationResult(
      baseTariff: totalBaseTariff,
      serviceCharge: serviceCharge,
      totalAmount: totalAmount,
      roadTypeBreakdown: breakdown,
      commissionRate: commissionRate,
      isEstimated: usedEstimation,
    );
  }

  static double? _calculateSegmentPrice({
    required String vehicleLevelId,
    required String roadType,
    required double distance,
    String? terminalDestinationId,
    String? fleetTypeId,
  }) {
    TariffModel? tariff = TariffStorageService.getTariffByVehicleLevelAndRoadType(
      vehicleLevelId,
      roadType,
      terminalDestinationId: terminalDestinationId,
      fleetTypeId: fleetTypeId,
    );

    if (tariff == null || !tariff.isValid()) {
      print('❌ No valid tariff for Level:$vehicleLevelId, Road:$roadType');
      return null;
    }

    double segmentPrice = distance * tariff.pricePerKm;
    
    print('   📊 Rate: ${tariff.pricePerKm.toStringAsFixed(2)} ETB/km');
    
    return segmentPrice;
  }

  static Future<Map<String, dynamic>> previewTariff({
    required VehicleModel vehicle,
  }) async {
    if (vehicle.currentRoute?.terminalDestination == null) {
      return {'error': 'No route assigned'};
    }

    final terminalDest = vehicle.currentRoute!.terminalDestination!;
    final vehicleLevelId = vehicle.vehicleLevelId;
    
    if (vehicleLevelId == null) {
      return {'error': 'No vehicle level ID'};
    }

    Map<String, dynamic> preview = {
      'vehicle': vehicle.plateNumber,
      'level': vehicle.vehicleLevel,
      'from': terminalDest.departureTerminalName,
      'to': terminalDest.arrivalTerminalName,
      'segments': [],
    };

    double totalDistance = 0;
    double estimatedTotal = 0;

    for (var segment in terminalDest.getRoadSegments()) {
      final tariff = TariffStorageService.getTariffByVehicleLevelAndRoadType(
        vehicleLevelId,
        segment.roadType,
        terminalDestinationId: terminalDest.id,
        fleetTypeId: vehicle.fleetTypeId,
      );

      totalDistance += segment.distance;
      if (tariff == null || !tariff.isValid()) {
        return {
          'error':
              'Missing tariff for road type ${segment.roadType}. Please configure tariffs before issuing this ticket.'
        };
      }

      double rate = tariff.pricePerKm;
      double cost = segment.distance * rate;

      preview['segments'].add({
        'road_type': segment.roadType,
        'distance': segment.distance,
        'rate': rate,
        'cost': cost,
      });

      estimatedTotal += cost;
    }

    preview['total_distance'] = totalDistance;
    preview['estimated_base_tariff'] = estimatedTotal;
    preview['has_valid_tariffs'] = true;

    return preview;
  }
}