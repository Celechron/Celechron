import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:celechron/model/fuse.dart';

class FuseAdapter extends TypeAdapter<Fuse> {
  @override
  final typeId = 12;

  @override
  void write(BinaryWriter writer, Fuse obj) =>
      writer.writeString(jsonEncode(obj));

  @override
  Fuse read(BinaryReader reader) => Fuse.fromJson(jsonDecode(reader.readString()));
}
