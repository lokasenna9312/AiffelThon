import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth 추가

import 'appbar.dart';
import 'UserDataProvider.dart';
import 'ui_utils.dart';
import 'changepw.dart';
import 'home.dart'; // HomePage가 home.dart에 정의되어 있습니다.

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.title});

  final String title;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // `late` 키워드를 사용하여 initState에서 초기화됩니다.
  late UserDataProvider userDataProvider;
  late UserDataProviderUtility utility;
  final _newID = TextEditingController();
  final _newPW = TextEditingController();
  final _newPW2 = TextEditingController();
  final _newEmail = TextEditingController();

  // !!! 새로 추가된 부분: 중복 실행 방지 플래그 !!!
  // 이 플래그는 _registerUser 메소드가 동시에 여러 번 실행되는 것을 방지합니다.
  bool _isProcessingRegistration = false;

  @override
  void initState() {
    super.initState(); // 항상 super.initState()를 먼저 호출해야 합니다.
    // initState에서는 `context`를 사용하여 Provider를 초기화할 수 있습니다.
    userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    utility = UserDataProviderUtility();
  }

  void _registerUser() async {
    // !!! 새로 추가된 부분: 중복 실행 방지 로직 !!!
    if (_isProcessingRegistration) {
      print('>>> register.dart: _registerUser 메소드 이미 처리 중. 중복 호출 방지.');
      return; // 이미 처리 중이면 아무것도 하지 않고 즉시 종료
    }
    _isProcessingRegistration = true; // 처리 시작 플래그 설정

    try {
      final String newID = _newID.text.trim();
      final String newPW = _newPW.text.trim();
      final String newPW2 = _newPW2.text.trim();
      final String newEmail = _newEmail.text.trim();

      // 1. UI 단계에서 즉각적인 유효성 검사 (네트워크 요청 없음)
      if (newID.isEmpty || newPW.isEmpty || newPW2.isEmpty || newEmail.isEmpty) {
        showSnackBarMessage(context, '모든 필드를 입력해주세요.');
        return; // 즉시 종료
      }

      if (newPW != newPW2) {
        showSnackBarMessage(context, '비밀번호가 일치하지 않습니다.');
        return; // 즉시 종료
      }

      // 2. 비즈니스 로직 유효성 검사 (ID 중복 확인 포함, 네트워크 요청 발생 가능)
      //    이 시점에서는 이미 기본적인 필드 유효성은 검증된 상태
      final ValidationResult result = await utility.registerAccount(
        newID: newID,
        newPW: newPW,
        newPW2: newPW2,
        newEmail: newEmail,
        userDataProvider: userDataProvider,
      );

      if (!result.isSuccess) {
        showSnackBarMessage(context, result.message);
        return; // 유효성 검사 실패 시 종료
      }

      // 3. 실제 Firebase에 계정 생성 요청 (utility.registerAccount 내부에서 처리 완료)
      //    위 result가 성공이면 이미 계정 생성이 시도된 상태
      print('>>> register.dart: 회원가입 성공. Firebase 인증 상태 업데이트 대기 중.');
      showSnackBarMessage(context, '회원가입 성공! 이메일 인증 링크를 확인해주세요.');

      await FirebaseAuth.instance.authStateChanges().firstWhere((user) => user != null);

      print('>>> register.dart: Firebase 인증 상태 업데이트 확인 완료. 이제 화면 전환 시작.');

      _newID.clear();
      _newPW.clear();
      _newPW2.clear();
      _newEmail.clear();

      // 로그인된 상태의 메인 페이지로 이동합니다.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(title: widget.title), // `title` 사용
        ),
            (Route<dynamic> route) => false,
      );

    } on FirebaseAuthException catch (e) {
      String errorMessage = '회원가입 오류: ${e.message}';
      if (e.code == 'email-already-in-use') {
        errorMessage = '이미 사용 중인 이메일입니다.';
      } else if (e.code == 'weak-password') {
        errorMessage = '비밀번호가 너무 약합니다.';
      }
      print('>>> register.dart: 회원가입 Firebase 오류: $errorMessage');
      showSnackBarMessage(context, errorMessage);

    } catch (e) {
      print('>>> register.dart: 회원가입 알 수 없는 오류: $e');
      showSnackBarMessage(context, '알 수 없는 오류 발생: $e');
    } finally {
      // !!! 새로 추가된 부분: 처리 완료 후 플래그 리셋 !!!
      _isProcessingRegistration = false;
    }
  }

  // ID 찾기 메소드
  void _findID() async {
    final String emailToFind = _newEmail.text.trim();

    if (emailToFind.isEmpty) {
      showSnackBarMessage(context, 'ID를 찾을 E메일 주소를 입력해주세요.');
      return;
    }

    final String? foundId = await userDataProvider.findIdByEmail(_newEmail.text.trim());

    if (foundId != null) {
      showSnackBarMessage(context, '찾으신 ID: $foundId');
    } else {
      showSnackBarMessage(context, '해당 E메일로 가입된 회원은 없습니다.');
    }
  }

  @override
  void dispose() {
    _newID.dispose();
    _newPW.dispose();
    _newPW2.dispose();
    _newEmail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: widget.title),
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
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () => _registerUser(),
                  child: Text('회원가입'),
                ),
                ElevatedButton(
                  onPressed: () => _findID(),
                  child: Text('ID 찾기'),
                ),
              ]
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangePWPage(title: widget.title),
                ),
              );
            },
            child: Text('비밀번호 재설정 페이지로'),
          ),
        ],
      ),
    );
  }
}