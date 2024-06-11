import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/zjuServices/tuple.dart';

import 'package:celechron/model/grade.dart';
import 'package:celechron/model/semester.dart';

abstract class Spider {

  set db(DatabaseHelper? db);

  Future<List<String?>> login() async {
    throw UnimplementedError();
  }

  void logout() {
    throw UnimplementedError();
  }

  Future<
      Tuple6<
          List<String?>,
          List<String?>,
          List<Semester>,
          Map<String, List<Grade>>,
          List<double>,
          Map<DateTime, String>>> getEverything() async {
    throw UnimplementedError();
  }
}