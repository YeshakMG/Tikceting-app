import 'package:hive/hive.dart';

part 'trip_model.g.dart';

@HiveType(typeId: 5)
class TripModel extends HiveObject {
  @HiveField(0)
  String vehicleId;

  @HiveField(1)
  DateTime dateAndTime;

  @HiveField(2)
  double km;

  @HiveField(3)
  double tariff;

  @HiveField(4)
  double serviceCharge;

  @HiveField(5)
  double totalPaid;

  @HiveField(6)
  String departureTerminalId;

  @HiveField(7)
  String arrivalTerminalId;

  @HiveField(8)
  String companyId;

  @HiveField(9)
  String employeeId;

  @HiveField(10)
  String departureName;

  @HiveField(11)
  String arrivalName;

  @HiveField(12)
  bool isSynced;

  @HiveField(13)
  String transactionId;

  TripModel({
    required this.vehicleId,
    required this.dateAndTime,
    required this.km,
    required this.tariff,
    required this.serviceCharge,
    required this.totalPaid,
    required this.departureTerminalId,
    required this.arrivalTerminalId,
    required this.companyId,
    required this.employeeId,
    required this.departureName,
    required this.arrivalName,
    this.isSynced = false,
    this.transactionId = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'vehicle_id': vehicleId,
      'date_and_time': dateAndTime.toIso8601String(),
      'km': km,
      'tariff': tariff,
      'service_charge': serviceCharge,
      'total_paid': totalPaid,
      'departure_terminal_id': departureTerminalId,
      'arrival_terminal_id': arrivalTerminalId,
      'company_id': companyId,
      'transaction_id': transactionId,
      // 'employee_id': employeeId,
    };
  }

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      vehicleId: json['vehicle_id'] ?? '',
      dateAndTime: DateTime.tryParse(json['date_and_time'] ?? '') ?? DateTime.now(),
      km: (json['km'] as num?)?.toDouble() ?? 0.0,
      tariff: (json['tariff'] as num?)?.toDouble() ?? 0.0,
      serviceCharge: (json['service_charge'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0.0,
      departureTerminalId: json['departure_terminal_id'] ?? '',
      arrivalTerminalId: json['arrival_terminal_id'] ?? '',
      companyId: json['company_id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      transactionId: json['transaction_id'] ?? json['transactionId'] ?? '',
      departureName: json['departure_name'] ??
          json['departureTerminal']?['name'] ??
          '', 
      arrivalName: json['arrival_name'] ??
          json['arrivalTerminal']?['name'] ??
          '',
    );
  }
}