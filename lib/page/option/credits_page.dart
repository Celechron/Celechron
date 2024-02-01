import 'package:flutter/cupertino.dart';
import 'package:celechron/design/persistent_headers.dart';

class CreditsPage extends StatelessWidget {

  final String version;
  const CreditsPage({required this.version, super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const CelechronSliverTextHeader(subtitle: '关于'),
            SliverToBoxAdapter(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                const SizedBox(
                  height: 64,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      "assets/logo.png",
                      height: 108,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Column(
                      children: [
                        const Text(
                          'Celechron',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                          ),
                        ),
                        Text(
                          '$version 版本',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(
                  height: 24,
                ),
                const Text(
                  '制作人员',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(
                  height: 24,
                ),
                const Text(
                  '🎨设计',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 32), child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  verticalDirection: VerticalDirection.down,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'nosig',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '空之探险队的 Kate',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )),
                const SizedBox(
                  height: 24,
                ),
                const Text(
                  '🧑‍💻开发',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 32), child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  verticalDirection: VerticalDirection.down,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'nosig',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'iotang',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )),
              ]),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [Text(
                  '本程序采用 GPLv3 协议开源',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context)
                  ),
                ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    '浙ICP备2024061973号-2A',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context),
                    ),
                  ),],
              )
            )
          ],
        ),
      ),
    );
  }
}
