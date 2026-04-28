import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String id;
  final String nickname;
  final String phone;
  final String email;
  final String avatar;

  User({
    required this.id,
    required this.nickname,
    required this.phone,
    required this.email,
    required this.avatar,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nickname': nickname,
      'phone': phone,
      'email': email,
      'avatar': avatar,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      nickname: map['nickname'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      avatar: map['avatar'] ?? '',
    );
  }
}

class UserProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoggedIn = false;
  static const String _userKey = 'user_data';
  static const String _loginKey = 'is_logged_in';

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_loginKey) ?? false;
    final userData = prefs.getString(_userKey);

    if (isLoggedIn && userData != null) {
      final map = Uri.splitQueryString(userData);
      _currentUser = User.fromMap(map);
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  Future<void> _saveUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser != null) {
      final map = _currentUser!.toMap();
      final userData = 'id=${map['id']}&nickname=${Uri.encodeComponent(map['nickname'])}&phone=${map['phone']}&email=${map['email']}&avatar=${Uri.encodeComponent(map['avatar'])}';
      await prefs.setString(_userKey, userData);
      await prefs.setBool(_loginKey, true);
    }
  }

  Future<void> login({
    required String phone,
    required String nickname,
    String? email,
    String? avatar,
  }) async {
    _currentUser = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nickname: nickname,
      phone: phone,
      email: email ?? '',
      avatar: avatar ?? '',
    );
    _isLoggedIn = true;
    await _saveUser();
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_loginKey);
    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<void> updateUser({
    String? nickname,
    String? avatar,
  }) async {
    if (_currentUser != null) {
      _currentUser = User(
        id: _currentUser!.id,
        nickname: nickname ?? _currentUser!.nickname,
        phone: _currentUser!.phone,
        email: _currentUser!.email,
        avatar: avatar ?? _currentUser!.avatar,
      );
      await _saveUser();
      notifyListeners();
    }
  }
}