import 'package:flutter/material.dart';

import 'freebbs.dart';
import 'qnabbs.dart';
import 'appbar.dart';

class CommunityPage extends StatelessWidget {
  final String CSTitle; // 이전 페이지 제목을 받을 변수

  const CommunityPage({super.key, required this.CSTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: CSTitle),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
            onPressed: () {
              // FreeBBSPage로 이동하면서 title 값을 전달
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FreeBBSPage(CSTitle: CSTitle),
                ),
              );
            },
            child: Text('자유게시판'),
          ),
          ElevatedButton(
            onPressed: () {
              // QnABBSPage로 이동하면서 title 값을 전달
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QnABBSPage(CSTitle: CSTitle),
                ),
              );
            },
            child: Text('질문게시판'),
          ),
        ]
      ),
    );
  }
}