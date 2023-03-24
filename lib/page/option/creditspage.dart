import 'package:flutter/material.dart';
import '../../model/user.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart';

class CreditsPage extends StatefulWidget {
  const CreditsPage({super.key});

  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于我们'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          const SizedBox(
            height: 8,
          ),
          Align(
            alignment: Alignment.center,
            child: SvgPicture.asset(
              "assets/logo.svg",
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
