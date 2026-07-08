import 'dart:convert';

class ExitTicketQRData {
  final String vehicleId;
  final String plateNumber;
  final String originTerminalId;
  final String? checkinDate;
  final String? notes;
  final DateTime timestamp;

  ExitTicketQRData({
    required this.vehicleId,
    required this.plateNumber,
    required this.originTerminalId,
    this.checkinDate,
    this.notes,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'vehicle_id': vehicleId,
        'plate_number': plateNumber,
        'origin_terminal_id': originTerminalId,
        'checkin_date': checkinDate,
        'notes': notes,
        'timestamp': timestamp.toIso8601String(),
      };

  String toQRString() {
    final jsonString = jsonEncode(toJson());

    final bytes = utf8.encode(jsonString);
    return base64Encode(bytes);
  }

  static ExitTicketQRData fromQRString(String qrString) {
    try {
      final bytes = base64Decode(qrString);
      final jsonString = utf8.decode(bytes);
      final Map<String, dynamic> json = jsonDecode(jsonString);

      return ExitTicketQRData(
        vehicleId: json['vehicle_id'],
        plateNumber: json['plate_number'],
        originTerminalId: json['origin_terminal_id'],
        checkinDate: json['checkin_date'],
        notes: json['notes'],
        timestamp: DateTime.parse(json['timestamp']),
      );
    } catch (e) {
      throw FormatException('Invalid QR code format: $e');
    }
  }
}
