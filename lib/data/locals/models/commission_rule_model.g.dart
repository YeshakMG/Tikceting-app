// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commission_rule_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CommissionRuleModelAdapter extends TypeAdapter<CommissionRuleModel> {
  @override
  final int typeId = 4;

  @override
  CommissionRuleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CommissionRuleModel(
      id: fields[0] as String,
      companyId: fields[1] as String?,
      zoneId: fields[2] as String?,
      cityId: fields[3] as String?,
      commissionRate: fields[4] as double,
      description: fields[5] as String?,
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, CommissionRuleModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.companyId)
      ..writeByte(2)
      ..write(obj.zoneId)
      ..writeByte(3)
      ..write(obj.cityId)
      ..writeByte(4)
      ..write(obj.commissionRate)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommissionRuleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
