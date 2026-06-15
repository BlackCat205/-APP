import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户数据模型，包含基本个人信息。
class User {
  final String id;
  final String nickname;
  final String phone;
  final String email;
  final String avatar;

  const User({
    required this.id,
    required this.nickname,
    required this.phone,
    required this.email,
    required this.avatar,
  });

  /// 转换为可持久化的 Map 结构。
  Map<String, dynamic> toMap() => {
    'id': id,
    'nickname': nickname,
    'phone': phone,
    'email': email,
    'avatar': avatar,
  };

  /// 从 Map 构造 User 实例，缺失字段使用空字符串兜底。
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String? ?? '',
      nickname: map['nickname'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      avatar: map['avatar'] as String? ?? '',
    );
  }
}

/// 用户状态管理（登录、登出、信息持久化）。
class UserProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoggedIn = false;

  static const String _userKey = 'user_data';
  static const String _loginKey = 'is_logged_in';

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;

  // ---------- 本地加载 ----------
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

  // ---------- 持久化保存 ----------
  Future<void> _saveUser() async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    final map = _currentUser!.toMap();
    final userData =
        'id=${map['id']}'
        '&nickname=${Uri.encodeComponent(map['nickname'] as String)}'
        '&phone=${map['phone']}'
        '&email=${map['email']}'
        '&avatar=${Uri.encodeComponent(map['avatar'] as String)}';
    await prefs.setString(_userKey, userData);
    await prefs.setBool(_loginKey, true);
  }

  // ---------- 鉴权操作 ----------
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
    if (_currentUser == null) return;
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