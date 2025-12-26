import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  Map<String, dynamic>? _profile;

  Map<String, dynamic>? get profile => _profile;

  void setProfile(Map<String, dynamic> profile) {
    _profile = profile;
    notifyListeners();
  }

  void clearProfile() {
    _profile = null;
    notifyListeners();
  }
}
