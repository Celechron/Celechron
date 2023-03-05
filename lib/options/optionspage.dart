import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:settings_ui/settings_ui.dart';
import 'options.dart';
import '../utils/utils.dart';

class OptionsPage extends StatefulWidget {
  @override
  State<OptionsPage> createState() => _OptionsPageState();
}

class _OptionsPageState extends State<OptionsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('工具与设置'),
      ),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text('时间规划'),
            tiles: <SettingsTile>[
              SettingsTile(
                title: Text('工作段时间长度'),
                value: Text(durationToString(options.getWorkTime())),
              )
            ],
          )
        ],
      ),
    );
  }
}
