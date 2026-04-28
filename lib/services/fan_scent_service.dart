import 'package:shared_preferences/shared_preferences.dart';

/// 风扇气味配置服务
class FanScentService {
  static const String _storageKey = 'fan_scent_config';

  // 可选气味列表
  static const List<String> availableScents = [
    '薰衣草',
    '檀香',
    '雪松',
    '甜橙',
    '柠檬',
    '玫瑰',
    '茉莉',
    '桂花',
    '百合',
    '薄荷',
    '绿茶',
    '海洋',
    '木质',
    '香草',
    '白桃',
    '葡萄',
    '蓝莓',
    '沉香',
    '柑橘',
    '栀子花',
  ];

  // 默认配置
  static const Map<int, String> _defaultConfig = {
    1: '薰衣草',
    2: '檀香',
    3: '雪松',
    4: '甜橙',
  };

  // 内存缓存
  static Map<int, String> _config = {};
  static bool _initialized = false;

  /// 初始化，加载保存的配置
  static Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);

    if (saved != null) {
      // 解析保存的配置
      final pairs = saved.split(',');
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final fanId = int.tryParse(parts[0]);
          final scent = parts[1];
          if (fanId != null && availableScents.contains(scent)) {
            _config[fanId] = scent;
          }
        }
      }
    }

    // 补充默认配置
    for (final entry in _defaultConfig.entries) {
      _config.putIfAbsent(entry.key, () => entry.value);
    }

    _initialized = true;
  }

  /// 获取风扇气味
  static String getFanScent(int fanId) {
    if (!_initialized) {
      // 未初始化时返回默认值
      return _defaultConfig[fanId] ?? '薰衣草';
    }
    return _config[fanId] ?? _defaultConfig[fanId] ?? '薰衣草';
  }

  /// 设置风扇气味
  static Future<void> setFanScent(int fanId, String scentName) async {
    if (!availableScents.contains(scentName)) return;

    _config[fanId] = scentName;
    await _saveToStorage();
  }

  /// 批量设置4个风扇气味
  static Future<void> setAllFanScents(Map<int, String> scents) async {
    for (final entry in scents.entries) {
      if (availableScents.contains(entry.value)) {
        _config[entry.key] = entry.value;
      }
    }
    await _saveToStorage();
  }

  /// 保存到本地存储
  static Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final pairs = _config.entries.map((e) => '${e.key}:${e.value}').join(',');
    await prefs.setString(_storageKey, pairs);
  }

  /// 获取当前所有配置
  static Map<int, String> getAllConfig() {
    return Map.from(_config);
  }
}
