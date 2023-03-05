import 'package:flutter/cupertino.dart';
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
                onPressed: (context) async {
                  Duration newWorkTime = options.getWorkTime();
                  await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text(
                            '工作段时间长度',
                          ),
                          content: SizedBox(
                            width: double.maxFinite,
                            height: 200,
                            child: Column(
                              children: [
                                Expanded(
                                  child: CupertinoTimerPicker(
                                    mode: CupertinoTimerPickerMode.hm,
                                    initialTimerDuration: newWorkTime,
                                    onTimerDurationChanged: (value) {
                                      newWorkTime = value;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      });
                  options.setWorkTime(newWorkTime);
                  setState(() {});
                },
              ),
              SettingsTile(
                title: Text('休息段时间长度'),
                value: Text(durationToString(options.getRestTime())),
                onPressed: (context) async {
                  Duration newRestTime = options.getRestTime();
                  await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text(
                            '休息段时间长度',
                          ),
                          content: SizedBox(
                            width: double.maxFinite,
                            height: 200,
                            child: Column(
                              children: [
                                Expanded(
                                  child: CupertinoTimerPicker(
                                    mode: CupertinoTimerPickerMode.hm,
                                    initialTimerDuration: newRestTime,
                                    onTimerDurationChanged: (value) {
                                      newRestTime = value;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      });
                  options.setRestTime(newRestTime);
                  setState(() {});
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
