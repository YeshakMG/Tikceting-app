// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VehicleModelAdapter extends TypeAdapter<VehicleModel> {
  @override
  final int typeId = 0;

  @override
  VehicleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VehicleModel(
      id: fields[0] as String,
      plateNumber: fields[1] as String,
      plateRegion: fields[2] as String,
      fleetType: fields[3] as String,
      vehicleLevel: fields[4] as String,
      associationName: fields[5] as String,
      seatCapacity: fields[6] as int,
      status: fields[7] as String,
      assignedTerminalId: fields[8] as String?,
      arrivalTerminals: (fields[13] as List?)?.cast<String>(),
      tariffs: (fields[14] as List?)?.cast<String>(),
      createdBy: fields[9] as String?,
      updatedBy: fields[10] as String?,
      createdAt: fields[11] as String?,
      updatedAt: fields[12] as String?,
      vehicleLevelId: fields[15] as String?,
      fleetTypeId: fields[16] as String?,
      currentRoute: fields[17] as VehicleRoute?,
    );
  }

  @override
  void write(BinaryWriter writer, VehicleModel obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.plateNumber)
      ..writeByte(2)
      ..write(obj.plateRegion)
      ..writeByte(3)
      ..write(obj.fleetType)
      ..writeByte(4)
      ..write(obj.vehicleLevel)
      ..writeByte(5)
      ..write(obj.associationName)
      ..writeByte(6)
      ..write(obj.seatCapacity)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.assignedTerminalId)
      ..writeByte(9)
      ..write(obj.createdBy)
      ..writeByte(10)
      ..write(obj.updatedBy)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.arrivalTerminals)
      ..writeByte(14)
      ..write(obj.tariffs)
      ..writeByte(15)
      ..write(obj.vehicleLevelId)
      ..writeByte(16)
      ..write(obj.fleetTypeId)
      ..writeByte(17)
      ..write(obj.currentRoute);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
