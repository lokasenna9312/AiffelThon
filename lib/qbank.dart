import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appbar.dart'; // 사용자 정의 AppBar (CSAppBar)
import 'dart:async';
import 'dart:math'; // 랜덤 선택
import 'package:uuid/uuid.dart'; // 고유 ID 생성을 위해 추가

// String extension for isNullOrEmpty (Dart 2.12+ 에서는 ?.isEmpty 로 충분)
// 하지만 null일 경우를 위해 확장 함수가 더 안전할 수 있습니다.
extension StringNullOrEmptyExtension on String? {
  bool get isNullOrEmpty {
    return this == null || this!.trim().isEmpty;
  }
}

class QuestionBankPage extends StatefulWidget {
  final String title;
  const QuestionBankPage({super.key, required this.title});

  @override
  State<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends State<QuestionBankPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  String? _selectedGrade;
  int? _numberOfRandomQuestions;

  List<String> _gradeOptions = [];
  List<Map<String, String>> _parsedDocIds = []; // 문서 ID와 파싱된 정보 저장

  bool _isLoadingOptions = true;
  bool _isLoadingQuestions = false;
  String _errorMessage = '';

  List<Map<String, dynamic>> _randomlySelectedQuestions = [];

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool?> _submissionStatus = {};
  final Map<String, String> _userSubmittedAnswers = {};

  @override
  void initState() {
    super.initState();
    _fetchAndParseAllDocumentIdsForOptions();
  }

  TextEditingController _getControllerForQuestion(String uniqueDisplayId) {
    return _controllers.putIfAbsent(uniqueDisplayId, () {
      return TextEditingController(text: _userSubmittedAnswers[uniqueDisplayId]);
    });
  }

  void _clearAllAttemptStatesAndQuestions() {
    if (!mounted) return;
    setState(() {
      _controllers.values.forEach((controller) => controller.clear());
      _submissionStatus.clear();
      _userSubmittedAnswers.clear();
      _randomlySelectedQuestions = [];
      _errorMessage = ''; // 오류 메시지도 초기화
    });
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _fetchAndParseAllDocumentIdsForOptions() async {
    if (!mounted) return;
    setState(() => _isLoadingOptions = true);
    _parsedDocIds.clear();
    _gradeOptions.clear();
    final Set<String> grades = {};
    try {
      final snapshot = await _firestore.collection('exam').get();
      if (!mounted) return;
      for (var doc in snapshot.docs) {
        final parts = doc.id.split('-');
        if (parts.length >= 3) {
          String grade = parts.last.trim();
          _parsedDocIds.add({'docId': doc.id, 'grade': grade}); // Firestore 문서 ID도 저장
          grades.add(grade);
        } else {
          print("Warning: Could not parse grade from doc ID: ${doc.id}");
        }
      }
      _gradeOptions = grades.toList()..sort();
      if (_gradeOptions.isEmpty && mounted) _errorMessage = '등급 데이터를 찾을 수 없습니다.';
    } catch (e) {
      if (mounted) _errorMessage = '옵션 로딩 중 오류: $e';
      print('Error fetching all document IDs for options: $e');
    } finally {
      if (mounted) setState(() => _isLoadingOptions = false);
    }
  }

  void _updateSelectedGrade(String? grade) {
    if (!mounted) return;
    setState(() {
      _selectedGrade = grade;
      _clearAllAttemptStatesAndQuestions();
    });
  }

  Map<String, dynamic> _cleanNewlinesRecursive(Map<String, dynamic> questionData, Uuid uuidGenerator) {
    Map<String, dynamic> cleanedData = {};

    // 현재 레벨의 문제에 uniqueDisplayId가 없으면 생성하여 할당
    cleanedData['uniqueDisplayId'] = questionData['uniqueDisplayId'] ?? uuidGenerator.v4();
    questionData.forEach((key, value) {
      if (key == 'uniqueDisplayId') return; // 이미 위에서 처리했으므로 건너뜀
      if (value is String) {
        cleanedData[key] = value.replaceAll('\\n', '\n');
      } else if ((key == 'sub_questions' || key == 'sub_sub_questions') && value is Map) {
        Map<String, dynamic> nestedCleanedMap = {};
        (value as Map<String, dynamic>).forEach((subKey, subValue) {
          if (subValue is Map<String, dynamic>) {
            // 재귀 호출 시에도 uuidGenerator 전달
            nestedCleanedMap[subKey] = _cleanNewlinesRecursive(subValue, uuidGenerator);
          } else {
            nestedCleanedMap[subKey] = subValue;
          }
        });
        cleanedData[key] = nestedCleanedMap;
      }
      else {
        cleanedData[key] = value; // 'no', 'question', 'answer', 'type' 등 다른 필드 복사
      }
    });
    return cleanedData;
  }


  Future<void> _fetchAndGenerateRandomExam() async {
    if (_selectedGrade == null) {
      if (mounted) setState(() { _errorMessage = '먼저 등급을 선택해주세요.'; _clearAllAttemptStatesAndQuestions(); });
      return;
    }
    if (_numberOfRandomQuestions == null || _numberOfRandomQuestions! <= 0) {
      if (mounted) setState(() { _errorMessage = '출제할 문제 수를 1 이상 입력해주세요.'; _clearAllAttemptStatesAndQuestions(); });
      return;
    }
    if (mounted) setState(() { _isLoadingQuestions = true; _errorMessage = ''; _clearAllAttemptStatesAndQuestions(); });

    List<Map<String, dynamic>> pooledMainQuestions = [];
    try {
      for (var docInfo in _parsedDocIds) { // _parsedDocIds에 docId와 grade가 이미 있음
        if (docInfo['grade'] == _selectedGrade) {
          final docSnapshot = await _firestore.collection('exam').doc(docInfo['docId']!).get();
          if (!mounted) return;
          if (docSnapshot.exists) {
            final docData = docSnapshot.data();
            if (docData != null) {
              List<String> sortedMainKeys = docData.keys.toList();
              sortedMainKeys.sort((a, b) => (int.tryParse(a) ?? 99999).compareTo(int.tryParse(b) ?? 99999));
              for (String mainKey in sortedMainKeys) {
                var mainValue = docData[mainKey];
                if (mainValue is Map<String, dynamic>) {
                  Map<String, dynamic> questionData = Map<String, dynamic>.from(mainValue);
                  questionData['uniqueDisplayId'] = _uuid.v4();
                  questionData['sourceExamId'] = docInfo['docId']!; // 출처(문서ID) 저장
                  if (!questionData.containsKey('no') || (questionData['no'] as String?).isNullOrEmpty) {
                    questionData['no'] = mainKey;
                  }
                  pooledMainQuestions.add(_cleanNewlinesRecursive(questionData, _uuid));
                }
              }
            }
          }
        }
      }

      if (pooledMainQuestions.isNotEmpty) {
        if (pooledMainQuestions.length <= _numberOfRandomQuestions!) {
          _randomlySelectedQuestions = List.from(pooledMainQuestions);
        } else {
          final random = Random();
          List<Map<String, dynamic>> tempList = List.from(pooledMainQuestions);
          for (int i = 0; i < _numberOfRandomQuestions!; i++) {
            if (tempList.isEmpty) break;
            int randomIndex = random.nextInt(tempList.length);
            _randomlySelectedQuestions.add(tempList.removeAt(randomIndex));
          }
        }
        if (_randomlySelectedQuestions.isEmpty && _numberOfRandomQuestions! > 0) {
          _errorMessage = '문제를 가져왔으나, 랜덤 선택 결과 문제가 없습니다.';
        }
      } else { _errorMessage = "'$_selectedGrade' 등급에 해당하는 문제가 전체 시험 데이터에 없습니다."; }
    } catch (e, s) {
      _errorMessage = '문제 풀 구성 중 오류 발생.';
      print('Error generating random exam: $e\nStack: $s');
    }
    finally { if (mounted) setState(() => _isLoadingQuestions = false); }
  }

  void _checkAnswer(String uniqueDisplayId, String correctAnswerText, String questionType) {
    final userAnswer = _controllers[uniqueDisplayId]?.text ?? "";
    String processedUserAnswer = userAnswer.trim();
    String processedCorrectAnswer = correctAnswerText.trim();
    bool isCorrect = processedUserAnswer.toLowerCase() == processedCorrectAnswer.toLowerCase();

    if (questionType == "계산" && !isCorrect) {
      RegExp numberAndUnitExtractor = RegExp(r"([0-9\.]+)\s*(\[.*?\])?");
      Match? userAnswerMatch = numberAndUnitExtractor.firstMatch(processedUserAnswer);
      Match? correctAnswerMatch = numberAndUnitExtractor.firstMatch(processedCorrectAnswer);
      if (userAnswerMatch != null && correctAnswerMatch != null) {
        String userAnswerVal = userAnswerMatch.group(1) ?? "";
        String correctAnswerVal = correctAnswerMatch.group(1) ?? "";
        if (double.tryParse(userAnswerVal) != null && double.tryParse(correctAnswerVal) != null) {
          isCorrect = (double.parse(userAnswerVal) - double.parse(correctAnswerVal)).abs() < 0.0001;
        } else { isCorrect = userAnswerVal == correctAnswerVal; }
      }
    }
    if (mounted) {
      setState(() {
        _userSubmittedAnswers[uniqueDisplayId] = userAnswer;
        _submissionStatus[uniqueDisplayId] = isCorrect;
      });
    }
  }

  void _tryAgain(String uniqueDisplayId) {
    if (mounted) {
      setState(() {
        _controllers[uniqueDisplayId]?.clear();
        _submissionStatus.remove(uniqueDisplayId);
        _userSubmittedAnswers.remove(uniqueDisplayId);
      });
    }
  }

  // 각 레벨의 문제를 그리는 재귀적 헬퍼 함수
  List<Widget> _buildQuestionHierarchyWidgets({
    required Map<String, dynamic> questionData, // 현재 레벨의 문제 데이터
    required double currentIndent,              // 현재 레벨의 들여쓰기
    required String currentOrderPrefix,         // 현재 레벨의 문제 번호 접두사 (예: "1.", "(a)", "i)")
    required bool showQuestionTextForThisLevel, // 현재 레벨에서 문제 텍스트를 표시할지 여부
  }) {
    List<Widget> widgets = [];
    final String? originalQuestionNo = questionData['no'] as String?; // Firestore 원본 no
    final String questionType = questionData['type'] as String? ?? '타입 정보 없음';

    // 현재 레벨의 문제 항목 UI 추가 (TextField 등 인터랙티브 요소 포함)
    widgets.add(_buildQuestionInteractiveDisplay(
      questionData: questionData,
      leftIndent: currentIndent,
      displayNoWithPrefix: currentOrderPrefix, // 화면에 표시될 번호 (예: "1.", "(a)")
      questionTypeToDisplay: (questionType == "발문") ? "" : " ($questionType)", // 발문이면 타입 숨김
      showQuestionText: showQuestionTextForThisLevel, // 질문 텍스트 표시 여부
    ));

    // 이 문제의 하위 문제들 (sub_questions) 처리
    final dynamic subQuestionsField = questionData['sub_questions'];
    if (subQuestionsField is Map<String, dynamic> && subQuestionsField.isNotEmpty) {
      Map<String, dynamic> subQuestionsMap = subQuestionsField;
      List<String> sortedSubKeys = subQuestionsMap.keys.toList();
      sortedSubKeys.sort((a, b) => (int.tryParse(a) ?? 99999).compareTo(int.tryParse(b) ?? 99999));

      int subOrderCounter = 0;
      for (String subKey in sortedSubKeys) {
        final dynamic subQuestionValue = subQuestionsMap[subKey];
        if (subQuestionValue is Map<String, dynamic>) {
          subOrderCounter++;
          // 하위 문제 번호 형식 (예: "(1)", "(2)")
          String subQuestionOrderPrefix = "($subOrderCounter)";
          widgets.addAll(_buildQuestionHierarchyWidgets( // 재귀 호출
            questionData: Map<String, dynamic>.from(subQuestionValue),
            currentIndent: currentIndent + 16.0, // 들여쓰기 증가
            currentOrderPrefix: subQuestionOrderPrefix,
            showQuestionTextForThisLevel: true, // 하위 레벨은 항상 질문 텍스트 표시
          ));
        }
      }
    }
    return widgets;
  }

  // 단일 문제의 인터랙티브 UI (TextField, 정답확인 등)를 생성하는 위젯
  Widget _buildQuestionInteractiveDisplay({
    required Map<String, dynamic> questionData,
    required double leftIndent,
    required String displayNoWithPrefix, // 예: "1.", "(1)", "ㄴ (a)" 등
    required String questionTypeToDisplay, // 예: "(단답형)" 또는 "" (발문인 경우)
    required bool showQuestionText, // 이 위젯 내에서 question 텍스트를 표시할지 여부
  }) {
    final String? uniqueDisplayId = questionData['uniqueDisplayId'] as String?;
    final String originalQuestionNo = questionData['no'] as String? ?? ''; // 디버깅/내부용

    String questionTextForDisplay = "";
    if (showQuestionText) { // 조건부로 질문 텍스트 구성
      questionTextForDisplay = questionData['question'] as String? ?? '질문 없음';
      // newline 처리는 _cleanNewlinesRecursive에서 이미 수행됨
    }

    String? correctAnswerForDisplay = questionData['answer'] as String?; // newline 처리됨
    final String actualQuestionType = questionData['type'] as String? ?? '타입 정보 없음'; // isAnswerable 조건용

    bool isAnswerable = (actualQuestionType == "단답형" || actualQuestionType == "계산" || actualQuestionType == "서술형") &&
        correctAnswerForDisplay != null &&
        uniqueDisplayId != null;

    TextEditingController? controller = isAnswerable ? _getControllerForQuestion(uniqueDisplayId!) : null;
    bool? currentSubmissionStatus = isAnswerable ? _submissionStatus[uniqueDisplayId!] : null;
    String? userSubmittedAnswerForDisplay = isAnswerable ? _userSubmittedAnswers[uniqueDisplayId!] : null;

    return Padding(
      padding: EdgeInsets.only(left: leftIndent, top: 8.0, bottom: 8.0, right: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showQuestionText) // 조건부 질문 텍스트 표시
            Text(
              '$displayNoWithPrefix ${questionTextForDisplay}${questionTypeToDisplay}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: leftIndent == 0 && showQuestionText ? FontWeight.w600 : (leftIndent < 24.0 ? FontWeight.w500 : FontWeight.normal),
              ),
            ),
          if (showQuestionText && isAnswerable) const SizedBox(height: 8), // 질문과 TextField 사이 간격

          if (isAnswerable && controller != null && correctAnswerForDisplay != null) ...[
            // ... TextField, 버튼, 피드백 UI (이전 _buildProblemInteractiveEntry와 동일, 변수명만 question으로) ...
            TextField( /* ... 이전과 동일 ... */
              controller: controller,
              enabled: currentSubmissionStatus == null,
              decoration: InputDecoration(
                hintText: '정답을 입력하세요...',
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                suffixIcon: (controller.text.isNotEmpty && currentSubmissionStatus == null)
                    ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { controller.clear(); if(mounted) setState((){});} )
                    : null,
              ),
              onChanged: (text) { if (currentSubmissionStatus == null && mounted) setState(() {}); },
              onSubmitted: (value) {
                if (currentSubmissionStatus == null) {
                  _checkAnswer(uniqueDisplayId!, correctAnswerForDisplay, actualQuestionType);
                }
              },
              maxLines: actualQuestionType == "서술형" ? null : 1,
              keyboardType: actualQuestionType == "서술형" ? TextInputType.multiline : TextInputType.text,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: currentSubmissionStatus == null
                      ? () { FocusScope.of(context).unfocus(); _checkAnswer(uniqueDisplayId!, correctAnswerForDisplay, actualQuestionType); }
                      : null,
                  child: Text(currentSubmissionStatus == null ? '정답 확인' : '채점 완료'),
                ),
                if (currentSubmissionStatus != null) ...[
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => _tryAgain(uniqueDisplayId!), child: const Text('다시 풀기')),
                ],
              ],
            ),
            if (currentSubmissionStatus != null) ...[
              const SizedBox(height: 8),
              Text(
                currentSubmissionStatus == true ? '정답입니다! 👍' : '오답입니다. 👎',
                style: TextStyle(color: currentSubmissionStatus == true ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
              ),
              Text('입력한 답: ${userSubmittedAnswerForDisplay ?? ""}'),
              Text('실제 정답: $correctAnswerForDisplay'),
            ],
          ] else if (correctAnswerForDisplay != null && actualQuestionType != "발문") ...[
            // TextField 없이 정답만 표시 (예: 그림 유형에 대한 설명 답안)
            Padding( // 정답 표시에 약간의 상단 간격
              padding: const EdgeInsets.only(top: 4.0),
              child: Text('정답: $correctAnswerForDisplay', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
            ),
          ] else if (actualQuestionType != "발문" && correctAnswerForDisplay == null && showQuestionText) ...[
            // showQuestionText가 true일 때만 이 메시지 표시 (주 문제의 TextField만 표시하는 경우 중복 방지)
            const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Text("텍스트 정답이 제공되지 않는 유형입니다.", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Colors.grey)),
            )
          ]
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: widget.title),
      body: Column(
        children: [
          // --- 등급 선택 및 문제 수 입력 UI ---
          Padding( /* ... 이전과 동일 ... */
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 8.0),
            child: Column(
              children: [
                if (_isLoadingOptions) const Center(child: CircularProgressIndicator())
                else DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: '등급 선택', border: OutlineInputBorder()),
                  value: _selectedGrade,
                  hint: const Text('풀어볼 등급을 선택하세요'),
                  items: _gradeOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: _updateSelectedGrade,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: '랜덤 출제 문제 수 (예: 18)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    if (mounted) setState(() { _numberOfRandomQuestions = int.tryParse(value); });
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: (_selectedGrade == null || _isLoadingQuestions || _numberOfRandomQuestions == null || _numberOfRandomQuestions! <=0)
                      ? null
                      : _fetchAndGenerateRandomExam,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), minimumSize: Size(double.infinity, 44)),
                  child: _isLoadingQuestions
                      ? const SizedBox(height:20, width:20, child:CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                      : const Text('랜덤 시험지 생성', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          if (_errorMessage.isNotEmpty && !_isLoadingOptions && _randomlySelectedQuestions.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0), child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),

          // --- 문제 목록 표시 ---
          Expanded(
            child: _isLoadingQuestions
                ? const Center(child: CircularProgressIndicator())
                : _randomlySelectedQuestions.isEmpty
                ? Center(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_selectedGrade == null ? '먼저 등급과 문제 수를 선택하고 시험지를 생성하세요.' : '선택한 등급의 문제가 없거나, 문제 수가 유효하지 않습니다.', textAlign: TextAlign.center),
            ))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              itemCount: _randomlySelectedQuestions.length, // 주 문제의 개수
              itemBuilder: (context, index) {
                final mainQuestionData = _randomlySelectedQuestions[index];
                final String pageOrderNo = "${index + 1}"; // 4. 페이지 내 순서
                final String? originalNo = mainQuestionData['no'] as String?;
                final String type = mainQuestionData['type'] as String? ?? '';
                final String questionText = (mainQuestionData['question'] as String? ?? ''); // newline 처리됨
                final String uniqueId = mainQuestionData['uniqueDisplayId'] as String;
                final String sourceExamId = mainQuestionData['sourceExamId'] as String? ?? '출처 미상'; // 3. 출처

                // 3. 문제 제목에 출처 표시, "발문" 타입 숨기기
                String titleDisplayType = (type == "발문" || type.isEmpty) ? "" : " ($type)";
                String mainTitleText = '문제 $pageOrderNo $titleDisplayType ($sourceExamId $originalNo번)';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 4.0),
                  elevation: 1.0,
                  child: ExpansionTile(
                    key: ValueKey(uniqueId),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    // 5. 원본 문제 반복 현상 해결: 주 문제 질문은 subtitle로, 인터랙티브 부분은 children으로
                    title: Text(mainTitleText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                    subtitle: questionText.isNotEmpty
                        ? Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(questionText, style: TextStyle(fontSize: 14.5, color: Colors.grey[800])),
                    )
                        : null,
                    initiallyExpanded: _randomlySelectedQuestions.length == 1,
                    // ExpansionTile의 children에는 _buildQuestionHierarchyWidgets 호출 결과만 넣음
                    // _buildQuestionHierarchyWidgets의 첫 번째 호출은 주 문제에 대한 것 (showQuestionText: false)
                    childrenPadding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0), // children 내부 공통 패딩
                    children: _buildQuestionHierarchyWidgets(
                      questionData: mainQuestionData,
                      currentIndent: 0, // 주 문제의 인터랙티브 부분은 기본 들여쓰기
                      currentOrderPrefix: "└ (풀이)", // 주 문제의 풀이 부분임을 나타내는 접두사
                      showQuestionTextForThisLevel: false, // 주 문제 질문은 subtitle로 갔으므로 여기선 false
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}