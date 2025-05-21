import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'UserDataProvider.dart';
import 'main.dart';
import 'account.dart';


class CSAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CSAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {

    final userDataProvider = Provider.of<UserDataProvider>(context);
    final bool isLoggedIn = userDataProvider.isLoggedIn;

    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Text(title),
      actions: <Widget>[
        if (isLoggedIn)
          Row(
            children: [
              ElevatedButton(
                child: Text('로그아웃'),
                onPressed: () {
                  Provider
                      .of<UserDataProvider>(context, listen: false)
                      .logoutUser();
                  // 로그아웃 후 필요한 화면 전환 (예: 로그인 페이지로 이동)은 해당 위젯 또는 상위에서 처리
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그아웃 되었습니다.')),
                  );
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CSHomePage(CSTitle: title),
                    ),
                    (Route<dynamic> route) => false, // 모든 이전 라우트 제거
                  );
                }
              ),
              ElevatedButton(
                child: Text('회원정보'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccountInfoPage(CSTitle: title),
                    ),
                  );
                }
              ),
            ]
          )
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}