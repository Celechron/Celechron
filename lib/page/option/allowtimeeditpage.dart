import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DateTimePair {
  DateTime first, second;
  bool isDeleted;
  DateTimePair({
    required this.first,
    required this.second,
    this.isDeleted = false,
  });
}

class DateTimePairListTile extends StatefulWidget {
  final DateTimePair val;
  final Function(DateTimePair pair)? onChanged;

  const DateTimePairListTile({
    super.key,
    required this.val,
    this.onChanged,
  });

  @override
  State<DateTimePairListTile> createState() => _DateTimePairListTileState();
}

class _DateTimePairListTileState extends State<DateTimePairListTile> {
  late DateTimePair val;

  @override
  void initState() {
    super.initState();
    print(':: ${widget.val.first}');
    val = DateTimePair(first: widget.val.first, second: widget.val.second);
  }

  String timeToString(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void saveChange() {
    if (widget.onChanged != null) {
      widget.onChanged!(val);
    }
  }

  Future<void> edit() async {
    var resFirst = await showTimePicker(
      context: context,
      helpText: '开始时间',
      initialTime: TimeOfDay.fromDateTime(val.first),
    );
    if (!context.mounted) return;
    if (resFirst == null) return;
    var resSecond = await showTimePicker(
      context: context,
      helpText: '结束时间',
      initialTime: TimeOfDay.fromDateTime(val.second),
    );
    if (resSecond == null) return;
    val.first = DateTime(0, 0, 0, resFirst.hour, resFirst.minute);
    val.second = DateTime(0, 0, 0, resSecond.hour, resSecond.minute);

    saveChange();
  }

  @override
  Widget build(BuildContext context) {
    print('${timeToString(val.first)} - ${timeToString(val.second)}');
    return ListTile(
      title: Text('${timeToString(val.first)} - ${timeToString(val.second)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: edit,
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            onPressed: () {
              val.isDeleted = true;
              saveChange();
            },
            icon: const Icon(Icons.delete),
          ),
        ],
      ),
    );
  }
}

class AllowTimeEditPage extends StatefulWidget {
  final Map<DateTime, DateTime> allowTime;
  const AllowTimeEditPage(this.allowTime, {super.key});

  @override
  State<AllowTimeEditPage> createState() => _AllowTimeEditPageState();
}

class _AllowTimeEditPageState extends State<AllowTimeEditPage> {
  List<DateTimePair> now = [];
  int __got = 0;

  void saveAndExit() {
    for (int i = 0; i < now.length; i++) {
      var x = now[i];

      if (!x.first.isBefore(x.second)) {
        /*Fluttertoast.showToast(
          msg: '开始时间必须早于结束时间',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0,
        );*/
        return;
      }

      for (int j = 0; j < now.length; j++) {
        if (i == j) continue;
        var y = now[j];
        if ((!x.first.isBefore(y.first) && !x.first.isAfter(y.second)) ||
            (!x.second.isBefore(y.first) && !x.second.isAfter(y.second))) {
          /*Fluttertoast.showToast(
            msg: '时间段之间有重合或直接相邻',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16.0,
          );*/
          return;
        }
      }
    }

    FormState().save();
    Map<DateTime, DateTime> res = {};
    for (var x in now) {
      res[x.first] = x.second;
    }
    Navigator.of(context).pop(res);
  }

  void exitWithoutSave() {
    Navigator.of(context).pop(widget.allowTime);
  }

  @override
  Widget build(BuildContext context) {
    if (__got == 0) {
      for (var x in widget.allowTime.keys) {
        now.add(DateTimePair(
          first: x.copyWith(),
          second: widget.allowTime[x]!.copyWith(),
        ));
      }
      now.sort((DateTimePair a, DateTimePair b) {
        if (a.first.compareTo(b.first) != 0) {
          return a.first.compareTo(b.first);
        }
        return a.second.compareTo(b.second);
      });
      __got = 1;
    }

    now.removeWhere((element) => element.isDeleted);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('编辑可用工作时段'),
        leading: IconButton(
          tooltip: '放弃更改',
          icon: const Icon(Icons.close),
          onPressed: exitWithoutSave,
        ),
        actions: [
          IconButton(
            tooltip: '保存',
            onPressed: saveAndExit,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Form(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                  itemCount: now.length + 1,
                  itemBuilder: (context, index) {
                    if (index < now.length) {
                      return Dismissible(
                        key: Key(now.toString()),
                        onDismissed: (direction) {
                          setState(() {
                            now.removeAt(index);
                          });
                        },
                        child: DateTimePairListTile(
                          val: DateTimePair(
                            first: now[index].first,
                            second: now[index].second,
                            isDeleted: now[index].isDeleted,
                          ),
                          onChanged: (DateTimePair updated) {
                            now[index] = DateTimePair(
                              first: updated.first,
                              second: updated.second,
                              isDeleted: updated.isDeleted,
                            );
                            setState(() {});
                          },
                        ),
                      );
                    }
                    return TextButton(
                      onPressed: () {
                        now.add(DateTimePair(
                          first: DateTime(0, 0, 0, 8, 0),
                          second: DateTime(0, 0, 0, 12, 0),
                          isDeleted: false,
                        ));
                        setState(() {});
                      },
                      child: const Text('添加一个时段'),
                    );
                  }),
            ),
          ],
        ),
      ),
    );
  }
}
