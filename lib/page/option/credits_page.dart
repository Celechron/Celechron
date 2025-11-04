import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:celechron/design/persistent_headers.dart';
import 'package:celechron/http/github_service.dart';

class CreditsPage extends StatefulWidget {
  final String version;
  const CreditsPage({required this.version, super.key});

  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> {
  List<String> _contributors = [];
  bool _isLoading = true;
  final _githubService = GitHubService();
  final _httpClient = HttpClient();

  @override
  void initState() {
    super.initState();
    _loadContributors();
  }

  Future<void> _loadContributors() async {
    try {
      var result = await _githubService.getContributors(_httpClient);
      if (result.item1 == null) {
        setState(() {
          _contributors = result.item2;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  Widget _buildContributorsList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: CupertinoActivityIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: _buildContributorRows(),
      ),
    );
  }

  List<Widget> _buildContributorRows() {
    List<Widget> rows = [];
    for (int i = 0; i < _contributors.length; i += 2) {
      List<Widget> children = [];
      
      // 第一个contributor
      children.add(
        Expanded(
          child: Text(
            _contributors[i],
            textAlign: TextAlign.center,
          ),
        ),
      );

      // 如果有第二个contributor，添加它
      if (i + 1 < _contributors.length) {
        children.add(
          Expanded(
            child: Text(
              _contributors[i + 1],
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          verticalDirection: VerticalDirection.down,
          children: children,
        ),
      );

      // 如果不是最后一行，添加间距
      if (i + 2 < _contributors.length) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return rows;
  }

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
                            '${widget.version} 版本',
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
                    height: 16,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
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
                    ),
                  ),
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
                    height: 16,
                  ),
                  _buildContributorsList(),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '本程序采用 GPLv3 协议开源',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: CupertinoDynamicColor.resolve(
                            CupertinoColors.secondaryLabel, context)),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    '浙ICP备2024061973号-2A',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoDynamicColor.resolve(
                          CupertinoColors.secondaryLabel, context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
