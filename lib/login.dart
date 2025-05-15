bool attemptLogin(id, pw) {
  Map<String, String> registeredUsers = {};
  registeredUsers['test'] = '1234';

  if (registeredUsers.containsKey(id) && registeredUsers[id] == pw) {
    print('로그인 성공!');
    return true;
  } else {
    print('로그인 실패: ID 또는 비밀번호가 일치하지 않습니다.');
    return false;
  }
}