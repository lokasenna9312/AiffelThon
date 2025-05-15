import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'join.dart';
import 'register.dart';
import 'home.dart';

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
      home: const CSHomePage(title: '서술형도 한다'),
      // 이 위치의 "서술형도 한다" 가 AppBar에 출력되는 문구입니다.
      // 다른 페이지의 AppBar에선 CSTitle이라는 변수명으로 호출됩니다.
      routes: {
        '/register': (context) => const RegisterPage(CSTitle: '회원가입'),
      },
    );
  }
}

class CSHomePage extends StatefulWidget {
  const CSHomePage({super.key, required this.title});

  final String title;

  @override
  State<CSHomePage> createState() => _CSHomePageState();
}

class _CSHomePageState extends State<CSHomePage> {

  final id_input = TextEditingController();
  final pw_input = TextEditingController();

  void _processLogin(BuildContext context) {
    String id = id_input.text;
    String pw = pw_input.text;
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    print('로그인 시도 - ID: $id, PW: $pw'); // 추가
    print('저장된 사용자 정보: ${userDataProvider.registeredUsers}');
    if (userDataProvider.registeredUsers.containsKey(id) && userDataProvider.registeredUsers[id] == pw) {
      // 로그인 성공 시의 동작 (예: 다음 화면으로 이동)
      print('로그인 성공! ID: $id, PW: $pw');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 성공!')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MainPage(CSTitle: widget.title)),
      );
    } else {
      // 로그인 실패 시의 동작 (예: 오류 메시지 표시)
      print('로그인 실패...');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패. ID 또는 비밀번호를 확인하세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
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
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text('회원가입'),
              ),
            ],
          ),
        ]
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
