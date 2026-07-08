// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tariff_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TariffModelAdapter extends TypeAdapter<TariffModel> {
  @override
  final int typeId = 8;

  @override
  TariffModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TariffModel(
      id: fields[0] as String,
      terminalDestinationId: fields[1] as String?,
      fleetTypeId: fields[2] as String?,
      vehicleLevelId: fields[3] as String,
      roadType: fields[4] as String,
      pricePerKm: fields[5] as double,
      vehicleLevelName: fields[6] as String?,
      createdAt: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime?,
      deletedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TariffModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.terminalDestinationId)
      ..writeByte(2)
      ..write(obj.fleetTypeId)
      ..writeByte(3)
      ..write(obj.vehicleLevelId)
      ..writeByte(4)
      ..write(obj.roadType)
      ..writeByte(5)
      ..write(obj.pricePerKm)
      ..writeByte(6)
      ..write(obj.vehicleLevelName)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.deletedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TariffModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
