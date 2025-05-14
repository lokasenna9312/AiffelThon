import 'package:flutter/material.dart';

import 'publishedexam.dart';
import 'qbank.dart';

class NewExamPage extends StatelessWidget {
  final String CSTitle; // 이전 페이지 제목을 받을 변수

  const NewExamPage({super.key, required this.CSTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(CSTitle), // 전달받은 제목 사용
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
            onPressed: () {
              // PublishedExam으로 이동하면서 title 값을 전달
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PublishedExam(CSTitle: CSTitle),
                ),
              );
            },
            child: Text('기출문제'),
          ),
          ElevatedButton(
            onPressed: () {
              // QnABBSPage로 이동하면서 title 값을 전달
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuestionBank(CSTitle: CSTitle),
                ),
              );
            },
            child: Text('문제은행'),
          ),
        ]
      ),
    );
  }
}