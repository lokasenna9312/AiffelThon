import 'package:flutter/material.dart';

class AnswersPage extends StatelessWidget {
  final String CSTitle; // 이전 페이지 제목을 받을 변수

  const AnswersPage({super.key, required this.CSTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(CSTitle), // 전달받은 제목 사용
      ),
      body: const Center(
        child: Text(
          '정답체크 화면입니다.',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}