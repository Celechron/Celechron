import 'dart:convert';

import 'package:celechron/utils/utils.dart';
import 'package:hive/hive.dart';
import 'package:celechron/model/period.dart';

class PeriodTypeAdapter extends TypeAdapter<PeriodType> {
  @override
  final typeId = 9;

  @override
  void write(BinaryWriter writer, PeriodType obj) => writer.writeInt(obj.index);

  @override
  PeriodType read(BinaryReader reader) => PeriodType.values[reader.readInt()];
}

class PeriodAdapter extends TypeAdapter<Period> {
  @override
  final typeId = 8;

  @override
  void write(BinaryWriter writer, Period obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.fromUid)
      ..writeByte(2)
      ..write(obj.periodType)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.endTime)
      ..writeByte(6)
      ..write(obj.location)
      ..writeByte(7)
      ..write(obj.summary);
  }

  @override
  Period read(BinaryReader reader) {
    var numOfFields = reader.readByte();
    var fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Period()
      ..uid = fields[0] as String
      ..fromUid = fields[1] as String?
      ..periodType = fields[2] as PeriodType
      ..description = fields[3] as String
      ..startTime = fields[4] as DateTime
      ..endTime = fields[5] as DateTime
      ..location = fields[6] as String
      ..summary = fields[7] as String;
  }
}
