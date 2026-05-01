import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'SystemSettingsPage.dart';
import 'LoginPage.dart';
import 'AIScentAssistantPage.dart';
import 'scent_memory/scent_memory_page.dart';
import 'smell_memory/smell_list_page.dart';
import 'care_history_page.dart';
import 'database_viewer_page.dart';
import '../providers/user_provider.dart';

// 常量定义：抽离硬编码，提升可维护性
const double kDefaultPadding = 16.0;
const double kCardRadius = 8.0;
const double kIconSize = 24.0;
const String kVersionInfo = 'v1.0.0';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late UserProvider _userProvider;

  @override
  void initState() {
    super.initState();
    // 提前初始化Provider，减少重复获取
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _userProvider.loadUser();
  }

  /// 退出登录弹窗
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await _userProvider.logout();
              if (mounted) {
                // 判空避免context失效
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已退出登录')));
              }
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 登录提示弹窗
  void _showLoginTipDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: const Text('请先登录'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text('去登录', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 构建用户信息卡片
  Widget _buildUserInfoCard() {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return GestureDetector(
          onTap: () {
            if (!userProvider.isLoggedIn) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kCardRadius),
              color: Colors.red[50],
            ),
            child: Row(
              children: [
                // 用户头像
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                  ),
                  child: const Center(
                    child: Icon(Icons.person, size: 40, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 16),
                // 用户信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userProvider.isLoggedIn
                            ? userProvider.currentUser!.nickname
                            : '用户昵称',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userProvider.isLoggedIn
                            ? userProvider.currentUser!.phone
                            : '点击登录',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // 登录/退出按钮
                userProvider.isLoggedIn
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

  /// 构建服务选项Item
  Widget _buildServiceItem({
    required String title,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final double itemWidth = (MediaQuery.of(context).size.width - 64) / 5;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: itemWidth,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: bgColor,
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: kIconSize),
              ),
            ),
            const SizedBox(height: 8),
            Text(title),
          ],
        ),
      ),
    );
  }

  /// 构建我的服务模块
  Widget _buildServiceModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '我的服务',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: kDefaultPadding),
        Center(
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              // 个性化设置
              _buildServiceItem(
                title: '个性化设置',
                icon: Icons.settings,
                bgColor: Colors.purple[100]!,
                iconColor: Colors.purple,
                onTap: () {
                  // 跳转到个性化设置页
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建系统设置模块
  Widget _buildSystemSettingsModule() {
    return Container(
      padding: const EdgeInsets.all(kDefaultPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        children: [
          // 系统设置
          _buildSettingItem(
            title: '系统设置',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SystemSettingsPage(),
              ),
            ),
          ),
          const SizedBox(height: kDefaultPadding),
          const Divider(height: 1, color: Colors.grey),
          const SizedBox(height: kDefaultPadding),
          // 气味记忆
          _buildSettingItem(
            title: '气味记忆',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SmellListPage()),
            ),
          ),
          const SizedBox(height: kDefaultPadding),
          const Divider(height: 1, color: Colors.grey),
          const SizedBox(height: kDefaultPadding),
          // 关于我们
          _buildSettingItem(
            title: '关于我们',
            onTap: () {
              // 跳转到关于我们页
            },
          ),
          const SizedBox(height: kDefaultPadding),
          const Divider(height: 1, color: Colors.grey),
          const SizedBox(height: kDefaultPadding),
          // 数据库调试（开发专用）
          _buildSettingItem(
            title: '数据库调试',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DatabaseViewerPage(),
                ),
              );
            },
          ),
          const SizedBox(height: kDefaultPadding),
          const Divider(height: 1, color: Colors.grey),
          const SizedBox(height: kDefaultPadding),
          // 版本信息
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('版本信息'),
              Text(kVersionInfo, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建设置项
  Widget _buildSettingItem({
    required String title,
    required VoidCallback onTap,
  }) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人中心')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserInfoCard(),
            const SizedBox(height: 32),
            _buildSystemSettingsModule(),
            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AIScentAssistantPageWrapper(),
            ),
          );
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.smart_toy),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
