import 'package:flutter/material.dart';

class AdminNavigationState extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  void select(int value) {
    if (_index == value) {
      return;
    }
    _index = value;
    notifyListeners();
  }
}

