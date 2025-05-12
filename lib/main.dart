import 'package:flutter/material.dart';

class MainPage extends StatelessWidget {
  final String firstPageTitle; // 이전 페이지 제목을 받을 변수

  const MainPage({super.key, required this.firstPageTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(firstPageTitle), // 전달받은 제목 사용
      ),
      body: const Center(
        child: Text(
          '서술형도 한다 앱의 첫 화면입니다.',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}