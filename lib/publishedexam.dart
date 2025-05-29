import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appbar.dart';
import 'dart:async'; // Debouncer를 위해 추가

class PublishedExamPage extends StatefulWidget {
  final String title; // 이전 페이지 제목을 받을 변수
  const PublishedExamPage({super.key, required this.title});

  @override
  State<PublishedExamPage> createState() => _PublishedExamPageState();
}

class _PublishedExamPageState extends State<PublishedExamPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 선택된 값들을 저장할 변수
  String? _selectedYear;
  String? _selectedRound;
  String? _selectedGrade;

  // 동적으로 채워질 옵션 리스트
  List<String> _yearOptions = [];
  // 현재 선택된 년도와 회차에 따라 필터링된 등급 옵션
  List<String> _filteredGradeOptions = [];
  // 현재 선택된 년도에 따라 필터링된 회차 옵션
  List<String> _filteredRoundOptions = [];


  // 모든 문서 ID에서 추출한 파싱된 데이터
  // 예: [{'year': '2023', 'round': '1회차', 'grade': 'A등급'}, ...]
  List<Map<String, String>> _parsedDocIds = [];

  bool _isLoadingOptions = true;
  bool _isLoadingquestions = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _questions = [];

  // Debouncer (연속적인 Firestore 호출 방지용)
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchAndParseDocumentIds();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // 문서 ID 파싱 함수
  // 예: "2023-1회차-A등급" -> {'year': '2023', 'round': '1회차', 'grade': 'A등급'}
  // 실패 시 null 반환
  Map<String, String>? _parseDocumentId(String docId) {
    final parts = docId.split('-');
    if (parts.length == 3) {
      return {
        'year': parts[0].trim(),
        'round': parts[1].trim(),
        'grade': parts[2].trim(),
      };
    }
    print('Warning: Could not parse document ID: $docId');
    return null;
  }

  Future<void> _fetchAndParseDocumentIds() async {
    setState(() {
      _isLoadingOptions = true;
      _errorMessage = '';
    });

    try {
      final QuerySnapshot snapshot = await _firestore.collection('exam').get();
      final Set<String> years = {};
      final List<Map<String, String>> parsedIds = [];

      for (var doc in snapshot.docs) {
        final parsed = _parseDocumentId(doc.id);
        if (parsed != null) {
          parsedIds.add(parsed);
          years.add(parsed['year']!);
        }
      }

      _parsedDocIds = parsedIds; // 파싱된 전체 ID 정보 저장
      _yearOptions = years.toList()..sort(); // 중복 제거 및 정렬

      if (_yearOptions.isEmpty && _parsedDocIds.isEmpty) {
        _errorMessage = '시험 데이터를 찾을 수 없습니다. Firestore에 문서를 추가해주세요.';
      }

    } catch (e) {
      _errorMessage = '옵션 정보를 불러오는 중 오류 발생: $e';
      print('Error fetching document IDs: $e');
    } finally {
      setState(() {
        _isLoadingOptions = false;
      });
    }
  }

  // 년도 선택 시 호출되어 해당 년도의 회차 옵션을 업데이트
  void _updateRoundOptions(String? selectedYear) {
    _selectedYear = selectedYear;
    _selectedRound = null; // 회차 선택 초기화
    _selectedGrade = null; // 등급 선택 초기화
    _questions = []; // 문제 목록 초기화

    if (selectedYear == null) {
      _filteredRoundOptions = [];
      _filteredGradeOptions = [];
    } else {
      final Set<String> rounds = {};
      for (var parsedId in _parsedDocIds) {
        if (parsedId['year'] == selectedYear) {
          rounds.add(parsedId['round']!);
        }
      }
      _filteredRoundOptions = rounds.toList()..sort(); // 중복 제거 및 정렬
      _filteredGradeOptions = []; // 등급 옵션도 초기화
    }
    setState(() {}); // UI 업데이트
  }

  // 회차 선택 시 호출되어 해당 년도/회차의 등급 옵션을 업데이트
  void _updateGradeOptions(String? selectedRound) {
    _selectedRound = selectedRound;
    _selectedGrade = null; // 등급 선택 초기화
    _questions = []; // 문제 목록 초기화

    if (_selectedYear == null || selectedRound == null) {
      _filteredGradeOptions = [];
    } else {
      final Set<String> grades = {};
      for (var parsedId in _parsedDocIds) {
        if (parsedId['year'] == _selectedYear && parsedId['round'] == selectedRound) {
          grades.add(parsedId['grade']!);
        }
      }
      _filteredGradeOptions = grades.toList()..sort(); // 중복 제거 및 정렬
    }
    setState(() {}); // UI 업데이트
  }


  String _formatDocumentId() {
    return '${_selectedYear}-${_selectedRound}-${_selectedGrade}';
  }

  List<int> _parsequestionNumberString(String? questionNoStr) {
    if (questionNoStr == null || questionNoStr.isEmpty) {
      // 기본값 또는 오류 처리 (예: 매우 큰 값을 반환하여 뒤로 보내거나, 특정 규칙 적용)
      return [99999, 99999]; // 예시: 파싱 불가한 경우 맨 뒤로
    }
    final parts = questionNoStr.split('_');
    int mainNo = 0;
    int subNo = 0;

    if (parts.isNotEmpty) {
      mainNo = int.tryParse(parts[0]) ?? 99999; // 파싱 실패 시 기본값
    }

    if (parts.length > 1) {
      subNo = int.tryParse(parts[1]) ?? 0; // 부번호는 없거나 0일 수 있음, 파싱 실패 시 0
    }
    return [mainNo, subNo];
  }

  Future<void> _fetchquestions() async {
    if (_selectedYear == null || _selectedRound == null || _selectedGrade == null) {
      setState(() {
        _errorMessage = '모든 항목을 선택해주세요.';
        _questions = [];
      });
      return;
    }

    setState(() {
      _isLoadingquestions = true;
      _errorMessage = '';
      _questions = []; // 화면에 표시될 문제 목록 (주 문제 + 하위 문제 flatten)
    });

    final String documentId = _formatDocumentId(); // 예: "2023-1회차-A등급"

    try {
      final DocumentSnapshot documentSnapshot =
      await _firestore.collection('exam').doc(documentId).get();

      if (documentSnapshot.exists) {
        final Map<String, dynamic>? documentData =
        documentSnapshot.data() as Map<String, dynamic>?;

        if (documentData != null) {
          List<Map<String, dynamic>> mainquestionsOnly = [];

          // 문서의 각 필드(키-값 쌍)를 순회합니다.
          // 여기서 키(key)는 "1", "2" 등 주 문제 번호 문자열(필드 이름)입니다.
          // 값(value)은 해당 주 문제의 상세 정보(Map) 및 sub_questions 리스트를 포함하는 맵입니다.
          documentData.forEach((mainquestionKey, mainquestionValue) {
            if (mainquestionValue is Map<String, dynamic>) {
              Map<String, dynamic> mainquestionData = Map<String, dynamic>.from(mainquestionValue);

              // 주 문제 자체를 리스트에 추가
              // UI에서 구분을 위해 플래그나 접두사 추가 가능 (예시)
              // mainquestionData['isSub'] = false;
              // mainquestionData['displayPrefix'] = '';
              mainquestionsOnly.add(mainquestionData);
            }
          });

          if (mainquestionsOnly.isNotEmpty) {
            _questions = mainquestionsOnly;
            // 문제 정렬 (커스텀 정렬 함수 사용, 'no' 필드는 String으로 처리)
            _questions.sort((a, b) {
              final String? noStrA = a['no'] as String?; // Firestore의 'no' 필드 값을 String으로 읽음
              final String? noStrB = b['no'] as String?; // Firestore의 'no' 필드 값을 String으로 읽음

              final List<int> parsedA = _parsequestionNumberString(noStrA);
              final List<int> parsedB = _parsequestionNumberString(noStrB);

              // 1. 주 번호 비교
              if (parsedA[0] != parsedB[0]) {
                return parsedA[0].compareTo(parsedB[0]);
              }
              // 2. 주 번호가 같으면 부 번호 비교
              return parsedA[1].compareTo(parsedB[1]);
            });
          } else {
            _errorMessage = '문서(${documentId}) 내에 문제 데이터가 발견되지 않았거나 형식이 올바르지 않습니다.';
          }
        } else {
          // 이 경우는 documentSnapshot.exists는 true이지만 data()가 null을 반환하는 매우 드문 케이스
          _errorMessage = '시험 문서(${documentId}) 데이터를 가져올 수 없습니다 (data is null).';
        }
      } else {
        _errorMessage = '선택한 조건의 시험 문서(${documentId})를 찾을 수 없습니다.';
      }
    } catch (e, s) {
      _errorMessage = '문제를 불러오는 중 오류가 발생했습니다.';
      print('Error fetching questions (Current Structure): $e');
      print('Stack trace for current error: $s');
      if (e is TypeError) { // 타입 에러를 구체적으로 잡아서 메시지 표시
        _errorMessage = '문제 데이터 타입 오류입니다. Firestore의 "no" 필드가 문자열인지, 앱 코드에서 올바르게 처리하는지 확인해주세요. 오류: $e';
      }
    } finally {
      setState(() {
        _isLoadingquestions = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: widget.title),
      body: Column(
        children: [
          if (_isLoadingOptions)
            const Center(child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ))
          else if (_yearOptions.isEmpty && _errorMessage.isNotEmpty)
            Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
          else ...[
            // 년도 선택 드롭다운
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: '시행년도', border: OutlineInputBorder()),
              value: _selectedYear,
              hint: const Text('년도 선택'),
              items: _yearOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: _updateRoundOptions, // 년도 변경 시 회차 옵션 업데이트
              disabledHint: _isLoadingOptions ? const Text("옵션 로딩 중...") : null,
            ),
            const SizedBox(height: 12),

            // 회차 선택 드롭다운
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: '회차', border: OutlineInputBorder()),
              value: _selectedRound,
              hint: const Text('회차 선택'),
              items: _filteredRoundOptions.map((String value) { // 필터링된 회차 옵션 사용
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (_selectedYear == null) ? null : _updateGradeOptions, // 년도가 선택되어야 활성화
              disabledHint: _selectedYear == null ? const Text("년도를 먼저 선택하세요") : null,
            ),
            const SizedBox(height: 12),

            // 등급 선택 드롭다운
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: '등급', border: OutlineInputBorder()),
              value: _selectedGrade,
              hint: const Text('등급 선택'),
              items: _filteredGradeOptions.map((String value) { // 필터링된 등급 옵션 사용
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (_selectedRound == null) ? null : (String? newValue) {
                setState(() {
                  _selectedGrade = newValue;
                  _questions = []; // 등급 변경 시 문제 목록 초기화
                });
              },
              disabledHint: _selectedRound == null ? const Text("회차를 먼저 선택하세요") : null,
            ),
            const SizedBox(height: 20),

            // 문제 불러오기 버튼
            ElevatedButton(
              onPressed: (_selectedYear == null || _selectedRound == null || _selectedGrade == null || _isLoadingquestions)
                  ? null // 모든 항목이 선택되지 않았거나, 문제 로딩 중이면 비활성화
                  : _fetchquestions,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isLoadingquestions
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : const Text('문제 불러오기', style: TextStyle(fontSize: 16)),
            ),
          ],
        const SizedBox(height: 20),

        // 오류 메시지 표시
        if (_errorMessage.isNotEmpty && !_isLoadingOptions) // 옵션 로딩 중 오류는 위에서 처리
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),

          // 문제 목록 표시
          Expanded(
            child: _isLoadingquestions
                ? const Center(child: CircularProgressIndicator())
                : _questions.isEmpty && !_isLoadingOptions && _errorMessage.isEmpty
                ? Center(child: Text(_selectedYear == null || _selectedRound == null || _selectedGrade == null ? '모든 항목을 선택하고 문제를 불러오세요.' : '선택한 조건의 문제가 없습니다.'))
                : ListView.builder(
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final mainquestion = _questions[index];
                final String? mainquestionNo = mainquestion['no'] as String?;
                final String mainQuestionText = mainquestion['question'] as String? ?? '내용 없음';
                final String? mainAnswerText = mainquestion['answer'] as String?;
                final String mainquestionType = mainquestion['type'] as String? ?? '타입 정보 없음';

                // sub_questions 맵 가져오기 및 UI용 리스트로 변환
                final dynamic subQuestionsField = mainquestion['sub_questions'];
                List<Map<String, dynamic>> subQuestionsForDisplay = [];
                if (subQuestionsField is Map<String, dynamic>) {
                  Map<String, dynamic> subQuestionsMap = subQuestionsField;
                  List<String> sortedSubKeys = subQuestionsMap.keys.toList();
                  sortedSubKeys.sort((a, b) =>
                      (int.tryParse(a) ?? 99999).compareTo(int.tryParse(b) ?? 99999));
                  for (String subKey in sortedSubKeys) {
                    final dynamic subQuestionValue = subQuestionsMap[subKey];
                    if (subQuestionValue is Map<String, dynamic>) {
                      subQuestionsForDisplay.add(Map<String, dynamic>.from(subQuestionValue));
                    }
                  }
                } else if (subQuestionsField != null) {
                  print("경고: mainquestion['no'] = ${mainquestion['no']}의 sub_questions 필드가 Map이 아닙니다. 타입: ${subQuestionsField.runtimeType}");
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                  child: ExpansionTile(
                    key: PageStorageKey(mainquestionNo),
                    title: Text(
                      '문제 ${mainquestionNo ?? '번호 없음'} (${mainquestionType})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(mainQuestionText, textAlign: TextAlign.start), // 부제목도 왼쪽 정렬 명시
                    // ExpansionTile 내부 children의 기본 패딩을 제거하여 직접 제어
                    childrenPadding: EdgeInsets.zero,
                    // tilePadding도 필요에 따라 조정 (기본값은 horizontal: 16.0)
                    // tilePadding: EdgeInsets.zero, // 제목 부분의 패딩도 제거하려면

                    children: <Widget>[
                      // 모든 children 내용을 하나의 Column으로 감싸고 왼쪽 정렬 및 일관된 패딩 적용
                      Container( // 전체 children 영역에 일관된 왼쪽 패딩 적용
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0, top: 8.0), // 상단 패딩도 추가
                        width: double.infinity, // Column이 가로 전체 너비를 차지하도록
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, // 이 Column의 자식들을 모두 왼쪽 정렬
                          children: [
                            // 주 문제의 정답 표시 (발문이 아니고 정답이 있을 경우)
                            if (mainquestionType != "발문" && mainAnswerText != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0), // 정답 위아래 간격
                                child: Text(
                                  '정답: $mainAnswerText',
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.start, // 명시적 왼쪽 정렬
                                ),
                              ),

                            // 구분선 (주 문제 정답과 하위 문제 사이, 필요하다면)
                            if ((mainquestionType != "발문" && mainAnswerText != null) && subQuestionsForDisplay.isNotEmpty)
                              const Divider(height: 16.0),

                            // 하위 문제들 표시
                            if (subQuestionsForDisplay.isNotEmpty)
                              ...subQuestionsForDisplay.map((subquestion) { // ... (spread operator) 사용하여 위젯 리스트 바로 삽입
                                final String? subNo = subquestion['no'] as String?;
                                final String subQuestionText = subquestion['question'] as String? ?? '내용 없음';
                                final String? subAnswer = subquestion['answer'] as String?;
                                final String subType = subquestion['type'] as String? ?? '타입 정보 없음';

                                String displaySubNo = subNo ?? "";
                                if (subNo != null && subNo.contains("_")) {
                                  displaySubNo = "(${subNo.split('_').last})";
                                } else if (subNo != null) {
                                  displaySubNo = "($subNo)";
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0), // 각 하위 문제 항목 간 간격
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, // 하위 문제 내용 왼쪽 정렬
                                    children: [
                                      Text(
                                        '${displaySubNo} ${subQuestionText}',
                                        style: const TextStyle(fontSize: 15),
                                        textAlign: TextAlign.start, // 명시적 왼쪽 정렬
                                      ),
                                      if (subAnswer != null && subType != "발문") ...[
                                        const SizedBox(height: 4),
                                        Padding( // 정답 텍스트에만 약간의 왼쪽 추가 들여쓰기 (선택적)
                                          padding: const EdgeInsets.only(left: 8.0),
                                          child: Text(
                                            '정답: $subAnswer',
                                            style: const TextStyle(color: Colors.green, fontSize: 14),
                                            textAlign: TextAlign.start, // 명시적 왼쪽 정렬
                                          ),
                                        ),
                                      ]
                                    ],
                                  ),
                                );
                              }).toList(), // map의 결과를 리스트로 변환
                          ],
                        ),
                      ),
                    ],
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