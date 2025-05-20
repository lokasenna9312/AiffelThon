import 'package:flutter/material.dart';

import 'answers.dart';
import 'incorrectnote.dart';
import 'rematch.dart';
import 'appbar.dart';

class SolvedQuestionPage extends StatelessWidget {
  final String CSTitle; // 이전 페이지 제목을 받을 변수

  const SolvedQuestionPage({super.key, required this.CSTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: CSTitle),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: () {
                  // AnswersPage로 이동하면서 title 값을 전달
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnswersPage(CSTitle: CSTitle),
                    ),
                  );
                },
                child: Text('정답체크'),
              ),
              ElevatedButton(
                onPressed: () {
                  // IncorrectNotePage로 이동하면서 title 값을 전달
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IncorrectNotePage(CSTitle: CSTitle),
                    ),
                  );
                },
                child: Text('오답노트'),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              // RematchPage로 이동하면서 title 값을 전달
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RematchPage(CSTitle: CSTitle),
                ),
              );
            },
            child: Text('다시 풀어보기'),
          ),
        ]
      ),
    );
  }
}