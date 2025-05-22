import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'changepw.dart';
import 'appbar.dart';
import 'ui_utils.dart';
import 'UserDataProvider.dart';
import 'main.dart';

class ModifyAccountPage extends StatefulWidget {
  const ModifyAccountPage({super.key, required this.title});

  final String title;

  @override
  State<ModifyAccountPage> createState() => _ModifyAccountPageState();
}

class _ModifyAccountPageState extends State<ModifyAccountPage> {
  late UserDataProvider userDataProvider;
  late UserDataProviderUtility utility;
  final _newID = TextEditingController();
  final _newPW = TextEditingController();
  final _newEmail = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    utility = UserDataProviderUtility();
  }

  void _changeEmail() async {
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final String newID = _newID.text.trim();
    final String newPW = _newPW.text.trim();
    final String newEmail = _newEmail.text.trim();
    
    final ValidationResult result = await utility.validateAndChangeEmail( // 반환 타입이 ValidationResult
      id: newID,
      pw: newPW,
      newEmail: newEmail,
      userDataProvider: userDataProvider,
    );

    if (!result.isSuccess) {
      showSnackBarMessage(context, result.message);
      return;
    }

    showSnackBarMessage(context, '새 E메일 주소로 확인 링크를 보냈습니다. 링크를 클릭하여 E메일 변경을 완료해주세요.');

    await userDataProvider.logoutUser();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => CSHomePage(title: widget.title), // 로그인 페이지로 이동
      ),
      (Route<dynamic> route) => false,
    );

    _newID.clear();
    _newPW.clear();
    _newEmail.clear();
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
            controller: _newPW,
            obscureText: true,
            decoration: const InputDecoration(labelText: '비밀번호'),
          ),
          TextField(
            controller: _newEmail,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          ElevatedButton(
            onPressed: () => _changeEmail(),
            child: Text('E메일 주소 변경'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangePWPage(title: widget.title),
                ),
              );
            },
            child: Text('비밀번호 재설정 페이지로'),
          ),
        ],
      ),
    );
  }
}