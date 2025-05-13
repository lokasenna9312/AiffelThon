import 'package:flutter/material.dart';
import 'newexam_temporary.dart';
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
          Column( // 버튼들을 세로로 배치
            mainAxisAlignment: MainAxisAlignment.spaceAround, // 버튼 사이에 공간을 줌
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewExamPageTemp(CSTitle: CSTitle),
                      // 새 문제 풀어보기 페이지를 실제로 만들게 되면 윗줄의 NewExamPageTemp를 NewExamPage로 고칩니다.
                    ),
                  );
                },
                child: Text('새 문제 풀어보기'),
              ),
              ElevatedButton(
                onPressed: () {
                  // RegisterPage로 이동하면서 title 값을 전달
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SolvedQuestionPage(CSTitle: CSTitle),
                    ),
                  );
                },
                child: Text('지난 문제 둘러보기'),
              ),
              ElevatedButton(
                onPressed: () {
                  // RegisterPage로 이동하면서 title 값을 전달
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
        ]
      ),
    );
  }
}