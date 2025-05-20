import 'package:flutter/material.dart';

import 'appbar.dart';

class IncorrectNotePage extends StatelessWidget {
  final String CSTitle; // 이전 페이지 제목을 받을 변수

  const IncorrectNotePage({super.key, required this.CSTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: CSTitle),
      body: const Center(
        child: Text(
          '오답노트 화면입니다.',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}