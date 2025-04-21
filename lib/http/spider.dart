import 'package:celechron/database/database_helper.dart';
import 'package:celechron/utils/tuple.dart';

import 'package:celechron/model/grade.dart';
import 'package:celechron/model/semester.dart';
import 'package:celechron/model/todo.dart';

abstract class Spider {
  set db(DatabaseHelper? db);

  Future<List<String?>> login() async {
    throw UnimplementedError();
  }

  void logout() {
    throw UnimplementedError();
  }

  Future<
      Tuple7<
          List<String?>,
          List<String?>,
          List<Semester>,
          List<Grade>,
          List<double>,
          Map<DateTime, String>,
          List<Todo>>> getEverything() async {
    throw UnimplementedError();
  }
}
