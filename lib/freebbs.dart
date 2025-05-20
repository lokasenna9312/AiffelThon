import 'package:flutter/material.dart';

import 'appbar.dart';

class FreeBBSPage extends StatelessWidget {
  final String CSTitle; // 이전 페이지 제목을 받을 변수

  const FreeBBSPage({super.key, required this.CSTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: CSTitle),
      body: const Center(
        child: Text(
          '자유게시판이 들어올 자리입니다.',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}