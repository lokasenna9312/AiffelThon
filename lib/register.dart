import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';

import 'appbar.dart';

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
    _registeredUsers[id] = {"pw" : pw, "email" : email};
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

  void changePW(String id, String email, String hashedwantedPW) {
    if (isUserRegistered(id) && isEmailEnlisted(email)) {
      _registeredUsers[id]?["pw"] = hashedwantedPW;
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

  bool _isLoggedIn = false; // 로그인 상태 관리
  String? _loggedInUserId;
  String? _loggedInUserEmail;

  bool get isLoggedIn => _isLoggedIn;
  String? get loggedInUserId => _loggedInUserId;
  String? get loggedInUserEmail => _loggedInUserEmail;

  void loginUser(String id, String email) {
    _isLoggedIn = true;
    _loggedInUserId = id;
    _loggedInUserEmail = email;
    notifyListeners();
  }

  void logoutUser() {
    _isLoggedIn = false;
    _loggedInUserId = null;
    _loggedInUserEmail = null;
    notifyListeners();
  }

  Future<bool> deleteUser(String id, String email, String pw) async {
    if (_registeredUsers.containsKey(id)) {
      final idToDelete = _registeredUsers[id];
      final emailToDelete = idToDelete?["email"];
      final hashedPWToDelete = idToDelete?["pw"];

      if (emailToDelete == email && hashedPWToDelete != null && BCrypt.checkpw(pw, hashedPWToDelete)) {
        _registeredUsers.remove(id);
        await saveUsersToJson();
        notifyListeners();
        return true; // 회원 탈퇴 성공
      } else {
        return false; // 이메일 또는 비밀번호 불일치
      }
    } else {
      return false; // 해당 ID의 사용자 없음
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
  late UserDataProvider userDataProvider;
  final _newID = TextEditingController();
  final _newPW = TextEditingController();
  final _newPW2 = TextEditingController();
  final _email = TextEditingController();

  late String CSTitle; // CSTitle 변수 선언

  @override
  void initState() {
    super.initState();
    CSTitle = widget.CSTitle;
    userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
  }

  void _registerUser(BuildContext context) {
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

  void _findID() {
    final id = userDataProvider.findIdByEmail(_email.text.trim());
    String? _foundID;
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

  void _changePW() {
    final String newID = _newID.text.trim();
    final String newPW = _newPW.text.trim();
    final String newPW2 = _newPW2.text.trim();
    final String email = _email.text.trim();
    if (newID.isNotEmpty && email.isNotEmpty && newPW.isNotEmpty && newPW2.isNotEmpty && userDataProvider.isUserRegistered(newID) && userDataProvider.isEmailEnlisted(email)) {
      if (newPW == newPW2) {
        String hashedwantedPW = BCrypt.hashpw(newPW, BCrypt.gensalt());
        userDataProvider.changePW(newID, email, hashedwantedPW);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('비밀번호가 변경되었습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('비밀번호가 맞지 않습니다.')),
        );
      }
    } else if (newID.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ID를 입력하지 않았습니다.')),
      );
    } else if (!userDataProvider.isUserRegistered(newID)) {
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
    } else if (newPW.isEmpty || newPW2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호를 입력하지 않았습니다.')),
      );
    } else if (newPW != newPW2) {
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
          Text("ID 찾기는 E메일만 입력하시면 됩니다.\n회원가입과 비밀번호 재설정은 위 입력칸을 모두 입력하십시오."),
          ElevatedButton(
            onPressed: () => _registerUser(context),
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
                onPressed: () => _changePW(),
                child: Text('비밀번호 재설정'),
              ),
            ]
          )
        ],
      ),
    );
  }
}