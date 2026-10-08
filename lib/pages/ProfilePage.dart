import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'LoginPage.dart';
import 'SystemSettingsPage.dart';
import 'database_viewer_page.dart';
import 'scent_library_page.dart';
import 'AIScentAssistantPage.dart'; // 直接引入，替换原包装器
import 'smell_memory/smell_list_page.dart';
import 'scent_profile_page.dart';
import 'usage_feedback_page.dart';

/// 个人中心页面
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final UserProvider _userProvider;

  // ========== 样式常量 ==========
  static const double _defaultPadding = 16.0;
  static const double _cardRadius = 8.0;
  static const double _avatarSize = 80.0;
  static const double _iconSize = 40.0;
  static const String _versionInfo = 'v1.0.0';

  @override
  void initState() {
    super.initState();
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _userProvider.loadUser();
  }

  // ---------- 弹窗 ----------
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await _userProvider.logout();
              if (!mounted) return;
              Navigator.pop(dialogContext);
              _showSnackBar('已退出登录');
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLoginTipDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('提示'),
        content: const Text('请先登录'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text('去登录', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ---------- UI 组件 ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人中心')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(_defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserInfoCard(),
            const SizedBox(height: 32),
            _buildSystemSettingsModule(),
          ],
        ),
      ),
      // 修复：直接跳转到 AIScentAssistantPage
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AIScentAssistantPage()),
          );
        },
        child: const Icon(Icons.smart_toy),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildUserInfoCard() {
    return Consumer<UserProvider>(
      builder: (_, userProvider, __) {
        final isLoggedIn = userProvider.isLoggedIn;
        return GestureDetector(
          onTap: () {
            if (!isLoggedIn) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_cardRadius),
              color: Colors.red[50],
            ),
            child: Row(
              children: [
                // 头像
                Container(
                  width: _avatarSize,
                  height: _avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person,
                      size: _iconSize,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLoggedIn
                            ? userProvider.currentUser!.nickname
                            : '用户昵称',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isLoggedIn ? userProvider.currentUser!.phone : '点击登录',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                isLoggedIn
                    ? IconButton(
                        icon: const Icon(Icons.logout, color: Colors.grey),
                        onPressed: _showLogoutDialog,
                        tooltip: '退出登录',
                      )
                    : const Icon(Icons.arrow_forward_ios, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemSettingsModule() {
    return Container(
      padding: const EdgeInsets.all(_defaultPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        children: [
          _buildSettingItem(
            '系统设置',
            onTap: () => _navigateTo(const SystemSettingsPage()),
          ),
          _buildDivider(),
          _buildSettingItem('气味记忆', onTap: () => _navigateTo(SmellListPage())),
          _buildDivider(),
          _buildSettingItem(
            '你的气味库',
            onTap: () => _navigateTo(const ScentLibraryPage()),
          ),
          _buildDivider(),
          _buildSettingItem(
            '我的气味画像',
            onTap: () => _navigateTo(const ScentProfilePage()),
          ),
          _buildDivider(),
          _buildSettingItem(
            '使用反馈记录',
            onTap: () => _navigateTo(const UsageFeedbackHistoryPage()),
          ),
          _buildDivider(),
          _buildSettingItem('关于我们', onTap: () {}),
          _buildDivider(),
          _buildSettingItem(
            '数据库调试',
            onTap: () => _navigateTo(const DatabaseViewerPage()),
          ),
          _buildDivider(),
          _buildVersionRow(),
        ],
      ),
    );
  }

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildDivider() {
    return const Column(
      children: [
        SizedBox(height: _defaultPadding),
        Divider(height: 1, color: Colors.grey),
        SizedBox(height: _defaultPadding),
      ],
    );
  }

  Widget _buildSettingItem(String title, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildVersionRow() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('版本信息'),
        Text(_versionInfo, style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}
