import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bcrypt/bcrypt.dart';

import 'appbar.dart';
import 'UserDataProvider.dart';
import 'ui_utils.dart';
import 'changepw.dart';
import 'home.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.CSTitle});

  final String CSTitle;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
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

  void _registerUser() async {
    final String newID = _newID.text.trim();
    final String newPW = _newPW.text.trim();
    final String newPW2 = _newPW2.text.trim();
    final String newEmail = _newEmail.text.trim();

    final ValidationResult result = await utility.RegisterAccount( // 반환 타입이 ValidationResult
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

    String hashedPW = BCrypt.hashpw(newPW, BCrypt.gensalt());
    userDataProvider.addUser(newID, hashedPW, newEmail);

    showSnackBarMessage(context, '회원가입이 완료되었습니다.\nID : $newID\nE메일 : $newEmail');

    if (userDataProvider.isLoggedIn) {
      userDataProvider.logoutUser();
    }

    userDataProvider.loginUser(newID, newEmail);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => MainPage(CSTitle: CSTitle),
      ),
      (Route<dynamic> route) => false, // 모든 이전 라우트 제거
    );

    _newID.clear();
    _newPW.clear();
    _newPW2.clear();
    _newEmail.clear();
  }

  void _findID() {
    final id = userDataProvider.findIdByEmail(_newEmail.text.trim());
    String? _foundID;
    setState(() {
      _foundID = id;
    });
    if (_foundID != null) {
      showSnackBarMessage(context, '찾으신 ID: $_foundID');
    } else {
      showSnackBarMessage(context, '해당 E메일로 가입된 회원은 없습니다.');
    }
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
          Text("ID 찾기는 E메일만 입력하시면 됩니다."),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _registerUser(),
                child: Text('회원가입'),
              ),
              ElevatedButton(
                onPressed: () => _findID(),
                child: Text('ID 찾기'),
              ),
            ]
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangePWPage(CSTitle: CSTitle),
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