// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terminal_destination.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TerminalDestinationAdapter extends TypeAdapter<TerminalDestination> {
  @override
  final int typeId = 10;

  @override
  TerminalDestination read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TerminalDestination(
      id: fields[0] as String,
      departureTerminalId: fields[1] as String,
      arrivalTerminalId: fields[2] as String,
      distance: fields[3] as double,
      roadType: fields[4] as String,
      roadDistances: (fields[5] as Map?)?.cast<String, double>(),
      departureTerminalName: fields[6] as String?,
      arrivalTerminalName: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TerminalDestination obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.departureTerminalId)
      ..writeByte(2)
      ..write(obj.arrivalTerminalId)
      ..writeByte(3)
      ..write(obj.distance)
      ..writeByte(4)
      ..write(obj.roadType)
      ..writeByte(5)
      ..write(obj.roadDistances)
      ..writeByte(6)
      ..write(obj.departureTerminalName)
      ..writeByte(7)
      ..write(obj.arrivalTerminalName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerminalDestinationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
