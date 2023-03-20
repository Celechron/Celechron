import 'package:celechron/utils/utils.dart';
import 'package:flutter/material.dart';
import '../../model/period.dart';
import '../../model/flow.dart';

class FlowPage extends StatefulWidget {
  const FlowPage({super.key});

  @override
  State<FlowPage> createState() => _FlowPageState();
}

class _FlowPageState extends State<FlowPage> {
  Widget createCard(context, Period period) {
    return GestureDetector(
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        period.summary,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    toStringHumanReadable(period.startTime),
                    style: const TextStyle(),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    toStringHumanReadable(period.endTime),
                    style: const TextStyle(),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    period.location,
                    style: const TextStyle(),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    period.uid,
                    style: const TextStyle(),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    '来自 ${period.fromUid}',
                    style: const TextStyle(),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    updateFlowList(DateTime.now()
        .copyWith(second: 0, millisecond: 0, microsecond: 0)
        .add(const Duration(minutes: 2)));
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '接下来',
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              children: flowList.map((e) => createCard(context, e)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
