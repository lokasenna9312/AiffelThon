import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bcrypt/bcrypt.dart';

import 'register.dart';
import 'appbar.dart';

class LostIDPage extends StatefulWidget {
  const LostIDPage({super.key, required this.CSTitle});

  final String CSTitle;

  @override
  State<LostIDPage> createState() => _LostIDPageState();
}


class _LostIDPageState extends State<LostIDPage> {
  final _id = TextEditingController();
  final _email = TextEditingController();
  final _wantedPW = TextEditingController();
  final _wantedPW2 = TextEditingController();
  String? _foundID;

  late String CSTitle; // CSTitle 변수 선언

  @override
  void initState() {
    super.initState();
    CSTitle = widget.CSTitle;
  }

  void _findID() {
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final id = userDataProvider.findIdByEmail(_email.text.trim());
    setState(() {
      _foundID = id;
    });
    if (_foundID != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('찾으신 ID: $_foundID')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('해당 E메일로 가입된 회원은 없습니다.')),
      );
    }
  }

  void _ChangePW() {
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final id = _id.text.trim();
    final email = _email.text.trim();
    final wantedPW = _wantedPW.text.trim();
    final wantedPW2 = _wantedPW2.text.trim();

    if (id.isNotEmpty && email.isNotEmpty && wantedPW.isNotEmpty && wantedPW2.isNotEmpty && userDataProvider.isUserRegistered(id) && userDataProvider.isEmailEnlisted(email)) {
      if (wantedPW == wantedPW2) {
        String hashedwantedPW = BCrypt.hashpw(wantedPW, BCrypt.gensalt());
        userDataProvider.changePassword(id, email, hashedwantedPW);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('비밀번호가 변경되었습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('비밀번호가 맞지 않습니다.')),
        );
      }
    } else if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ID를 입력하지 않았습니다.')),
      );
    } else if (!userDataProvider.isUserRegistered(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('해당 ID로 가입한 회원은 없습니다.')),
      );
    } else if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('E메일을 입력하지 않았습니다.')),
      );
    } else if (!userDataProvider.isEmailEnlisted(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('해당 E메일로 가입한 회원은 없습니다.')),
      );
    } else if (wantedPW.isEmpty || wantedPW2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호를 입력하지 않았습니다.')),
      );
    } else if (wantedPW != wantedPW2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 맞지 않습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: CSTitle),
      body: Column(
        children: [
          TextField(
            controller: _id,
            decoration: const InputDecoration(labelText: 'ID'),
          ),
          TextField(
            controller: _wantedPW,
            obscureText: true,
            decoration: const InputDecoration(labelText: '비밀번호'),
          ),
          TextField(
            controller: _wantedPW2,
            obscureText: true,
            decoration: const InputDecoration(labelText: '비밀번호 확인'),
          ),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          Text("ID 찾기는 E메일만 입력하시고 누르시면 됩니다.\n비밀번호 변경은 아래의 모든 칸을 채우고 눌러주세요."),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround, // 버튼 사이에 공간을 줌
            children: [
              ElevatedButton(
                onPressed: _findID,
                child: const Text('ID 찾기')
              ),
              ElevatedButton(
                  onPressed: _ChangePW,
                  child: const Text('비밀번호 변경')
              ),
            ],
          ),
        ],
      ),
    );
  }
}