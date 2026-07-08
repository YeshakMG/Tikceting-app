// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_route.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VehicleRouteAdapter extends TypeAdapter<VehicleRoute> {
  @override
  final int typeId = 9;

  @override
  VehicleRoute read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VehicleRoute(
      id: fields[0] as String,
      vehicleId: fields[1] as String,
      terminalDestinationId: fields[2] as String,
      assignedAt: fields[3] as DateTime?,
      unassignedAt: fields[4] as DateTime?,
      isOnTemporary: fields[5] as bool,
      terminalDestination: fields[6] as TerminalDestination?,
    );
  }

  @override
  void write(BinaryWriter writer, VehicleRoute obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.vehicleId)
      ..writeByte(2)
      ..write(obj.terminalDestinationId)
      ..writeByte(3)
      ..write(obj.assignedAt)
      ..writeByte(4)
      ..write(obj.unassignedAt)
      ..writeByte(5)
      ..write(obj.isOnTemporary)
      ..writeByte(6)
      ..write(obj.terminalDestination);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleRouteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
