import 'package:celechron/utils/platform_features.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher_string.dart';

import 'package:celechron/utils/utils.dart';
import 'package:celechron/model/option.dart';
import 'package:celechron/design/cupertino_async_switch.dart';

import 'allow_time_edit_page.dart';
import 'course_id_mapping_edit_page.dart';
import 'credits_page.dart';
import 'package:get/get.dart';
import 'custom_license_page.dart';
import 'login_page.dart';
import 'option_controller.dart';

const Color _kHeaderFooterColor = CupertinoDynamicColor(
  color: Color.fromRGBO(108, 108, 108, 1.0),
  darkColor: Color.fromRGBO(142, 142, 146, 1.0),
  highContrastColor: Color.fromRGBO(74, 74, 77, 1.0),
  darkHighContrastColor: Color.fromRGBO(176, 176, 183, 1.0),
  elevatedColor: Color.fromRGBO(108, 108, 108, 1.0),
  darkElevatedColor: Color.fromRGBO(142, 142, 146, 1.0),
  highContrastElevatedColor: Color.fromRGBO(108, 108, 108, 1.0),
  darkHighContrastElevatedColor: Color.fromRGBO(142, 142, 146, 1.0),
);

class OptionPage extends StatelessWidget {
  final _optionController =
      Get.put(OptionController(), tag: 'optionController');

  OptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    var trailingTextStyle = TextStyle(
        color: CupertinoDynamicColor.resolve(
            CupertinoColors.secondaryLabel, context),
        fontSize: 16);

    var headerFooterTextStyle = CupertinoTheme.of(context)
        .textTheme
        .textStyle
        .merge(TextStyle(
            fontSize: 13.0,
            color:
                CupertinoDynamicColor.resolve(_kHeaderFooterColor, context)));

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
            // 教务
            Obx(() => SliverToBoxAdapter(
                  child: CupertinoListSection.insetGrouped(
                    margin: _defaultMargin,
                    additionalDividerMargin: 2,
                    header: Container(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text('教务', style: headerFooterTextStyle)),
                    footer: _optionController.pushOnGradeChange &&
                            _optionController.scholar.value.isLogan
                        ? Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Text(
                                'Celechron 将不定期自动运行以刷新成绩。请开启通知权限，且不要将 Celechron 从后台中移除。',
                                style: headerFooterTextStyle))
                        : null,
                    children: <CupertinoListTile>[
                      if (_optionController.scholar.value.isLogan) ...{
                        CupertinoListTile(
                            title: Text(
                                '已登录: ${_optionController.scholar.value.username}'),
                            trailing: BackChervonRow(
                                child: Text('退出',
                                    style: TextStyle(
                                        color: CupertinoDynamicColor.resolve(
                                            CupertinoColors.secondaryLabel,
                                            context),
                                        fontSize: 16))),
                            onTap: () async {
                              await showCupertinoDialog(
                                  context: context,
                                  builder: (BuildContext dialogContext) {
                                    return CupertinoAlertDialog(
                                      title: const Text('退出登录'),
                                      content:
                                          const Text('确定要退出当前账号吗？'),
                                      actions: [
                                        CupertinoDialogAction(
                                          child: const Text('取消'),
                                          onPressed: () {
                                            Navigator.of(dialogContext).pop();
                                          },
                                        ),
                                        CupertinoDialogAction(
                                          isDestructiveAction: true,
                                          child: const Text('退出'),
                                          onPressed: () async {
                                            Navigator.of(dialogContext).pop();
                                            await _optionController.logout();
                                          },
                                        ),
                                      ],
                                    );
                                  });
                            }),
                        CupertinoListTile(
                          title: const Text('重修绩点计算'),
                          trailing: CupertinoSlidingSegmentedControl(
                            children: {
                              GpaStrategy.first: Text('取首次',
                                  style: CupertinoTheme.of(context)
                                      .textTheme
                                      .textStyle
                                      .copyWith(fontSize: 16)),
                              GpaStrategy.best: Text('取最高',
                                  style: CupertinoTheme.of(context)
                                      .textTheme
                                      .textStyle
                                      .copyWith(fontSize: 16)),
                            },
                            groupValue: _optionController.gpaStrategy,
                            onValueChanged: (value) {
                              _optionController.gpaStrategy = value!;
                            },
                          ),
                        ),
                        CupertinoListTile(
                            title: const Text('隐藏绩点'),
                            trailing: Obx(() => CupertinoSwitch(
                                  value: _optionController.hideHomeGpa,
                                  onChanged: (value) async {
                                    _optionController.hideHomeGpa = value;
                                  },
                                ))),
                        CupertinoListTile(
                          title: const Text('自定义课程代码映射'),
                          trailing: const BackChervonRow(),
                          onTap: () async {
                            Navigator.of(context, rootNavigator: true).push(
                                CupertinoPageRoute(
                                    builder: (context) =>
                                        CourseIdMappingEditPage()));
                          },
                        ),
                        CupertinoListTile(
                            title: const Text('推送成绩变动'),
                            trailing: CupertinoSwitch(
                              value: _optionController.pushOnGradeChange,
                              onChanged: PlatformFeatures.hasBackgroundRefresh
                                  ? (value) async {
                                      _optionController.pushOnGradeChange =
                                          value;
                                    }
                                  : null,
                            )),
                      } else ...{
                        CupertinoListTile(
                          title: const Text('点击登录',
                              style:
                                  TextStyle(color: CupertinoColors.activeBlue)),
                          trailing: const BackChervonRow(
                            child: Text(''),
                          ),
                          onTap: () async {
                            // Pop up a login widget from the bottom of the screen
                            showCupertinoModalPopup(
                                context: context,
                                builder: (BuildContext context) {
                                  return LoginForm();
                                });
                          },
                        ),
                      },
                    ],
                  ),
                )),
            // 时间规划
            SliverToBoxAdapter(
                child: CupertinoListSection.insetGrouped(
                    additionalDividerMargin: 2,
                    margin: _defaultMargin,
                    header: Container(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text('时间规划', style: headerFooterTextStyle)),
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
                                        minuteInterval: 5,
                                        initialTimerDuration: newWorkTime,
                                        onTimerDurationChanged: (value) {
                                          if (value >=
                                              const Duration(minutes: 5)) {
                                            newWorkTime = value;
                                          } else {
                                            newWorkTime =
                                                const Duration(minutes: 5);
                                          }
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
            // 日程
            Obx(() => SliverToBoxAdapter(
                    child: CupertinoListSection.insetGrouped(
                        additionalDividerMargin: 2,
                        margin: _defaultMargin,
                        header: Container(
                            padding: const EdgeInsets.only(left: 16),
                            child: Text('日程', style: headerFooterTextStyle)),
                        children: [
                      CupertinoListTile(
                        title: const Text('同步到系统日历'),
                        trailing: CupertinoAsyncSwitch(
                          value: _optionController.calendarSyncEnabled &&
                              _optionController.hasCalendarPermission,
                          onChanged: (value) async {
                            await _optionController.toggleCalendarSync(
                                context, value);
                          },
                        ),
                      ),
                      CupertinoListTile(
                        title: Text(
                          '课表同步选项',
                          style: TextStyle(
                            color: _optionController.calendarSyncEnabled
                                ? null // 使用默认颜色
                                : CupertinoDynamicColor.resolve(
                                    CupertinoColors.quaternaryLabel, context),
                          ),
                        ),
                        trailing: BackChervonRow(
                            child: Text('选择学期',
                                style: TextStyle(
                                    color: CupertinoDynamicColor.resolve(
                                        CupertinoColors.secondaryLabel,
                                        context),
                                    fontSize: 16))),
                        onTap: _optionController.calendarSyncEnabled
                            ? () {
                                _optionController
                                    .showCalendarSyncDialog(context);
                              }
                            : null, // 禁用点击
                      ),
                      CupertinoListTile(
                        title: const Text('导出为iCal文件'),
                        trailing: const BackChervonRow(),
                        onTap: () =>
                            _optionController.showExportDialog(context),
                      ),
                    ]))),
            // 工具
            SliverToBoxAdapter(
                child: CupertinoListSection.insetGrouped(
                    additionalDividerMargin: 2,
                    margin: _defaultMargin,
                    header: Container(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text('工具', style: headerFooterTextStyle)),
                    children: <Widget>[
                  CupertinoListTile(
                    title: const Text('暗色模式'),
                    trailing: BackChervonRow(
                        child: Obx(() => Text(
                              _optionController.brightnessMode ==
                                      BrightnessMode.system
                                  ? "跟随系统设置"
                                  : _optionController.brightnessMode ==
                                          BrightnessMode.light
                                      ? "亮色模式"
                                      : "暗色模式",
                              style: trailingTextStyle,
                            ))),
                    onTap: () => _showBrightnessPicker(context),
                  ),
                  CupertinoListTile(
                    title: const Text('付款码'),
                    trailing: const BackChervonRow(),
                    onTap: () async {
                      Navigator.of(context, rootNavigator: true)
                          .pushNamed('/ecardpaypage');
                    },
                  ),
                ])),
            // 关于
            SliverToBoxAdapter(
              child: CupertinoListSection.insetGrouped(
                  additionalDividerMargin: 2,
                  margin: _defaultMargin,
                  header: Container(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('关于', style: headerFooterTextStyle)),
                  children: <CupertinoListTile>[
                    CupertinoListTile(
                      title: const Text('关于 Celechron'),
                      trailing: BackChervonRow(
                        child: Text(_optionController.celechronVersion,
                            style: trailingTextStyle),
                      ),
                      onTap: () async {
                        Navigator.of(context, rootNavigator: true).push(
                            CupertinoPageRoute(
                                builder: (context) => CreditsPage(
                                    version:
                                        _optionController.celechronVersion)));
                      },
                    ),
                    CupertinoListTile(
                      title: const Text('服务条款'),
                      trailing: const BackChervonRow(),
                      onTap: () async {
                        Navigator.of(context, rootNavigator: true).push(
                            CupertinoPageRoute(
                                builder: (context) =>
                                    const CustomLicensePage()));
                      },
                    ),
                    CupertinoListTile(
                      title: const Text('前往项目网站'),
                      trailing: BackChervonRow(
                        child: Obx(() {
                          if (_optionController.hasNewVersion) {
                            return Row(children: [
                              Container(
                                margin: const EdgeInsets.only(right: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: CupertinoColors.systemRed,
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              Text('有新版本可用', style: trailingTextStyle)
                            ]);
                          } else {
                            return const Text('');
                          }
                        }),
                      ),
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

  void _showBrightnessPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          actions: <Widget>[
            CupertinoActionSheetAction(
              onPressed: () {
                _optionController.brightnessMode = BrightnessMode.system;
                Navigator.pop(context);
              },
              child: const Text('跟随系统设置'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                _optionController.brightnessMode = BrightnessMode.light;
                Navigator.pop(context);
              },
              child: const Text('亮色模式'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                _optionController.brightnessMode = BrightnessMode.dark;
                Navigator.pop(context);
              },
              child: const Text('暗色模式'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  static const _defaultMargin =
      EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 10.0);
}

class BackChervonRow extends StatelessWidget {
  final Widget? child;

  const BackChervonRow({super.key, this.child});

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
