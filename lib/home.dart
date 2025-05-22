import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'newexam.dart';
import 'solvedq.dart';
import 'community.dart';
import 'appbar.dart';
import 'UserDataProvider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatelessWidget {
  final String title;

  const HomePage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserDataProvider>(
      builder: (context, userDataProvider, child) {
        final bool isLoggedIn = userDataProvider.isLoggedIn;
        final User? currentUser = userDataProvider.currentUser;

        print('>>> MainPage Consumer rebuild: isLoggedIn = $isLoggedIn');
        if (isLoggedIn) {
          userDataProvider.loggedInUserId.then((id) {
            print('>>> MainPage Consumer: loggedInUserId (resolved) = $id');
          });
        }
        print('>>> MainPage Consumer: loggedInUserEmail = ${userDataProvider.loggedInUserEmail}');

        return Scaffold(
          appBar: CSAppBar(title: title),
          body: Column(
            children: [
              if (isLoggedIn && currentUser != null)
                Column(
                  children: [
                    FutureBuilder<String?>(
                      future: userDataProvider.loggedInUserId,
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Text('환영합니다, ${snapshot.data}님!');
                        }
                        return Container();
                      },
                    ),
                    if (!currentUser.emailVerified)
                      Column(
                        children: [
                          Text('이메일 인증이 필요합니다!'),
                          ElevatedButton(
                            onPressed: () async {
                              await currentUser.sendEmailVerification();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('인증 이메일을 다시 보냈습니다. 메일을 확인해주세요.')),
                              );
                            },
                            child: Text('인증 이메일 다시 보내기'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              // !!! 중요: 여기에 디버그 print 추가 !!!
                              print('>>> [인증 새로고침 버튼] 클릭 전: currentUser.emailVerified = ${currentUser.emailVerified}');
                              await currentUser.reload(); // 사용자 정보 새로고침
                              print('>>> [인증 새로고침 버튼] 클릭 후 reload 완료: currentUser.emailVerified = ${currentUser.emailVerified}');
                              userDataProvider.notifyListeners(); // UserDataProvider에게 상태 변경 알림 (UI 업데이트용)
                              print('>>> [인증 새로고침 버튼] notifyListeners 호출됨.');
                              if (currentUser.emailVerified) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('이메일 인증이 확인되었습니다!')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('아직 이메일이 인증되지 않았습니다. 메일을 확인해주세요.')),
                                );
                              }
                            },
                            child: Text('인증 상태 새로고침'),
                          ),
                        ],
                      )
                    else
                      Text('이메일이 인증되었습니다.'),
                  ],
                )
              else
                Text('로그인이 필요합니다.'),
              Text('회원정보창입니다. 이 자리에 본인의 학습 내역이 들어올 예정입니다.'),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NewExamPage(title: title),
                          ),
                        );
                      },
                      child: Text('새 문제 풀어보기'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SolvedQuestionPage(title: title),
                          ),
                        );
                      },
                      child: Text('지난 문제 둘러보기'),
                    ),
                  ]
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CommunityPage(title: title),
                    ),
                  );
                },
                child: Text('커뮤니티'),
              ),
            ],
          ),
        );
      },
    );
  }
}