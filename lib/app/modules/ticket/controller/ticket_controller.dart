import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/data/locals/models/user_model.dart';
import 'package:oro_ticket_app/data/locals/hive_boxes.dart';
import 'package:oro_ticket_app/data/locals/models/arrival_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/models/departure_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/models/vehicle_model.dart';
import 'package:oro_ticket_app/data/locals/models/commission_rule_model.dart';
import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:oro_ticket_app/data/locals/service/tariff_calculator_service.dart';

class TicketController extends GetxController {
  final locationFrom = ''.obs;
  final locationTo = ''.obs;
  final plateNumber = ''.obs;
  final vehicleId = ''.obs;
  final seatNo = ''.obs;
  final level = ''.obs;
  final dateTime = ''.obs;
  final km = ''.obs;
  final associationId = ''.obs;
  final regionId = ''.obs;
  final fleetType = ''.obs;
  final companyId = ''.obs;

  final tariff = ''.obs;
  final serviceCharge = ''.obs;
  final totalPayment = ''.obs;

  final commissionRate = 0.0.obs;
  final roadTypeBreakdown = <String, double>{}.obs;

  // Associations
  final associations = ''.obs;
  final region = ''.obs;

  // Models
  final selectedVehicle = Rxn<VehicleModel>();
  final selectedArrival = Rxn<ArrivalTerminalModel>();
  final selectedDepartureTerminal = Rxn<DepartureTerminalModel>();

  var arrivalTerminalId = ''.obs;
  var departureTerminalId = ''.obs;

  // Afaan Oromo weekday names
  static const Map<int, String> oromoWeekdays = {
    0: 'Dilbata', // Sunday
    1: 'Wiixata', // Monday
    2: 'Qibxata', // Tuesday
    3: 'Roobii', // Wednesday
    4: 'Kamiisa', // Thursday
    5: 'Jimaata', // Friday
    6: 'Sanbata', // Saturday
  };

  // Populates ticket info and calculates charges
  // void populateFromModels(
  //   VehicleModel vehicle,
  //   ArrivalTerminalModel arrival,
  //   DepartureTerminalModel departure,
  //   UserModel user,
  // ) {
  //   selectedVehicle.value = vehicle;
  //   selectedArrival.value = arrival;
  //   vehicleId.value = vehicle.id;
  //   plateNumber.value = vehicle.plateNumber;
  //   seatNo.value = vehicle.seatCapacity.toString();
  //   level.value = vehicle.vehicleLevel;
  //   locationFrom.value = departure.name;

  //   locationTo.value = arrival.id;
  //   departureTerminalId.value = departure.id;
  //   km.value = "${arrival.distance.toStringAsFixed(1)} km";
  //   tariff.value = "${arrival.tariff.toStringAsFixed(2)} ETB";
  //   associations.value = vehicle.associationName;
  //   region.value = vehicle.plateRegion;
  //   fleetType.value = vehicle.fleetType;
  //   companyId.value = user.companyId;

  //   final now = DateTime.now();
  //   final ethDate = now.convertToEthiopian();
  //   final weekdayOromo = oromoWeekdays[now.weekday] ?? '';
  //   final formattedDate =
  //       "${ethDate.day.toString().padLeft(2, '0')}-${ethDate.month.toString().padLeft(2, '0')}-${ethDate.year}";
  //   final formattedTime =
  //       "${ethDate.hour.toString().padLeft(2, '0')}:${ethDate.minute.toString().padLeft(2, '0')}";

  //   dateTime.value = "$weekdayOromo - $formattedDate $formattedTime";
  //   calculateCharges(arrival.tariff);
  // }

  // // Calculate commission and total payment
  // void calculateCharges(double baseTariff) async {
  //   final box = await HiveBoxes.getBox<CommissionRuleModel>(
  //       HiveBoxes.commissionRulesBox);
  //   final rule = box.values.firstOrNull;
  //   double rate = rule?.commissionRate ?? 0.0;
  //   commissionRate.value = rate;
  //   double computedService = baseTariff * rate;
  //   double total = baseTariff + computedService;
  //   serviceCharge.value = "${computedService.toStringAsFixed(2)} ETB";
  //   totalPayment.value = "${total.toStringAsFixed(2)} ETB";
  // }

  final currentSeatNumber = 1.obs; // Next seat to be sold
  final totalSeatsSold = 0.obs;
  final isVehicleFull = false.obs;

  // Method to get next available seat
  int getNextSeatNumber() {
    // You could also check against a list of sold seats if needed
    return currentSeatNumber.value;
  }

  // Method to mark a seat as sold
  void markSeatAsSold() {
    totalSeatsSold.value++;
    currentSeatNumber.value++;

    // Check if vehicle is full
    final seatCapacity = int.tryParse(this.seatNo.value) ?? 0;
    isVehicleFull.value = totalSeatsSold.value >= seatCapacity;
  }

  // Reset for new vehicle
  void resetSeatTracking() {
    currentSeatNumber.value = 1;
    totalSeatsSold.value = 0;
    isVehicleFull.value = false;
  }

  // Check remaining seats
  int getRemainingSeats() {
    final capacity = int.tryParse(seatNo.value) ?? 0;
    return capacity - totalSeatsSold.value;
  }

  void populateFromModels(
    VehicleModel vehicle,
    ArrivalTerminalModel arrival,
    DepartureTerminalModel departure,
    UserModel user,
  ) {
    selectedVehicle.value = vehicle;
    selectedArrival.value = arrival;
    selectedDepartureTerminal.value = departure;

    vehicleId.value = vehicle.id;
    plateNumber.value = vehicle.plateNumber;
    seatNo.value = vehicle.seatCapacity.toString();
    level.value = vehicle.vehicleLevel;
    locationFrom.value = departure.name;
    locationTo.value = arrival.name;
    departureTerminalId.value = departure.id;
    arrivalTerminalId.value = arrival.id;

    if (vehicle.currentRoute?.terminalDestination != null) {
      final route = vehicle.currentRoute!.terminalDestination!;
      km.value = "${route.distance.toStringAsFixed(1)} km";
    } else {
      km.value = "${arrival.distance.toStringAsFixed(1)} km";
    }

    associations.value = vehicle.associationName;
    region.value = vehicle.plateRegion;
    fleetType.value = vehicle.fleetType;
    companyId.value = user.companyId;

    final now = DateTime.now();
    final ethDate = now.convertToEthiopian();
    final weekdayOromo = TicketController.oromoWeekdays[now.weekday] ?? '';
    final formattedDate =
        "${ethDate.day.toString().padLeft(2, '0')}-${ethDate.month.toString().padLeft(2, '0')}-${ethDate.year}";
    final formattedTime =
        "${ethDate.hour.toString().padLeft(2, '0')}:${ethDate.minute.toString().padLeft(2, '0')}";

    dateTime.value = "$weekdayOromo - $formattedDate $formattedTime";

    calculateCharges(0.0);
  }

  void calculateCharges(double baseTariff) async {
    final box = await HiveBoxes.getBox<CommissionRuleModel>(
        HiveBoxes.commissionRulesBox);
    final rule = box.values.firstOrNull;
    double rate = rule?.commissionRate ?? 0.0;
    commissionRate.value = rate;

    if (selectedVehicle.value != null) {
      final result = TariffCalculatorService.calculateTariff(
        vehicle: selectedVehicle.value!,
        commissionRate: rate,
      );

      if (result.hasError) {
        print('❌ Tariff calculation error: ${result.error}');
        Get.snackbar(
          "Warning",
          result.error ?? "Could not calculate tariff",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withValues(alpha: 0.8),
          colorText: Colors.white,
        );
      }

      // Update values
      tariff.value = "${result.baseTariff.toStringAsFixed(2)} ETB";
      serviceCharge.value = "${result.serviceCharge.toStringAsFixed(2)} ETB";
      totalPayment.value = "${result.totalAmount.toStringAsFixed(2)} ETB";

      // 👇 Store the breakdown for UI display
      roadTypeBreakdown.value = result.roadTypeBreakdown;

      if (result.isEstimated) {
        Get.snackbar(
          "Notice",
          "Using estimated pricing. Some tariffs are missing.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withValues(alpha: 0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
    } else {
      // Clear breakdown when no calculation
      roadTypeBreakdown.clear();

      // Fallback calculation
      double computedService = baseTariff * rate;
      double total = baseTariff + computedService;
      serviceCharge.value = "${computedService.toStringAsFixed(2)} ETB";
      totalPayment.value = "${total.toStringAsFixed(2)} ETB";
    }
  }

  // New method to print ticket with copies = seatNo count
/*  Future<void> printTicket() async {
    // parse seat count safely (default to 1)
    final copies = int.tryParse(seatNo.value) ?? 1;

    final ticketText = '''
  OROMIA TRANSPORT AGENCY
  -------------------------------
  Company: Malkaa Technology
  Phone: 011-123-4567
  Date: ${dateTime.value}
  From: ${locationFrom.value}
  To: ${selectedArrival.value?.name ?? ''}
  Vehicle: ${plateNumber.value} (${region.value})
  Level: ${level.value}
  Seat: ${seatNo.value}
  Distance: ${km.value}
  Tariff: ${tariff.value}
  Service Charge: ${serviceCharge.value}
  Total: ${totalPayment.value}
  -------------------------------
  Free-call: 8556
  Phone:

  ''';

    final printer = TicketPrinter();
    await printer.connectAndPrint(
        text: ticketText, copies: copies, qrCodeData: '');
  }
*/
}