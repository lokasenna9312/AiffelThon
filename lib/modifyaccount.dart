import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'appbar.dart';
import 'ui_utils.dart';
import 'UserDataProvider.dart';
import 'deleteaccount.dart';
import 'main.dart';

class ModifyAccountPage extends StatefulWidget {
  const ModifyAccountPage({super.key, required this.CSTitle});

  final String CSTitle;

  @override
  State<ModifyAccountPage> createState() => _ModifyAccountPageState();
}

class _ModifyAccountPageState extends State<ModifyAccountPage> {
  late UserDataProvider userDataProvider;
  late UserDataProviderUtility utility;
  final _newID = TextEditingController();
  final _newPW = TextEditingController();
  final _newPW2 = TextEditingController();
  final _newEmail = TextEditingController();

  late String CSTitle; // CSTitle 변수 선언

  @override
  void initState() {
    super.initState();
    CSTitle = widget.CSTitle;
    userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    utility = UserDataProviderUtility();
  }

  void _changeEmail() async {
    final String newID = _newID.text.trim();
    final String newPW = _newPW.text.trim();
    final String newPW2 = _newPW2.text.trim();
    final String newEmail = _newEmail.text.trim();
    
    final ValidationResult result = await utility.ValidateAndChangeEmail( // 반환 타입이 ValidationResult
      newID: newID,
      newPW: newPW,
      newPW2: newPW2,
      newEmail: newEmail,
      userDataProvider: userDataProvider,
    );

    if (!result.isSuccess) {
      showSnackBarMessage(context, result.message);
      return;
    }

    userDataProvider.changeEmail(newID, newEmail, newPW);
    showSnackBarMessage(context, 'E메일 주소가 변경되었습니다.\n바뀐 주소 : $newEmail');

    _newID.clear();
    _newPW.clear();
    _newPW2.clear();
    _newEmail.clear();
  }

  // _changePW() 함수는 register.dart 파일에도 똑같이 정의되어 있습니다.
  // 이 함수를 수정하시려면 register.dart 파일의 함수도 똑같이 수정해주세요.
  void _changePW() async {
    final String newID = _newID.text.trim();
    final String newPW = _newPW.text.trim();
    final String newPW2 = _newPW2.text.trim();
    final String newEmail = _newEmail.text.trim();

    final ValidationResult result = await utility.ValidateAndChangePW(
      newID: newID,
      newPW: newPW,
      newPW2: newPW2,
      newEmail: newEmail,
      userDataProvider: userDataProvider,
    );

    if (!result.isSuccess) {
      showSnackBarMessage(context, result.message);
      return;
    }

    final String hashedPassword = result.message;

    userDataProvider.changePW(newID, newEmail, hashedPassword);
    showSnackBarMessage(context, '비밀번호가 성공적으로 변경되었습니다.');

    // 비밀번호 변경 후에는 기존 세션을 무효화하고 로그아웃 처리
    userDataProvider.logoutUser(); // UserDataProvider의 logoutUser 메소드 호출

    // 로그인 페이지 또는 앱의 초기 화면으로 이동
    Navigator.pushAndRemoveUntil( // 현재 스택의 모든 위젯을 제거하고 새 위젯으로 대체
      context,
      MaterialPageRoute(builder: (context) => CSHomePage(CSTitle: CSTitle)), // 가정된 로그인 페이지
      (Route<dynamic> route) => false, // 모든 이전 라우트 제거
    );

    _newID.clear();
    _newPW.clear();
    _newPW2.clear();
    _newEmail.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: CSTitle),
      body: Column(
        children: [
          TextField(
            controller: _newID,
            decoration: const InputDecoration(labelText: 'ID'),
          ),
          TextField(
            controller: _newPW,
            obscureText: true,
            decoration: const InputDecoration(labelText: '비밀번호'),
          ),
          TextField(
            controller: _newPW2,
            obscureText: true,
            decoration: const InputDecoration(labelText: '비밀번호 확인'),
          ),
          TextField(
            controller: _newEmail,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround, // 버튼 사이에 공간을 줌
            children: [
              ElevatedButton(
                onPressed: () => _changeEmail(),
                child: Text('E메일 주소 변경'),
              ),
              ElevatedButton(
                onPressed: () => _changePW(),
                child: Text('비밀번호 변경'),
              ),
            ]
          ),
          ElevatedButton(
            onPressed: () {
              // WithdrawPage로 이동하면서 title 값을 전달
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeleteAccountPage(CSTitle: CSTitle),
                ),
              );
            },
            child: Text('회원 탈퇴'),
          ),
        ],
      ),
    );
  }
}