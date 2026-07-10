import 'dart:convert';

import 'package:oro_ticket_app/data/locals/models/vehicle_model.dart';

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
    final directTariff = _getTotalTariffOnly(vehicle);

    if (directTariff != null && directTariff > 0) {
      final serviceCharge = _calculateServiceCharge(
        tariffAmount: directTariff,
        commissionRate: commissionRate,
      );
      final totalAmount = directTariff + serviceCharge;

      print('''
    🚌 Calculating tariff for vehicle ${vehicle.plateNumber}:
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Source: vehicle.tariffs direct amount
    Base Tariff: ${directTariff.toStringAsFixed(2)} ETB
    Commission Rate: ${(commissionRate * 100).toStringAsFixed(1)}%
    Service Charge: ${serviceCharge.toStringAsFixed(2)} ETB
    Total Amount: ${totalAmount.toStringAsFixed(2)} ETB
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ''');

      return TariffCalculationResult(
        baseTariff: directTariff,
        serviceCharge: serviceCharge,
        totalAmount: totalAmount,
        roadTypeBreakdown: {
          'total_tariff': directTariff,
        },
        commissionRate: commissionRate,
        isEstimated: false,
      );
    }

    print('''
    ❌ total_tariff is missing for vehicle ${vehicle.plateNumber}
    🧾 Vehicle tariffs: ${vehicle.tariffs}
    ''');

    return TariffCalculationResult(
      baseTariff: 0.0,
      serviceCharge: 0.0,
      totalAmount: 0.0,
      roadTypeBreakdown: {},
      commissionRate: commissionRate,
      isEstimated: true,
      error: 'total_tariff not found in selected vehicle tariffs',
    );
  }

  static double _calculateServiceCharge({
    required double tariffAmount,
    required double commissionRate,
  }) {
    return tariffAmount * commissionRate;
  }

  static Map<String, dynamic>? _parseTariffEntry(String rawEntry) {
    final raw = rawEntry.trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('{') && raw.endsWith('}')) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  static double? _getTotalTariffOnly(VehicleModel vehicle) {
    final entries = vehicle.tariffs;
    if (entries == null || entries.isEmpty) return null;

    for (final rawEntry in entries) {
      final parsed = _parseTariffEntry(rawEntry);
      if (parsed == null) continue;

      final totalTariff = parsed['total_tariff'];
      if (totalTariff == null) continue;

      final value = double.tryParse(totalTariff.toString());
      if (value != null && value > 0) {
        return value;
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>> previewTariff({
    required VehicleModel vehicle,
  }) async {
    final totalTariff = _getTotalTariffOnly(vehicle);
    if (totalTariff == null || totalTariff <= 0) {
      return {
        'vehicle': vehicle.plateNumber,
        'error': 'total_tariff not found in selected vehicle tariffs',
        'has_valid_tariffs': false,
      };
    }

    return {
      'vehicle': vehicle.plateNumber,
      'base_tariff': totalTariff,
      'source': 'total_tariff',
      'has_valid_tariffs': true,
    };
  }
}