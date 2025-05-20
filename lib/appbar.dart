import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'register.dart';
import 'main.dart';


class CSAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CSAppBar({super.key, required this.title});

  // 로그인, 로그아웃 기능은 register.dart 파일에서 다룹니다.
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Text(title),
      actions: <Widget>[
        ElevatedButton(
          child: Text('로그아웃'),
          onPressed: () {
            Provider.of<UserDataProvider>(context, listen: false).logoutUser();
            // 로그아웃 후 필요한 화면 전환 (예: 로그인 페이지로 이동)은 해당 위젯 또는 상위에서 처리
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('로그아웃 되었습니다.')),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CSHomePage(CSTitle: title),
              ),
            );
          }
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}