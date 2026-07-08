import 'package:hive/hive.dart';

part 'service_charge_model.g.dart';

@HiveType(typeId: 6)
class ServiceChargeModel extends HiveObject {
  @HiveField(0)
  String departureTerminal;

  @HiveField(1)
  DateTime dateTime;

  @HiveField(2)
  double serviceChargeAmount;

  @HiveField(3)
  String employeeName;

  @HiveField(4)
  String employeeId;

  @HiveField(5)
  String companyId;

  @HiveField(6)
  String transactionId;

  ServiceChargeModel({
    required this.departureTerminal,
    required this.dateTime,
    required this.serviceChargeAmount,
    required this.employeeName,
    required this.employeeId,
    required this.companyId,
    this.transactionId = '',
  });

  Map<String, dynamic> toJson() => {
        "departure_terminal_id": departureTerminal,
        "date_and_time": dateTime.toIso8601String(),
        "service_charge_amount": serviceChargeAmount,
        "employee_name": employeeName,
        // Backend expects 'created_by' instead of 'employee_id'
        "created_by": employeeId,
        "company_id": companyId,
        "transaction_id": transactionId,
      };

  factory ServiceChargeModel.fromJson(Map<String, dynamic> json) {
    return ServiceChargeModel(
      departureTerminal: json['departure_terminal_id'] ?? '',
      dateTime: DateTime.parse(json['date_and_time']),
      serviceChargeAmount: (json['service_charge_amount'] as num).toDouble(),
      employeeName: json['employee_name'] ?? '',
      employeeId: json['employee_id'] ?? '',
      companyId: json['company_id'] ?? '',
      transactionId: json['transaction_id'] ?? json['transactionId'] ?? '',
    );
  }
}
