import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'register.dart';
import 'appbar.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key, required this.CSTitle});
  final String CSTitle;

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  final _id = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();

  late String CSTitle; // CSTitle 변수 선언

  @override
  void initState() {
    super.initState();
    CSTitle = widget.CSTitle;
  }

  void _withdrawAccount(BuildContext context) async {
    final userDataProvider = Provider.of<UserDataProvider>(
        context, listen: false);
    final id = _id.text.trim();
    final email = _email.text.trim();
    final pw = _pw.text.trim();

    if (id.isNotEmpty && email.isNotEmpty && pw.isNotEmpty) {
      final isDeleted = await userDataProvider.deleteUser(id, email, pw);
      if (isDeleted) {
        Navigator.pop(context); // 탈퇴 성공 후 이전 화면으로 이동 또는 다른 화면으로 이동
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CSHomePage(CSTitle: CSTitle)),
        );
        // 필요하다면 로그아웃 처리 또는 앱 상태 초기화 로직 추가
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID, 이메일 또는 비밀번호가 일치하지 않습니다.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 정보를 입력해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: CSTitle),
      body: Column(
        children: [
          TextField(controller: _id, decoration: const InputDecoration(labelText: 'ID')),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail')),
          TextField(
            controller: _pw,
            obscureText: true,
            decoration: const InputDecoration(labelText: '비밀번호'),
          ),
          Text("회원 탈퇴를 위해서는 ID와 E메일, 비밀번호를 모두 입력하셔야 합니다."),
          ElevatedButton(
            onPressed: () => _withdrawAccount(context),
            child: const Text('회원 탈퇴'),
          ),
        ],
      ),
    );
  }
}
