import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:celechron/model/user.dart';

class UserAdapter extends TypeAdapter<User> {
  @override
  final typeId = 5;

  @override
  void write(BinaryWriter writer, User obj) =>
      writer.writeString(jsonEncode(obj));

  @override
  User read(BinaryReader reader) => User.fromJson(jsonDecode(reader.readString()));
}
