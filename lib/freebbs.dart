import 'package:flutter/material.dart';

class FreeBBSPage extends StatelessWidget {
  final String CSTitle; // 이전 페이지 제목을 받을 변수

  const FreeBBSPage({super.key, required this.CSTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(CSTitle), // 전달받은 제목 사용
      ),
      body: const Center(
        child: Text(
          '자유게시판이 들어올 자리입니다.',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}