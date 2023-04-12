import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:celechron/model/user.dart';

class LoginForm extends StatelessWidget {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final buttonPressed = false.obs;

  LoginForm({super.key});

  @override
  Widget build(BuildContext context) {

    var brightness = MediaQuery.of(context).platformBrightness;

    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: CupertinoDynamicColor.resolve(CupertinoColors.systemGroupedBackground, context)
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 6,
        right: 6,
      ),
      child: SafeArea(
        top: false,
        child:Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8, top: 16),
            child: Text(
              '统一身份认证登录',
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                SizedBox(height: 48, child: CupertinoTextField(
                  controller: usernameController,
                  keyboardType: TextInputType.number,
                  prefix: Container(padding: const EdgeInsets.only(left: 12), child: Text('学号', style: CupertinoTheme.of(context).textTheme.textStyle)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: brightness == Brightness.light ? CupertinoColors.systemBackground : CupertinoColors.secondarySystemBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                )),
                const SizedBox(height: 16),
                SizedBox(height: 48, child: CupertinoTextField(
                  controller: passwordController,
                  obscureText: true,
                  prefix: Container(padding: const EdgeInsets.only(left: 12), child: Text('密码', style: CupertinoTheme.of(context).textTheme.textStyle),),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: brightness == Brightness.light ? CupertinoColors.systemBackground : CupertinoColors.secondarySystemBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                )),
                const SizedBox(height: 16),
                Obx(() => CupertinoButton(

                  onPressed: () async {
                    buttonPressed.value = true;
                    var user = Get.find<Rx<User>>(tag: 'user');
                    user.update((val) {
                      val!.username = usernameController.value.text;
                      val.password = passwordController.value.text;
                      val.login().then((value) {
                        if (value) {
                          user.refresh();
                          buttonPressed.value = false;
                          Navigator.of(context).pop();
                        }
                      }).timeout(const Duration(seconds: 10)).catchError((error) {
                        buttonPressed.value = false;
                        showCupertinoDialog(context: context, builder: (context) {
                          return CupertinoAlertDialog(
                            title: const Text('登录失败'),
                            content: Text(error.toString()),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('确定'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              )
                            ],
                          );
                        });
                      });
                    });
                  },
                  color: buttonPressed.value ? CupertinoColors.inactiveGray : CupertinoColors.activeBlue,
                  child: SizedBox(height: 24, child: buttonPressed.value ? const CupertinoActivityIndicator() : const Text('登录', style: TextStyle(color: CupertinoColors.white)),
                  ))),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
