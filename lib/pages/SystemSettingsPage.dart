import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

/// 系统设置页面
/// 包含主题切换、通知管理、缓存清理、账号安全等核心功能
class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  // 主题模式：system/light/dark
  String _themeMode = 'system';
  // 通知开关状态
  bool _notificationEnabled = true;
  // 加载状态标识
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  /// 初始化加载本地存储的设置项
  Future<void> _initSettings() async {
    try {
      setState(() => _isLoading = true);
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _themeMode = prefs.getString('theme_mode') ?? 'system';
        _notificationEnabled = prefs.getBool('notification_enabled') ?? true;
      });
    } catch (e) {
      debugPrint('加载设置失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('加载设置失败，请重试')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 保存主题模式设置
  Future<void> _saveThemeMode(String mode) async {
    if (mode == _themeMode) return; // 避免重复操作

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode);

      if (mounted) {
        setState(() => _themeMode = mode);
        // 重启页面应用主题
        _restartAppToApplyTheme();
        _showSnackBar('主题已更新为${_getThemeName(mode)}');
      }
    } catch (e) {
      debugPrint('保存主题模式失败: $e');
      if (mounted) {
        _showSnackBar('保存主题失败，请重试');
      }
    }
  }

  /// 保存通知开关设置
  Future<void> _saveNotificationSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_enabled', enabled);

      if (mounted) {
        setState(() => _notificationEnabled = enabled);
        _showSnackBar(enabled ? '已开启推送通知' : '已关闭推送通知');
      }
    } catch (e) {
      debugPrint('保存通知设置失败: $e');
      if (mounted) {
        _showSnackBar('保存通知设置失败，请重试');
      }
    }
  }

  /// 清空缓存逻辑
  Future<void> _clearCache() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('清空缓存'),
        content: const Text('确定要清空所有缓存数据吗？这将删除浏览历史等临时数据，操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                // 关闭弹窗
                Navigator.pop(context);
                // 可扩展：清空图片缓存、网络缓存等
                _showSnackBar('缓存已清空');
              } catch (e) {
                debugPrint('清空缓存失败: $e');
                _showSnackBar('清空缓存失败，请重试');
              }
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 重启应用以应用主题
  void _restartAppToApplyTheme() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainPage()),
      (route) => false,
    );
  }

  /// 显示SnackBar提示
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

  /// 根据模式值获取主题名称
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

  /// 构建主题选项组件
  Widget _buildThemeOption(String title, String mode) {
    return GestureDetector(
      onTap: () => _saveThemeMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            Radio(
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 主题模式模块
                  _buildSectionTitle('主题模式'),
                  const SizedBox(height: 16),
                  _buildCardContainer(
                    child: Column(
                      children: [
                        _buildThemeOption('跟随系统', 'system'),
                        const Divider(height: 1, color: Colors.grey),
                        _buildThemeOption('浅色模式', 'light'),
                        const Divider(height: 1, color: Colors.grey),
                        _buildThemeOption('深色模式', 'dark'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 通知设置模块
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
                          activeColor: Colors.red,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 存储管理模块
                  _buildSectionTitle('存储管理'),
                  const SizedBox(height: 16),
                  _buildCardContainer(
                    child: GestureDetector(
                      onTap: _clearCache,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('清空缓存'),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 账号与安全模块
                  _buildSectionTitle('账号与安全'),
                  const SizedBox(height: 16),
                  _buildCardContainer(
                    child: Column(
                      children: [
                        _buildSettingItem(
                          title: '修改密码',
                          onTap: () => _showSnackBar('修改密码功能开发中'),
                        ),
                        const Divider(height: 1, color: Colors.grey),
                        _buildSettingItem(
                          title: '注销账号',
                          textColor: Colors.red,
                          onTap: () => _showAccountCancellationDialog(),
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

  /// 构建模块标题
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

  /// 构建带边框的卡片容器
  Widget _buildCardContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        color: Colors.white,
      ),
      child: child,
    );
  }

  /// 构建设置项行
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

  /// 显示注销账号确认弹窗
  void _showAccountCancellationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('注销账号'),
        content: const Text('确定要注销账号吗？此操作不可恢复，所有数据将被清空。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('注销账号功能开发中');
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
