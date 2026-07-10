import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oro_ticket_app/app/modules/home/controllers/home_controller.dart';
import 'package:oro_ticket_app/app/modules/ticket/model/exit_ticket_qr_model.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';
import 'package:oro_ticket_app/data/locals/models/tariff_model.dart';
import 'package:oro_ticket_app/data/locals/models/trip_model.dart';
import 'package:oro_ticket_app/data/locals/models/vehicle_model.dart';
import 'package:oro_ticket_app/data/locals/models/departure_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/models/arrival_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/models/vehicle_print_lock_model.dart';
import 'package:oro_ticket_app/data/locals/service/tariff_storage_service.dart';
import 'package:oro_ticket_app/data/repositories/enhanced_sync_repository.dart';
import 'package:oro_ticket_app/data/repositories/sync_repository.dart';
import 'package:oro_ticket_app/widgets/app_scafold.dart';
import '../controller/ticket_controller.dart';
import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:oro_ticket_app/data/locals/models/service_charge_model.dart';
import 'package:oro_ticket_app/data/locals/hive_boxes.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:oro_ticket_app/app/modules/utils/ticket_printer.dart';
import 'package:uuid/uuid.dart';

class TicketView extends StatefulWidget {
  @override
  State<TicketView> createState() => _TicketViewState();
}

class _TicketViewState extends State<TicketView> {
  static const Uuid _uuid = Uuid();
  final _ticketController = Get.put(TicketController());
  final homeController = Get.put(HomeController());
  static const Duration vehicleLockDuration = Duration(hours: 1, minutes: 30);
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _departureController = TextEditingController();
  final TextEditingController _arrivalController = TextEditingController();

  List<ArrivalTerminalModel> arrivalTerminals = [];
  ArrivalTerminalModel? selectedArrival;

  String? selectedDeparture;
  String plateInput = '';
  List<VehicleModel> suggestions = [];
  final plateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDefaultDeparture();
    _loadArrivalTerminals();
    _syncTariffsIfNeeded();
    _cleanupExpiredLocks();
  }

  @override
  void dispose() {
    _departureController.dispose();
    _arrivalController.dispose();
    plateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _lockVehicleForPrinting(String vehicleId) async {
    final lockBox = Hive.box<VehiclePrintLock>('vehiclePrintLocksBox');
    final now = DateTime.now();

    final lockUntil = now.add(vehicleLockDuration);

    final existingLock = lockBox.values.firstWhereOrNull(
      (lock) => lock.vehicleId == vehicleId,
    );

    if (existingLock != null) {
      existingLock.lockUntil = lockUntil;
      await existingLock.save();
      print('🔄 Extended lock for vehicle $vehicleId until $lockUntil');
    } else {
      final newLock = VehiclePrintLock(
        vehicleId: vehicleId,
        lockUntil: lockUntil,
      );
      await lockBox.add(newLock);
      print('🔒 Vehicle $vehicleId locked until $lockUntil');
    }
  }

  void _cleanupExpiredLocks() {
    final lockBox = Hive.box<VehiclePrintLock>('vehiclePrintLocksBox');
    final now = DateTime.now();

    final expiredLocks =
        lockBox.values.where((lock) => lock.lockUntil.isBefore(now)).toList();

    for (var lock in expiredLocks) {
      lock.delete();
    }

    if (expiredLocks.isNotEmpty) {
      print('🧹 Cleaned up ${expiredLocks.length} expired vehicle locks');
    }
  }

  void _showSnack(String title, String message,
      {Color? backgroundColor, int seconds = 4}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$title: $message"),
        backgroundColor: backgroundColor ?? Colors.blueGrey,
        duration: Duration(seconds: seconds),
      ),
    );
  }

  void _loadArrivalTerminals() {
    final box = Hive.box<ArrivalTerminalModel>('arrivalTerminalsBox');
    setState(() {
      arrivalTerminals = box.values.toList();
    });
  }

  void _loadDefaultDeparture() {
    _setLoginDepartureTerminal();
  }

  void _setLoginDepartureTerminal() {
    final terminalBox =
        Hive.box<DepartureTerminalModel>('departureTerminalsBox');
    final terminal = terminalBox.values.firstOrNull;

    if (terminal != null) {
      setState(() {
        selectedDeparture = terminal.name;
        _departureController.text = terminal.name;
        _ticketController.locationFrom.value = terminal.name;
        _ticketController.departureTerminalId.value =
            terminal.id; // ✅ set correct ID
        _ticketController.selectedDepartureTerminal.value =
            terminal; // ✅ store full model if needed
      });
    }
  }

  bool _matchesLoginDepartureTerminal({
    required String terminalId,
    required String terminalName,
  }) {
    final loginDepartureId = _ticketController.departureTerminalId.value.trim();
    final loginDepartureName = (_departureController.text.isNotEmpty
            ? _departureController.text
            : selectedDeparture ?? '')
        .trim();

    return (terminalId.isNotEmpty && loginDepartureId.isNotEmpty && terminalId == loginDepartureId) ||
        (terminalName.isNotEmpty && loginDepartureName.isNotEmpty &&
            terminalName.toLowerCase() == loginDepartureName.toLowerCase());
  }

  Future<void> _syncTariffsIfNeeded() async {
    final tariffBox = Hive.box<TariffModel>(HiveBoxes.tariffsBox);

    if (tariffBox.isEmpty) {
      print('📦 No tariffs found locally, syncing...');
      final syncRepo = SyncRepository();
      await syncRepo.syncTariffs();
    } else {
      print('📦 Found ${tariffBox.length} tariffs locally');
      TariffStorageService.debugPrintAllTariffs();
    }
  }

  void _onPlateInputChanged(String input) {
    final vehicleBox = Hive.box<VehicleModel>('vehiclesBox');
    final lockBox = Hive.box<VehiclePrintLock>('vehiclePrintLocksBox');
    final now = DateTime.now();

    _cleanupExpiredLocks();

    final normalizedInput = input.trim().toLowerCase();
    var candidates = vehicleBox.values.where((vehicle) {
      final isLocked = lockBox.values.any(
        (lock) => lock.vehicleId == vehicle.id && lock.lockUntil.isAfter(now),
      );
      if (isLocked) return false;

      if (normalizedInput.isEmpty) return false;

      return vehicle.plateNumber.toLowerCase().contains(normalizedInput);
    }).toList();

    setState(() {
      plateInput = input;
      suggestions = candidates;
      if (plateController.text != input) {
        plateController.text = input;
        plateController.selection = TextSelection.fromPosition(TextPosition(offset: input.length));
      }
    });

    if (input.isEmpty) {
      _resetTicketController();
      _ticketController.selectedVehicle.value = null;
      selectedArrival = null;
      _arrivalController.clear();
      _setLoginDepartureTerminal();
    }

    // If input is empty and there is no route selected, reset controller
    if (input.isEmpty && (selectedDeparture == null || selectedArrival == null)) {
      _resetTicketController();
      _ticketController.selectedVehicle.value = null;
      _setLoginDepartureTerminal();
    }
  }

  void _applyVehicleSelection(VehicleModel vehicle) {
    print('🟦 Plate selection started');
    print('   Selected plate: ${vehicle.plateNumber}');
    print('   Vehicle ID: ${vehicle.id}');
    print('📦 Full selected vehicle payload:');
    try {
      final prettyVehicle = const JsonEncoder.withIndent('  ').convert(vehicle.toJson());
      print(prettyVehicle);
    } catch (e) {
      print('⚠️ Failed to pretty print vehicle payload: $e');
      print(vehicle.toJson());
    }

    plateController.text = vehicle.plateNumber;
    plateInput = vehicle.plateNumber;
    suggestions.clear();

    _ticketController.selectedVehicle.value = vehicle;

    _ticketController.plateNumber.value = vehicle.plateNumber;
    _ticketController.level.value = vehicle.vehicleLevel;
    _ticketController.seatNo.value = vehicle.seatCapacity.toString();
    _ticketController.associations.value = vehicle.associationName;
    _ticketController.vehicleId.value = vehicle.id;
    _ticketController.region.value = vehicle.plateRegion;
    _ticketController.fleetType.value = vehicle.fleetType;

    final route = vehicle.currentRoute?.terminalDestination;
    if (route != null) {
      final loginDepartureName = selectedDeparture ?? _departureController.text;
      final loginDepartureId = _ticketController.departureTerminalId.value;

      final routeDepartureName = route.departureTerminalName?.trim().isNotEmpty == true
          ? route.departureTerminalName!.trim()
          : '';
      final routeArrivalName = route.arrivalTerminalName?.trim().isNotEmpty == true
          ? route.arrivalTerminalName!.trim()
          : '';

      final arrivalMatchesLogin = _matchesLoginDepartureTerminal(
        terminalId: route.arrivalTerminalId,
        terminalName: routeArrivalName,
      );

      final departureMatchesLogin = _matchesLoginDepartureTerminal(
        terminalId: route.departureTerminalId,
        terminalName: routeDepartureName,
      );

      final isReversed = arrivalMatchesLogin && !departureMatchesLogin;

      print('🧭 Route resolution for selected vehicle');
      print('   Login departure: $loginDepartureName (ID: $loginDepartureId)');
      print('   API route departure: $routeDepartureName (ID: ${route.departureTerminalId})');
      print('   API route arrival: $routeArrivalName (ID: ${route.arrivalTerminalId})');
      print('   Reversed route detected: $isReversed');

      final correctedArrivalName = isReversed
          ? (routeDepartureName.isNotEmpty ? routeDepartureName : vehicle.currentRoute?.terminalDestination?.departureTerminalName ?? '')
          : (routeArrivalName.isNotEmpty ? routeArrivalName : vehicle.currentRoute?.terminalDestination?.arrivalTerminalName ?? '');

      final correctedArrivalId = isReversed
          ? route.departureTerminalId
          : route.arrivalTerminalId;

      _setLoginDepartureTerminal();

      _ticketController.locationFrom.value = loginDepartureName;
      _ticketController.departureTerminalId.value = loginDepartureId;
      _ticketController.selectedDepartureTerminal.value =
          _ticketController.selectedDepartureTerminal.value ??
              DepartureTerminalModel(
                id: loginDepartureId,
                name: loginDepartureName,
                status: 'active',
              );

      ArrivalTerminalModel? matchedArrival;
      if (correctedArrivalId.isNotEmpty) {
        matchedArrival = arrivalTerminals.firstWhereOrNull(
          (terminal) => terminal.id == correctedArrivalId,
        );
      }
      matchedArrival ??= arrivalTerminals.firstWhereOrNull(
        (terminal) => terminal.name == correctedArrivalName,
      );

      if (matchedArrival != null) {
        selectedArrival = matchedArrival;
        _ticketController.selectedArrival.value = matchedArrival;
        _ticketController.locationTo.value = matchedArrival.name;
        _ticketController.arrivalTerminalId.value = matchedArrival.id;
        _arrivalController.text = matchedArrival.name;
      } else {
        final fallbackArrival = ArrivalTerminalModel(
          id: correctedArrivalId,
          name: correctedArrivalName,
          tariff: 0.0,
          distance: route.distance,
          roadType: route.roadType,
          roadDistances: route.roadDistances,
        );
        selectedArrival = fallbackArrival;
        _ticketController.selectedArrival.value = fallbackArrival;
        _ticketController.locationTo.value = correctedArrivalName;
        _ticketController.arrivalTerminalId.value = correctedArrivalId;
        _arrivalController.text = correctedArrivalName;
      }

      _ticketController.km.value = '${route.distance.toStringAsFixed(1)} km';

      print('✅ Ticket data populated from selected plate');
      print('   Departure: ${_ticketController.locationFrom.value} (ID: ${_ticketController.departureTerminalId.value})');
      print('   Arrival: ${_ticketController.locationTo.value} (ID: ${_ticketController.arrivalTerminalId.value})');
      print('   Distance: ${_ticketController.km.value}');
      print('   Fleet: ${_ticketController.fleetType.value}');
      print('   Level: ${_ticketController.level.value}');
      print('   Seats: ${_ticketController.seatNo.value}');
    } else {
      print('⚠️ Selected vehicle has no current route/terminal destination');
    }

    _ticketController.calculateCharges(0.0);

    print('💰 Charge calculation done for selected plate');
    print('   Tariff: ${_ticketController.tariff.value}');
    print('   Service charge: ${_ticketController.serviceCharge.value}');
    print('   Total: ${_ticketController.totalPayment.value}');

    final now = DateTime.now();
    final ethDate = now.convertToEthiopian();
    _ticketController.dateTime.value =
        "${TicketController.oromoWeekdays[now.weekday]} - "
        "${ethDate.year}/${ethDate.month.toString().padLeft(2, '0')}/${ethDate.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    print('🕒 Ticket timestamp set: ${_ticketController.dateTime.value}');
    print('🟩 Plate selection completed for ${vehicle.plateNumber}');

    setState(() {});
  }

  void _clearVehicleSelection() {
    suggestions.clear();
    plateController.clear();
    plateInput = '';
    selectedArrival = null;
    _arrivalController.clear();
    _resetTicketController();
    _ticketController.selectedVehicle.value = null;
    _ticketController.selectedArrival.value = null;
    _ticketController.selectedDepartureTerminal.value = null;
    _setLoginDepartureTerminal();
    _ticketController.locationTo.value = '';
    _ticketController.arrivalTerminalId.value = '';
    setState(() {});
  }

  Widget _buildRouteArrow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 2,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_downward_rounded,
            size: 14,
            color: AppColors.primary,
          ),
        ),
        Container(
          width: 2,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildReadonlyRouteField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return TextFormField(
      readOnly: true,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  void _resetTicketController() {
    plateController.clear();
    _ticketController.plateNumber.value = '';
    _ticketController.level.value = '';
    _ticketController.seatNo.value = '';
    _ticketController.associations.value = '';
    _ticketController.vehicleId.value = '';
    _ticketController.region.value = '';
    _ticketController.fleetType.value = '';
    _ticketController.km.value = '';
    _ticketController.tariff.value = '';
    _ticketController.serviceCharge.value = '';
    _ticketController.totalPayment.value = '';
    _ticketController.selectedVehicle.value = null;
    _ticketController.selectedArrival.value = null;
    _arrivalController.clear();
  }

  bool get _canShowTicket =>
      plateInput.isNotEmpty &&
      selectedDeparture != null &&
      selectedArrival != null;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Print Ticket",
      userName: "Employee Name",
      currentBottomNavIndex: 1,
      showBottomNavBar: true,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vehicle and Route',
                        style: AppTextStyles.buttonMediumB,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type a plate number, then select from the suggestions.',
                        style: AppTextStyles.caption.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      _buildReadonlyRouteField(
                        label: 'Departure Terminal',
                        controller: _departureController,
                        icon: Icons.trip_origin,
                      ),
                      if (_ticketController.selectedVehicle.value != null) ...[
                        const SizedBox(height: 8),
                        Center(child: _buildRouteArrow()),
                        const SizedBox(height: 8),
                        _buildReadonlyRouteField(
                          label: 'Arrival Terminal',
                          controller: _arrivalController,
                          icon: Icons.location_on,
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: plateController,
                        readOnly: _ticketController.selectedVehicle.value != null,
                        decoration: InputDecoration(
                          labelText: 'Plate Number',
                          isDense: true,
                          prefixIcon: Icon(Icons.directions_bus),
                          suffixIcon: _ticketController.selectedVehicle.value != null
                              ? IconButton(
                                  tooltip: 'Clear vehicle selection',
                                  icon: const Icon(Icons.clear),
                                  onPressed: _clearVehicleSelection,
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: _onPlateInputChanged,
                      ),
                      if (suggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.separated(
                            controller: _scrollController,
                            itemCount: suggestions.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (context, index) {
                              final vehicle = suggestions[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.directions_bus, size: 20),
                                title: Text(vehicle.plateNumber),
                                subtitle: Text('${vehicle.plateRegion} • ${vehicle.fleetType}'),
                                onTap: () => _applyVehicleSelection(vehicle),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Ticket Card
              if (_canShowTicket) Obx(() => _redesignedTicketCard()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _redesignedTicketCard() {
    final companyName = homeController.companyName.value;
    final companyPhone = homeController.companyPhoneNo.value;
    final dateTime = _ticketController.dateTime.value;
    final from = _ticketController.locationFrom.value;
    final to = _ticketController.locationTo.value;
    final plateNumber = _ticketController.plateNumber.value;
    final region = _ticketController.region.value;
    final plate = plateNumber.startsWith(region) || region.isEmpty
        ? plateNumber
        : '$region$plateNumber';
    final association = _ticketController.associations.value;
    final seatNo = _ticketController.seatNo.value;
    final level = _ticketController.level.value;
    final km = _ticketController.km.value;
    final tariff = _ticketController.tariff.value;
    final serviceCharge = _ticketController.serviceCharge.value;
    final total = _ticketController.totalPayment.value;
    final agent = homeController.user.value?.fullName ?? '';

    final receiptText = [
      'Oromia Transport Agency',
      '==============================',
      _receiptRow('Company:', companyName),
      _receiptRow('Tel:', companyPhone),
      _receiptRow('Date:', dateTime),
      '------------------------------',
      _receiptRow('From:', from),
      _receiptRow('To:', to),
      _receiptRow('Plate:', plate),
      _receiptRow('Association:', association),
      _receiptRow('Seat No:', seatNo),
      _receiptRow('Level:', level),
      _receiptRow('KM:', km),
      '------------------------------',
      _receiptRow('Tariff', tariff),
      _receiptRow('Service Charge', serviceCharge),
      _receiptRow('TOTAL:', total),
      '------------------------------',
      _receiptRow('Agent:', agent),
      _receiptRow('Free-call:', '8556'),
    ].join('\n');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  receiptText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // Validate vehicle has a route
                if (_ticketController.selectedVehicle.value?.currentRoute == null) {
                  _showSnack(
                    "Error",
                    "Selected vehicle is not assigned to any route",
                    backgroundColor: Colors.red,
                    seconds: 4,
                  );
                  return;
                }

                // Try auto-connect if Bluetooth is available but not connected
                final printerHelper = TicketPrinter();
                final connected = await printerHelper.ensureConnected();
                if (!connected) {
                  _showSnack(
                    "Bluetooth Required",
                    "No paired Bluetooth thermal printer found. Please pair a printer and try again.",
                    backgroundColor: Colors.red,
                    seconds: 5,
                  );
                  return;
                }

                // Show printing status (optional lightweight)
                _showSnack(
                  "Printing",
                  "Connected to printer, printing...",
                  backgroundColor: Colors.blue,
                  seconds: 2,
                );

                try {
                  // Prepare all data first
                  final transactionId = _buildTransactionId();
                  final tripData = _prepareTripData(transactionId);
                  final exitTicketText = _prepareExitTicketText(tripData);
                  final exitQRData = _prepareExitQRData(tripData);

                  final printer = TicketPrinter();
                  final copies = 1; // Test mode: print one ticket only

                  print('🖨️ Attempting to print $copies copy for test...');

                  final ticketTexts = <String>[
                    _prepareTicketTextForSeat(tripData, 1),
                  ];
                  final passengerQRDatas = <String>[
                    _preparePassengerQRDataForSeat(tripData, 1),
                  ];

                  final printResult = await printer.connectAndPrintVerified(
                    texts: ticketTexts,
                    passengerQRDatas: passengerQRDatas,
                    copies: copies,
                    exitText: exitTicketText,
                    exitQRData: exitQRData,
                  );

                  if (printResult.success) {
                    // Calculate service charge
                    final now = DateTime.now();
                    double parseSafe(String value) =>
                        double.tryParse(value.split(' ').first) ?? 0.0;

                    final int seatCount = int.tryParse(_ticketController.seatNo.value) ?? 1;
                    final double totalServiceCharge =
                        parseSafe(_ticketController.serviceCharge.value) * seatCount;

                    print('💾 Saving trip data:');
                    print('   transactionId: $transactionId');
                    print('   vehicleId: ${tripData.vehicleId}');
                    print('   departure: ${tripData.departureName}');
                    print('   arrival: ${tripData.arrivalName}');
                    print('   totalPaid: ${tripData.totalPaid}');
                    print('   trip payload ready for save/post:');
                    print('   ${tripData.toJson()}');

                    final serviceCharge = ServiceChargeModel(
                      departureTerminal: tripData.departureTerminalId,
                      dateTime: now,
                      serviceChargeAmount: totalServiceCharge,
                      employeeName: homeController.user.value!.fullName,
                      companyId: tripData.companyId,
                      employeeId: tripData.employeeId,
                      transactionId: transactionId,
                    );

                    print('💵 Saving service charge data:');
                    print('   transactionId: ${serviceCharge.transactionId}');
                    print('   departureTerminal: ${serviceCharge.departureTerminal}');
                    print('   amount: ${serviceCharge.serviceChargeAmount}');
                    print('   employeeId: ${serviceCharge.employeeId}');
                    print('   service charge payload ready for save/post:');
                    print('   ${serviceCharge.toJson()}');

                    final enhancedSyncRepo = EnhancedSyncRepository();
                    final syncResult = await enhancedSyncRepo.saveDataWithSync(
                      trip: tripData,
                      serviceCharge: serviceCharge,
                    );

                    await _lockVehicleForPrinting(_ticketController.selectedVehicle.value!.id);
                    _resetTicketController();

                    // User feedback based on sync result
                    if (syncResult == SyncResult.postedToServer) {
                      _showSnack(
                        "Success ✅",
                        "Ticket posted to server successfully",
                        backgroundColor: Colors.green,
                        seconds: 4,
                      );
                    } else if (syncResult == SyncResult.savedOffline) {
                      _showSnack(
                        "Saved Offline",
                        "No internet. Ticket saved locally and will sync automatically.",
                        backgroundColor: Colors.orange,
                        seconds: 5,
                      );
                    } else {
                      _showSnack(
                        "Partial Sync",
                        "Some data synced. Remaining items will sync automatically.",
                        backgroundColor: Colors.orange,
                        seconds: 5,
                      );
                    }
                  } else {
                    // Print failed
                    print('❌ Print failed: ${printResult.error}');
                    _showSnack(
                      "Print Failed ❌",
                      printResult.error ?? "Failed to print ticket.",
                      backgroundColor: Colors.red,
                      seconds: 5,
                    );
                  }
                } catch (e, stackTrace) {
                  print('❌ Unexpected error during printing:');
                  print('Error: $e');
                  print('Stack trace: $stackTrace');

                  _showSnack(
                    "Error ❌",
                    "An unexpected error occurred. Check logs for details.",
                    backgroundColor: Colors.red,
                    seconds: 5,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Print & Save", style: AppTextStyles.button),
            ),
          ),
        ],
      ),
    );
  }

  String _receiptRow(String label, String value) {
    const width = 30;
    final left = label;
    final right = value.isEmpty ? '-' : value;
    final gap = width - left.length - right.length;
    if (gap <= 1) {
      return '$left $right';
    }
    return '$left${' ' * gap}$right';
  }

// Prepare trip data without saving
  TripModel _prepareTripData(String transactionId) {
    final now = DateTime.now();

    double parseSafe(String value) =>
        double.tryParse(value.split(' ').first) ?? 0.0;

    final baseTariff = parseSafe(_ticketController.tariff.value);
    final serviceChargePerTicket =
        parseSafe(_ticketController.serviceCharge.value);
    final totalPaid = parseSafe(_ticketController.totalPayment.value);

    return TripModel(
      vehicleId: _ticketController.vehicleId.value,
      departureTerminalId: _ticketController.departureTerminalId.value,
      arrivalTerminalId: _ticketController.arrivalTerminalId.value,
      dateAndTime: now,
      km: parseSafe(_ticketController.km.value),
      tariff: baseTariff,
      serviceCharge: serviceChargePerTicket,
      totalPaid: totalPaid,
      employeeId: homeController.user.value!.id,
      companyId: homeController.companyId.value,
      departureName: _ticketController.locationFrom.value,
      arrivalName: _ticketController.locationTo.value,
      transactionId: transactionId,
    );
  }

  String _buildTransactionId() {
    return _uuid.v4();
  }

  String _prepareTicketTextForSeat(TripModel trip, int seatNumber) {
    double parseSafe(String value) =>
        double.tryParse(value.split(' ').first) ?? 0.0;

    return formatTicketText(
      companyName: homeController.companyName.value,
      companyPhoneNo: homeController.companyPhoneNo.value,
      region: _ticketController.region.value,
      plateNumber: _ticketController.plateNumber.value,
      from: trip.departureName,
      to: trip.arrivalName,
      dateTime: trip.dateAndTime,
      seatNo: seatNumber.toString(), // Use seat number 1, 2, 3, etc.
      association: _ticketController.associations.value,
      level: _ticketController.level.value,
      km: trip.km,
      tariff: trip.tariff,
      serviceCharge: parseSafe(_ticketController.serviceCharge.value),
      totalPayment: trip.totalPaid,
      agent: homeController.user.value!.fullName,
    );
  }

  String _prepareExitTicketText(TripModel trip) {
    return formatExitTicketText(
      companyName: homeController.companyName.value,
      companyPhoneNo: homeController.companyPhoneNo.value,
      region: _ticketController.region.value,
      plateNumber: _ticketController.plateNumber.value,
      from: trip.departureName,
      to: trip.arrivalName,
      dateTime: trip.dateAndTime,
      seatCapacity: _ticketController.seatNo.value,
      tariff: trip.tariff,
      association: _ticketController.associations.value,
      level: _ticketController.level.value,
      totalPayment: trip.totalPaid,
      agent: homeController.user.value!.fullName,
    );
  }

  String _preparePassengerQRDataForSeat(TripModel trip, int seatNumber) {
    final ethDate = trip.dateAndTime.convertToEthiopian();
    final period = ethDate.hour >= 12 ? 'PM' : 'AM';
    final dateStr = "${ethDate.day}-${ethDate.month}-${ethDate.year}";
    final timeStr =
        "${ethDate.hour.toString().padLeft(2, '0')}:${ethDate.minute.toString().padLeft(2, '0')} $period";

    return '''
TRIP INFORMATION
---------------------------
FROM: ${trip.departureName}
TO:   ${trip.arrivalName}
WHEN: ${"$dateStr $timeStr"}
PLATE NUMBER:  ${_ticketController.region} ${_ticketController.plateNumber.value}
SEAT NO: $seatNumber
---------------------------
FEEDBACK & SUPPORT
Call: 8556
---------------------------
''';
  }

  ExitTicketQRData _prepareExitQRData(TripModel trip) {
    final vehicle = _ticketController.selectedVehicle.value!;

    return ExitTicketQRData(
      vehicleId: vehicle.id,
      plateNumber: vehicle.plateNumber,
      originTerminalId: _ticketController.departureTerminalId.value,
      checkinDate: DateFormat('yyyy-MM-dd').format(trip.dateAndTime),
      notes: 'Route: ${trip.departureName} → ${trip.arrivalName}',
      timestamp: trip.dateAndTime,
    );
  }

}

String formatTicketText({
  required String companyName,
  required String companyPhoneNo,
  required String region,
  required String plateNumber,
  required String from,
  required String to,
  required DateTime dateTime,
  required String seatNo,
  required String association,
  required String level,
  required double km,
  required double tariff,
  required double serviceCharge,
  required double totalPayment,
  required String agent,
}) {
  const lineWidth = 30;
  String line(String left, String right) {
    final available = lineWidth - left.length;
    return left + right.padLeft(available);
  }

  final ethDate = dateTime.convertToEthiopian();
  final period = ethDate.hour >= 12 ? 'PM' : 'AM';
  final dateStr = "${ethDate.day}-${ethDate.month}-${ethDate.year}";
  final timeStr =
      "${ethDate.hour.toString().padLeft(2, '0')}:${ethDate.minute.toString().padLeft(2, '0')} $period ";

  return '''
Oromia Transport Agency
${'=' * lineWidth}
${line("Company:", companyName)}
${line("Tel:", companyPhoneNo)}
${line("Date:", "$dateStr $timeStr")}
${'-' * lineWidth}
${line("From:", from)}
${line("To:", to)}
${line("Plate:", "$region$plateNumber")}
${line("Association:", association)}
${line("Seat No:", seatNo)}
${line("Level:", level)}
${line("KM:", km.toStringAsFixed(2))}
${'-' * lineWidth}
${line("Tariff", tariff.toStringAsFixed(2))}
${line("Service Charge", serviceCharge.toStringAsFixed(2))}
${line("TOTAL:", totalPayment.toStringAsFixed(2))}
${'-' * lineWidth}
${line("Agent:", agent)}
<B>${line("Free-call:", "8556")}</B>''';
}

String formatExitTicketText({
  required String companyName,
  required String companyPhoneNo,
  required String region,
  required String plateNumber,
  required String from,
  required String to,
  required DateTime dateTime,
  required String seatCapacity, // total seat capacity of the vehicle
  required String association,
  required String level,
  required String agent,
  required double tariff,
  required double totalPayment,
}) {
  const lineWidth = 30;
  String line(String left, String right) {
    final available = lineWidth - left.length;
    return left + right.padLeft(available);
  }

  final ethDate = dateTime.convertToEthiopian();
  final period = ethDate.hour >= 12 ? 'PM' : 'AM';
  final dateStr = "${ethDate.day}-${ethDate.month}-${ethDate.year}";
  final timeStr =
      "${ethDate.hour.toString().padLeft(2, '0')}:${ethDate.minute.toString().padLeft(2, '0')} $period";

  return '''
${line("Company:", companyName)}
${line("Tel:", companyPhoneNo)}
${line("Date:", "$dateStr $timeStr")}
${'-' * lineWidth}
${line("From:", from)}
${line("To:", to)}
${line("Plate:", "$region$plateNumber")}
${line("Association:", association)}
${line("Seat Capacity:", seatCapacity)}
${line("Tariff:", tariff.toStringAsFixed(2))}
${line("TOTAL:", (tariff * int.parse(seatCapacity)).toStringAsFixed(2))}
${line("Level:", level)}
${'-' * lineWidth}
${line("Agent:", agent)}
''';
}
