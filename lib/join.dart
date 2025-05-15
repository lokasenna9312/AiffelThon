import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart'; // 앱 내부 저장소 경로 접근

class UserDataProvider extends ChangeNotifier {
  Map<String, String> _registeredUsers = {};

  Map<String, String> get registeredUsers => _registeredUsers;

  void addUser(String id, String pw) async {
    _registeredUsers[id] = pw;
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
      print('회원 정보가 JSON 파일로 저장되었습니다: $jsonString');
    } catch (e) {
      print('회원 정보 저장 중 오류 발생: $e');
    }
  }

  // JSON 파일에서 회원 정보를 로드하는 메소드 (추가적으로 구현할 수 있습니다.)
  Future<void> loadUsersFromJson() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/users.json');
      print('회원 정보 로드 시작 - 파일 경로: ${file.path}');
      if (await file.exists()) {
        String jsonString = await file.readAsString();
        print('파일 내용: $jsonString');
        Map<String, dynamic> parsedJson = jsonDecode(jsonString);
        _registeredUsers = parsedJson.cast<String, String>();
        print('회원 정보 로드 완료: $_registeredUsers'); // 이 로그를 추가하세요.
        notifyListeners();
      } else {
        print('저장된 회원 정보 파일이 없습니다.');
      }
    } catch (e) {
      print('회원 정보 로드 중 오류 발생: $e');
    }
  }
}