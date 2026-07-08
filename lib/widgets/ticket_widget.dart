import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app/modules/home/controllers/home_controller.dart';

class PrintableTicketWidget extends StatelessWidget {
  final String tripId;
  final String plateNumber;
  final String region;
  final String association;
  final String departure;
  final String arrival;
  final String level;
  final String seat;
  final String distance;
  final String tariff;
  final String serviceCharge;
  final String totalPaid;
  final String agent;
  final String dateTime;

  const PrintableTicketWidget({
    required this.tripId,
    required this.plateNumber,
    required this.region,
    required this.association,
    required this.departure,
    required this.arrival,
    required this.level,
    required this.seat,
    required this.distance,
    required this.tariff,
    required this.serviceCharge,
    required this.totalPaid,
    required this.agent,
    required this.dateTime,
  });

  @override
  Widget build(BuildContext context) {
    final homeController = Get.put(HomeController());

    return Container(
      padding: const EdgeInsets.all(16),
      color: Color(0xFFF9F7FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child:
                Text("Oromia Transport Agency", style: AppTextStyles.heading3),
          ),
          Center(
            child: Text(homeController.companyName.value,
                style: AppTextStyles.buttonMediumB
                    .copyWith(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          _iconRow(
              Icons.directions_bus, "Plate Number", "$region-$plateNumber"),
          _iconRow(Icons.business, "Association", association),
          Divider(),
          _iconRow(Icons.location_pin, departure, null),
          _iconRow(Icons.location_pin, arrival, null),
          Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                dateTime,
                style: AppTextStyles.caption
                    .copyWith(color: Colors.grey, fontWeight: FontWeight.bold),
              )),
          Divider(),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _infoTag(Icons.event_seat, "$seat Seat"),
              _infoTag(Icons.grade, "Level $level"),
              _infoTag(Icons.straighten, "$distance km"),
              _infoTag(Icons.monetization_on, "$tariff ETB"),
            ],
          ),
          Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _priceColumn("Service Charge", "$serviceCharge ETB"),
              _priceColumn("Total Payment", "$totalPaid ETB"),
            ],
          ),
          const SizedBox(height: 8),
          Text("Agent Name: $agent",
              style: AppTextStyles.caption
                  .copyWith(color: Colors.grey, fontWeight: FontWeight.bold)),
          Text("Free Call Service: 8556",
              style: AppTextStyles.caption
                  .copyWith(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Center(
            child: QrImageView(
              data: tripId,
              version: QrVersions.auto,
              size: 100.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: Icon(icon, color: Colors.green),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (value != null)
                Text(label,
                    style: AppTextStyles.caption2.copyWith(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              Text(value ?? label,
                  style: AppTextStyles.caption.copyWith(
                      color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _infoTag(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _priceColumn(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppTextStyles.caption
                .copyWith(color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(
          value,
          style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
