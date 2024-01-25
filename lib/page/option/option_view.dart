import 'package:celechron/page/option/custom_license_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:celechron/utils/utils.dart';
import 'package:url_launcher/url_launcher_string.dart';
import './allow_time_edit_page.dart';
import 'credits_page.dart';
import 'package:get/get.dart';

import 'login_page.dart';
import 'option_controller.dart';

class OptionPage extends StatelessWidget {
  final _optionController = Get.put(OptionController());

  OptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    var trailingTextStyle = TextStyle(
        color: CupertinoDynamicColor.resolve(
            CupertinoColors.secondaryLabel, context),
        fontSize: 16);

    return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        child: SafeArea(
            child: CustomScrollView(
          slivers: [
            const CupertinoSliverNavigationBar(
              largeTitle: Text('设置'),
              backgroundColor: CupertinoColors.systemGroupedBackground,
              border: null,
            ),
            SliverToBoxAdapter(
              child: CupertinoListSection.insetGrouped(
                margin: _defaultMargin,
                additionalDividerMargin: 2,
                header: Container(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('教务',
                        style: TextStyle(
                            color: CupertinoDynamicColor.resolve(
                                CupertinoColors.secondaryLabel, context),
                            fontSize: 14))),
                children: <CupertinoListTile>[
                  CupertinoListTile(
                    title: Obx(() {
                      if (_optionController.user.value.isLogin) {
                        return Text(
                            '已登录: ${_optionController.user.value.username}');
                      } else {
                        return const Text('点击登录',
                            style:
                                TextStyle(color: CupertinoColors.activeBlue));
                      }
                    }),
                    trailing: BackChervonRow(child: Obx(() {
                      if (_optionController.user.value.isLogin) {
                        return Text('退出',
                            style: TextStyle(
                                color: CupertinoDynamicColor.resolve(
                                    CupertinoColors.secondaryLabel, context),
                                fontSize: 16));
                      } else {
                        return const Text('');
                      }
                    })),
                    onTap: () {
                      if (_optionController.user.value.isLogin) {
                        _optionController.logout();
                      } else {
                        // Pop up a login widget from the bottom of the screen
                        showCupertinoModalPopup(
                            context: context,
                            builder: (BuildContext context) {
                              return LoginForm();
                            });
                      }
                    },
                  ),
                  CupertinoListTile(
                    title: const Text('重修绩点计算'),
                    trailing: Obx(() => CupertinoSlidingSegmentedControl(
                          children: {
                            0: Text('取首次',
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .copyWith(fontSize: 16)),
                            1: Text('取最高',
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .copyWith(fontSize: 16)),
                          },
                          groupValue: _optionController.gpaStrategy,
                          onValueChanged: (value) {
                            _optionController.gpaStrategy = value!;
                          },
                        )),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
                child: CupertinoListSection.insetGrouped(
                    additionalDividerMargin: 2,
                    margin: _defaultMargin,
                    header: Container(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text('时间规划',
                            style: TextStyle(
                                color: CupertinoDynamicColor.resolve(
                                    CupertinoColors.secondaryLabel, context),
                                fontSize: 14))),
                    children: <CupertinoListTile>[
                  CupertinoListTile(
                    title: const Text('工作段时间长度'),
                    trailing: BackChervonRow(
                        child: Obx(() => Text(
                            durationToString(_optionController.workTime),
                            style: TextStyle(
                                color: CupertinoDynamicColor.resolve(
                                    CupertinoColors.secondaryLabel, context),
                                fontSize: 16)))),
                    onTap: () async {
                      Duration newWorkTime = _optionController.workTime;
                      await showCupertinoDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return CupertinoAlertDialog(
                              title: const Text(
                                '工作段时间长度',
                              ),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: 200,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: CupertinoTimerPicker(
                                        mode: CupertinoTimerPickerMode.hm,
                                        initialTimerDuration: newWorkTime,
                                        onTimerDurationChanged: (value) {
                                          newWorkTime = value;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
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
                          });
                      _optionController.workTime = newWorkTime;
                    },
                  ),
                  CupertinoListTile(
                    title: const Text('休息段时间长度'),
                    trailing: BackChervonRow(
                        child: Obx(() => Text(
                            durationToString(_optionController.restTime),
                            style: trailingTextStyle))),
                    onTap: () async {
                      Duration newRestTime = _optionController.restTime;
                      await showCupertinoDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return CupertinoAlertDialog(
                              title: const Text(
                                '休息段时间长度',
                              ),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: 200,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: CupertinoTimerPicker(
                                        mode: CupertinoTimerPickerMode.hm,
                                        initialTimerDuration: newRestTime,
                                        onTimerDurationChanged: (value) {
                                          newRestTime = value;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
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
                          });
                      _optionController.restTime = newRestTime;
                    },
                  ),
                  CupertinoListTile(
                    title: const Text('可用的工作时段'),
                    trailing: BackChervonRow(
                        child: Obx(() => Text(
                            '${_optionController.allowTimeLength} 个时段',
                            style: trailingTextStyle))),
                    onTap: () async {
                      await Navigator.of(context, rootNavigator: true)
                          .push(CupertinoPageRoute(
                        builder: (context) => const AllowTimeEditPage(),
                      ));
                    },
                  ),
                ])),
            //关于
            SliverToBoxAdapter(
              child: CupertinoListSection.insetGrouped(
                  additionalDividerMargin: 2,
                  margin: _defaultMargin,
                  header: Container(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('关于',
                          style: TextStyle(
                              color: CupertinoDynamicColor.resolve(
                                  CupertinoColors.secondaryLabel, context),
                              fontSize: 14))),
                  children: <CupertinoListTile>[
                    CupertinoListTile(
                      title: const Text('关于 Celechron'),
                      trailing: BackChervonRow(
                        child: Text(celechronVersion, style: trailingTextStyle),
                      ),
                      onTap: () async {
                        Navigator.of(context, rootNavigator: true).push(
                            CupertinoPageRoute(
                                builder: (context) => const CreditsPage()));
                      },
                    ),
                    CupertinoListTile(
                      title: const Text('服务条款'),
                      onTap: () async {
                        Navigator.of(context, rootNavigator: true).push(
                            CupertinoPageRoute(
                                builder: (context) =>
                                    const CustomLicensePage()));
                      },
                    ),
                    CupertinoListTile(
                      title: const Text('前往项目网站'),
                      onTap: () async {
                        await launchUrlString(
                          'https://celechron.top',
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ]),
            )
          ],
        )));
  }

  static const _defaultMargin =
      EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 10.0);
}

class BackChervonRow extends StatelessWidget {
  final Widget? child;

  const BackChervonRow({Key? key, this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (child != null) child!,
      const SizedBox(width: 4),
      Icon(Icons.arrow_forward_ios,
          color: CupertinoDynamicColor.resolve(
              CupertinoColors.tertiaryLabel, context),
          size: 16)
    ]);
  }
}
