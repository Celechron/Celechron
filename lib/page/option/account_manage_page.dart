import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'package:celechron/design/persistent_headers.dart';
import 'login_page.dart';
import 'option_controller.dart';

class AccountManagePage extends StatelessWidget {
  final _optionController = Get.find<OptionController>(tag: 'optionController');

  AccountManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    var headerFooterTextStyle = TextStyle(
        color: CupertinoDynamicColor.resolve(
            CupertinoColors.secondaryLabel, context),
        fontSize: 14);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const CelechronSliverTextHeader(subtitle: '账号管理'),
            SliverToBoxAdapter(
              child: Obx(() {
                var accounts = _optionController.accounts;
                var currentUsername = _optionController.scholar.value.username;
                var isLogan = _optionController.scholar.value.isLogan;
                return Column(children: [
                  if (accounts.isNotEmpty)
                    CupertinoListSection.insetGrouped(
                      additionalDividerMargin: 2,
                      header: Container(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text('已存账号', style: headerFooterTextStyle)),
                      footer: accounts.length > 1
                          ? Container(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text('点击账号即可切换，左滑可删除非当前账号。',
                                  style: headerFooterTextStyle))
                          : null,
                      children: [
                        for (var account in accounts)
                          _buildAccountRow(context, account,
                              account['username'] == currentUsername),
                      ],
                    ),
                  CupertinoListSection.insetGrouped(
                    additionalDividerMargin: 2,
                    children: [
                      CupertinoListTile(
                        title: const Text('添加新账号',
                            style:
                                TextStyle(color: CupertinoColors.activeBlue)),
                        onTap: () {
                          showCupertinoModalPopup(
                              context: context,
                              builder: (BuildContext context) {
                                return LoginForm();
                              });
                        },
                      ),
                      if (isLogan)
                        CupertinoListTile(
                          title: const Text('退出当前账号',
                              style: TextStyle(
                                  color: CupertinoColors.destructiveRed)),
                          onTap: () => _confirmSignOut(context),
                        ),
                    ],
                  ),
                ]);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountRow(
      BuildContext context, Map<String, String> account, bool isCurrent) {
    var username = account['username'] ?? '';
    var tile = CupertinoListTile(
      title: Text(username),
      trailing: isCurrent
          ? const Icon(CupertinoIcons.check_mark,
              color: CupertinoColors.activeBlue, size: 20)
          : null,
      onTap: isCurrent
          ? null
          : () {
              if (_optionController.accountBusy.value) return;
              _optionController.switchAccount(username);
            },
    );
    if (isCurrent) return tile;

    return Dismissible(
      key: Key('account_$username'),
      direction: DismissDirection.endToStart,
      movementDuration: const Duration(milliseconds: 300),
      resizeDuration: const Duration(milliseconds: 300),
      dismissThresholds: const {DismissDirection.endToStart: 0.25},
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: CupertinoColors.systemRed,
        child: const Icon(
          CupertinoIcons.delete,
          color: CupertinoColors.white,
          size: 20,
        ),
      ),
      confirmDismiss: (direction) async {
        if (_optionController.accountBusy.value) return false;
        return await showCupertinoDialog<bool>(
              context: context,
              builder: (BuildContext dialogContext) {
                return CupertinoAlertDialog(
                  title: const Text('删除账号'),
                  content: Text('将从本机删除账号 $username 及其缓存数据（包括任务与规划）。'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('取消'),
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      child: const Text('删除'),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ],
                );
              },
            ) ??
            false;
      },
      onDismissed: (direction) {
        _optionController.deleteAccount(username);
      },
      child: tile,
    );
  }

  void _confirmSignOut(BuildContext context) {
    var hasOthers = _optionController.accounts.length > 1;
    showCupertinoDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return CupertinoAlertDialog(
            title: const Text('退出当前账号'),
            content: Text(hasOthers
                ? '将删除该账号在本机的全部数据（包括任务与规划），并切换到下一个账号。'
                : '将删除该账号在本机的全部数据（包括任务与规划）。'),
            actions: [
              CupertinoDialogAction(
                child: const Text('取消'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('退出'),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _optionController.signOutCurrent();
                },
              ),
            ],
          );
        });
  }
}
