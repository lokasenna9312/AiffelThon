import 'package:flutter/material.dart';
import 'package:dart_openai/dart_openai.dart';

class NewExamPageTemp extends StatefulWidget {
  final String CSTitle; // 이전 페이지 제목을 받을 변수

  const NewExamPageTemp({super.key, required this.CSTitle});

  @override
  _NewExamPageTempState createState() => _NewExamPageTempState();
}

class _NewExamPageTempState extends State<NewExamPageTemp> {
  final _formKey = GlobalKey<FormState>();
  String problemText = '';
  String answerText = '';
  String evaluationResult = '';

  Future<void> evaluateAnswer() async {
    /* OpenAI API 키 설정(실제 환경에서는 안전하게 관리 필요) */
    OpenAI.apiKey = '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';

    /* API 호출 */
    var response = await OpenAI.instance.completion.create(
      model: 'gpt-4.1',
      prompt: '주관식 문제 \'${problemText}\'에 대한 답안\'${answerText}\'을 평가하시오.',
      maxTokens: 100,
    );

    setState(() {
      evaluationResult = response.choices.first.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.CSTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: problemText,
                decoration: InputDecoration(labelText: '문제'),
                onChanged: (value) => setState(() => problemText = value),
              ),
              SizedBox(height: 20),
              TextFormField(
                initialValue: answerText,
                decoration: InputDecoration(labelText: '답변'),
                onChanged: (value) => setState(() => answerText = value),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: evaluateAnswer,
                child: Text('평가하기'),
              ),
              SizedBox(height: 20),
              Text(evaluationResult),
            ],
          ),
        ),
      ),
    );
  }
}