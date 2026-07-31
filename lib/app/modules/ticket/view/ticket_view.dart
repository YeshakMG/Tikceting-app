import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oro_ticket_app/app/modules/home/controllers/home_controller.dart';
import 'package:oro_ticket_app/app/modules/ticket/model/exit_ticket_qr_model.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/dimensions.dart';
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
import 'package:vs_scrollbar/vs_scrollbar.dart';
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
    final terminalBox =
        Hive.box<DepartureTerminalModel>('departureTerminalsBox');
    final terminal = terminalBox.values.firstOrNull;

    if (terminal != null) {
      setState(() {
        selectedDeparture = terminal.name;
        _ticketController.locationFrom.value = terminal.name;
        _ticketController.departureTerminalId.value =
            terminal.id; // ✅ set correct ID
        _ticketController.selectedDepartureTerminal.value =
            terminal; // ✅ store full model if needed
      });
    }
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

    // Basic plate filter
    var candidates = vehicleBox.values.toList();
    if (input.isNotEmpty) {
      candidates = candidates.where((v) => v.plateNumber.toLowerCase().contains(input.toLowerCase())).toList();
    }

    // If a route is selected, keep vehicles that either have a matching currentRoute IDs
    // or assignedTerminalId equals departure terminal
    if (selectedDeparture != null && selectedArrival != null) {
      final depId = _ticketController.departureTerminalId.value;
      final arrId = _ticketController.arrivalTerminalId.value;

      candidates = candidates.where((v) {
        // Skip locked
        final locked = lockBox.values.any((l) => l.vehicleId == v.id && l.lockUntil.isAfter(now));
        if (locked) return false;

        // Match by current route if present
        final rd = v.currentRoute?.terminalDestination;
        if (rd != null) {
          if ((rd.departureTerminalId == depId && rd.arrivalTerminalId == arrId) ||
              (rd.departureTerminalId == arrId && rd.arrivalTerminalId == depId)) {
            return true;
          }
        }

        // Fallback: assigned terminal
        if (v.assignedTerminalId != null && v.assignedTerminalId == depId) return true;

        // Fallback: arrivalTerminals list contains arrival
        if (v.arrivalTerminals != null && v.arrivalTerminals!.contains(arrId)) return true;

        return false;
      }).toList();
    }

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
    }

    // final vehicleBox = Hive.box<VehicleModel>('vehiclesBox');
    // final lockBox = Hive.box<VehiclePrintLock>('vehiclePrintLocksBox');

    // final now = DateTime.now();

    _cleanupExpiredLocks();

    // Start from full vehicle list, then apply plate filter if provided
    var filtered = vehicleBox.values.toList();

    if (input.isNotEmpty) {
      filtered = filtered
          .where((v) => v.plateNumber.toLowerCase().contains(input.toLowerCase()))
          .toList();
    }

    // If route is selected, filter by route/terminal match
    if (selectedDeparture != null && selectedArrival != null) {
      filtered = filtered.where((vehicle) {
        final isLocked = lockBox.values.any((lock) =>
            lock.vehicleId == vehicle.id && lock.lockUntil.isAfter(now));

        if (isLocked) return false;

        if (vehicle.currentRoute?.terminalDestination != null) {
          final route = vehicle.currentRoute!.terminalDestination!;
          final departureTerminalId = _ticketController.departureTerminalId.value;
          final arrivalTerminalId = _ticketController.arrivalTerminalId.value;

          final routeDep = route.departureTerminalId.toString();
          final routeArr = route.arrivalTerminalId.toString();

          bool matchesForward = routeDep == departureTerminalId && routeArr == arrivalTerminalId;
          bool matchesBackward = routeDep == arrivalTerminalId && routeArr == departureTerminalId;

          // Fallback to names
          if (!matchesForward && !matchesBackward) {
            final depName = route.departureTerminalName?.toString();
            final arrName = route.arrivalTerminalName?.toString();
            if (depName != null && arrName != null) {
              matchesForward = depName == _ticketController.locationFrom.value && arrName == _ticketController.locationTo.value;
              matchesBackward = depName == _ticketController.locationTo.value && arrName == _ticketController.locationFrom.value;
            }
          }

          // Fallback to vehicle.arrivalTerminals list
          if (!matchesForward && !matchesBackward && vehicle.arrivalTerminals != null) {
            matchesForward = vehicle.arrivalTerminals!.contains(_ticketController.arrivalTerminalId.value);
          }

          return matchesForward || matchesBackward;
        }

        // If no route info available, attempt to match by assigned terminal
        if (vehicle.assignedTerminalId != null && vehicle.assignedTerminalId!.isNotEmpty) {
          return vehicle.assignedTerminalId == _ticketController.departureTerminalId.value;
        }

        return false;
      }).toList();
    }

    setState(() {
      plateInput = input;
      suggestions = filtered;

      if (plateController.text != input) {
        plateController.text = input;
        plateController.selection = TextSelection.fromPosition(
          TextPosition(offset: input.length),
        );
      }
    });

    // If input is empty and there is no route selected, reset controller
    if (input.isEmpty && (selectedDeparture == null || selectedArrival == null)) {
      _resetTicketController();
      _ticketController.selectedVehicle.value = null;
    }
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
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text("Oromia Transport Agency"),
              SizedBox(height: 20),

              // Departure Terminal (read-only)
              TextFormField(
                readOnly: true,
                initialValue: selectedDeparture,
                decoration: InputDecoration(
                  labelText: 'Departure Terminal',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),

              // Destination
              IgnorePointer(
                ignoring: _ticketController.selectedVehicle.value != null,
                child: DropdownButtonFormField<ArrivalTerminalModel>(
                  value: selectedArrival,
                  isExpanded: true,
                  hint: Text('Select destination'),
                  onChanged: (val) {
                    setState(() {
                      selectedArrival = val;
                    });
                    if (val != null) {
                      _ticketController.locationTo.value = val.name;
                      _ticketController.arrivalTerminalId.value = val.id;
                      if (_ticketController.selectedVehicle.value != null) {
                        _ticketController.calculateCharges(0.0);
                      }
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Destination Terminal',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  items: arrivalTerminals
                      .map((loc) => DropdownMenuItem(
                            value: loc,
                            child: Text(loc.name),
                          ))
                      .toList(),
                ),
              ),
              SizedBox(height: 10),

              // Plate input with suggestion
              TextFormField(
                controller: plateController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Plate Number',
                  prefixIcon: Icon(Icons.directions_bus),
                  border: OutlineInputBorder(),
                ),
                onChanged: _onPlateInputChanged,
              ),
              if (suggestions.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(top: 8),
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: VsScrollbar(
                    controller: _scrollController,
                    showTrackOnHover: true,
                    isAlwaysShown: true,
                    scrollbarFadeDuration: Duration(milliseconds: 500),
                    scrollbarTimeToFade: Duration(milliseconds: 800),
                    style: VsScrollbarStyle(
                      hoverThickness: 2.0,
                      radius: Radius.circular(8),
                      thickness: 6.0,
                      color: AppColors.primary.withValues(alpha: 0.05),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      // shrinkWrap: true,
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final vehicle = suggestions[index];
                        return ListTile(
                          title: Text(vehicle.plateNumber),
                          subtitle: Text(
                              '${vehicle.plateRegion} • ${vehicle.fleetType}'),
                          // onTap: () {
                          //   plateController.text = vehicle.plateNumber;
                          //   plateInput = vehicle.plateNumber;
                          //   suggestions.clear();

                          //   _ticketController.plateNumber.value =
                          //       vehicle.plateNumber;
                          //   _ticketController.level.value = vehicle.vehicleLevel;
                          //   _ticketController.seatNo.value =
                          //       vehicle.seatCapacity.toString();
                          //   _ticketController.level.value = vehicle.vehicleLevel;
                          //   _ticketController.associations.value =
                          //       vehicle.associationName;
                          //   _ticketController.vehicleId.value = vehicle.id;

                          //   _ticketController.region.value = vehicle.plateRegion;
                          //   // _ticketController.departureTerminalId.value =
                          //   //     _ticketController.locationFrom.value;

                          //   _ticketController.fleetType.value = vehicle.fleetType;
                          //   // Set the date and time
                          //   final now = DateTime.now();
                          //   final ethDate = now.convertToEthiopian();

                          //   _ticketController.dateTime.value =
                          //       "${TicketController.oromoWeekdays[now.weekday]} - "
                          //       "${ethDate.year}/${ethDate.month.toString().padLeft(2, '0')}/${ethDate.day.toString().padLeft(2, '0')} "
                          //       "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

                          //   setState(() {}); // Refresh suggestion UI
                          // },
                          // In _TicketViewState, modify the onTap of vehicle selection:
                          onTap: () {
                            plateController.text = vehicle.plateNumber;
                            plateInput = vehicle.plateNumber;
                            suggestions.clear();

                            // Store the selected vehicle in controller
                            _ticketController.selectedVehicle.value = vehicle;

                            // Populate vehicle info
                            _ticketController.plateNumber.value =
                                vehicle.plateNumber;
                            _ticketController.level.value =
                                vehicle.vehicleLevel;
                            _ticketController.seatNo.value =
                                vehicle.seatCapacity.toString();
                            _ticketController.associations.value =
                                vehicle.associationName;
                            _ticketController.vehicleId.value = vehicle.id;
                            _ticketController.region.value =
                                vehicle.plateRegion;
                            _ticketController.fleetType.value =
                                vehicle.fleetType;

                            // 👇 NEW: Populate route information from vehicle's current route
                            if (vehicle.currentRoute?.terminalDestination !=
                                null) {
                              final route =
                                  vehicle.currentRoute!.terminalDestination!;

                              final hasSegmentedDistances =
                                  route.roadDistances != null &&
                                      route.roadDistances!.isNotEmpty;
                              final distanceForKm = hasSegmentedDistances
                                  ? route.roadDistances!.values
                                      .fold<double>(0.0, (sum, d) => sum + d)
                                  : route.distance;

                              // Update distance from vehicle route
                              _ticketController.km.value =
                                "${distanceForKm.toStringAsFixed(1)} km";

                              // Update arrival terminal info if not already selected
                              // if (route.arrivalTerminalName != null) {
                              //   _ticketController.locationTo.value =
                              //       route.arrivalTerminalName!;

                              //   // Find and set the matching arrival terminal from the list
                              //   final matchingArrival =
                              //       arrivalTerminals.firstWhereOrNull((a) =>
                              //           a.name == route.arrivalTerminalName);
                              //   if (matchingArrival != null) {
                              //     setState(() {
                              //       selectedArrival = matchingArrival;
                              //     });
                              //     _ticketController.arrivalTerminalId.value =
                              //         matchingArrival.id;
                              //   }
                              // }

                              // // Update departure terminal info
                              // if (route.departureTerminalName != null) {
                              //   _ticketController.locationFrom.value =
                              //       route.departureTerminalName!;
                              // }
                            }

                            // Calculate tariff using the new system
                            _ticketController.calculateCharges(0.0);

                            // Set date/time
                            final now = DateTime.now();
                            final ethDate = now.convertToEthiopian();
                            _ticketController.dateTime.value =
                                "${TicketController.oromoWeekdays[now.weekday]} - "
                                "${ethDate.year}/${ethDate.month.toString().padLeft(2, '0')}/${ethDate.day.toString().padLeft(2, '0')} "
                                "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ),
              SizedBox(height: 20),

              // Ticket Card
              if (_canShowTicket) Obx(() => _redesignedTicketCard()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _redesignedTicketCard() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Text("Ticket Details", style: AppTextStyles.buttonMediumB),
          SizedBox(height: 5),
          Text("Oromia Transport Agency", style: AppTextStyles.heading3),
          SizedBox(height: 5),
          Text(homeController.companyName.value,
              style: AppTextStyles.buttonMediumB
                  .copyWith(color: Colors.grey, fontWeight: FontWeight.bold)),
          SizedBox(height: 5),
          Text("Phone: 011-1234567",
              style: AppTextStyles.caption
                  .copyWith(color: Colors.grey, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(Icons.directions_bus, color: AppColors.primary),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plate Number',
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.grey, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Text(_ticketController.region.value,
                          style: AppTextStyles.body2
                              .copyWith(fontWeight: FontWeight.bold)),
                      Text(_ticketController.plateNumber.value,
                          style: AppTextStyles.body2
                              .copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(Icons.business, color: AppColors.primary),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Association',
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(_ticketController.associations.value,
                      style: AppTextStyles.body2
                          .copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          Divider(
            height: 30,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.my_location, color: AppColors.primary)),
                  SizedBox(width: 12),
                  _locationColumn(_ticketController.locationFrom.value),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child:
                          Icon(Icons.location_pin, color: AppColors.primary)),
                  SizedBox(width: 12),
                  _locationColumn(_ticketController.locationTo.value),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Text(_ticketController.dateTime.value,
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.black, fontWeight: FontWeight.bold))
                ],
              )
            ],
          ),
          Divider(height: 30),
          Row(
            children: [
              _infoTag(
                  Icons.event_seat, "${_ticketController.seatNo.value} Seat"),
              SizedBox(width: 50),
              _infoTag(Icons.grade, _ticketController.level.value),
            ],
          ),
          SizedBox(
            height: 10,
          ),
          Row(
            children: [
              _infoTag(Icons.straighten, _ticketController.km.value),
              SizedBox(width: 35),
              _infoTag(Icons.monetization_on, _ticketController.tariff.value),
            ],
          ),
          // Obx(() {
          //   final breakdown = _ticketController.roadTypeBreakdown;
          //   if (breakdown.isEmpty) return SizedBox.shrink();

          //   return _buildRoadTypeBreakdown(breakdown);
          // }),
          Divider(
            height: 30,
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Service Charge',
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(
                    _ticketController.serviceCharge.value,
                    style: AppTextStyles.body2
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(width: 50),
              Column(
                children: [
                  Text("Total Payment",
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(
                    _ticketController.totalPayment.value,
                    style: AppTextStyles.body2
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 15),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Agent Name: ${homeController.user.value?.fullName}",
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.grey, fontWeight: FontWeight.bold)),
                  SizedBox(
                    height: 10,
                  ),
                  Text("Free Call Service: 8556",
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.grey, fontWeight: FontWeight.bold)),
                  SizedBox(
                    height: 10,
                  ),
                  // Text("Terminal phone: 011-1234567",
                  //     style: AppTextStyles.caption.copyWith(
                  //         color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          SizedBox(
            height: AppDimensions.horizontalSpacingMedium,
          ),
          // ElevatedButton(
          //   onPressed: () async {
          //     final tripBox = Hive.box<TripModel>(HiveBoxes.tripBox);
          //     final serviceChargeBox =
          //         Hive.box<ServiceChargeModel>(HiveBoxes.serviceChargeBox);

          //     final now = DateTime.now();
          //     final today = DateTime(now.year, now.month, now.day);

          //     double parseSafe(String value) =>
          //         double.tryParse(value.split(' ').first) ?? 0.0;

          //     // Seat count from controller (string to int)
          //     final int seatCount =
          //         int.tryParse(_ticketController.seatNo.value) ?? 1;

          //     // Multiply service charge by number of selected seats
          //     final double totalServiceCharge =
          //         parseSafe(_ticketController.serviceCharge.value) * seatCount;

          //     final trip = TripModel(
          //       vehicleId: _ticketController.vehicleId.value,
          //       departureTerminalId:
          //           _ticketController.departureTerminalId.value,
          //       arrivalTerminalId: _ticketController.arrivalTerminalId.value,
          //       dateAndTime: now,
          //       km: parseSafe(_ticketController.km.value),
          //       tariff: parseSafe(_ticketController.tariff.value),
          //       serviceCharge: parseSafe(_ticketController.serviceCharge.value),
          //       totalPaid: parseSafe(_ticketController.totalPayment.value),
          //       employeeId: homeController.user.value!.id,
          //       companyId: homeController.companyId.value,
          //       departureName: selectedDeparture.toString(),
          //       arrivalName: _ticketController.locationTo.value,
          //     );

          //     // Debug TripModel print
          //     print("🚌 TripModel Debug Info:");
          //     print("Vehicle ID: ${trip.vehicleId}");
          //     print(
          //         "From: ${trip.departureTerminalId}, To: ${trip.arrivalTerminalId}");
          //     print(
          //         "KM: ${trip.km}, Tariff: ${trip.tariff}, Charge: ${trip.serviceCharge}");
          //     print(
          //         "Total Paid: ${trip.totalPaid}, Employee: ${trip.employeeId}, Company: ${trip.companyId}");
          //     print("Date: ${trip.dateAndTime}");

          //     final tripKey = await tripBox.add(trip);

          //     // Check if a charge already exists for today, terminal, and employee
          //     final existingEntry =
          //         serviceChargeBox.values.firstWhereOrNull((entry) {
          //       final entryDate = DateTime(entry.dateTime.year,
          //           entry.dateTime.month, entry.dateTime.day);

          //       return entry.departureTerminal == trip.departureTerminalId &&
          //           entry.employeeId == trip.employeeId &&
          //           entryDate == today;
          //     });

          //     if (existingEntry != null) {
          //       // Add new service charge to existing
          //       existingEntry.serviceChargeAmount += totalServiceCharge;
          //       await existingEntry.save();

          //       // Debug updated ServiceChargeModel
          //       print("💵 Updated ServiceChargeModel:");
          //       print(
          //           "Terminal: ${existingEntry.departureTerminal}, Employee: ${existingEntry.employeeId}");
          //       print(
          //           "New Charge: ${existingEntry.serviceChargeAmount}, Date: ${existingEntry.dateTime}");
          //     } else {
          //       // Create new entry
          //       final newCharge = ServiceChargeModel(
          //         departureTerminal: trip.departureTerminalId,
          //         dateTime: now,
          //         serviceChargeAmount: totalServiceCharge,
          //         employeeName: homeController.user.value!.fullName,
          //         companyId: trip.companyId,
          //         employeeId: trip.employeeId,
          //       );

          //       await serviceChargeBox.add(newCharge);

          //       // Debug new ServiceChargeModel
          //       print("💰 New ServiceChargeModel:");
          //       print(
          //           "Terminal: ${newCharge.departureTerminal}, Employee: ${newCharge.employeeId}");
          //       print(
          //           "Charge: ${newCharge.serviceChargeAmount}, Date: ${newCharge.dateTime}");
          //     }
          //     final ticketText = formatTicketText(
          //         companyName: homeController.companyName.value,
          //         companyPhoneNo: homeController.companyPhoneNo.value,
          //         region: _ticketController.region.value,
          //         plateNumber: _ticketController.plateNumber.value,
          //         from: trip.departureName,
          //         to: trip.arrivalName,
          //         dateTime: trip.dateAndTime,
          //         seatNo: _ticketController.seatNo.value,
          //         association: _ticketController.associations.value,
          //         level: _ticketController.level.value,
          //         km: trip.km,
          //         tariff: trip.tariff,
          //         serviceCharge:
          //             parseSafe(_ticketController.serviceCharge.value),
          //         totalPayment: trip.totalPaid,
          //         agent: homeController.user.value!.fullName);
          //     final qrcodeData =
          //         '${trip.departureName}\n${trip.arrivalName}\n${trip.dateAndTime}\n${_ticketController.region}${_ticketController.plateNumber.value}';

          //     final printer = TicketPrinter();

          //     final exitTicket = formatExitTicketText(
          //         companyName: homeController.companyName.value,
          //         companyPhoneNo: homeController.companyPhoneNo.value,
          //         region: _ticketController.region.value,
          //         plateNumber: _ticketController.plateNumber.value,
          //         from: trip.departureName,
          //         to: trip.arrivalName,
          //         dateTime: trip.dateAndTime,
          //         seatCapacity: _ticketController.seatNo.value,
          //         association: _ticketController.associations.value,
          //         level: _ticketController.level.value,
          //         agent: homeController.user.value!.fullName);
          //     final copies = 1;
          //     // int.tryParse(_ticketController.seatNo.value) ?? 1;

          //     await printer.connectAndPrint(
          //         text: ticketText,
          //         qrCodeData: qrcodeData,
          //         copies: copies,
          //         exitText: exitTicket);

          //     // Success Feedback Snackbar
          //     Get.snackbar(
          //       "Saved",
          //       "Ticket & Service Charge updated and printed successfully",
          //       snackPosition: SnackPosition.BOTTOM,
          //       backgroundColor: Colors.green.withValues(alpha: 0.8),
          //       colorText: Colors.white,
          //     );
          //     final savedTrip = tripBox.get(tripKey);
          //     if (savedTrip != null) {}
          //   },
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: AppColors.primary,
          //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //     shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(12)),
          //   ),
          //   child: const Text(
          //     "Print & Save",
          //     style: AppTextStyles.button,
          //   ),
          // )
          // In TicketView, update the print button onPressed:

          /*ElevatedButton(
            onPressed: () async {
              // Validate vehicle has a route
              if (_ticketController.selectedVehicle.value?.currentRoute ==
                  null) {
                Get.snackbar(
                  "Error",
                  "Selected vehicle is not assigned to any route",
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.withValues(alpha: 0.8),
                  colorText: Colors.white,
                );
                return;
              }

              final tripBox = Hive.box<TripModel>(HiveBoxes.tripBox);
              final serviceChargeBox =
                  Hive.box<ServiceChargeModel>(HiveBoxes.serviceChargeBox);

              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);

              double parseSafe(String value) =>
                  double.tryParse(value.split(' ').first) ?? 0.0;

              final int seatCount =
                  int.tryParse(_ticketController.seatNo.value) ?? 1;
              final double totalServiceCharge =
                  parseSafe(_ticketController.serviceCharge.value) * seatCount;

              final baseTariff = parseSafe(_ticketController.tariff.value);
              final serviceChargePerTicket =
                  parseSafe(_ticketController.serviceCharge.value);
              final totalPaid = parseSafe(_ticketController.totalPayment.value);

              final vehicle = _ticketController.selectedVehicle.value!;
              final route = vehicle.currentRoute!.terminalDestination!;

              final trip = TripModel(
                vehicleId: _ticketController.vehicleId.value,
                departureTerminalId:
                    _ticketController.departureTerminalId.value,
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
              );

              // Save trip
              final tripKey = await tripBox.add(trip);

              // Save service charge
              final existingEntry =
                  serviceChargeBox.values.firstWhereOrNull((entry) {
                final entryDate = DateTime(entry.dateTime.year,
                    entry.dateTime.month, entry.dateTime.day);
                return entry.departureTerminal == trip.departureTerminalId &&
                    entry.employeeId == trip.employeeId &&
                    entryDate == today;
              });

              if (existingEntry != null) {
                existingEntry.serviceChargeAmount += totalServiceCharge;
                await existingEntry.save();
              } else {
                final newCharge = ServiceChargeModel(
                  departureTerminal: trip.departureTerminalId,
                  dateTime: now,
                  serviceChargeAmount: totalServiceCharge,
                  employeeName: homeController.user.value!.fullName,
                  companyId: trip.companyId,
                  employeeId: trip.employeeId,
                );
                await serviceChargeBox.add(newCharge);
              }

              final ticketText = formatTicketText(
                companyName: homeController.companyName.value,
                companyPhoneNo: homeController.companyPhoneNo.value,
                region: _ticketController.region.value,
                plateNumber: _ticketController.plateNumber.value,
                from: trip.departureName,
                to: trip.arrivalName,
                dateTime: trip.dateAndTime,
                seatNo: _ticketController.seatNo.value,
                association: _ticketController.associations.value,
                level: _ticketController.level.value,
                km: trip.km,
                tariff: trip.tariff,
                serviceCharge: serviceChargePerTicket,
                totalPayment: trip.totalPaid,
                agent: homeController.user.value!.fullName,
              );
              final ethDate = trip.dateAndTime.convertToEthiopian();
              final period = ethDate.hour >= 12 ? 'PM' : 'AM';
              final dateStr = "${ethDate.day}-${ethDate.month}-${ethDate.year}";
              final timeStr =
                  "${ethDate.hour.toString().padLeft(2, '0')}:${ethDate.minute.toString().padLeft(2, '0')} $period";

              final passengerQRData = '''
TRIP INFORMATION
---------------------------
FROM: ${trip.departureName}
TO:   ${trip.arrivalName}
WHEN: ${"$dateStr $timeStr"}
PLATE NUMBER:  ${_ticketController.region} ${_ticketController.plateNumber.value}

---------------------------
FEEDBACK & SUPPORT
Call: 8556
---------------------------
''';
              final exitTicket = formatExitTicketText(
                companyName: homeController.companyName.value,
                companyPhoneNo: homeController.companyPhoneNo.value,
                region: _ticketController.region.value,
                plateNumber: _ticketController.plateNumber.value,
                from: trip.departureName,
                to: trip.arrivalName,
                dateTime: trip.dateAndTime,
                seatCapacity: _ticketController.seatNo.value,
                // tariff: parseSafe(_ticketController.totalPayment.value),
                tariff: trip.tariff,
                association: _ticketController.associations.value,
                level: _ticketController.level.value,
                agent: homeController.user.value!.fullName,
              );

              final exitQRData = ExitTicketQRData(
                vehicleId: vehicle.id,
                plateNumber: vehicle.plateNumber,
                originTerminalId: _ticketController.departureTerminalId.value,
                checkinDate: DateFormat('yyyy-MM-dd').format(now),
                notes: 'Route: ${trip.departureName} → ${trip.arrivalName}',
                timestamp: now,
              );
              print('🖨️ Exit Ticket QR Data:');
              print('   Vehicle ID: ${exitQRData.vehicleId}');
              print('   Plate Number: ${exitQRData.plateNumber}');
              print('   Origin Terminal: ${exitQRData.originTerminalId}');
              print('   Check-in Date: ${exitQRData.checkinDate}');
              print('   QR String: ${exitQRData.toQRString()}');

              final printer = TicketPrinter();
              final copies = int.tryParse(_ticketController.seatNo.value) ?? 1;
              await printer.connectAndPrint(
                text: ticketText,
                qrCodeData: passengerQRData,
                copies: copies,
                exitText: exitTicket,
                exitQRData: exitQRData,
              );

              Get.snackbar(
                "Success",
                "Ticket printed successfully",
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green.withValues(alpha: 0.8),
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Print & Save", style: AppTextStyles.button),
          )*/
          // ElevatedButton(
          //   onPressed: () async {
          //     // Validate vehicle has a route
          //     if (_ticketController.selectedVehicle.value?.currentRoute ==
          //         null) {
          //       Get.snackbar(
          //         "Error",
          //         "Selected vehicle is not assigned to any route",
          //         snackPosition: SnackPosition.BOTTOM,
          //         backgroundColor: Colors.red.withValues(alpha: 0.8),
          //         colorText: Colors.white,
          //       );
          //       return;
          //     }

          //     // Show status without blocking
          //     Get.snackbar(
          //       "Printing",
          //       "Connecting to printer...",
          //       snackPosition: SnackPosition.BOTTOM,
          //       backgroundColor: Colors.blue.withValues(alpha: 0.8),
          //       colorText: Colors.white,
          //       duration: Duration(seconds: 2),
          //     );

          //     try {
          //       // Prepare all data first (but don't save yet)
          //       final tripData = _prepareTripData();
          //       final ticketText = _prepareTicketText(tripData);
          //       final exitTicketText = _prepareExitTicketText(tripData);
          //       final passengerQRData = _preparePassengerQRData(tripData);
          //       final exitQRData = _prepareExitQRData(tripData);

          //       final printer = TicketPrinter();
          //       final copies =
          //           int.tryParse(_ticketController.seatNo.value) ?? 1;

          //       print('🖨️ Attempting to print $copies copies...');

          //       final printResult = await printer.connectAndPrintVerified(
          //         text: ticketText,
          //         qrCodeData: passengerQRData,
          //         copies: copies,
          //         exitText: exitTicketText,
          //         exitQRData: exitQRData,
          //       );

          //       if (printResult.success) {
          //         // Only save data after successful print
          //         await _saveTripData(tripData);
          //         await _lockVehicleForPrinting(
          //             _ticketController.selectedVehicle.value!.id);
          //         _resetTicketController();
          //         Get.snackbar(
          //           "Success ✅",
          //           "Ticket printed and saved successfully",
          //           snackPosition: SnackPosition.BOTTOM,
          //           backgroundColor: Colors.green.withValues(alpha: 0.8),
          //           colorText: Colors.white,
          //           duration: Duration(seconds: 3),
          //         );
          //       } else {
          //         // Print failed - don't save anything, show error immediately
          //         print('❌ Print failed: ${printResult.error}');
          //         print('🖨️ Prepared Ticket Data:');
          //         print(
          //             ticketText); // Print first - errors will show immediately
          //         Get.snackbar(
          //           "Print Failed ❌",
          //           printResult.error ??
          //               "Failed to print ticket. Data not saved.",
          //           snackPosition: SnackPosition.BOTTOM,
          //           backgroundColor: Colors.red.withValues(alpha: 0.9),
          //           colorText: Colors.white,
          //           duration: Duration(seconds: 5),
          //           mainButton: TextButton(
          //             onPressed: () {
          //               // Allow user to see full error
          //               Get.defaultDialog(
          //                 title: "Print Error Details",
          //                 content: Text(
          //                   printResult.error ?? "Unknown error",
          //                   style: AppTextStyles.caption
          //                       .copyWith(color: AppColors.body, fontSize: 10),
          //                 ),
          //                 titleStyle: AppTextStyles.caption
          //                     .copyWith(color: AppColors.body, fontSize: 14),
          //                 confirm: TextButton(
          //                   onPressed: () => Get.back(),
          //                   child: Text("OK"),
          //                 ),
          //               );
          //             },
          //             child: Text("Details",
          //                 style: TextStyle(color: Colors.white)),
          //           ),
          //         );
          //       }
          //     } catch (e, stackTrace) {
          //       print('❌ Unexpected error during printing:');
          //       print('Error: $e');
          //       print('Stack trace: $stackTrace');

          //       Get.snackbar(
          //         "Error ❌",
          //         "An unexpected error occurred. Check logs for details.",
          //         snackPosition: SnackPosition.BOTTOM,
          //         backgroundColor: Colors.red.withValues(alpha: 0.9),
          //         colorText: Colors.white,
          //         duration: Duration(seconds: 5),
          //         mainButton: TextButton(
          //           onPressed: () {
          //             Get.defaultDialog(
          //               title: "Error Details",
          //               content: SingleChildScrollView(
          //                 child: Column(
          //                   crossAxisAlignment: CrossAxisAlignment.start,
          //                   mainAxisSize: MainAxisSize.min,
          //                   children: [
          //                     Text(
          //                       "Error: ${e.toString()}",
          //                       style: TextStyle(fontSize: 14),
          //                     ),
          //                     SizedBox(height: 10),
          //                     Text(
          //                       "Check debug console for full stack trace",
          //                       style:
          //                           TextStyle(fontSize: 12, color: Colors.grey),
          //                     ),
          //                   ],
          //                 ),
          //               ),
          //               confirm: TextButton(
          //                 onPressed: () => Get.back(),
          //                 child: Text("OK"),
          //               ),
          //             );
          //           },
          //           child:
          //               Text("Details", style: TextStyle(color: Colors.white)),
          //         ),
          //       );
          //     }
          //   },
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: AppColors.primary,
          //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //     shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(12)),
          //   ),
          //   child: const Text("Print & Save", style: AppTextStyles.button),
          // )
          // In your TicketView, modify the print button's onPressed:

          ElevatedButton(
            onPressed: () async {
              // Validate vehicle has a route
              if (_ticketController.selectedVehicle.value?.currentRoute ==
                  null) {
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
                final parsedCopies =
                    int.tryParse(_ticketController.seatNo.value) ?? 1;
                final copies = parsedCopies > 0 ? parsedCopies : 1;
                // final copies = 1; // Test mode: print one ticket only

                print('🖨️ Attempting to print $copies copies...');

                final ticketTexts =
                    List<String>.generate(copies, (index) =>
                        _prepareTicketTextForSeat(tripData, index + 1));
                final passengerQRDatas =
                    List<String>.generate(copies, (index) =>
                        _preparePassengerQRDataForSeat(tripData, index + 1));

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

                  final int seatCount =
                      int.tryParse(_ticketController.seatNo.value) ?? 1;
                  final double totalServiceCharge =
                      parseSafe(_ticketController.serviceCharge.value) *
                          seatCount;

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

                  final enhancedSyncRepo = Get.find<EnhancedSyncRepository>();
                  final syncResult = await enhancedSyncRepo.saveDataWithSync(
                    trip: tripData,
                    serviceCharge: serviceCharge,
                  );

                  await _lockVehicleForPrinting(
                      _ticketController.selectedVehicle.value!.id);
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
        ],
      ),
    );
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

  Widget _locationColumn(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: AppTextStyles.caption2
                .copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
        SizedBox(
          height: 5,
        )
      ],
    );
  }

  Widget _infoTag(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          SizedBox(width: 6),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
        ],
      ),
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
${line("Free-call:", "8556")}''';
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
