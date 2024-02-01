import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:celechron/model/scholar.dart';

class ScholarAdapter extends TypeAdapter<Scholar> {
  @override
  final typeId = 5;

  @override
  void write(BinaryWriter writer, Scholar obj) =>
      writer.writeString(jsonEncode(obj));

  @override
  Scholar read(BinaryReader reader) => Scholar.fromJson(jsonDecode(reader.readString()));
}
