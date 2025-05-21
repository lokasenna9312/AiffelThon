import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';

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
      // 해당 ID 또는 해당 E메일의 사용자가 존재하지 않는 경우에 대한` 처리 (선택 사항)
      print('해당 ID 또는 해당 E메일로 가입한 회원은 없습니다.');
    }
  }

  void changeEmail(String id, String email, String pw) {
    String storedHashedPassword = _registeredUsers[id]?["pw"];
    if (isUserRegistered(id) && BCrypt.checkpw(pw, storedHashedPassword)) {
      _registeredUsers[id]?["email"] = email;
      if (_isLoggedIn && _loggedInUserId == id) {
        _loggedInUserEmail = email;
      }
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

class ValidationResult {
  final bool isSuccess;
  final String message; // 성공 시 해싱된 비밀번호, 실패 시 에러 메시지

  ValidationResult.success(String hashedPassword)
      : isSuccess = true,
        message = hashedPassword;

  ValidationResult.failure(String errorMessage)
      : isSuccess = false,
        message = errorMessage;
}

class UserDataProviderUtility {
  Future<ValidationResult> ValidateAndChangePW({
    required String newID,
    required String newPW,
    required String newPW2,
    required String newEmail,
    required UserDataProvider userDataProvider,
  }) async {
    // 1. 모든 필수 필드 입력 여부 확인
    if (newID.isEmpty || newPW.isEmpty || newPW2.isEmpty || newEmail.isEmpty) {
      return ValidationResult.failure('모든 필드를 입력해주세요.');
    }

    // 2. 새 비밀번호와 확인 비밀번호 일치 여부 확인
    if (newPW != newPW2) {
      return ValidationResult.failure('비밀번호가 일치하지 않습니다.');
    }

    // 3. ID 존재 여부 확인 (UserDataProvider 통해)
    if (!userDataProvider.isUserRegistered(newID)) {
      return ValidationResult.failure('해당 ID로 가입된 회원은 없습니다.');
    }

    // 4. 입력된 이메일이 해당 ID와 일치하는지 확인 (보안 강화)
    String? registeredEmailForId = userDataProvider.registeredUsers[newID]?["email"];
    if (registeredEmailForId == null || registeredEmailForId != newEmail) {
      return ValidationResult.failure('입력하신 ID와 E메일이 일치하는 사용자가 없습니다.');
    }

    // 모든 유효성 검사를 통과했다면, 비밀번호를 해싱하여 반환합니다.
    String hashedPassword = BCrypt.hashpw(newPW, BCrypt.gensalt());
    return ValidationResult.success(hashedPassword); // 성공 시 해싱된 비밀번호 반환
  }

  Future<ValidationResult> ValidateAndChangeEmail({
    required String newID,
    required String newPW,
    required String newPW2,
    required String newEmail,
    required UserDataProvider userDataProvider,
  }) async {
    // 1. 모든 필수 필드 입력 여부 확인
    if (newID.isEmpty || newPW.isEmpty || newPW2.isEmpty || newEmail.isEmpty) {
      return ValidationResult.failure('모든 필드를 입력해주세요.');
    }

    // 2. 현재 비밀번호와 확인 비밀번호 일치 여부 확인
    if (newPW != newPW2) {
      return ValidationResult.failure('비밀번호가 일치하지 않습니다.');
    }

    // 3. ID 존재 여부 확인 (UserDataProvider 통해)
    if (!userDataProvider.isUserRegistered(newID)) {
      return ValidationResult.failure('해당 ID로 가입된 회원은 없습니다.');
    }

    // 4. 기존 이메일 주소와 동일한지 확인
    String? registeredEmail = userDataProvider.registeredUsers[newID]?["email"];
    if (registeredEmail == newEmail) {
      return ValidationResult.failure('기존 E메일 주소와 동일합니다. 다른 주소를 입력해주세요.');
    }

    // 5. 변경하려는 이메일이 이미 다른 계정으로 등록되어 있는지 확인
    if (userDataProvider.isEmailEnlisted(newEmail)) {
      return ValidationResult.failure('입력하신 E메일은 이미 다른 계정으로 등록되어 있습니다.');
    }

    return ValidationResult.success('유효성 검사 성공');
  }
}