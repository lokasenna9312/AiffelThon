import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appbar.dart'; // 사용자 정의 AppBar
import 'dart:async';
import 'dart:math'; // 랜덤 선택
import 'package:uuid/uuid.dart'; // 고유 ID 생성을 위해 추가 (pubspec.yaml에 uuid 패키지 추가 필요)

class QuestionBankPage extends StatefulWidget {
  final String title;
  const QuestionBankPage({super.key, required this.title});

  @override
  State<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends State<QuestionBankPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid(); // 고유 ID 생성기

  String? _selectedGrade; // ★★★ 문제 풀 구성의 핵심 필터
  int? _numberOfRandomQuestions;

  List<String> _yearOptions = [];
  List<String> _filteredRoundOptions = [];
  List<String> _filteredGradeOptions = []; // 등급 선택 UI용
  List<Map<String, String>> _parsedDocIds = []; // 모든 문서의 파싱된 ID (등급 필터링에 사용)

  bool _isLoadingOptions = true;
  bool _isLoadingquestions = false;
  String _errorMessage = '';

  // _allFetchedMainQuestions는 이제 사용하지 않거나 다른 용도로 사용 가능
  List<Map<String, dynamic>> _randomlySelectedQuestions = []; // 최종적으로 화면에 표시될 랜덤 선택 문제

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool?> _submissionStatus = {};
  final Map<String, String> _userSubmittedAnswers = {};

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // _fetchAndParseDocumentIds는 이제 모든 문서 ID를 가져와서 등급 목록 등을 만드는 데 주로 사용
    _fetchAndParseAllDocumentIdsForOptions();
  }

  // 모든 문서 ID를 파싱하여 드롭다운 옵션, 특히 등급 옵션을 채우는 함수
  Future<void> _fetchAndParseAllDocumentIdsForOptions() async {
    if (!mounted) return;
    setState(() => _isLoadingOptions = true);
    _parsedDocIds.clear();
    _yearOptions.clear();
    _filteredRoundOptions.clear();
    _filteredGradeOptions.clear(); // 등급 옵션도 초기화

    final Set<String> years = {};
    final Set<String> rounds = {}; // 모든 회차 옵션 (선택적)
    final Set<String> grades = {}; // 모든 등급 옵션

    try {
      final snapshot = await _firestore.collection('exam').get();
      for (var doc in snapshot.docs) {
        final parts = doc.id.split('-');
        if (parts.length == 3) {
          final parsedData = {'year': parts[0].trim(), 'round': parts[1].trim(), 'grade': parts[2].trim()};
          _parsedDocIds.add(parsedData);
          years.add(parsedData['year']!);
          rounds.add(parsedData['round']!);
          grades.add(parsedData['grade']!);
        }
      }
      _yearOptions = years.toList()..sort();
      // _filteredRoundOptions = rounds.toList()..sort(); // 필요하다면 전체 회차 목록
      _filteredGradeOptions = grades.toList()..sort(); // 전체 등급 목록으로 변경

      if (_yearOptions.isEmpty && mounted) _errorMessage = '시험 데이터가 없습니다.';
    } catch (e) {
      if (mounted) _errorMessage = '옵션 로딩 중 오류: $e';
      print('Error fetching all document IDs: $e');
    } finally {
      if (mounted) setState(() => _isLoadingOptions = false);
    }
  }

  // TextEditingController 관리 (키는 이제 uniqueDisplayId 사용)
  TextEditingController _getControllerForProblem(String uniqueDisplayId) {
    return _controllers.putIfAbsent(uniqueDisplayId, () {
      return TextEditingController(text: _userSubmittedAnswers[uniqueDisplayId]);
    });
  }

  void _clearAllAttemptStatesAndQuestions() {
    _controllers.values.forEach((controller) => controller.clear());
    _submissionStatus.clear();
    _userSubmittedAnswers.clear();
    _randomlySelectedQuestions = []; // 랜덤 문제 리스트 초기화
    // _allFetchedMainQuestions 관련 로직도 필요하면 초기화
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // 년도, 회차 선택은 이제 UI 필터용, 실제 문제 풀은 등급 기준으로만.
  void _updateSelectedGrade(String? grade) {
    if (!mounted) return;
    setState(() {
      _selectedGrade = grade;
      _errorMessage = '';
      _clearAllAttemptStatesAndQuestions(); // 등급 변경 시 이전 문제 및 상태 초기화
    });
  }


  Map<String, dynamic> _cleanNewlinesRecursive(Map<String, dynamic> problemData) {
    Map<String, dynamic> cleanedData = {};
    problemData.forEach((key, value) {
      if (value is String) {
        cleanedData[key] = value.replaceAll('\\n', '\n');
      } else if (key == 'sub_questions' && value is Map) {
        Map<String, dynamic> nestedCleanedSubQuestions = {};
        (value as Map<String, dynamic>).forEach((subKey, subValue) {
          if (subValue is Map<String, dynamic>) {
            nestedCleanedSubQuestions[subKey] = _cleanNewlinesRecursive(subValue);
          } else {
            nestedCleanedSubQuestions[subKey] = subValue;
          }
        });
        cleanedData[key] = nestedCleanedSubQuestions;
      } else if (key == 'sub_sub_questions' && value is Map) { // sub_sub_questions도 Map으로 가정
        Map<String, dynamic> nestedCleanedSubSubQuestions = {};
        (value as Map<String, dynamic>).forEach((subSubKey, subSubValue) {
          if (subSubValue is Map<String, dynamic>) {
            nestedCleanedSubSubQuestions[subSubKey] = _cleanNewlinesRecursive(subSubValue);
          } else {
            nestedCleanedSubSubQuestions[subSubKey] = subSubValue;
          }
        });
        cleanedData[key] = nestedCleanedSubSubQuestions;
      }
      else {
        cleanedData[key] = value;
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
      if (mounted) setState(() { _errorMessage = '출제할 문제 수를 입력해주세요.'; _clearAllAttemptStatesAndQuestions(); });
      return;
    }

    if (mounted) setState(() { _isLoadingquestions = true; _errorMessage = ''; _clearAllAttemptStatesAndQuestions(); });

    List<Map<String, dynamic>> pooledMainProblems = [];
    try {
      final querySnapshot = await _firestore.collection('exam').get();
      if (!mounted) return;

      for (var doc in querySnapshot.docs) {
        final parts = doc.id.split('-');
        if (parts.length == 3) {
          String docGrade = parts[2].trim();
          if (docGrade == _selectedGrade) { // 선택된 등급과 일치하는 문서만 처리
            final docData = doc.data(); // 이미 Map<String, dynamic>
            List<String> sortedMainProblemKeys = docData.keys.toList();
            sortedMainProblemKeys.sort((a, b) => (int.tryParse(a) ?? 99999).compareTo(int.tryParse(b) ?? 99999));

            for (String mainKey in sortedMainProblemKeys) {
              var mainValue = docData[mainKey];
              if (mainValue is Map<String, dynamic>) {
                Map<String, dynamic> questionData = Map<String, dynamic>.from(mainValue);
                // 각 문제 객체에 고유 ID 및 원본 문서 ID 추가
                questionData['uniqueDisplayId'] = _uuid.v4();
                questionData['originalDocId'] = doc.id;

                if (!questionData.containsKey('no') || (questionData['no'] as String?).isNullOrEmpty) {
                  questionData['no'] = mainKey;
                }
                // Newline 처리
                pooledMainProblems.add(_cleanNewlinesRecursive(questionData));
              }
            }
          }
        }
      }

      if (pooledMainProblems.isNotEmpty) {
        if (pooledMainProblems.length <= _numberOfRandomQuestions!) {
          _randomlySelectedQuestions = List.from(pooledMainProblems);
        } else {
          final random = Random();
          _randomlySelectedQuestions = [];
          List<Map<String, dynamic>> tempList = List.from(pooledMainProblems);
          for (int i = 0; i < _numberOfRandomQuestions!; i++) {
            if (tempList.isEmpty) break; // 풀에 문제가 부족하면 중단
            int randomIndex = random.nextInt(tempList.length);
            _randomlySelectedQuestions.add(tempList.removeAt(randomIndex));
          }
        }
        // 랜덤 선택 후에는 순서 유지를 위해 별도 정렬은 생략 (랜덤 순서 유지)
        if (_randomlySelectedQuestions.isEmpty && _numberOfRandomQuestions! > 0) {
          _errorMessage = '문제를 가져왔으나, 랜덤 선택 결과 문제가 없습니다. (문제 수 확인)';
        }

      } else { _errorMessage = "'$_selectedGrade' 등급에 해당하는 문제가 없습니다."; }
    } catch (e, s) {
      _errorMessage = '문제 풀 구성 중 오류 발생.';
      print('Error generating random exam: $e\nStack: $s');
    }
    finally { if (mounted) setState(() => _isLoadingquestions = false); }
  }

  // _checkAnswer, _tryAgain, _buildProblemInteractiveEntry 함수는 이전과 거의 동일
  // 단, _getControllerForProblem, _checkAnswer, _tryAgain은 이제 problem['uniqueDisplayId']를 키로 사용해야 함.
  // _buildProblemInteractiveEntry의 problemNo도 uniqueDisplayId를 사용하도록 수정
  void _checkAnswer(String uniqueDisplayId, String correctAnswerText, String problemType) { /* ... 기존 로직에서 problemNo 대신 uniqueDisplayId 사용 ... */
    final userAnswer = _controllers[uniqueDisplayId]?.text ?? "";
    String processedUserAnswer = userAnswer.trim();
    String processedCorrectAnswer = correctAnswerText.trim();
    bool isCorrect = processedUserAnswer.toLowerCase() == processedCorrectAnswer.toLowerCase();
    // ... (계산 문제 비교 로직) ...
    if (mounted) {
      setState(() {
        _userSubmittedAnswers[uniqueDisplayId] = userAnswer;
        _submissionStatus[uniqueDisplayId] = isCorrect;
      });
    }
  }

  void _tryAgain(String uniqueDisplayId) { /* ... problemNo 대신 uniqueDisplayId 사용 ... */
    if (mounted) {
      setState(() {
        _controllers[uniqueDisplayId]?.clear();
        _submissionStatus.remove(uniqueDisplayId);
        _userSubmittedAnswers.remove(uniqueDisplayId);
      });
    }
  }

  Widget _buildProblemInteractiveEntry({
    required Map<String, dynamic> problemData, // 여기에는 'uniqueDisplayId'가 포함되어 있어야 함
    required double leftIndent,
    required String displayPrefix,
  }) {
    final String? problemNoForDisplay = problemData['no'] as String?; // 화면 표시용 번호
    final String? uniqueDisplayId = problemData['uniqueDisplayId'] as String?; // 상태 관리용 고유 ID

    String questionTextFromFile = problemData['question'] as String? ?? '질문 없음';
    // _cleanNewlinesRecursive 에서 이미 처리했으므로, 여기서는 불필요 (또는 방어적으로 남겨둘 수 있음)
    // String questionTextForDisplay = questionTextFromFile.replaceAll('\\n', '\n');
    String questionTextForDisplay = questionTextFromFile;


    String? correctAnswerFromFile = problemData['answer'] as String?;
    String? correctAnswerForDisplay;
    if (correctAnswerFromFile != null) {
      // correctAnswerForDisplay = correctAnswerFromFile.replaceAll('\\n', '\n');
      correctAnswerForDisplay = correctAnswerFromFile; // _cleanNewlinesRecursive 에서 처리됨
    }

    final String problemType = problemData['type'] as String? ?? '타입 정보 없음';

    bool isAnswerable = (problemType == "단답형" || problemType == "계산" || problemType == "서술형") &&
        correctAnswerForDisplay != null &&
        uniqueDisplayId != null; // problemNo 대신 uniqueDisplayId 사용

    TextEditingController? controller = isAnswerable ? _getControllerForProblem(uniqueDisplayId!) : null;
    bool? currentSubmissionStatus = isAnswerable ? _submissionStatus[uniqueDisplayId!] : null;
    String? userSubmittedAnswerForDisplay = isAnswerable ? _userSubmittedAnswers[uniqueDisplayId!] : null;

    return Padding(
      padding: EdgeInsets.only(left: leftIndent, top: 8.0, bottom: 8.0, right: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text( // 화면 표시용 번호(displayPrefix)와 문제 타입 사용
            '$displayPrefix ${questionTextForDisplay} (${problemType})',
            style: TextStyle( /* ... 이전과 동일 ... */ ),
          ),
          // ... (나머지 TextField, 버튼, 피드백 UI는 uniqueDisplayId와 correctAnswerForDisplay를 사용하도록 수정) ...
          if (isAnswerable && controller != null && correctAnswerForDisplay != null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              enabled: currentSubmissionStatus == null,
              decoration: InputDecoration( /* ... */ ),
              onChanged: (text) { if (currentSubmissionStatus == null && mounted) setState(() {}); },
              onSubmitted: (value) {
                if (currentSubmissionStatus == null) {
                  _checkAnswer(uniqueDisplayId!, correctAnswerForDisplay!, problemType);
                }
              },
              maxLines: problemType == "서술형" ? null : 1,
              keyboardType: problemType == "서술형" ? TextInputType.multiline : TextInputType.text,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: currentSubmissionStatus == null
                      ? () { FocusScope.of(context).unfocus(); _checkAnswer(uniqueDisplayId!, correctAnswerForDisplay!, problemType); }
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
              Text('입력한 답: ${userSubmittedAnswerForDisplay ?? ""}'),
              Text('실제 정답: $correctAnswerForDisplay'),
            ],
          ] else if (correctAnswerForDisplay != null && problemType != "발문") ...[
            Text('정답: $correctAnswerForDisplay', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
          ] // ...
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: "${widget.title} - 랜덤 시험지"),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 8.0),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: '등급 선택', border: OutlineInputBorder()),
                  value: _selectedGrade,
                  hint: const Text('등급을 선택하세요'),
                  items: _filteredGradeOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: _updateSelectedGrade, // 변경 시 _clearAllAttemptStatesAndQuestions 호출됨
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: '랜덤 출제 문제 수 (예: 5)',
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
                  onPressed: (_selectedGrade == null || _isLoadingquestions || _numberOfRandomQuestions == null || _numberOfRandomQuestions! <=0)
                      ? null
                      : _fetchAndGenerateRandomExam,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), minimumSize: Size(double.infinity, 44)),
                  child: _isLoadingquestions
                      ? const SizedBox(height:20, width:20, child:CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                      : const Text('랜덤 시험지 생성', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          if (_errorMessage.isNotEmpty && !_isLoadingOptions && _randomlySelectedQuestions.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0), child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),

          Expanded(
            child: _isLoadingquestions
                ? const Center(child: CircularProgressIndicator())
                : _randomlySelectedQuestions.isEmpty
                ? Center(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_selectedGrade == null ? '먼저 등급과 문제 수를 선택하고 시험지를 생성하세요.' : '선택한 등급의 문제가 없거나, 문제 수가 유효하지 않습니다.', textAlign: TextAlign.center),
            ))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              itemCount: _randomlySelectedQuestions.length,
              itemBuilder: (context, index) {
                final mainQuestionData = _randomlySelectedQuestions[index];
                final String? mainQOriginalNo = mainQuestionData['no'] as String?; // Firestore의 원본 'no'
                final String mainQType = mainQuestionData['type'] as String? ?? '';
                final String mainQText = mainQuestionData['question'] as String? ?? ''; // _cleanNewlinesRecursive에서 이미 처리됨
                final String uniqueIdForMainQ = mainQuestionData['uniqueDisplayId'] as String;


                List<Widget> expansionChildren = [];

                // 주 문제 자체에 대한 답변 UI
                if (mainQType != "발문" || mainQuestionData.containsKey('answer')) {
                  expansionChildren.add(
                      _buildProblemInteractiveEntry(
                        problemData: mainQuestionData, // uniqueDisplayId 포함됨
                        leftIndent: 0.0,
                        displayPrefix: "본 문제 (${mainQOriginalNo ?? ''})",
                      )
                  );
                } else if (mainQType == "발문" && !mainQuestionData.containsKey('answer') && (mainQuestionData['sub_questions'] as Map?)?.isEmpty == true) {
                  expansionChildren.add(const Padding(padding: EdgeInsets.all(16.0), child: Text("하위 문제가 없습니다.", style: TextStyle(fontStyle: FontStyle.italic))));
                }

                // 하위 문제 (sub_questions) 처리
                final dynamic subQuestionsField = mainQuestionData['sub_questions'];
                if (subQuestionsField is Map<String, dynamic>) {
                  Map<String, dynamic> subQuestionsMap = subQuestionsField;
                  if (subQuestionsMap.isNotEmpty) {
                    if (expansionChildren.isNotEmpty && (mainQType != "발문" || mainQuestionData.containsKey('answer')) ) {
                      expansionChildren.add(const Divider(height: 10, thickness: 0.5, indent: 8, endIndent: 8,));
                    }
                    List<String> sortedSubKeys = subQuestionsMap.keys.toList();
                    sortedSubKeys.sort((a, b) => (int.tryParse(a) ?? 99999).compareTo(int.tryParse(b) ?? 99999));
                    for (String subKey in sortedSubKeys) {
                      final dynamic subQuestionValue = subQuestionsMap[subKey];
                      if (subQuestionValue is Map<String, dynamic>) {
                        Map<String, dynamic> subQData = Map.from(subQuestionValue);
                        // subQData에도 uniqueDisplayId와 newline 처리된 텍스트가 있어야 함 (fetch 단계에서 처리)
                        // 이 예제에서는 _cleanNewlinesRecursive가 fetch에서 호출된다고 가정
                        // subQData['uniqueDisplayId'] = _uuid.v4(); // 만약 fetch 시점에 추가 안했다면 여기서라도 해야 하지만, fetch에서 하는게 나음

                        String subQDisplayNo = "(${subKey})";
                        expansionChildren.add(
                            _buildProblemInteractiveEntry(
                              problemData: subQData,
                              leftIndent: 8.0,
                              displayPrefix: subQDisplayNo,
                            )
                        );
                        final dynamic subSubQuestionsField = subQData['sub_sub_questions'];
                        if (subSubQuestionsField is Map<String, dynamic>) {
                          Map<String, dynamic> subSubQuestionsMap = subSubQuestionsField;
                          if (subSubQuestionsMap.isNotEmpty) {
                            List<String> sortedSubSubKeys = subSubQuestionsMap.keys.toList();
                            sortedSubSubKeys.sort((a,b) => (int.tryParse(a) ?? 99999).compareTo(int.tryParse(b) ?? 99999));
                            for (String subSubKey in sortedSubSubKeys) {
                              final dynamic subSubQValue = subSubQuestionsMap[subSubKey];
                              if (subSubQValue is Map<String, dynamic>) {
                                Map<String, dynamic> subSubQData = Map.from(subSubQValue);
                                // subSubQData['uniqueDisplayId'] = _uuid.v4();
                                String subSubQDisplayNo = "ㄴ (${subSubKey})";
                                expansionChildren.add(
                                    _buildProblemInteractiveEntry(
                                      problemData: subSubQData,
                                      leftIndent: 16.0,
                                      displayPrefix: subSubQDisplayNo,
                                    )
                                );
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 4.0),
                  elevation: 1.0,
                  child: ExpansionTile(
                    key: ValueKey(uniqueIdForMainQ), // 고유 ID 사용
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    childrenPadding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0), // children 내부 공통 패딩
                    title: Text(
                      '문제 ${mainQOriginalNo ?? ""} (${mainQType})', // 원본 문제 번호로 표시
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                    ),
                    subtitle: mainQText.isNotEmpty
                        ? Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(mainQText, style: TextStyle(fontSize: 14.5, color: Colors.grey[800]), maxLines: 10, overflow: TextOverflow.ellipsis),
                    )
                        : null,
                    initiallyExpanded: _randomlySelectedQuestions.length == 1, // 한 문제만 있을 땐 펼치기
                    children: expansionChildren.isEmpty && mainQType == "발문"
                        ? <Widget>[const Padding(padding: EdgeInsets.all(16.0), child: Text("세부 내용이 없습니다.", style: TextStyle(fontStyle: FontStyle.italic)))]
                        : expansionChildren,
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

extension StringNullOrEmptyExtension on String? {
  bool get isNullOrEmpty {
    return this == null || this!.isEmpty;
  }
}