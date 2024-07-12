import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class UidColors {
  static Color colorFromUid(String? uid) {
    int value = (uid ?? '').hashCode;
    return HSLColor.fromAHSL(
            1.0,
            (20 + (value * 19 + 133) % 310),
            (80 + (value * 17 + 155) % 20) / 100.00,
            (60 + (value * 13 + 494) % 20) / 100.00)
        .toColor();
  }
}

class TimeColors {
  static Color colorFromHour(int hour) {
    Color color = Colors.red;
    if (hour <= 8) {
      color = Colors.red;
    } else if (hour >= 9 && hour <= 12) {
      color = Colors.amber;
    } else if (hour == 13) {
      color = const Color.fromARGB(255, 163, 232, 0);
    } else if (hour >= 14 && hour <= 15) {
      color = Colors.green;
    } else if (hour >= 16 && hour <= 17) {
      color = Colors.lightBlue;
    } else if (hour >= 18 && hour <= 19) {
      color = const Color.fromARGB(255, 38, 0, 255);
    } else if (hour >= 20) {
      color = const Color.fromARGB(255, 195, 0, 255);
    }
    return color;
  }

  static Color colorFromClass(int number) {
    Color color = Colors.red;
    if (number <= 1) {
      color = Colors.red;
    } else if (number >= 2 && number <= 5) {
      color = Colors.amber;
    } else if (number == 6) {
      color = const Color.fromARGB(255, 163, 232, 0);
    } else if (number >= 7 && number <= 8) {
      color = Colors.green;
    } else if (number >= 9 && number <= 10) {
      color = Colors.lightBlue;
    } else if (number >= 11 && number <= 12) {
      color = const Color.fromARGB(255, 38, 0, 255);
    } else if (number >= 13) {
      color = const Color.fromARGB(255, 195, 0, 255);
    }
    return color;
  }
}

class CustomCupertinoDynamicColors {
  static const CupertinoDynamicColor spring =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 255, 226, 1.0),
    darkColor: Color.fromRGBO(147, 251, 56, 1.0),
  );

  static const CupertinoDynamicColor summer =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 218, 238, 1.0),
    darkColor: Color.fromRGBO(255, 25, 69, 1.0),
  );

  static const CupertinoDynamicColor autumn =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 234, 230, 1.0),
    darkColor: Color.fromRGBO(255, 101, 56, 1.0),
  );

  static const CupertinoDynamicColor winter =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(226, 239, 255, 1.0),
    darkColor: Color.fromRGBO(0, 183, 251, 1.0),
  );

  static const CupertinoDynamicColor violet =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 229, 255, 1.0),
    darkColor: Color.fromRGBO(151, 131, 216, 1.0),
  );

  static const CupertinoDynamicColor sakura =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 226, 255, 1.0),
    darkColor: Color.fromRGBO(218, 130, 217, 1.0),
  );

  static const CupertinoDynamicColor sand =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 246, 211, 1.0),
    darkColor: Color.fromRGBO(252, 222, 59, 1.0),
  );

  static const CupertinoDynamicColor cyan =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(218, 234, 255, 1.0),
    darkColor: Color.fromRGBO(0, 140, 255, 1.0),
  );

  static const CupertinoDynamicColor magenta =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 229, 255, 1.0),
    darkColor: Color.fromRGBO(238, 55, 161, 1.0),
  );

  static const CupertinoDynamicColor peach =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 235, 226, 1.0),
    darkColor: Color.fromRGBO(233, 114, 70, 1.0),
  );

  static const CupertinoDynamicColor okGreen =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 255, 226, 1.0),
    darkColor: Color.fromRGBO(63, 222, 23, 1.0),
  );
}
