import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'UserDataProvider.dart';
import 'appbar.dart';
import 'ui_utils.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, required this.title});
  final String title;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _id = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();

  void _deleteAccount(BuildContext context) async {
    final userDataProvider = Provider.of<UserDataProvider>(
        context, listen: false);
    final id = _id.text.trim();
    final email = _email.text.trim();
    final pw = _pw.text.trim();

    if (id.isEmpty || email.isEmpty || pw.isEmpty) {
      showSnackBarMessage(context, '모든 정보를 입력해주세요.');
      return; // 유효성 검사 실패 시 함수 종료
    }

    final userDataProviderUtility = UserDataProviderUtility();
    final ValidationResult result = await userDataProviderUtility.validateAndDeleteUser(
      id: id,
      email: email,
      pw: pw, // 'pw' 변수명 사용
      userDataProvider: userDataProvider,
    );

    if (result.isSuccess) {
      showSnackBarMessage(context, '회원 탈퇴가 완료되었습니다.');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => MainPage(title: widget.title),
        ),
        (Route<dynamic> route) => false, // 모든 이전 라우트 제거
      );
      _id.clear();
      _email.clear();
      _pw.clear();
    } else {
      showSnackBarMessage(context, 'ID, 이메일 또는 비밀번호가 일치하지 않습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: widget.title),
      body: Column(
        children: [
          TextField(controller: _id, decoration: const InputDecoration(labelText: 'ID')),
          TextField(
            controller: _pw,
            obscureText: true,
            decoration: const InputDecoration(labelText: '비밀번호'),
          ),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail')),
          ElevatedButton(
            onPressed: () => _deleteAccount(context),
            child: const Text('회원 탈퇴'),
          ),
        ],
      ),
    );
  }
}
