import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../model/deadline.dart';
import '../../utils/utils.dart';
import '../../utils/timehelper.dart';

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
                              return Container(
                                height: MediaQuery.of(context)
                                        .copyWith()
                                        .size
                                        .height /
                                    3,
                                color: Colors.white,
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
                              return Container(
                                height: MediaQuery.of(context)
                                        .copyWith()
                                        .size
                                        .height /
                                    3,
                                color: Colors.white,
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
                              return Container(
                                height: MediaQuery.of(context)
                                        .copyWith()
                                        .size
                                        .height /
                                    3,
                                color: Colors.white,
                                child: CupertinoTimerPicker(
                                  mode: CupertinoTimerPickerMode.hm,
                                  initialTimerDuration: now.timeSpent,
                                  onTimerDurationChanged: (value) {
                                    setState(() {
                                      now.timeSpent = value;
                                    });
                                  },
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

    // return Container(
    //   height: double.maxFinite,
    //   decoration: BoxDecoration(
    //     borderRadius: BorderRadius.circular(10),
    //     color: CupertinoDynamicColor.resolve(
    //         CupertinoColors.systemGroupedBackground, context),
    //   ),
    //   padding: EdgeInsets.only(
    //     bottom: MediaQuery.of(context).viewInsets.bottom,
    //     left: 8,
    //     right: 8,
    //   ),
    //   child: CustomScrollView(
    //     slivers: [
    //       SliverList(
    //         delegate: SliverChildListDelegate([
    //           CupertinoNavigationBar(
    //             backgroundColor: CupertinoDynamicColor.resolve(
    //                 CupertinoColors.systemGroupedBackground, context),
    //             leading: CupertinoButton(
    //               padding: EdgeInsets.zero,
    //               onPressed: exitWithoutSave,
    //               child: const Icon(CupertinoIcons.xmark),
    //             ),
    //             middle: const Text('编辑任务'),
    //             trailing: CupertinoButton(
    //               padding: EdgeInsets.zero,
    //               onPressed: saveAndExit,
    //               child: const Icon(CupertinoIcons.check_mark),
    //             ),
    //             border: null,
    //           ),
    //           const SizedBox(height: 24),
    //         ]),
    //       ),
    //     ],
    //   ),
    // );
    // return Scaffold(
    //   resizeToAvoidBottomInset: true,
    //   appBar: AppBar(
    //     title: const Text('编辑任务'),
    //     leading: IconButton(
    //       tooltip: '放弃更改',
    //       icon: const Icon(Icons.close),
    //       onPressed: exitWithoutSave,
    //     ),
    //     actions: [
    //       IconButton(
    //         tooltip: '保存',
    //         onPressed: saveAndExit,
    //         icon: const Icon(Icons.check),
    //       ),
    //     ],
    //   ),
    //   body: Form(
    //     child: Container(
    //       padding: const EdgeInsets.all(16),
    //       child: ListView(
    //         children: [
    //           TextFormField(
    //             decoration: const InputDecoration(
    //               border: UnderlineInputBorder(),
    //               labelText: '任务名',
    //             ),
    //             initialValue: now.summary,
    //             onChanged: (value) {
    //               now.summary = value;
    //             },
    //           ),
    //           Row(
    //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //             children: [
    //               Text(
    //                 '${now.endTime.year} 年 ${now.endTime.month} 月 ${now.endTime.day} 日',
    //               ),
    //               TextButton(
    //                 onPressed: () async {
    //                   var res = await showDatePicker(
    //                     context: context,
    //                     initialDate: now.endTime,
    //                     firstDate: DateTime(2023, 1, 1),
    //                     lastDate: DateTime(2099, 1, 1),
    //                   );
    //                   if (res != null) {
    //                     setState(() {
    //                       now.endTime = now.endTime.copyWith(
    //                         year: res.year,
    //                         month: res.month,
    //                         day: res.day,
    //                       );
    //                     });
    //                   }
    //                 },
    //                 child: const Text('更改截止日期'),
    //               ),
    //             ],
    //           ),
    //           Row(
    //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //             children: [
    //               Text(
    //                 now.endTime.toIso8601String().substring(11, 16),
    //               ),
    //               TextButton(
    //                 onPressed: () async {
    //                   var res = await showTimePicker(
    //                     context: context,
    //                     initialTime: TimeOfDay.fromDateTime(now.endTime),
    //                   );
    //                   if (res != null) {
    //                     setState(() {
    //                       now.endTime = now.endTime.copyWith(
    //                         hour: res.hour,
    //                         minute: res.minute,
    //                       );
    //                     });
    //                   }
    //                 },
    //                 child: const Text('更改截止时间'),
    //               ),
    //             ],
    //           ),
    //           Row(
    //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //             children: [
    //               Text('预期要做 ${durationToString(now.timeNeeded)}'),
    //               TextButton(
    //                 onPressed: () {
    //                   showCupertinoDialog(
    //                       context: context,
    //                       builder: (BuildContext context) {
    //                         return CupertinoAlertDialog(
    //                           title: const Text(
    //                             '预期用时',
    //                           ),
    //                           content: SizedBox(
    //                             width: double.maxFinite,
    //                             height: 200,
    //                             child: Column(
    //                               children: [
    //                                 Expanded(
    //                                   child: CupertinoTimerPicker(
    //                                     mode: CupertinoTimerPickerMode.hm,
    //                                     initialTimerDuration: now.timeNeeded,
    //                                     minuteInterval: 5,
    //                                     onTimerDurationChanged: (value) {
    //                                       setState(() {
    //                                         now.timeNeeded = value;
    //                                       });
    //                                     },
    //                                   ),
    //                                 ),
    //                               ],
    //                             ),
    //                           ),
    //                           actions: [
    //                             CupertinoDialogAction(
    //                               child: const Text('确定'),
    //                               onPressed: () async {
    //                                 Navigator.of(context).pop();
    //                               },
    //                             )
    //                           ],
    //                         );
    //                       });
    //                 },
    //                 child: const Text('调整预期'),
    //               ),
    //             ],
    //           ),
    //           Row(
    //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //             children: [
    //               Text('已经做了 ${durationToString(now.timeSpent)}'),
    //               TextButton(
    //                 onPressed: () {
    //                   showCupertinoDialog(
    //                       context: context,
    //                       builder: (BuildContext context) {
    //                         return CupertinoAlertDialog(
    //                           title: const Text(
    //                             '已经用时',
    //                           ),
    //                           content: SizedBox(
    //                             width: double.maxFinite,
    //                             height: 200,
    //                             child: Column(
    //                               children: [
    //                                 Expanded(
    //                                   child: CupertinoTimerPicker(
    //                                     mode: CupertinoTimerPickerMode.hm,
    //                                     initialTimerDuration: now.timeSpent,
    //                                     onTimerDurationChanged: (value) {
    //                                       setState(() {
    //                                         now.timeSpent = value;
    //                                       });
    //                                     },
    //                                   ),
    //                                 ),
    //                               ],
    //                             ),
    //                           ),
    //                           actions: [
    //                             CupertinoDialogAction(
    //                               child: const Text('确定'),
    //                               onPressed: () async {
    //                                 Navigator.of(context).pop();
    //                               },
    //                             )
    //                           ],
    //                         );
    //                       });
    //                 },
    //                 child: const Text('调整用时'),
    //               ),
    //             ],
    //           ),
    //           TextFormField(
    //             decoration: const InputDecoration(
    //               border: UnderlineInputBorder(),
    //               labelText: '地点',
    //             ),
    //             initialValue: now.location,
    //             onChanged: (value) {
    //               now.location = value;
    //             },
    //           ),
    //           const SizedBox(height: 16.0),
    //           TextFormField(
    //             keyboardType: TextInputType.multiline,
    //             maxLines: null,
    //             decoration: const InputDecoration(
    //               border: UnderlineInputBorder(),
    //               labelText: '说明',
    //             ),
    //             initialValue: now.description,
    //             onChanged: (value) {
    //               now.description = value;
    //             },
    //           ),
    //           const SizedBox(height: 16.0),
    //           CheckboxListTile(
    //             title: const Text('允许在中间插入休息时间'),
    //             value: now.isBreakable,
    //             onChanged: (value) {
    //               setState(() {
    //                 now.isBreakable = !now.isBreakable;
    //               });
    //             },
    //           ),
    //           const SizedBox(height: 16.0),
    //           Row(
    //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //             children: [
    //               TextButton(
    //                 onPressed: exitWithoutSave,
    //                 child: const Text('放弃更改并退出'),
    //               ),
    //               TextButton(
    //                 onPressed: saveAndExit,
    //                 child: const Text('保存更改并退出'),
    //               ),
    //             ],
    //           ),
    //           const SizedBox(height: 16.0),
    //           Row(
    //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //             children: [
    //               TextButton(
    //                 onPressed: removeAndExit,
    //                 child: const Text('移除任务'),
    //               ),
    //             ],
    //           ),
    //         ],
    //       ),
    //     ),
    //   ),
    // );
  }
}
