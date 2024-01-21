import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('关于'),
        border: null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          const SizedBox(
            height: 72,
          ),
          Align(
            alignment: Alignment.center,
            child: Image.asset(
              "assets/logo.png",
              height: 160,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          const Text(
            'Celechron',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          const Text(
            '制作人员',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          const Text(
            '设计',
            style: TextStyle(
              fontSize: 18,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          const Text(
            '空之探险队的 Kate',
          ),
          const SizedBox(
            height: 16,
          ),
          const Text(
            '开发者',
            style: TextStyle(
              fontSize: 18,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: 10.0,
            mainAxisSpacing: 10.0,
            childAspectRatio: 8,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
            ),
            children: const [
              Text(
                'nosig',
                textAlign: TextAlign.center,
              ),
              Text(
                'iotang',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(
            height: 16,
          ),
          const Expanded(
            child: Text(
              '本程序采用 GPLv3 协议开源',
              style: TextStyle(
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
