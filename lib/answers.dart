import 'package:flutter/material.dart';

import 'appbar.dart';

class AnswersPage extends StatelessWidget {
  final String CSTitle; // 이전 페이지 제목을 받을 변수

  const AnswersPage({super.key, required this.CSTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: CSTitle),
      body: const Center(
        child: Text(
          '정답체크 화면입니다.',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}