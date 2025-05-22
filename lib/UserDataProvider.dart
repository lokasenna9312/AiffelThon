import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase 인증
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore 데이터베이스

// ValidationResult 클래스는 유효성 검사 결과를 반환하기 위한 헬퍼 클래스입니다.
class ValidationResult {
  final bool isSuccess;
  final String message;

  ValidationResult.success(String validatedResult)
      : isSuccess = true,
        message = validatedResult;

  ValidationResult.failure(String errorMessage)
      : isSuccess = false,
        message = errorMessage;
}

// UserDataProvider 클래스는 Firebase Authentication 및 Cloud Firestore와 상호작용하여
// 사용자 인증 및 회원 정보를 관리합니다.
class UserDataProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 로그인된 Firebase 사용자 객체를 저장합니다.
  User? _currentUser;
  User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  // 새로 추가된 부분: 현재 로그인된 사용자의 ID를 반환합니다. (Firestore에 저장된 사용자 지정 ID)
  Future<String?> get loggedInUserId async { // Future<String?>와 async 추가
    if (_currentUser != null) {
      // Firestore에서 현재 사용자의 UID에 해당하는 문서의 'id' 필드를 조회합니다.
      final docSnapshot = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (docSnapshot.exists) {
        // 문서가 존재하면 해당 문서의 'id' 필드 값을 String?으로 캐스팅하여 반환합니다.
        return docSnapshot.data()?['id'] as String?;
      }
    }
    return null; // 로그인되지 않았거나, Firestore에 ID가 없는 경우 null 반환
  }

  // 새로 추가된 부분: 현재 로그인된 사용자의 이메일 주소를 반환합니다. (Firebase Authentication에 저장된 이메일)
  String? get loggedInUserEmail => _currentUser?.email;

  // UserDataProvider 생성자:
  // Firebase 인증 상태 변화를 실시간으로 구독하여 _currentUser를 업데이트하고 UI에 알립니다.
  UserDataProvider() {
    _auth.authStateChanges().listen((User? user) async {
      _currentUser = user;
      print('Auth state changed: user = $user');
      print('Auth state changed: isLoggedIn = $isLoggedIn');
      if (user != null) {
        String? id = await loggedInUserId; // await 추가
        print('Auth state changed: loggedInId (from getter) = $id');
      }
      print('Auth state changed: loggedInEmail = ${loggedInUserEmail}');
      notifyListeners(); // 로그인 상태 변화 시 UI를 업데이트하도록 알립니다.
    });
  }

  /// Firestore에서 주어진 사용자 지정 ID에 해당하는 이메일 주소를 조회합니다.
  /// 이메일/비밀번호 기반 Firebase 인증을 위해 ID에 연결된 이메일이 필요할 때 사용됩니다.
  Future<String?> findEmailById(String id) async {
    try {
      // 'users' 컬렉션에서 'id' 필드가 주어진 id와 일치하는 문서를 찾습니다.
      // limit(1)을 사용하여 첫 번째 일치하는 문서만 가져와 효율성을 높입니다.
      final querySnapshot = await _firestore.collection('users')
          .where('id', isEqualTo: id)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // 문서가 존재하면 해당 문서의 'email' 필드 값을 반환합니다.
        return querySnapshot.docs.first.data()['email'];
      }
      // 해당 ID의 사용자를 찾을 수 없으면 null을 반환합니다.
      return null;
    } catch (e) {
      // 오류 발생 시 콘솔에 출력하고 null을 반환합니다.
      print('ID로 이메일을 찾는 중 오류 발생: $e');
      return null;
    }
  }

  /// 회원가입 함수: ID, 비밀번호, 이메일을 매개변수로 받습니다.
  /// Firebase Authentication으로 계정을 생성하고, Firestore에 추가 사용자 정보를 저장합니다.
  Future<ValidationResult> registerUser(String id, String pw, String email) async {
    try {
      // 1. Firebase Authentication으로 계정 생성 시도 (이메일과 비밀번호 사용)
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pw, // 비밀번호 변수명 'pw' 사용
      );
      User? user = userCredential.user;

      if (user != null) {
        // 2. 계정 생성 성공 시, Firestore에 사용자 지정 ID 및 이메일 저장
        // Firebase UID를 문서 ID로 사용하여 각 사용자의 고유성을 보장합니다.
        await _firestore.collection('users').doc(user.uid).set({
          'id': id, // 사용자에게 보여지는 ID (Firestore에 저장)
          'email': email, // Firebase Authentication의 이메일과 동일하게 저장
          // 필요한 경우 다른 사용자 정보도 여기에 추가할 수 있습니다.
        });

        await user.sendEmailVerification();

        return ValidationResult.success('회원가입 성공!\nID : $id\nE-mail : $email\nE메일 인증 링크를 확인해주세요.');
      } else {
        // user 객체가 null인 경우 (매우 드물지만 안전을 위해)
        return ValidationResult.failure('회원가입에 실패했습니다: 사용자 정보 없음');
      }
    } on FirebaseAuthException catch (e) {
      // Firebase Authentication 관련 오류 처리
      if (e.code == 'weak-password') {
        return ValidationResult.failure('비밀번호가 너무 약합니다.');
      } else if (e.code == 'email-already-in-use') {
        return ValidationResult.failure('이미 사용 중인 이메일입니다.');
      } else if (e.code == 'invalid-email') {
        return ValidationResult.failure('유효하지 않은 이메일 형식입니다.');
      }
      return ValidationResult.failure('회원가입 오류: ${e.message}');
    } catch (e) {
      // 기타 예상치 못한 오류 처리
      return ValidationResult.failure('알 수 없는 오류 발생: $e');
    }
  }

  /// 로그인 함수: ID와 비밀번호를 매개변수로 받습니다.
  /// 먼저 ID에 해당하는 이메일을 찾은 후, 해당 이메일과 비밀번호로 Firebase 인증을 시도합니다.
  Future<ValidationResult> loginUser(String id, String pw) async {
    // 1. 주어진 ID에 해당하는 이메일 주소를 Firestore에서 조회합니다.
    String? email = await findEmailById(id);

    // 2. 이메일 주소를 찾을 수 없으면 로그인 실패를 반환합니다.
    if (email == null) {
      return ValidationResult.failure('해당 ID의 사용자를 찾을 수 없습니다.');
    }

    try {
      // 3. 찾은 이메일 주소와 입력된 비밀번호로 Firebase Authentication을 통해 로그인 시도
      await _auth.signInWithEmailAndPassword(email: email, password: pw); // 비밀번호 변수명 'pw' 사용
      // 로그인 성공 시 _currentUser가 자동으로 업데이트되고 notifyListeners 호출됨
      return ValidationResult.success('로그인 성공');
    } on FirebaseAuthException catch (e) {
      // Firebase Authentication 관련 오류 처리
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        // Firebase는 ID가 아닌 이메일/비밀번호 불일치로 에러를 반환하므로,
        // 사용자에게는 일반적인 메시지를 제공하는 것이 좋습니다.
        return ValidationResult.failure('잘못된 ID 또는 비밀번호입니다.');
      } else if (e.code == 'invalid-email') {
        return ValidationResult.failure('유효하지 않은 이메일 형식입니다. (내부 오류)');
      } else if (e.code == 'user-disabled') {
        return ValidationResult.failure('이 계정은 비활성화되었습니다.');
      }
      return ValidationResult.failure('로그인 오류: ${e.message}');
    } catch (e) {
      // 기타 예상치 못한 오류 처리
      return ValidationResult.failure('알 수 없는 오류 발생: $e');
    }
  }

  /// 로그아웃 함수
  Future<void> logoutUser() async {
    await _auth.signOut();
    print('Logout completed. isLoggedIn = $isLoggedIn'); // 디버그 print
    notifyListeners();
    // _currentUser가 자동으로 null로 업데이트되고 notifyListeners 호출됨
  }

  /// Firestore에서 사용자 지정 ID의 중복 여부를 확인합니다.
  Future<bool> isIdAlreadyTaken(String id) async {
    try {
      final querySnapshot = await _firestore.collection('users')
          .where('id', isEqualTo: id)
          .limit(1) // 첫 번째 일치하는 문서만 필요하므로 제한합니다.
          .get();
      return querySnapshot.docs.isNotEmpty; // 문서가 존재하면 중복된 ID입니다.
    } catch (e) {
      print('ID 중복 확인 중 오류 발생: $e');
      return true; // 오류 발생 시 안전하게 중복으로 간주 (또는 다른 오류 처리)
    }
  }

  /// 비밀번호 변경 함수: ID, 현재 비밀번호(pw), 새 비밀번호를 매개변수로 받습니다.
  /// 현재 로그인된 사용자의 비밀번호를 변경합니다.
  Future<ValidationResult> changePW(String id, String pw, String newPw) async {
    User? user = _auth.currentUser;
    if (user == null) {
      return ValidationResult.failure('로그인된 사용자가 없습니다.');
    }

    // 현재 로그인된 사용자의 ID와 입력된 ID가 일치하는지 확인 (선택 사항, 보안 강화)
    String? currentUserIdInFirestore = (await _firestore.collection('users').doc(user.uid).get()).data()?['id'];
    if (currentUserIdInFirestore != id) {
      return ValidationResult.failure('입력된 ID가 현재 로그인된 계정과 일치하지 않습니다.');
    }

    try {
      // 1. 재인증: 민감한 작업이므로 현재 비밀번호(pw)로 사용자를 재인증합니다.
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!, // 현재 로그인된 사용자의 이메일 사용
        password: pw, // 현재 비밀번호 변수명 'pw' 사용
      );
      await user.reauthenticateWithCredential(credential);

      // 2. 새 비밀번호로 업데이트
      await user.updatePassword(newPw);
      return ValidationResult.success('비밀번호가 성공적으로 변경되었습니다.');
    } on FirebaseAuthException catch (e) {
      // Firebase Authentication 관련 오류 처리
      if (e.code == 'wrong-password') {
        return ValidationResult.failure('현재 비밀번호가 일치하지 않습니다.');
      } else if (e.code == 'requires-recent-login') {
        return ValidationResult.failure('보안을 위해 다시 로그인해야 합니다. 재로그인 후 다시 시도해주세요.');
      } else if (e.code == 'weak-password') {
        return ValidationResult.failure('새 비밀번호가 너무 약합니다.');
      }
      return ValidationResult.failure('비밀번호 변경 오류: ${e.message}');
    } catch (e) {
      return ValidationResult.failure('알 수 없는 오류 발생: $e');
    }
  }

  /// 이메일 변경 함수: ID, 비밀번호, 새 이메일을 매개변수로 받습니다.
  /// 현재 로그인된 사용자의 이메일 주소를 변경합니다.
  /// Firebase는 이메일 변경 시 확인 이메일을 보내므로, 사용자에게 해당 안내가 필요합니다.
  Future<ValidationResult> changeEmailAddress(String id, String pw, String newEmail) async {
    User? user = _auth.currentUser;
    if (user == null) {
      return ValidationResult.failure('로그인된 사용자가 없습니다.');
    }

    // 현재 로그인된 사용자의 ID와 입력된 ID가 일치하는지 확인 (선택 사항, 보안 강화)
    String? currentUserIdInFirestore = (await _firestore.collection('users').doc(user.uid).get()).data()?['id'];
    if (currentUserIdInFirestore != id) {
      return ValidationResult.failure('입력된 ID가 현재 로그인된 계정과 일치하지 않습니다.');
    }

    try {
      // 1. 재인증: 민감한 작업이므로 현재 비밀번호(pw)로 사용자를 재인증합니다.
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!, // 현재 로그인된 사용자의 이메일 사용
        password: pw, // 현재 비밀번호 변수명 'pw' 사용
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Firebase Authentication의 verifyBeforeUpdateEmail을 사용하여 이메일 변경 시도
      //    이메일 확인 후 변경이 이루어집니다.
      await user.verifyBeforeUpdateEmail(newEmail);

      // 3. Firestore에 저장된 이메일 정보도 업데이트 (선택 사항, 일관성 유지에 좋음)
      await _firestore.collection('users').doc(user.uid).update({
        'email': newEmail,
      });

      // 이메일 변경은 사용자에게 확인 이메일을 보낸 후 적용됩니다.
      return ValidationResult.success('새 이메일 주소로 확인 링크를 보냈습니다. 링크를 클릭하여 이메일 변경을 완료해주세요.');
    } on FirebaseAuthException catch (e) {
      // Firebase Authentication 관련 오류 처리
      if (e.code == 'wrong-password') {
        return ValidationResult.failure('현재 비밀번호가 일치하지 않습니다.');
      } else if (e.code == 'requires-recent-login') {
        return ValidationResult.failure('보안을 위해 다시 로그인해야 합니다. 재로그인 후 다시 시도해주세요.');
      } else if (e.code == 'email-already-in-use') {
        return ValidationResult.failure('입력하신 E메일은 이미 다른 계정으로 등록되어 있습니다.');
      } else if (e.code == 'invalid-email') {
        return ValidationResult.failure('유효하지 않은 이메일 형식입니다.');
      }
      return ValidationResult.failure('이메일 변경 오류: ${e.message}');
    } catch (e) {
      return ValidationResult.failure('알 수 없는 오류 발생: $e');
    }
  }

  /// 회원 탈퇴 함수: ID와 비밀번호를 매개변수로 받습니다.
  /// 현재 로그인된 사용자의 계정을 삭제합니다. 민감한 작업이므로 재인증이 필요합니다.
  Future<ValidationResult> deleteAccount(String id, String email, String pw) async {
    User? user = _auth.currentUser;
    if (user == null) {
      return ValidationResult.failure('로그인된 사용자가 없습니다.');
    }

    // 현재 로그인된 사용자의 ID와 입력된 ID가 일치하는지 확인 (선택 사항, 보안 강화)
    String? currentUserIdInFirestore = (await _firestore.collection('users').doc(user.uid).get()).data()?['id'];
    if (currentUserIdInFirestore != id) {
      return ValidationResult.failure('입력된 ID가 현재 로그인된 계정과 일치하지 않습니다.');
    }

    try {
      // 1. 재인증: 비밀번호(pw)로 사용자를 재인증합니다.
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!, // 현재 로그인된 사용자의 이메일 사용
        password: pw, // 현재 비밀번호 변수명 'pw' 사용
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Firestore에서 사용자 정보 삭제
      // Firebase Authentication 계정 삭제 전에 Firestore 데이터 삭제를 시도합니다.
      await _firestore.collection('users').doc(user.uid).delete();

      // 3. Firebase Auth에서 계정 삭제
      await user.delete();
      return ValidationResult.success('계정이 성공적으로 삭제되었습니다.');
    } on FirebaseAuthException catch (e) {
      // Firebase Authentication 관련 오류 처리
      if (e.code == 'wrong-password') {
        return ValidationResult.failure('비밀번호가 일치하지 않습니다.');
      } else if (e.code == 'requires-recent-login') {
        return ValidationResult.failure('보안을 위해 다시 로그인해야 합니다. 재로그인 후 다시 시도해주세요.');
      }
      return ValidationResult.failure('계정 삭제 오류: ${e.message}');
    } catch (e) {
      return ValidationResult.failure('알 수 없는 오류 발생: $e');
    }
  }

  /// 이메일로 ID 찾기 (Firestore 쿼리)
  /// 주어진 이메일 주소를 통해 Firestore에 저장된 사용자 지정 ID를 찾습니다.
  Future<String?> findIdByEmail(String email) async {
    try {
      final querySnapshot = await _firestore.collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['id'];
      }
      return null;
    } catch (e) {
      print('이메일로 ID를 찾는 중 오류 발생: $e');
      return null;
    }
  }
}

// UserDataProviderUtility 클래스는 UI 계층에서 UserDataProvider를 사용하기 위한
// 유효성 검사 및 헬퍼 함수들을 제공합니다.
class UserDataProviderUtility {
  /// 회원가입 유효성 검사 및 처리
  /// 입력된 ID, 비밀번호, 이메일의 유효성을 검사하고 UserDataProvider를 통해 계정을 생성합니다.
  Future<ValidationResult> registerAccount({
    required String newID, // 사용자에게 보여지는 ID
    required String newPW, // 비밀번호
    required String newPW2, // 비밀번호 확인
    required String newEmail, // 이메일
    required UserDataProvider userDataProvider, // Firebase 기능이 있는 UserDataProvider 인스턴스
  }) async {
    // 1. 모든 필수 필드 입력 여부 확인
    if (newID.isEmpty || newPW.isEmpty || newPW2.isEmpty || newEmail.isEmpty) {
      return ValidationResult.failure('모든 필드를 입력해주세요.');
    }

    // 2. 새 비밀번호와 확인 비밀번호 일치 여부 확인
    if (newPW != newPW2) {
      return ValidationResult.failure('비밀번호가 일치하지 않습니다.');
    }

    // 3. 사용자 지정 ID 중복 확인 (Firestore 쿼리 이용)
    bool isIdTaken = await userDataProvider.isIdAlreadyTaken(newID);
    if (isIdTaken) {
      return ValidationResult.failure('이미 해당 ID로 가입된 회원이 있습니다.');
    }

    // 4. 이메일 중복 확인은 Firebase Authentication의 createUserWithEmailAndPassword 메서드에서
    //    'email-already-in-use' 오류를 통해 자동으로 처리됩니다.
    //    따라서 여기서는 별도의 사전 이메일 중복 검사 로직을 넣지 않고,
    //    UserDataProvider의 registerUser 호출 시 반환되는 결과를 기다립니다.

    // 모든 클라이언트 측 유효성 검사를 통과했다면, UserDataProvider를 통해 실제 계정 생성 시도
    ValidationResult registerResult = await userDataProvider.registerUser(newID, newPW, newEmail);

    // UserDataProvider에서 반환된 최종 결과를 그대로 반환합니다.
    return registerResult;
  }

  /// ID와 비밀번호로 로그인 유효성 검사 및 처리
  /// 입력된 ID와 비밀번호를 사용하여 UserDataProvider를 통해 로그인 시도합니다.
  Future<ValidationResult> validateAndLoginById({
    required String id,
    required String pw, // 비밀번호 변수명 'pw' 사용
    required UserDataProvider userDataProvider,
  }) async {
    // 1. 모든 필수 필드 입력 여부 확인
    if (id.isEmpty || pw.isEmpty) {
      return ValidationResult.failure('ID와 비밀번호를 모두 입력해주세요.');
    }

    // 2. UserDataProvider의 loginUser 메서드를 호출하여 실제 로그인 처리
    // 이 메서드 내부에서 ID로 이메일을 조회하고, 이메일/비밀번호로 Firebase Auth 로그인을 시도합니다.
    ValidationResult loginResult = await userDataProvider.loginUser(id, pw);

    return loginResult;
  }

  /// 비밀번호 변경 유효성 검사 및 처리
  /// 현재 로그인된 사용자의 비밀번호를 변경합니다.
  Future<ValidationResult> validateAndChangePW({
    required String id, // 변경하려는 계정의 ID (로그인된 사용자와 일치하는지 확인용)
    required String currentPW, // 현재 비밀번호 (재인증용)
    required String newPW, // 새 비밀번호
    required String newPW2, // 새 비밀번호 확인
    required UserDataProvider userDataProvider, // Firebase 기능이 있는 UserDataProvider 인스턴스
  }) async {
    // 1. 모든 필수 필드 입력 여부 확인
    if (id.isEmpty || currentPW.isEmpty || newPW.isEmpty || newPW2.isEmpty) {
      return ValidationResult.failure('모든 필드를 입력해주세요.');
    }

    // 2. 새 비밀번호와 확인 비밀번호 일치 여부 확인
    if (newPW != newPW2) {
      return ValidationResult.failure('새 비밀번호가 일치하지 않습니다.');
    }

    // 3. 현재 로그인된 사용자 확인
    if (userDataProvider.currentUser == null) {
      return ValidationResult.failure('로그인된 사용자가 없습니다. 먼저 로그인해주세요.');
    }

    // 4. 입력된 ID가 현재 로그인된 사용자의 ID와 일치하는지 확인 (보안 강화)
    String? loggedInId = (await userDataProvider.findIdByEmail(userDataProvider.currentUser!.email!));
    if (loggedInId != id) {
      return ValidationResult.failure('입력하신 ID가 현재 로그인된 계정과 일치하지 않습니다.');
    }

    // 모든 유효성 검사를 통과했다면, UserDataProvider를 통해 실제 비밀번호 변경 작업 위임
    ValidationResult changeResult = await userDataProvider.changePW(id, currentPW, newPW);
    return changeResult;
  }

  /// 이메일 변경 유효성 검사 및 처리
  /// 현재 로그인된 사용자의 이메일 주소를 변경합니다.
  Future<ValidationResult> validateAndChangeEmail({
    required String id, // 변경하려는 계정의 ID (로그인된 사용자와 일치하는지 확인용)
    required String pw, // 현재 비밀번호 (재인증용)
    required String newEmail, // 변경할 새 이메일 주소
    required UserDataProvider userDataProvider, // Firebase 기능이 있는 UserDataProvider 인스턴스
  }) async {
    // 1. 모든 필수 필드 입력 여부 확인
    if (id.isEmpty || pw.isEmpty || newEmail.isEmpty) {
      return ValidationResult.failure('모든 필드를 입력해주세요.');
    }

    // 2. 현재 로그인된 사용자 확인
    if (userDataProvider.currentUser == null) {
      return ValidationResult.failure('로그인된 사용자가 없습니다. 먼저 로그인해주세요.');
    }

    // 3. 입력된 ID가 현재 로그인된 사용자의 ID와 일치하는지 확인 (보안 강화)
    String? loggedInId = (await userDataProvider.findIdByEmail(userDataProvider.currentUser!.email!));
    if (loggedInId != id) {
      return ValidationResult.failure('입력하신 ID가 현재 로그인된 계정과 일치하지 않습니다.');
    }

    // 4. 기존 이메일 주소와 동일한지 확인
    if (userDataProvider.currentUser!.email == newEmail) {
      return ValidationResult.failure('기존 E메일 주소와 동일합니다. 다른 주소를 입력해주세요.');
    }

    // 5. 변경하려는 이메일이 이미 다른 계정으로 등록되어 있는지 확인
    //    Firebase Authentication의 verifyBeforeUpdateEmail 메서드에서 'email-already-in-use' 오류를 통해
    //    자동으로 처리되므로, 여기서는 별도의 사전 중복 검사 로직을 넣지 않고,
    //    UserDataProvider의 changeEmailAddress 호출 시 반환되는 결과를 기다립니다.

    // 모든 유효성 검사를 통과했다면, UserDataProvider를 통해 실제 이메일 변경 작업 위임
    ValidationResult changeResult = await userDataProvider.changeEmailAddress(id, pw, newEmail);
    return changeResult;
  }

  /// ID 찾기 (이메일 기반)
  /// 이메일 주소를 통해 Firestore에 저장된 사용자 지정 ID를 찾습니다.
  Future<String?> findIdByEmail({
    required String email,
    required UserDataProvider userDataProvider,
  }) async {
    if (email.isEmpty) {
      return null; // 이메일이 비어있으면 ID를 찾을 수 없음
    }
    // UserDataProvider의 findIdByEmail 메서드를 호출하여 Firestore에서 ID를 조회합니다.
    return await userDataProvider.findIdByEmail(email);
  }

  /// 회원 탈퇴 유효성 검사 및 처리
  /// 사용자에게 비밀번호를 재확인 받은 후 계정을 삭제합니다.
  Future<ValidationResult> validateAndDeleteUser({
    required String id, // 탈퇴하려는 계정의 ID (로그인된 사용자와 일치하는지 확인용)
    required String email, // 탈퇴하려는 계정의 E메일 (로그인된 사용자와 일치하는지 확인용)
    required String pw, // 비밀번호 (재인증용)
    required UserDataProvider userDataProvider,
  }) async {
    // 1. 모든 필수 필드 입력 여부 확인
    if (id.isEmpty || email.isEmpty || pw.isEmpty) {
      return ValidationResult.failure('ID와 E메일, 비밀번호를 모두 입력해주세요.');
    }

    // 2. 현재 로그인된 사용자 확인
    if (userDataProvider.currentUser == null) {
      return ValidationResult.failure('로그인된 사용자가 없습니다.');
    }

    // 3. 입력된 ID가 현재 로그인된 사용자의 ID와 일치하는지 확인 (보안 강화)
    String? loggedInId = (await userDataProvider.loggedInUserId);
    if (loggedInId != id) {
      return ValidationResult.failure('입력하신 ID가 현재 로그인된 계정과 일치하지 않습니다.');
    }

    // 4. 입력된 E메일이 현재 로그인된 사용자의 E메일과 일치하는지 확인 (보안 강화)
    String? loggedInEmail = (await userDataProvider.loggedInUserEmail);
    if (loggedInEmail != email) {
      return ValidationResult.failure('입력하신 E메일이 현재 로그인된 계정과 일치하지 않습니다.');
    }

    // 모든 유효성 검사를 통과했다면, UserDataProvider를 통해 실제 회원 탈퇴 작업 위임
    ValidationResult deleteResult = await userDataProvider.deleteAccount(id, email, pw);
    return deleteResult;
  }
}
