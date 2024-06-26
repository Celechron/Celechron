// Autogenerated from Pigeon (v18.0.1), do not edit directly.
// See also: https://pub.dev/packages/pigeon
// ignore_for_file: public_member_api_docs, non_constant_identifier_names, avoid_as, unused_import, unnecessary_parenthesis, prefer_null_aware_operators, omit_local_variable_types, unused_shown_name, unnecessary_import, no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'dart:typed_data' show Float64List, Int32List, Int64List, Uint8List;

import 'package:flutter/foundation.dart' show ReadBuffer, WriteBuffer;
import 'package:flutter/services.dart';

PlatformException _createConnectionError(String channelName) {
  return PlatformException(
    code: 'channel-error',
    message: 'Unable to establish connection on channel: "$channelName".',
  );
}

enum PeriodTypeDto {
  classes,
  test,
  user,
  flow,
}

class PeriodDto {
  PeriodDto({
    required this.uid,
    required this.type,
    this.name,
    required this.startTime,
    required this.endTime,
    this.location,
  });

  String uid;

  PeriodTypeDto type;

  String? name;

  int startTime;

  int endTime;

  String? location;

  Object encode() {
    return <Object?>[
      uid,
      type.index,
      name,
      startTime,
      endTime,
      location,
    ];
  }

  static PeriodDto decode(Object result) {
    result as List<Object?>;
    return PeriodDto(
      uid: result[0]! as String,
      type: PeriodTypeDto.values[result[1]! as int],
      name: result[2] as String?,
      startTime: result[3]! as int,
      endTime: result[4]! as int,
      location: result[5] as String?,
    );
  }
}

class FlowMessage {
  FlowMessage({
    required this.flowListDto,
  });

  List<PeriodDto?> flowListDto;

  Object encode() {
    return <Object?>[
      flowListDto,
    ];
  }

  static FlowMessage decode(Object result) {
    result as List<Object?>;
    return FlowMessage(
      flowListDto: (result[0] as List<Object?>?)!.cast<PeriodDto?>(),
    );
  }
}

class _FlowMessengerCodec extends StandardMessageCodec {
  const _FlowMessengerCodec();
  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is FlowMessage) {
      buffer.putUint8(128);
      writeValue(buffer, value.encode());
    } else if (value is PeriodDto) {
      buffer.putUint8(129);
      writeValue(buffer, value.encode());
    } else {
      super.writeValue(buffer, value);
    }
  }

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    switch (type) {
      case 128: 
        return FlowMessage.decode(readValue(buffer)!);
      case 129: 
        return PeriodDto.decode(readValue(buffer)!);
      default:
        return super.readValueOfType(type, buffer);
    }
  }
}

class FlowMessenger {
  /// Constructor for [FlowMessenger].  The [binaryMessenger] named argument is
  /// available for dependency injection.  If it is left null, the default
  /// BinaryMessenger will be used which routes to the host platform.
  FlowMessenger({BinaryMessenger? binaryMessenger, String messageChannelSuffix = ''})
      : __pigeon_binaryMessenger = binaryMessenger,
        __pigeon_messageChannelSuffix = messageChannelSuffix.isNotEmpty ? '.$messageChannelSuffix' : '';
  final BinaryMessenger? __pigeon_binaryMessenger;

  static const MessageCodec<Object?> pigeonChannelCodec = _FlowMessengerCodec();

  final String __pigeon_messageChannelSuffix;

  Future<bool> transfer(FlowMessage data) async {
    final String __pigeon_channelName = 'dev.flutter.pigeon.celechron.FlowMessenger.transfer$__pigeon_messageChannelSuffix';
    final BasicMessageChannel<Object?> __pigeon_channel = BasicMessageChannel<Object?>(
      __pigeon_channelName,
      pigeonChannelCodec,
      binaryMessenger: __pigeon_binaryMessenger,
    );
    final List<Object?>? __pigeon_replyList =
        await __pigeon_channel.send(<Object?>[data]) as List<Object?>?;
    if (__pigeon_replyList == null) {
      throw _createConnectionError(__pigeon_channelName);
    } else if (__pigeon_replyList.length > 1) {
      throw PlatformException(
        code: __pigeon_replyList[0]! as String,
        message: __pigeon_replyList[1] as String?,
        details: __pigeon_replyList[2],
      );
    } else if (__pigeon_replyList[0] == null) {
      throw PlatformException(
        code: 'null-error',
        message: 'Host platform returned null value for non-null return value.',
      );
    } else {
      return (__pigeon_replyList[0] as bool?)!;
    }
  }
}
