import 'package:hive/hive.dart';
import 'package:celechron/model/task.dart';

class DeadlineStatusAdapter extends TypeAdapter<TaskStatus> {
  @override
  final typeId = 7;

  @override
  void write(BinaryWriter writer, TaskStatus obj) => writer.writeInt(obj.index);

  @override
  TaskStatus read(BinaryReader reader) => TaskStatus.values[reader.readInt()];
}

class DeadlineTypeAdapter extends TypeAdapter<TaskType> {
  @override
  final typeId = 10;

  @override
  void write(BinaryWriter writer, TaskType obj) => writer.writeInt(obj.index);

  @override
  TaskType read(BinaryReader reader) => TaskType.values[reader.readInt()];
}

class DeadlineRepeatTypeAdapter extends TypeAdapter<TaskRepeatType> {
  @override
  final typeId = 11;

  @override
  void write(BinaryWriter writer, TaskRepeatType obj) =>
      writer.writeInt(obj.index);

  @override
  TaskRepeatType read(BinaryReader reader) =>
      TaskRepeatType.values[reader.readInt()];
}

class DeadlineAdapter extends TypeAdapter<Task> {
  @override
  final typeId = 6;

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.status)
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
      ..write(obj.type)
      ..writeByte(10)
      ..write(obj.startTime)
      ..writeByte(11)
      ..write(obj.repeatType)
      ..writeByte(12)
      ..write(obj.repeatPeriod)
      ..writeByte(13)
      ..write(obj.repeatEndsTime)
      ..writeByte(14)
      ..write(obj.blockArrangements)
      ..writeByte(15)
      ..write(obj.fromUid);
  }

  @override
  Task read(BinaryReader reader) {
    var numOfFields = reader.readByte();
    var fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      endTime: DateTime.now(),
      startTime: DateTime.now(),
      repeatEndsTime: DateTime.now(),
    )
      ..uid = fields[0] as String
      ..status = fields[1] as TaskStatus
      ..description = fields[2] as String
      ..timeSpent = fields[3] as Duration
      ..timeNeeded = fields[4] as Duration
      ..endTime = fields[5] as DateTime
      ..location = fields[6] as String
      ..summary = fields[7] as String
      ..isBreakable = fields[8] as bool
      ..type = fields[9] as TaskType? ?? TaskType.deadline
      ..startTime = fields[10] as DateTime? ?? (fields[5] as DateTime)
      ..repeatType = fields[11] as TaskRepeatType? ?? TaskRepeatType.norepeat
      ..repeatPeriod = fields[12] as int? ?? 1
      ..repeatEndsTime = fields[13] as DateTime? ?? (fields[5] as DateTime)
      ..blockArrangements = fields[14] as bool? ?? true
      ..fromUid = fields[15] as String?;
  }
}
