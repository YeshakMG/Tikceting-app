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
  final String userName;

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
    required this.userName,
  });
}
