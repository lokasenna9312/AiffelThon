import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bcrypt/bcrypt.dart';

import 'register.dart';
import 'home.dart';
import 'appbar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // runApp() 호출 전에 위젯 바인딩 초기화

  final userDataProvider = UserDataProvider();
  await userDataProvider.loadUsersFromJson(); // 앱 시작 시 회원 정보 로드

  runApp(
    ChangeNotifierProvider.value(
      value: userDataProvider,
      child: const CertificateStudy(),
    ),
  );
}

class CertificateStudy extends StatelessWidget {
  const CertificateStudy({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '서술형도 한다 - AiffelThon 과제',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const CSHomePage(CSTitle: '서술형도 한다'),
      // 이 위치의 "서술형도 한다" 가 AppBar에 출력되는 문구입니다.
      // 다른 페이지의 AppBar에선 CSTitle이라는 변수명으로 호출됩니다.
    );
  }
}

class CSHomePage extends StatefulWidget {
  final String CSTitle;

  const CSHomePage({super.key, required this.CSTitle});

  @override
  State<CSHomePage> createState() => _CSHomePageState();
}

class _CSHomePageState extends State<CSHomePage> {
  final id_input = TextEditingController();
  final pw_input = TextEditingController();

  late String CSTitle; // CSTitle 변수 선언

  @override
  void initState() {
    super.initState();
    CSTitle = widget.CSTitle;
  }

  void _processLogin(BuildContext context) {
    String id = id_input.text;
    String pw = pw_input.text;

    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    if (userDataProvider.registeredUsers.containsKey(id)) {
      String? storedHashedPassword = userDataProvider.registeredUsers[id]?["password"];
      String? email = userDataProvider.registeredUsers[id]?["email"];
      if (storedHashedPassword != null && BCrypt.checkpw(pw, storedHashedPassword) && email != null) {
        // 로그인 성공 시의 동작 (예: 다음 화면으로 이동)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 성공!')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MainPage(CSTitle: CSTitle, id: id, email:email)),
        );
      } else if (storedHashedPassword != null && !BCrypt.checkpw(pw, storedHashedPassword)) {
        // 비밀번호 불일치 시의 동작
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패. 비밀번호를 확인하세요.')),
        );
      } else {
        // storedHashedPassword가 null인 경우 (ID는 존재하지만 비밀번호 정보가 없는 경우)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('비밀번호를 재설정해주세요.')),
        );
      }
    } else {
      // ID가 존재하지 않는 경우
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('존재하지 않는 ID입니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: CSTitle),
      body: Column(
        children: [
          Image(image: AssetImage('assets/images/logo.png')),
          TextField(
            style: TextStyle(fontSize: 15.0),
            controller: id_input,
            decoration: InputDecoration(labelText: 'ID : ')
          ),
          TextField(
            style: TextStyle(fontSize: 15.0),
            controller: pw_input,
            obscureText: true,
            decoration: InputDecoration(labelText: '비밀번호 : ')
          ),
          Row( // 버튼들을 가로로 배치
            mainAxisAlignment: MainAxisAlignment.spaceAround, // 버튼 사이에 공간을 줌
            children: [
              ElevatedButton(
                onPressed: () {
                  _processLogin(context);
                },
                child: Text('로그인'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RegisterPage(CSTitle: CSTitle),
                    ),
                  );
                },
                child: Text('게정 만들기 / 찾기'),
              ),
            ],
          ),
        ]
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
