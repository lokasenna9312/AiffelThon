import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';

import 'lostid.dart';

class UserDataProvider extends ChangeNotifier {
  Map<String, Map> _registeredUsers = {};
  /* 아래 Map객체는 외부에서는 _registeredUsers에 직접 접근할 수 없고,
  오직 registeredUsers를 통해서만 접근할 수 있게 됨, 캡슐화 원칙을 따르는 방법으로
  데이터 무결성을 유지하고, 객체 내부의 구현을 감추는데 유용함.
   */
  Map<String, Map> get registeredUsers => _registeredUsers;
  Future<File> _getUserDataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/users.json');
  }

  void addUser(String id, String pw, String email) async {
    _registeredUsers[id] = {"password" : pw, "email" : email};
    await saveUsersToJson();
    notifyListeners();
  }

  bool isUserRegistered(String id) {
    return _registeredUsers.containsKey(id);
  }
  bool isEmailEnlisted(String email) {
    for (var userEntry in _registeredUsers.values) {
      if (userEntry.containsKey("email") && userEntry["email"] == email) {
        return true; // 이미 해당 이메일 주소가 등록되어 있음
      }
    }
    return false; // 해당 이메일 주소로 등록된 회원이 없음
  }

  String? findIdByEmail(String email) {
    for (var entry in _registeredUsers.entries) {
      if (entry.value.containsKey('email') && entry.value['email'] == email) {
        return entry.key;
      }
    }
    return null;
  }

  void changePassword(String id, String email, String hashedwantedPW) {
    if (isUserRegistered(id) && isEmailEnlisted(email)) {
      _registeredUsers[id]?["password"] = hashedwantedPW;
      saveUsersToJson();
      notifyListeners();
    } else {
      // 해당 ID 또는 해당 E메일의 사용자가 존재하지 않는 경우에 대한 처리 (선택 사항)
      print('해당 ID 또는 해당 E메일로 가입한 회원은 없습니다.');
    }
  }

  // registeredUsers 맵을 JSON 파일로 저장하는 메소드
  /* 비동기 처리는 파일 쓰기 작업과 같은 I/O작업을 별도의 스레드에서
  실행하여 메인 스레드의 작업을 방해하지 않도록 함으로써, 앱의 UI가 멈추지 않고
  부드럽게 유지되도록 함, 이는 사용자 경험을 크게 향상시키며, 복잡한 동기화 문제를
  피할 수 있게 해줌.
   */
  Future<void> saveUsersToJson() async {
    try {
      // 앱 내부 문서 디렉토리 경로 가져오기
      final file = await _getUserDataFile();

      // Map을 JSON 문자열로 변환
      String jsonString = jsonEncode(_registeredUsers);

      // 파일에 쓰기
      await file.writeAsString(jsonString);
      print('회원 정보가 JSON 파일로 저장되었습니다.');
    } catch (e) {
      print('회원 정보 저장 중 오류 발생: $e');
    }
  }

  // JSON 파일에서 회원 정보를 로드하는 메소드
  Future<void> loadUsersFromJson() async {
    try {
      final file = await _getUserDataFile();
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
  final _email = TextEditingController();

  void _registerUser(BuildContext context) {
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final String newID = _newID.text.trim();
    final String newPW = _newPW.text.trim();
    final String newPW2 = _newPW2.text.trim();
    final String email = _email.text.trim();

    if (newID.isNotEmpty && newPW.isNotEmpty && newPW2.isNotEmpty && email.isNotEmpty && newPW == newPW2 && !userDataProvider.isUserRegistered(newID)) {
      String hashedPW = BCrypt.hashpw(newPW, BCrypt.gensalt());
      userDataProvider.addUser(newID, hashedPW, email);
      Navigator.pop(context); // 회원가입 완료 후 이전 화면으로 이동
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입이 완료되었습니다.')),
      );
    } else if (newID.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID를 입력하지 않았습니다.')),
      );
    } else if (userDataProvider.isUserRegistered(newID)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 존재하는 ID입니다.')),
      );
    } else if (newPW.isEmpty || newPW2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호를 입력하지 않았습니다.')),
      );
    } else if (newPW != newPW2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 맞지 않습니다.')),
      );
    } else if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E메일 주소를 입력하지 않았습니다.')),
      );
    } else if (userDataProvider.isEmailEnlisted(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 가입된 E메일 주소입니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입력 내용을 확인해주세요.')),
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
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround, // 버튼 사이에 공간을 줌
            children: [
              ElevatedButton(
                onPressed: () => _registerUser(context),
                child: const Text('회원가입'),
              ),
              ElevatedButton(
                onPressed: () {
                  // LostIDPage로 이동하면서 title 값을 전달
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LostIDPage(CSTitle: widget.CSTitle),
                    ),
                  );
                },
                child: Text('ID, PW 찾기'),
              ),
            ]
          )
        ],
      ),
    );
  }
}