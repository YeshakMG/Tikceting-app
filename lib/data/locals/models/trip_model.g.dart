// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripModelAdapter extends TypeAdapter<TripModel> {
  @override
  final int typeId = 5;

  @override
  TripModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TripModel(
      vehicleId: fields[0] as String,
      dateAndTime: fields[1] as DateTime,
      km: fields[2] as double,
      tariff: fields[3] as double,
      serviceCharge: fields[4] as double,
      totalPaid: fields[5] as double,
      departureTerminalId: fields[6] as String,
      arrivalTerminalId: fields[7] as String,
      companyId: fields[8] as String,
      employeeId: fields[9] as String,
      departureName: fields[10] as String,
      arrivalName: fields[11] as String,
      isSynced: fields[12] as bool,
      transactionId: fields[13] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, TripModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.vehicleId)
      ..writeByte(1)
      ..write(obj.dateAndTime)
      ..writeByte(2)
      ..write(obj.km)
      ..writeByte(3)
      ..write(obj.tariff)
      ..writeByte(4)
      ..write(obj.serviceCharge)
      ..writeByte(5)
      ..write(obj.totalPaid)
      ..writeByte(6)
      ..write(obj.departureTerminalId)
      ..writeByte(7)
      ..write(obj.arrivalTerminalId)
      ..writeByte(8)
      ..write(obj.companyId)
      ..writeByte(9)
      ..write(obj.employeeId)
      ..writeByte(10)
      ..write(obj.departureName)
      ..writeByte(11)
      ..write(obj.arrivalName)
      ..writeByte(12)
      ..write(obj.isSynced)
      ..writeByte(13)
      ..write(obj.transactionId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
