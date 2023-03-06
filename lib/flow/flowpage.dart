
import 'package:celechron/utils/utils.dart';
import 'package:flutter/material.dart';

class FlowPage extends StatefulWidget {
  @override
  State<FlowPage> createState() => _FlowPageState();
}

class _FlowPageState extends State<FlowPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '接下来',
        ),
      ),
      body: ListView(
        children: [],
      ),
    );
  }
}
