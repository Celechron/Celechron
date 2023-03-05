import 'package:hive/hive.dart';
import '../utils/utils.dart';

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

  Future<void> init() async {
    Hive.registerAdapter(DurationAdapter());
    optionsBox = await Hive.openBox(dbOptions);
  }

  Duration getWorkTime() {
    if (optionsBox.get('workTime') == null) {
      optionsBox.put('workTime', const Duration(minutes: 45));
    }
    return optionsBox.get('workTime');
  }
}

late Options options;
