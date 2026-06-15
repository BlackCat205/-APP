import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

/// 系统设置页面：主题切换、通知管理、缓存清理、账号安全
class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  String _themeMode = 'system';
  bool _notificationEnabled = true;
  bool _isLoading = false;

  // ========== 常量 ==========
  static const String _themeKey = 'theme_mode';
  static const String _notificationKey = 'notification_enabled';
  static const double _defaultPadding = 16.0;
  static const double _cardRadius = 8.0;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _themeMode = prefs.getString(_themeKey) ?? 'system';
        _notificationEnabled = prefs.getBool(_notificationKey) ?? true;
      });
    } catch (e) {
      debugPrint('加载设置失败: $e');
      _showSnackBar('加载设置失败，请重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveThemeMode(String mode) async {
    if (mode == _themeMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode);
      if (!mounted) return;
      setState(() => _themeMode = mode);
      _restartAppToApplyTheme();
      _showSnackBar('主题已更新为${_getThemeName(mode)}');
    } catch (e) {
      debugPrint('保存主题模式失败: $e');
      _showSnackBar('保存主题失败，请重试');
    }
  }

  Future<void> _saveNotificationSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationKey, enabled);
      if (!mounted) return;
      setState(() => _notificationEnabled = enabled);
      _showSnackBar(enabled ? '已开启推送通知' : '已关闭推送通知');
    } catch (e) {
      debugPrint('保存通知设置失败: $e');
      _showSnackBar('保存通知设置失败，请重试');
    }
  }

  Future<void> _clearCache() async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空缓存'),
        content: const Text('确定要清空所有缓存数据吗？这将删除浏览历史等临时数据，操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _showSnackBar('缓存已清空');
    }
  }

  void _restartAppToApplyTheme() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainPage()),
          (route) => false,
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getThemeName(String mode) {
    switch (mode) {
      case 'light':
        return '浅色模式';
      case 'dark':
        return '深色模式';
      default:
        return '跟随系统';
    }
  }

  void _showAccountCancellationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('注销账号'),
        content: const Text('确定要注销账号吗？此操作不可恢复，所有数据将被清空。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showSnackBar('注销账号功能开发中');
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ========== UI ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(_defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('主题模式'),
            const SizedBox(height: 16),
            _buildCardContainer(
              child: Column(
                children: [
                  _buildThemeOption('跟随系统', 'system'),
                  _buildDivider(),
                  _buildThemeOption('浅色模式', 'light'),
                  _buildDivider(),
                  _buildThemeOption('深色模式', 'dark'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('通知设置'),
            const SizedBox(height: 16),
            _buildCardContainer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('接收推送通知'),
                  Switch(
                    value: _notificationEnabled,
                    onChanged: _saveNotificationSetting,
                    activeThumbColor: Colors.red,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('存储管理'),
            const SizedBox(height: 16),
            _buildCardContainer(
              child: GestureDetector(
                onTap: _clearCache,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('清空缓存'),
                    Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('账号与安全'),
            const SizedBox(height: 16),
            _buildCardContainer(
              child: Column(
                children: [
                  _buildSettingItem(
                    title: '修改密码',
                    onTap: () => _showSnackBar('修改密码功能开发中'),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    title: '注销账号',
                    textColor: Colors.red,
                    onTap: _showAccountCancellationDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        color: Colors.white,
      ),
      child: child,
    );
  }

  Widget _buildThemeOption(String title, String mode) {
    return GestureDetector(
      onTap: () => _saveThemeMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            Radio<String>(
              value: mode,
              groupValue: _themeMode,
              onChanged: (value) {
                if (value != null) _saveThemeMode(value);
              },
              activeColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(color: textColor ?? Colors.black87)),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: Colors.grey);
  }
}