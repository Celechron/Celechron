import 'package:flutter/material.dart';
import '../utils/utils.dart';
import 'dart:io';
import '../data/deadline.dart';

class DeadlineEditPage extends StatefulWidget {
  Deadline deadline;
  DeadlineEditPage(this.deadline);

  @override
  State<DeadlineEditPage> createState() => _DeadlineEditPageState();
}

class _DeadlineEditPageState extends State<DeadlineEditPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('编辑任务'),
        actions: [ButtonBar()],
      ),
      body: Placeholder(),
    );
  }
}
