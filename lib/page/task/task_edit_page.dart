import 'package:flutter/cupertino.dart';
import 'package:celechron/model/deadline.dart';
import 'package:celechron/utils/utils.dart';
import 'package:celechron/utils/timehelper.dart';

class TaskEditPage extends StatefulWidget {
  final Deadline deadline;
  const TaskEditPage(this.deadline, {super.key});

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  late Deadline now;
  int __got = 0;

  void saveAndExit() {
    FormState().save();
    now.forceRefreshType();
    Navigator.of(context).pop(now);
  }

  void removeAndExit() {
    FormState().save();
    now.forceRefreshType();
    now.deadlineType = DeadlineType.deleted;
    Navigator.of(context).pop(now);
  }

  void exitWithoutSave() {
    now = widget.deadline.copyWith();
    Navigator.of(context).pop(now);
  }

  @override
  Widget build(BuildContext context) {
    if (__got == 0) {
      now = widget.deadline.copyWith();
      __got = 1;
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoDynamicColor.resolve(
            CupertinoColors.systemGroupedBackground, context),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: exitWithoutSave,
          child: const Icon(CupertinoIcons.xmark),
        ),
        middle: const Text('编辑任务'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: saveAndExit,
          child: const Icon(CupertinoIcons.check_mark),
        ),
        border: null,
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate([
                CupertinoListSection.insetGrouped(
                  children: [
                    CupertinoTextFormFieldRow(
                      placeholder: '任务名',
                      textAlign: TextAlign.left,
                      controller: TextEditingController(text: now.summary),
                      onChanged: (String value) {
                        now.summary = value;
                      },
                    ),
                    CupertinoTextFormFieldRow(
                      placeholder: '截止时间',
                      textAlign: TextAlign.left,
                      controller: TextEditingController(
                          text:
                              '截止于 ${TimeHelper.chineseDateTime(now.endTime)}'),
                      readOnly: true,
                      onTap: () async {
                        await showCupertinoModalPopup(
                            context: context,
                            builder: (BuildContext context) {
                              return CupertinoPageScaffold(
                                child: SizedBox(
                                  height: MediaQuery.of(context)
                                          .copyWith()
                                          .size
                                          .height /
                                      3,
                                  child: CupertinoDatePicker(
                                    initialDateTime: now.endTime,
                                    use24hFormat: true,
                                    minuteInterval: 1,
                                    mode: CupertinoDatePickerMode.dateAndTime,
                                    onDateTimeChanged: (DateTime newTime) {
                                      setState(() {
                                        now.endTime = newTime;
                                      });
                                    },
                                  ),
                                ),
                              );
                            });
                      },
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('时间安排'),
                  children: [
                    CupertinoListTile(
                      title: const Text('预期用时'),
                      trailing: Text(durationToString(now.timeNeeded)),
                      onTap: () async {
                        await showCupertinoModalPopup(
                            context: context,
                            builder: (BuildContext context) {
                              return CupertinoPageScaffold(
                                child: SizedBox(
                                  height: MediaQuery.of(context)
                                          .copyWith()
                                          .size
                                          .height /
                                      3,
                                  child: CupertinoTimerPicker(
                                    mode: CupertinoTimerPickerMode.hm,
                                    initialTimerDuration: now.timeNeeded,
                                    onTimerDurationChanged: (value) {
                                      if (value > Duration.zero) {
                                        setState(() {
                                          now.timeNeeded = value;
                                        });
                                      } else {
                                        setState(() {
                                          now.timeNeeded =
                                              const Duration(minutes: 1);
                                        });
                                      }
                                    },
                                  ),
                                ),
                              );
                            });
                      },
                    ),
                    CupertinoListTile(
                      title: const Text('已经用时'),
                      trailing: Text(durationToString(now.timeSpent)),
                      onTap: () async {
                        await showCupertinoModalPopup(
                            context: context,
                            builder: (BuildContext context) {
                              return CupertinoPageScaffold(
                                child: SizedBox(
                                  height: MediaQuery.of(context)
                                          .copyWith()
                                          .size
                                          .height /
                                      3,
                                  child: CupertinoTimerPicker(
                                    mode: CupertinoTimerPickerMode.hm,
                                    initialTimerDuration: now.timeSpent,
                                    onTimerDurationChanged: (value) {
                                      setState(() {
                                        now.timeSpent = value;
                                      });
                                    },
                                  ),
                                ),
                              );
                            });
                      },
                    ),
                    CupertinoListTile(
                      title: const Text('允许插入休息时间'),
                      trailing: CupertinoSwitch(
                        value: now.isBreakable,
                        onChanged: (value) {
                          setState(() {
                            now.isBreakable = !now.isBreakable;
                          });
                        },
                      ),
                      onTap: () {},
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('附加信息'),
                  children: [
                    CupertinoTextFormFieldRow(
                      placeholder: '地点',
                      textAlign: TextAlign.left,
                      controller: TextEditingController(text: now.location),
                      onChanged: (String value) {
                        now.location = value;
                      },
                    ),
                    CupertinoTextFormFieldRow(
                      placeholder: '说明',
                      textAlign: TextAlign.left,
                      controller: TextEditingController(text: now.description),
                      onChanged: (String value) {
                        now.description = value;
                      },
                    ),
                  ],
                ),
                CupertinoButton(
                  onPressed: removeAndExit,
                  child: const Text(
                    '删除任务',
                    style: TextStyle(
                      color: CupertinoColors.systemPink,
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
