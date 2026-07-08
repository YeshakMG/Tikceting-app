import 'dart:io';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';

import 'package:oro_ticket_app/data/locals/models/trip_model.dart';
import 'package:oro_ticket_app/data/locals/models/vehicle_model.dart';
import 'package:oro_ticket_app/data/locals/models/departure_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/models/arrival_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/hive_boxes.dart';

class TripReportItem {
  final String departureName;
  final String arrivalName;
  final String plateNumber;
  final String plateRegion;
  final String vehicleLevel;
  final String associationName;
  final double price; // tariff
  final double serviceCharge;
  final double totalPrice; // totalPaid

  TripReportItem({
    required this.departureName,
    required this.arrivalName,
    required this.plateNumber,
    required this.plateRegion,
    required this.vehicleLevel,
    required this.associationName,
    required this.price,
    required this.serviceCharge,
    required this.totalPrice,
  });
}

class LocalReportController extends GetxController {
  RxList<TripReportItem> allTrips = <TripReportItem>[].obs;
  RxList<TripReportItem> filteredTrips = <TripReportItem>[].obs;
  RxBool sortAsc = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadTripsFromHive();
  }

  Future<void> loadTripsFromHive() async {
    print("📥 Loading trips from Hive...");
    try {
      final tripBox = Hive.box<TripModel>(HiveBoxes.tripBox);
      final vehicleBox = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);
      final departureBox =
          Hive.box<DepartureTerminalModel>(HiveBoxes.departureTerminalsBox);
      final arrivalBox =
          Hive.box<ArrivalTerminalModel>(HiveBoxes.arrivalTerminalsBox);

      print("📦 tripBox length: ${tripBox.length}");
      if (tripBox.isEmpty) {
        print("❌ tripBox is empty — no data.");
        allTrips.clear();
        filteredTrips.clear();
        return;
      }

      final loadedTrips = tripBox.values.map((trip) {
        final vehicle =
            vehicleBox.values.firstWhereOrNull((v) => v.id == trip.vehicleId);
        final departure = departureBox.values
            .firstWhereOrNull((d) => d.id == trip.departureTerminalId);
        final arrival = arrivalBox.values
            .firstWhereOrNull((a) => a.id == trip.arrivalTerminalId);

        return TripReportItem(
          departureName: departure?.name ?? 'Unknown',
          arrivalName: arrival?.name ?? 'Unknown',
          plateNumber: vehicle?.plateNumber ?? 'Unknown',
          plateRegion: vehicle?.plateRegion ?? 'Unknown',
          vehicleLevel: vehicle?.vehicleLevel ?? 'Unknown',
          associationName: vehicle?.associationName ?? 'Unknown',
          price: trip.tariff,
          serviceCharge: trip.serviceCharge,
          totalPrice: trip.totalPaid,
        );
      }).toList();

      allTrips.assignAll(loadedTrips);
      filteredTrips.assignAll(loadedTrips);

      print("✅ Loaded \${allTrips.length} trips with full info.");
    } catch (e, st) {
      print("❌ Error loading trips from Hive: \$e");
      print(st);
      allTrips.clear();
      filteredTrips.clear();
    }
  }

  void searchTrips(String query) {
    if (query.isEmpty) {
      filteredTrips.assignAll(allTrips);
      return;
    }
    final lowerQuery = query.toLowerCase();
    filteredTrips.assignAll(allTrips.where((trip) {
      return trip.departureName.toLowerCase().contains(lowerQuery) ||
          trip.arrivalName.toLowerCase().contains(lowerQuery) ||
          trip.plateNumber.toLowerCase().contains(lowerQuery) ||
          trip.plateRegion.toLowerCase().contains(lowerQuery) ||
          trip.vehicleLevel.toLowerCase().contains(lowerQuery) ||
          trip.associationName.toLowerCase().contains(lowerQuery);
    }).toList());
  }

  void sortByDepartureName() {
    sortAsc.value = !sortAsc.value;
    filteredTrips.sort((a, b) {
      final depA = a.departureName.toLowerCase();
      final depB = b.departureName.toLowerCase();
      return sortAsc.value ? depA.compareTo(depB) : depB.compareTo(depA);
    });
    filteredTrips.refresh();
  }

  void sortByPrice() {
    sortAsc.value = !sortAsc.value;
    filteredTrips.sort((a, b) {
      return sortAsc.value
          ? a.price.compareTo(b.price)
          : b.price.compareTo(a.price);
    });
    filteredTrips.refresh();
  }

  Future<void> generatePDFReport() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Header(level: 0, child: pw.Text("Local Trip Report")),
            pw.Table.fromTextArray(
              headers: [
                'Departure',
                'Arrival',
                'Plate Number',
                'Region',
                'Level',
                'Association',
                'Price',
                'Service Charge',
                'Total Price',
              ],
              data: filteredTrips.map((trip) {
                return [
                  trip.departureName,
                  trip.arrivalName,
                  trip.plateNumber,
                  trip.plateRegion,
                  trip.vehicleLevel,
                  trip.associationName,
                  trip.price.toStringAsFixed(2),
                  trip.serviceCharge.toStringAsFixed(2),
                  trip.totalPrice.toStringAsFixed(2),
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    final outputDir = await getApplicationDocumentsDirectory();
    final file = File(
        '\${outputDir.path}/local_trip_report_\${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    print('✅ PDF generated at: \${file.path}');
    Get.snackbar("Success", "PDF report generated at:\n\${file.path}");
  }
}
