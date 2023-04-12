import 'package:celechron/utils/utils.dart';
import 'package:hive/hive.dart';
import 'package:celechron/model/deadline.dart';

class DeadlineTypeAdapter extends TypeAdapter<DeadlineType> {
  @override
  final typeId = 7;

  @override
  void write(BinaryWriter writer, DeadlineType obj) =>
      writer.writeInt(obj.index);

  @override
  DeadlineType read(BinaryReader reader) =>
      DeadlineType.values[reader.readInt()];
}

class DeadlineAdapter extends TypeAdapter<Deadline> {
  @override
  final typeId = 6;

  @override
  void write(BinaryWriter writer, Deadline obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.deadlineType)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.timeSpent)
      ..writeByte(4)
      ..write(obj.timeNeeded)
      ..writeByte(5)
      ..write(obj.endTime)
      ..writeByte(6)
      ..write(obj.location)
      ..writeByte(7)
      ..write(obj.summary)
      ..writeByte(8)
      ..write(obj.isBreakable);
  }

  @override
  Deadline read(BinaryReader reader) {
    var numOfFields = reader.readByte();
    var fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Deadline(endTime: DateTime.now())
      ..uid = fields[0] as String
      ..deadlineType = fields[1] as DeadlineType
      ..description = fields[2] as String
      ..timeSpent = fields[3] as Duration
      ..timeNeeded = fields[4] as Duration
      ..endTime = fields[5] as DateTime
      ..location = fields[6] as String
      ..summary = fields[7] as String
      ..isBreakable = fields[8] as bool;
  }
}
