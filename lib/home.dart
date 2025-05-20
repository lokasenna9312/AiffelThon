import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'newexam.dart';
import 'solvedq.dart';
import 'community.dart';
import 'appbar.dart';
import 'register.dart';
import 'deleteaccount.dart';

class MainPage extends StatelessWidget {
  final String CSTitle; // 이전 페이지 제목을 받을 변수

  const MainPage({super.key, required this.CSTitle});

  @override
  Widget build(BuildContext context) {
    final userDataProvider = Provider.of<UserDataProvider>(context);
    final String? id = userDataProvider.loggedInUserId;
    final String? email = userDataProvider.loggedInUserEmail;

    return Scaffold(
      appBar: CSAppBar(title: CSTitle),
      body: Column(
        children: [
          Text("ID : $id\nE메일 : $email"),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewExamPage(CSTitle: CSTitle),
                      ),
                    );
                  },
                  child: Text('새 문제 풀어보기'),
                ),
              ElevatedButton(
                onPressed: () {
                  // SolvedQuestionPage로 이동하면서 title 값을 전달
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SolvedQuestionPage(CSTitle: CSTitle),
                    ),
                  );
                },
                child: Text('지난 문제 둘러보기'),
              ),
            ]
          ),
          ElevatedButton(
            onPressed: () {
              // CommunityPage로 이동하면서 title 값을 전달
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommunityPage(CSTitle: CSTitle),
                ),
              );
            },
            child: Text('커뮤니티'),
          ),
        ],
      ),
    );
  }
}