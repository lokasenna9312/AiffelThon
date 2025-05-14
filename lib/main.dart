import 'package:flutter/material.dart';
import 'newexam.dart';
import 'solvedq.dart';
import 'community.dart';

class MainPage extends StatelessWidget {
  final String CSTitle; // 이전 페이지 제목을 받을 변수

  const MainPage({super.key, required this.CSTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(CSTitle), // 전달받은 제목 사용
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewExamPage(CSTitle: CSTitle),
                        // 새 문제 풀어보기 페이지를 실제로 만들게 되면 윗줄의 NewExamPageTemp를 NewExamPage로 고칩니다.
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