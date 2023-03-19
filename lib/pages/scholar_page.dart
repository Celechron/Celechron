import 'package:flutter/material.dart';

import '../data/user.dart';
import 'login_page.dart';

class ScholarPage extends StatefulWidget {
  const ScholarPage({super.key});

  @override
  State<ScholarPage> createState() => _ScholarPageState();
}

class _ScholarPageState extends State<ScholarPage> {
  // On the top there is a user info card, which contains the user's student id. If the user is not logged in, it will be a login button. On clicking the login button, it will navigate to the login page.
  Widget _buildUserInfoCard() {
    var user = User();
    if (user.isLogin) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 100,
            width: double.infinity,
            color: Colors.white,
            child: Center(
              child:
                  Text('${user.username}\n${user.gpa[0].toStringAsFixed(2)}'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              user.logout();
              setState(() {});
            },
            child: const Text('退出登录'),
          ),
        ],
      );
    }
    return GestureDetector(
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) => const LoginPage(),
              ),
            ).then((value) => setState(() {})),
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
        title: const Text('Scholar'),
      ),
      body: Column(
        children: [
          _buildUserInfoCard(),
        ],
      ),
    );
  }
}
