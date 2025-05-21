import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'changepw.dart';
import 'appbar.dart';
import 'ui_utils.dart';
import 'UserDataProvider.dart';

class ModifyAccountPage extends StatefulWidget {
  const ModifyAccountPage({super.key, required this.CSTitle});

  final String CSTitle;

  @override
  State<ModifyAccountPage> createState() => _ModifyAccountPageState();
}

class _ModifyAccountPageState extends State<ModifyAccountPage> {
  late UserDataProvider userDataProvider;
  late UserDataProviderUtility utility;
  final _newID = TextEditingController();
  final _newPW = TextEditingController();
  final _newEmail = TextEditingController();

  late String CSTitle; // CSTitle 변수 선언

  @override
  void initState() {
    super.initState();
    CSTitle = widget.CSTitle;
    userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    utility = UserDataProviderUtility();
  }

  void _changeEmail() async {
    final String newID = _newID.text.trim();
    final String newPW = _newPW.text.trim();
    final String newEmail = _newEmail.text.trim();
    
    final ValidationResult result = await utility.ValidateAndChangeEmail( // 반환 타입이 ValidationResult
      newID: newID,
      newPW: newPW,
      newEmail: newEmail,
      userDataProvider: userDataProvider,
    );

    if (!result.isSuccess) {
      showSnackBarMessage(context, result.message);
      return;
    }

    userDataProvider.changeEmail(newID, newPW, newEmail);
    showSnackBarMessage(context, 'E메일 주소가 변경되었습니다.\n바뀐 주소 : $newEmail');

    _newID.clear();
    _newPW.clear();
    _newEmail.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CSAppBar(title: CSTitle),
      body: Column(
        children: [
          TextField(
            controller: _newID,
            decoration: const InputDecoration(labelText: 'ID'),
          ),
          TextField(
            controller: _newPW,
            obscureText: true,
            decoration: const InputDecoration(labelText: '비밀번호'),
          ),
          TextField(
            controller: _newEmail,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          ElevatedButton(
            onPressed: () => _changeEmail(),
            child: Text('E메일 주소 변경'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangePWPage(CSTitle: CSTitle),
                ),
              );
            },
            child: Text('비밀번호 재설정 페이지로'),
          ),
        ],
      ),
    );
  }
}