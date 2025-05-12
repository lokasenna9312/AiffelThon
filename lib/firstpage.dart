import 'package:flutter/material.dart';
import 'login.dart';
import 'register.dart';
import 'main.dart';

void main() {
  runApp(const CertificateStudy());
}

class CertificateStudy extends StatelessWidget {
  const CertificateStudy({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '서술형도 한다',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const CSHomePage(title: '서술형도 한다'),
    );
  }
}

class CSHomePage extends StatefulWidget {
  const CSHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<CSHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<CSHomePage> {
  final id_input = TextEditingController();
  final pw_input = TextEditingController();

  void _processLogin(BuildContext context) {
    String id = id_input.text;
    String pw = pw_input.text;

    if (attemptLogin(id, pw)) {
      // 로그인 성공 시의 동작 (예: 다음 화면으로 이동)
      print('로그인 성공! ID: $id, PW: $pw');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 성공!')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MainPage(firstPageTitle: widget.title)),
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
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Column(
          children: [
            Image(image: AssetImage('/assets/images/q-net_logo.png')),
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
                    // RegisterPage로 이동하면서 title 값을 전달
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RegisterPage(firstPageTitle: widget.title),
                      ),
                    );
                  },
                  child: Text('회원가입'),
                ),
              ],
            ),
          ]
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
