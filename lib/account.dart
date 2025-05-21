import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'modifyaccount.dart';
import 'appbar.dart';
import 'deleteaccount.dart';
import 'UserDataProvider.dart';

class AccountInfoPage extends StatefulWidget {
  final String CSTitle;

  const AccountInfoPage({super.key, required this.CSTitle});

  @override
  State<AccountInfoPage> createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends State<AccountInfoPage> {
  late String CSTitle; // CSTitle 변수 선언

  @override
  void initState() {
    super.initState();
    CSTitle = widget.CSTitle;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: CSTitle), // widget.CSTitle로 접근
      body: Column(
        children: [
          // UserDataProvider의 변경을 수신 대기하는 Consumer 위젯을 사용하여
          // ID와 E메일 텍스트만 업데이트되도록 합니다.
          Consumer<UserDataProvider>(
            builder: (context, userDataProvider, child) {
              final String? id = userDataProvider.loggedInUserId;
              final String? email = userDataProvider.loggedInUserEmail;

              return Text("ID : $id\nE메일 : $email");
            },
          ),
          const Text(
            '회원정보창입니다. 이 자리에 본인의 학습 내역이 들어올 예정입니다.',
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ModifyAccountPage(CSTitle: widget.CSTitle), // ModifyPage로 변경된 이름 사용
                    ),
                  );
                },
                child: const Text('수정'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeleteAccountPage(CSTitle: widget.CSTitle),
                    ),
                  );
                },
                child: const Text('탈퇴'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}