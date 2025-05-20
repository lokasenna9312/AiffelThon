import 'package:flutter/material.dart';

class CSAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CSAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Text(title),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}