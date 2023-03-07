import 'package:hive/hive.dart';

class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final typeId = 4;

  @override
  void write(BinaryWriter writer, Duration obj) =>
      writer.writeInt(obj.inMicroseconds);

  @override
  Duration read(BinaryReader reader) =>
      Duration(microseconds: reader.readInt());
}

class Options {
  late final Box optionsBox;

  final String dbOptions = 'dbOptions';
  final String kWorkTime = 'workTime';
  final String kRestTime = 'restTime';
  final String kAllowTime = 'allowTime';

  Future<void> init() async {
    Hive.registerAdapter(DurationAdapter());
    optionsBox = await Hive.openBox(dbOptions);
  }

  Duration getWorkTime() {
    if (optionsBox.get(kWorkTime) == null) {
      optionsBox.put(kWorkTime, const Duration(minutes: 45));
    }
    return optionsBox.get(kWorkTime);
  }

  void setWorkTime(Duration workTime) {
    optionsBox.put(kWorkTime, workTime);
  }

  Duration getRestTime() {
    if (optionsBox.get(kRestTime) == null) {
      optionsBox.put(kRestTime, const Duration(minutes: 15));
    }
    return optionsBox.get(kRestTime);
  }

  void setRestTime(Duration restTime) {
    optionsBox.put(kRestTime, restTime);
  }

  Map<dynamic, dynamic> getAllowTime() {
    if (true || optionsBox.get(kAllowTime) == null) {
      Map<DateTime, DateTime> base = {};
      base[DateTime(0, 0, 0, 8, 0)] = DateTime(0, 0, 0, 11, 35);
      base[DateTime(0, 0, 0, 14, 15)] = DateTime(0, 0, 0, 22, 00);
      optionsBox.put(kAllowTime, base);
    }
    return optionsBox.get(kAllowTime);
  }

  void setAllowTime(Map<DateTime, DateTime> allowTime) {
    optionsBox.put(kAllowTime, allowTime);
  }
}

late Options options;
