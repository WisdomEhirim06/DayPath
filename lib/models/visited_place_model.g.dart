// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visited_place_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VisitedPlaceAdapter extends TypeAdapter<VisitedPlace> {
  @override
  final int typeId = 0;

  @override
  VisitedPlace read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VisitedPlace(
      id: fields[0] as String,
      latitude: fields[1] as double,
      longitude: fields[2] as double,
      placeName: fields[3] as String,
      startTime: fields[4] as DateTime,
      endTime: fields[5] as DateTime,
      date: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, VisitedPlace obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.latitude)
      ..writeByte(2)
      ..write(obj.longitude)
      ..writeByte(3)
      ..write(obj.placeName)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.endTime)
      ..writeByte(6)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisitedPlaceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
