import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'appbar.dart';
import 'ui_utils.dart';
import 'UserDataProvider.dart';
import 'main.dart';

class ChangePWPage extends StatefulWidget {
  const ChangePWPage({super.key, required this.title});

  final String title;

  @override
  State<ChangePWPage> createState() => _ChangePWPageState();
}

class _ChangePWPageState extends State<ChangePWPage> {
  late UserDataProvider userDataProvider;
  late UserDataProviderUtility utility;
  final _newID = TextEditingController();
  final _currentPW = TextEditingController();
  final _newPW = TextEditingController();
  final _newPW2 = TextEditingController();
  

  @override
  void initState() {
    super.initState();
    userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    utility = UserDataProviderUtility();
  }

  void _changePW() async {
    final String newID = _newID.text.trim();
    final String currentPW = _currentPW.text.trim();
    final String newPW = _newPW.text.trim();
    final String newPW2 = _newPW2.text.trim();

    final ValidationResult result = await utility.validateAndChangePW(
      id: newID,
      currentPW: currentPW,
      newPW: newPW,
      newPW2: newPW2,
      userDataProvider: userDataProvider,
    );

    if (!result.isSuccess) {
      showSnackBarMessage(context, result.message);
      return;
    }

    userDataProvider.changePW(newID, currentPW, newPW);
    showSnackBarMessage(context, '비밀번호가 성공적으로 변경되었습니다.');

    // 비밀번호 변경 후에는 기존 세션을 무효화하고 로그아웃 처리
    userDataProvider.logoutUser(); // UserDataProvider의 logoutUser 메소드 호출

    // 로그인 페이지 또는 앱의 초기 화면으로 이동
    Navigator.pushAndRemoveUntil( // 현재 스택의 모든 위젯을 제거하고 새 위젯으로 대체
      context,
      MaterialPageRoute(builder: (context) => CSHomePage(title: widget.title)), // 가정된 로그인 페이지
          (Route<dynamic> route) => false, // 모든 이전 라우트 제거
    );

    _newID.clear();
    _currentPW.clear();
    _newPW.clear();
    _newPW2.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: widget.title),
      body: Column(
        children: [
          TextField(
            controller: _newID,
            decoration: const InputDecoration(labelText: 'ID'),
          ),
          TextField(
            controller: _currentPW,
            decoration: const InputDecoration(labelText: '기존 비밀번호'),
          ),
          TextField(
            controller: _newPW,
            obscureText: true,
            decoration: const InputDecoration(labelText: '수정할 비밀번호'),
          ),
          TextField(
            controller: _newPW2,
            obscureText: true,
            decoration: const InputDecoration(labelText: '수정할 비밀번호 확인'),
          ),
          ElevatedButton(
            onPressed: () => _changePW(),
            child: Text('비밀번호 변경'),
          ),
        ],
      ),
    );
  }
}