import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bcrypt/bcrypt.dart';

import 'appbar.dart';
import 'UserDataProvider.dart';
import 'ui_utils.dart';
import 'changepw.dart';

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

  void _registerUser() {
    final String newID = _newID.text.trim();
    final String newPW = _newPW.text.trim();
    final String newPW2 = _newPW2.text.trim();
    final String newEmail = _newEmail.text.trim();

    if (newID.isNotEmpty && newPW.isNotEmpty && newPW2.isNotEmpty && newEmail.isNotEmpty && newPW == newPW2 && !userDataProvider.isUserRegistered(newID)) {
      String hashedPW = BCrypt.hashpw(newPW, BCrypt.gensalt());
      userDataProvider.addUser(newID, hashedPW, newEmail);
      Navigator.pop(context); // 회원가입 완료 후 이전 화면으로 이동
      showSnackBarMessage(context, '회원가입이 완료되었습니다.'); // 헬퍼 함수 사용
    } else if (newID.isEmpty) {
      showSnackBarMessage(context, 'ID를 입력하지 않았습니다.');
    } else if (userDataProvider.isUserRegistered(newID)) {
      showSnackBarMessage(context, '이미 존재하는 ID입니다.');
    } else if (newPW.isEmpty || newPW2.isEmpty) {
      showSnackBarMessage(context, '비밀번호를 입력하지 않았습니다.');
    } else if (newPW != newPW2) {
      showSnackBarMessage(context, '비밀번호가 맞지 않습니다.');
    } else if (newEmail.isEmpty) {
      showSnackBarMessage(context, 'E메일 주소를 입력하지 않았습니다.');
    } else if (userDataProvider.isEmailEnlisted(newEmail)) {
      showSnackBarMessage(context, '이미 가입된 E메일 주소입니다.');
    } else {
      showSnackBarMessage(context, '입력 내용을 확인해주세요.');
    }
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
          ElevatedButton(
            onPressed: () => _registerUser(),
            child: Text('회원가입'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround, // 버튼 사이에 공간을 줌
            children: [
              ElevatedButton(
                onPressed: () => _findID(),
                child: Text('ID 찾기'),
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
                child: Text('비밀번호 재설정'),
              ),
            ]
          )
        ],
      ),
    );
  }
}