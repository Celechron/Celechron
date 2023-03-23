import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'login_page.dart';
import 'scholar_controller.dart';

class ScholarPage extends StatelessWidget {
  ScholarPage({super.key});

  final _scholarController = Get.put(ScholarController());

  // On the top there is a user info card, which contains the user's student id. If the user is not logged in, it will be a login button. On clicking the login button, it will navigate to the login page.
  Widget _buildUserInfoCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 100,
          width: double.infinity,
          color: Colors.white,
          child: Center(
            child: Obx(() => Text(
                '${_scholarController.user.value.username}\n${_scholarController.user.value.gpa[0].toStringAsFixed(2)}')),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            _scholarController.user.update((val) {
              val!.logout();
            });
          },
          child: const Text('退出登录'),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
        onTap: () => Get.to(() => const LoginPage()),
        child: Container(
          height: 50,
          width: double.infinity,
          color: Colors.blue,
          child: const Center(
            child: Text('登录'),
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学业数据'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() => _scholarController.user.value.isLogin
              ? _buildUserInfoCard()
              : _buildLoginButton()),
          Obx(() => Text(_scholarController.user.value.lastUpdateTime.toIso8601String())),
        ],
      ),
    );
  }
}
