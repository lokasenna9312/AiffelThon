import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';

class UserDataProvider extends ChangeNotifier {
  Map<String, Map> _registeredUsers = {};
  Map<String, Map> get registeredUsers => _registeredUsers;

  void addUser(String id, String pw) async {
    _registeredUsers[id] = {"password" : pw};
    await saveUsersToJson();
    notifyListeners();
  }

  bool isUserRegistered(String id) {
    return _registeredUsers.containsKey(id);
  }

  // registeredUsers 맵을 JSON 파일로 저장하는 메소드
  Future<void> saveUsersToJson() async {
    try {
      // 앱 내부 문서 디렉토리 경로 가져오기
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/users.json');

      // Map을 JSON 문자열로 변환
      String jsonString = jsonEncode(_registeredUsers);

      // 파일에 쓰기
      await file.writeAsString(jsonString);
      print('회원 정보가 JSON 파일로 저장되었습니다.');
    } catch (e) {
      print('회원 정보 저장 중 오류 발생: $e');
    }
  }

  // JSON 파일에서 회원 정보를 로드하는 메소드 (추가적으로 구현할 수 있습니다.)
  Future<void> loadUsersFromJson() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/users.json');
      if (await file.exists()) {
        String jsonString = await file.readAsString();
        Map<String, dynamic> parsedJson = jsonDecode(jsonString);
        _registeredUsers = parsedJson.cast<String, Map>();
        notifyListeners();
      } else {
        print('저장된 회원 정보 파일이 없습니다.');
      }
    } catch (e) {
      print('회원 정보 로드 중 오류 발생: $e');
    }
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.CSTitle});

  final String CSTitle;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _newID = TextEditingController();
  final _newPW = TextEditingController();
  final _newPW2 = TextEditingController();

  void _registerUser(BuildContext context) {
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final String newID = _newID.text.trim();
    final String newPW = _newPW.text.trim();
    final String newPW2 = _newPW2.text.trim();

    if (newID.isNotEmpty && newPW.isNotEmpty && newPW2.isNotEmpty && newPW == newPW2 && !userDataProvider.isUserRegistered(newID)) {
      String hashedPW = BCrypt.hashpw(newPW, BCrypt.gensalt());
      userDataProvider.addUser(newID, hashedPW);
      Navigator.pop(context); // 회원가입 완료 후 이전 화면으로 이동
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입이 완료되었습니다.')),
      );
    } else if (newPW != newPW2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 맞지 않습니다.')),
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
          ElevatedButton(
            onPressed: () => _registerUser(context),
            child: const Text('회원가입'),
          ),
        ],
      ),
    );
  }
}