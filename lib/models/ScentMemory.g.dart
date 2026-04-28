// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ScentMemory.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScentMemoryAdapter extends TypeAdapter<ScentMemory> {
  @override
  final int typeId = 0;

  @override
  ScentMemory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScentMemory(
      id: fields[0] as String,
      userInput: fields[1] as String,
      emotion: fields[2] as String,
      scent: fields[3] as String,
      timestamp: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ScentMemory obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userInput)
      ..writeByte(2)
      ..write(obj.emotion)
      ..writeByte(3)
      ..write(obj.scent)
      ..writeByte(4)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScentMemoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
