import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import '../../database/database_helper.dart';
import '../../utils/utils.dart';

class OptionPage extends StatefulWidget {
  const OptionPage({super.key});

  @override
  State<OptionPage> createState() => _OptionPageState();
}

class _OptionPageState extends State<OptionPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('时间规划'),
            tiles: <SettingsTile>[
              SettingsTile(
                title: const Text('工作段时间长度'),
                value: Text(durationToString(db.getWorkTime())),
                onPressed: (context) async {
                  Duration newWorkTime = db.getWorkTime();
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
                  db.setWorkTime(newWorkTime);
                  setState(() {});
                },
              ),
              SettingsTile(
                title: const Text('休息段时间长度'),
                value: Text(durationToString(db.getRestTime())),
                onPressed: (context) async {
                  Duration newRestTime = db.getRestTime();
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
                  db.setRestTime(newRestTime);
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
