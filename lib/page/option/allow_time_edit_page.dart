import 'package:celechron/design/persistent_headers.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'option_controller.dart';

String timeToString(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class DateTimePair {
  DateTime first, second;
  bool isDeleted;
  DateTimePair({
    required this.first,
    required this.second,
    this.isDeleted = false,
  });
}

class DateTimePairEditDialog extends StatefulWidget {
  final DateTimePair val;
  final Function(DateTimePair pair)? onChanged;
  const DateTimePairEditDialog({
    super.key,
    required this.val,
    this.onChanged,
  });
  @override
  State<DateTimePairEditDialog> createState() => _DateTimePairEditDialogState();
}

class _DateTimePairEditDialogState extends State<DateTimePairEditDialog> {
  late DateTimePair val;
  @override
  void initState() {
    super.initState();
    val = DateTimePair(first: widget.val.first, second: widget.val.second);
  }

  void saveChange() {
    if (widget.onChanged != null) {
      widget.onChanged!(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text(
        '更改时段',
      ),
      content: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '开始：${timeToString(val.first)}',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(
                            fontSize: 16,
                          ),
                    ),
                    CupertinoButton(
                      onPressed: () async {
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
                                    initialDateTime: val.first,
                                    use24hFormat: true,
                                    minuteInterval: 1,
                                    mode: CupertinoDatePickerMode.time,
                                    onDateTimeChanged: (DateTime newTime) {
                                      setState(() {
                                        val.first = newTime;
                                      });
                                    },
                                  ),
                                ),
                              );
                            });
                      },
                      child: const Text('更改'),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '结束：${timeToString(val.second)}',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(
                            fontSize: 16,
                          ),
                    ),
                    CupertinoButton(
                      onPressed: () async {
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
                                    initialDateTime: val.second,
                                    use24hFormat: true,
                                    minuteInterval: 1,
                                    mode: CupertinoDatePickerMode.time,
                                    onDateTimeChanged: (DateTime newTime) {
                                      setState(() {
                                        val.second = newTime;
                                      });
                                    },
                                  ),
                                ),
                              );
                            });
                      },
                      child: const Text('更改'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        CupertinoDialogAction(
          child: const Text('取消'),
          onPressed: () async {
            Navigator.of(context).pop();
          },
        ),
        CupertinoDialogAction(
          child: const Text('确定'),
          onPressed: () async {
            Navigator.of(context).pop();
            saveChange();
          },
        ),
      ],
    );
  }
}

class AllowTimeEditPage extends StatefulWidget {
  const AllowTimeEditPage({super.key});

  @override
  State<AllowTimeEditPage> createState() => _AllowTimeEditPageState();
}

class _AllowTimeEditPageState extends State<AllowTimeEditPage> {
  final _optionController = Get.put(OptionController());
  List<DateTimePair> now = [];
  int __got = 0;

  void getAllowTime() {
    now.clear();
    for (var x in _optionController.allowTime.keys) {
      now.add(DateTimePair(
        first: x.copyWith(),
        second: _optionController.allowTime[x]!.copyWith(),
      ));
    }
    now.sort((DateTimePair a, DateTimePair b) {
      if (a.first.compareTo(b.first) != 0) {
        return a.first.compareTo(b.first);
      }
      return a.second.compareTo(b.second);
    });
    setState(() {});
  }

  void saveAllowTime() async {
    for (int i = 0; i < now.length; i++) {
      var x = now[i];

      if (!x.first.isBefore(x.second)) {
        await showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: const Text(
                '开始时间必须早于结束时间',
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('确定'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                  },
                )
              ],
            );
          },
        );
        getAllowTime();
        return;
      }

      for (int j = 0; j < now.length; j++) {
        if (i == j) continue;
        var y = now[j];
        if ((!x.first.isBefore(y.first) && !x.first.isAfter(y.second)) ||
            (!x.second.isBefore(y.first) && !x.second.isAfter(y.second))) {
          await showCupertinoDialog(
            context: context,
            builder: (BuildContext context) {
              return CupertinoAlertDialog(
                title: const Text(
                  '时间段之间不能有重合或直接相邻',
                ),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('确定'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                    },
                  )
                ],
              );
            },
          );
          getAllowTime();
          return;
        }
      }
    }

    FormState().save();
    Map<DateTime, DateTime> res = {};
    for (var x in now) {
      res[x.first] = x.second;
    }

    _optionController.allowTime = res;
  }

  @override
  Widget build(BuildContext context) {
    if (__got == 0) {
      getAllowTime();
      __got = 1;
    }

    now.removeWhere((element) => element.isDeleted);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const CelechronSliverTextHeader(subtitle: '编辑可用工作时段'),
            SliverList(
              delegate: SliverChildListDelegate([
                CupertinoListSection.insetGrouped(
                  header: Container(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      '可用工作时段列表',
                      style: TextStyle(
                          color: CupertinoDynamicColor.resolve(
                              CupertinoColors.secondaryLabel, context),
                          fontSize: 14),
                    ),
                  ),
                  children: [
                    ...List.generate(
                      now.length,
                      (index) => CupertinoFormRow(
                        prefix: Text(
                            '${timeToString(now[index].first)} - ${timeToString(now[index].second)}'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                showCupertinoDialog(
                                  context: context,
                                  builder: (context) => DateTimePairEditDialog(
                                    val: now[index],
                                    onChanged: (DateTimePair updated) {
                                      setState(() {
                                        now[index] = DateTimePair(
                                          first: updated.first,
                                          second: updated.second,
                                          isDeleted: updated.isDeleted,
                                        );
                                        saveAllowTime();
                                      });
                                    },
                                  ),
                                );
                              },
                              child: const Icon(
                                CupertinoIcons.pencil,
                                color: CupertinoColors.activeBlue,
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                if (now.length > 1) {
                                  setState(() {
                                    now.removeAt(index);
                                    saveAllowTime();
                                  });
                                }
                              },
                              child: const Icon(
                                CupertinoIcons.delete,
                                color: CupertinoColors.destructiveRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  onPressed: () {
                    now.add(DateTimePair(
                      first: DateTime(0, 0, 0, 8, 0),
                      second: DateTime(0, 0, 0, 12, 0),
                      isDeleted: false,
                    ));
                    setState(() {});
                  },
                  child: const Text('添加一个时段'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
