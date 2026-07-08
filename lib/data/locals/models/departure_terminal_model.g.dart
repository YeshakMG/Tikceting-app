// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'departure_terminal_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DepartureTerminalModelAdapter
    extends TypeAdapter<DepartureTerminalModel> {
  @override
  final int typeId = 1;

  @override
  DepartureTerminalModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DepartureTerminalModel(
      id: fields[0] as String,
      name: fields[1] as String,
      status: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DepartureTerminalModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepartureTerminalModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
