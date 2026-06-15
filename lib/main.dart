import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'pages/HomeControlPage.dart';
import 'pages/ProfilePage.dart';
import 'pages/care_history_page.dart';
import 'pages/smell_memory/smell_edit_page.dart';
import 'pages/smell_memory/smell_list_page.dart';
import 'providers/device_provider.dart';
import 'providers/user_provider.dart';
import 'services/care_service.dart';
import 'services/fan_scent_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面端初始化 sqflite_common_ffi
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Hive.initFlutter();
  await FanScentService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// 应用根组件，管理主题、路由和全局初始化逻辑。
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _themeMode = 'system';

  // ========== 常量 ==========
  static const String _appTitle = '香氛App';
  static const String _fontFamily = 'Noto Sans SC';

  // 关怀弹窗样式
  static const Color _careBg = Color(0xFFF5E6D3);
  static const Color _careTitleColor = Color(0xFF2D2D2D);
  static const Color _careTextColor = Color(0xFF2D2D2D);
  static const Color _careButtonGray = Color(0xFF8C8C8C);
  static const Color _careButtonGreen = Color(0xFFA8D8B9);

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _loadUser();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkCare());
  }

  // ---------- 初始化 ----------

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _themeMode = prefs.getString('theme_mode') ?? 'system');
  }

  Future<void> _loadUser() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadUser();
  }

  Future<void> _checkCare() async {
    try {
      final care = await CareService.checkCare();
      if (care != null && context.mounted) {
        _showCareDialog(care);
      }
    } catch (e) {
      debugPrint('检查关怀失败: $e');
    }
  }

  // ---------- 关怀弹窗 ----------

  void _showCareDialog(Map<String, dynamic> care) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _careBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Center(
          child: Text(
            '💛 来自气味的关怀',
            style: TextStyle(fontWeight: FontWeight.w600, color: _careTitleColor),
          ),
        ),
        content: Text(
          care['message'] as String,
          style: const TextStyle(fontSize: 16, color: _careTextColor),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('稍后再说', style: TextStyle(color: _careButtonGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushReplacementNamed(context, '/');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _careButtonGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              '🌿 开始对应场景疗愈',
              style: TextStyle(color: _careTextColor),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 主题 ----------

  ThemeMode _getThemeMode() {
    switch (_themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appTitle,
      theme: ThemeData(primarySwatch: Colors.red, fontFamily: _fontFamily),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        fontFamily: _fontFamily,
      ),
      themeMode: _getThemeMode(),
      initialRoute: '/',
      routes: {
        '/': (_) => const MainPage(),
        '/smell-edit': (_) => const SmellEditPage(),
        '/smell-list': (_) => const SmellListPage(),
      },
    );
  }
}

/// 主页：底部导航栏切换三个页面。
class MainPage extends StatefulWidget {
  final int initialIndex;
  const MainPage({super.key, this.initialIndex = 0});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late int _currentIndex;

  // ========== 常量 ==========
  static const Color _selectedItemColor = Colors.red;
  static const Color _unselectedItemColor = Colors.grey;

  // 三个标签页
  static const List<Widget> _pages = [
    HomeControlPage(),
    CareHistoryPage(),
    ProfilePage(),
  ];

  // 导航栏项定义
  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '家'),
    BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: '气味关怀'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: _navItems,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _selectedItemColor,
        unselectedItemColor: _unselectedItemColor,
      ),
    );
  }
}