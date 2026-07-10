import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:oro_ticket_app/app/modules/home/controllers/home_controller.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';
import 'package:oro_ticket_app/widgets/app_scafold.dart';
import 'package:vs_scrollbar/vs_scrollbar.dart';

import '../controller/sync_controller.dart';
import 'package:oro_ticket_app/data/locals/models/trip_model.dart';
import 'package:oro_ticket_app/data/locals/models/vehicle_model.dart';
import 'package:oro_ticket_app/data/locals/models/departure_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/models/arrival_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/hive_boxes.dart';

class SyncView extends StatelessWidget {
  final SyncController controller = Get.put(SyncController());
  final HomeController homeController = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    final ScrollController _scrollController = ScrollController();
    return AppScaffold(
      title: "Trip list",
      userName: '',
      body: Column(
        children: [
          Obx(
            () => Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total trips',
                        style: AppTextStyles.buttonMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${controller.filteredTickets.length}',
                        style: AppTextStyles.buttonMediumB.copyWith(fontSize: 20),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Trip list',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildTopBar(context),
          Expanded(
            child: Obx(() {
              final tickets = controller.filteredTickets;
              if (tickets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text("No Trips found",
                          style:
                              AppTextStyles.body2.copyWith(color: Colors.grey)),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: controller.refreshTickets,
                child: VsScrollbar(
                 controller: _scrollController,
                  showTrackOnHover: true,
                  isAlwaysShown: true,
                  scrollbarFadeDuration: Duration(milliseconds: 500),
                  scrollbarTimeToFade: Duration(milliseconds: 800),
                  style: VsScrollbarStyle(
                    hoverThickness: 2.0,
                    radius: Radius.circular(8),
                    thickness: 4.0,
                    color: AppColors.primary.withValues(alpha: 0.05),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: tickets.length,
                    itemBuilder: (context, index) {
                      return _buildTicketCard(tickets[index]);
                    },
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (val) => controller.searchQuery.value = val,
              decoration: InputDecoration(
                hintText: "Search by Plate No., Terminal, Association...",
                hintStyle: AppTextStyles.caption3.copyWith(
                    fontSize: 10, color: AppColors.bottomNavUnselected),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(TripModel trip) {
    final vehicleBox = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);
    final departureBox =
        Hive.box<DepartureTerminalModel>(HiveBoxes.departureTerminalsBox);
    final arrivalBox =
        Hive.box<ArrivalTerminalModel>(HiveBoxes.arrivalTerminalsBox);

    final vehicle = vehicleBox.values.firstWhere(
      (v) => v.id == trip.vehicleId,
      orElse: () => VehicleModel(
        id: "unknown",
        plateNumber: "unknown",
        plateRegion: "unknown",
        fleetType: "unknown",
        vehicleLevel: "Standard",
        associationName: "unknown",
        seatCapacity: 0,
        status: "unknown",
        arrivalTerminals: [],
        tariffs: [],
      ),
    );

    final departure = departureBox.values.firstWhere(
      (d) => d.id == trip.departureTerminalId,
      orElse: () => DepartureTerminalModel(
          id: "unknown", name: "Unknown", status: "active"),
    );

    final arrival = arrivalBox.values.firstWhere(
      (a) => a.id == trip.arrivalTerminalId,
      orElse: () => ArrivalTerminalModel(
          id: "unknown", name: "Unknown", tariff: 0.0, distance: 0.0),
    );

    final ethDate = trip.dateAndTime.convertToEthiopian();
    final period = ethDate.hour >= 12 ? 'PM' : 'AM';

    return Card(
      // color: AppColors.cardAlt,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 0, // flatter modern look
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plate & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${vehicle.plateRegion}${vehicle.plateNumber}",
                  style: AppTextStyles.buttonMediumB,
                ),
                Chip(
                  label: Text(
                    trip.isSynced ? "Synced" : "Not Synced",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: trip.isSynced
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                  backgroundColor:
                      trip.isSynced ? Colors.green.shade50 : Colors.red.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Route
            Row(
              children: [
                const Icon(Icons.place, size: 16, color: Colors.redAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${departure.name} → ${arrival.name}",
                    style: AppTextStyles.body2
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),

            // Association & Seat
            Row(
              children: [
                const Icon(Icons.business, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(vehicle.associationName,
                        style: AppTextStyles.body2)),
                const Icon(Icons.event_seat, size: 16, color: Colors.teal),
                const SizedBox(width: 4),
                Text("Seat Capacity: ${vehicle.seatCapacity}",
                    style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(height: 10),

            // Tariff, Service, Total
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPriceItem("Tariff", trip.tariff.toStringAsFixed(1)),
                  _buildPriceItem(
                      "Service", trip.serviceCharge.toStringAsFixed(1)),
                  _buildPriceItem("Total", trip.totalPaid.toStringAsFixed(1),
                      isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Date
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  "${ethDate.day}-${ethDate.month}-${ethDate.year} "
                  "${ethDate.hour}:${ethDate.minute.toString().padLeft(2, '0')} $period",
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceItem(String label, String value, {bool isTotal = false}) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.caption
              .copyWith(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.body2.copyWith(
            fontWeight: FontWeight.bold,
            color: isTotal ? Colors.green.shade800 : Colors.black,
          ),
        ),
      ],
    );
  }
}
