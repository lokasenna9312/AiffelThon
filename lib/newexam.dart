import 'package:flutter/material.dart';

import 'publishedexam.dart';
import 'qbank.dart';
import 'appbar.dart';

class NewExamPage extends StatelessWidget {
  final String title; // 이전 페이지 제목을 받을 변수

  const NewExamPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: title),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
            onPressed: () {
              // PublishedExam으로 이동하면서 title 값을 전달
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PublishedExam(title: title),
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
                  builder: (context) => QuestionBank(title: title),
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