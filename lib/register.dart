import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'join.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.CSTitle});

  final String CSTitle;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _newID = TextEditingController();
  final _newPW = TextEditingController();

  void _registerUser(BuildContext context) {
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final String newID = _newID.text.trim();
    final String newPW = _newPW.text.trim();

    if (newID.isNotEmpty && newPW.isNotEmpty && !userDataProvider.isUserRegistered(newID)) {
      userDataProvider.addUser(newID, newPW);
      Navigator.pop(context); // 회원가입 완료 후 이전 화면으로 이동
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입이 완료되었습니다.')),
      );
    } else if (userDataProvider.isUserRegistered(newID)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 존재하는 ID입니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID와 비밀번호를 모두 입력해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.CSTitle),
      ),
      body: Column(
        children: [
          TextField(
            controller: _newID,
            decoration: const InputDecoration(labelText: '새로운 ID'),
          ),
          TextField(
            controller: _newPW,
            obscureText: true,
            decoration: const InputDecoration(labelText: '새로운 비밀번호'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _registerUser(context),
            child: const Text('회원가입'),
          ),
        ],
      ),
    );
  }
}