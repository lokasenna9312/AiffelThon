import 'package:flutter/material.dart';

class UserDataProvider extends ChangeNotifier {
  Map<String, String> _registeredUsers = {};

  Map<String, String> get registeredUsers => _registeredUsers;

  void addUser(String id, String pw) {
    _registeredUsers[id] = pw;
    notifyListeners(); // 데이터 변경을 리스너들에게 알림
  }

  bool isUserRegistered(String id) {
    return _registeredUsers.containsKey(id);
  }
}