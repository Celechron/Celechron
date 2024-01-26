import 'package:celechron/utils/utils.dart';
import 'package:hive/hive.dart';
import 'package:celechron/model/deadline.dart';

class DeadlineStatusAdapter extends TypeAdapter<DeadlineStatus> {
  @override
  final typeId = 7;

  @override
  void write(BinaryWriter writer, DeadlineStatus obj) =>
      writer.writeInt(obj.index);

  @override
  DeadlineStatus read(BinaryReader reader) =>
      DeadlineStatus.values[reader.readInt()];
}

class DeadlineTypeAdapter extends TypeAdapter<DeadlineType> {
  @override
  final typeId = 10;

  @override
  void write(BinaryWriter writer, DeadlineType obj) =>
      writer.writeInt(obj.index);

  @override
  DeadlineType read(BinaryReader reader) =>
      DeadlineType.values[reader.readInt()];
}

class DeadlineRepeatTypeAdapter extends TypeAdapter<DeadlineRepeatType> {
  @override
  final typeId = 11;

  @override
  void write(BinaryWriter writer, DeadlineRepeatType obj) =>
      writer.writeInt(obj.index);

  @override
  DeadlineRepeatType read(BinaryReader reader) =>
      DeadlineRepeatType.values[reader.readInt()];
}

class DeadlineAdapter extends TypeAdapter<Deadline> {
  @override
  final typeId = 6;

  @override
  void write(BinaryWriter writer, Deadline obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.deadlineStatus)
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
      ..write(obj.isBreakable)
      ..writeByte(9)
      ..write(obj.deadlineType)
      ..writeByte(10)
      ..write(obj.startTime)
      ..writeByte(11)
      ..write(obj.deadlineRepeatType)
      ..writeByte(12)
      ..write(obj.deadlineRepeatPeriod)
      ..writeByte(13)
      ..write(obj.deadlineRepeatEndsTime)
      ..writeByte(14)
      ..write(obj.blockArrangements)
      ..writeByte(15)
      ..write(obj.fromUid);
  }

  @override
  Deadline read(BinaryReader reader) {
    var numOfFields = reader.readByte();
    var fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Deadline(
      endTime: DateTime.now(),
      startTime: DateTime.now(),
      deadlineRepeatEndsTime: DateTime.now(),
    )
      ..uid = fields[0] as String
      ..deadlineStatus = fields[1] as DeadlineStatus
      ..description = fields[2] as String
      ..timeSpent = fields[3] as Duration
      ..timeNeeded = fields[4] as Duration
      ..endTime = fields[5] as DateTime
      ..location = fields[6] as String
      ..summary = fields[7] as String
      ..isBreakable = fields[8] as bool
      ..deadlineType = fields[9] as DeadlineType? ?? DeadlineType.normal
      ..startTime = fields[10] as DateTime? ?? (fields[5] as DateTime)
      ..deadlineRepeatType =
          fields[11] as DeadlineRepeatType? ?? DeadlineRepeatType.norepeat
      ..deadlineRepeatPeriod = fields[12] as int? ?? 1
      ..deadlineRepeatEndsTime =
          fields[13] as DateTime? ?? (fields[5] as DateTime)
      ..blockArrangements = fields[14] as bool? ?? true
      ..fromUid = fields[15] as String?;
  }
}
