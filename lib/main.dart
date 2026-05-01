import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/MallPage.dart';
import 'pages/HomeControlPage.dart';
import 'pages/ProfilePage.dart';
import 'pages/scent_memory/scent_memory_page.dart';
import 'pages/smell_memory/smell_save_popup.dart';
import 'pages/smell_memory/smell_edit_page.dart';
import 'pages/smell_memory/smell_list_page.dart';
import 'pages/care_history_page.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/user_provider.dart';
import 'providers/device_provider.dart'; // 新增导入
import 'providers/review_provider.dart'; // 新增导入
import 'services/care_service.dart'; // 新增导入
import 'services/fan_scent_service.dart'; // 风扇气味配置服务
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows/Linux 桌面端初始化 sqflite_common_ffi
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 初始化Hive
  await Hive.initFlutter();

  // 初始化风扇气味配置
  await FanScentService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => OrderProvider()),
        ChangeNotifierProvider(create: (context) => DeviceProvider()), // 新增
        ChangeNotifierProvider(create: (context) => ReviewProvider()), // 新增
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _themeMode = 'system';

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _loadUser();

    // 延迟执行，确保 context 已经准备好
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCare();
    });
  }

  /// 检查是否需要触发关怀提醒
  Future<void> _checkCare() async {
    try {
      final care = await CareService.checkCare();
      if (care != null && context.mounted) {
        _showCareDialog(care);
      }
    } catch (e) {
      print('检查关怀失败: $e');
    }
  }

  /// 显示关怀弹窗
  void _showCareDialog(Map<String, dynamic> care) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5E6D3), // 暖米色背景
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Center(
            child: Text(
              '💛 来自气味的关怀',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D2D2D),
              ),
            ),
          ),
          content: Text(
            care['message'] as String,
            style: TextStyle(fontSize: 16, color: const Color(0xFF2D2D2D)),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                '稍后再说',
                style: TextStyle(color: const Color(0xFF8C8C8C)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // 跳转到对应场景页面
                // 这里可以根据场景类型跳转到不同的页面
                // 暂时跳转到首页
                Navigator.pushReplacementNamed(context, '/');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA8D8B9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '🌿 开始对应场景疗愈',
                style: TextStyle(color: const Color(0xFF2D2D2D)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = prefs.getString('theme_mode') ?? 'system';
    });
  }

  Future<void> _loadUser() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadUser();
  }

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
      title: 'VR古建嗅觉沉浸式旅游',
      theme: ThemeData(primarySwatch: Colors.red, fontFamily: 'Noto Sans SC'),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        fontFamily: 'Noto Sans SC',
      ),
      themeMode: _getThemeMode(),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainPage(),
        '/smell-edit': (context) => const SmellEditPage(),
        '/smell-list': (context) => const SmellListPage(),
      },
    );
  }
}

class MainPage extends StatefulWidget {
  final int initialIndex; // 新增参数，默认值为0
  const MainPage({super.key, this.initialIndex = 0});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex; // 使用传入的初始索引
  }

  final List<Widget> _pages = [
    HomeControlPage(),
    MallPage(),
    const CareHistoryPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '家'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: '商城'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: '气味关怀'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
