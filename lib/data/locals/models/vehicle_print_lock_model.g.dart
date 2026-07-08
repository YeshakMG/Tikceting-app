// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_print_lock_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VehiclePrintLockAdapter extends TypeAdapter<VehiclePrintLock> {
  @override
  final int typeId = 11;

  @override
  VehiclePrintLock read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VehiclePrintLock(
      vehicleId: fields[0] as String,
      lockUntil: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, VehiclePrintLock obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.vehicleId)
      ..writeByte(1)
      ..write(obj.lockUntil);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehiclePrintLockAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
