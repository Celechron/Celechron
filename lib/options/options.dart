import 'package:hive/hive.dart';
import '../utils/utils.dart';

class Options {
  late final Box optionsBox;

  final String dbOptions = 'dbOptions';

  Options() {
    optionsBox = Hive.box(dbOptions);
  }

  Future<Duration> getWorkTime() async {
    if (optionsBox.get('workTime') == null) {
      optionsBox.put('workTime', const Duration(minutes: 45));
    }
    return optionsBox.get('workTime');
  }
}

late Options options;
