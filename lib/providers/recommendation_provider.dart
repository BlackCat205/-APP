import 'package:flutter/foundation.dart';
import '../models/recommendation.dart';
import '../services/recommendation_service.dart';

/// 监听提交后的使用/反馈、用户切换及气味配置；过期异步结果不得覆盖新结果。
class RecommendationProvider extends ChangeNotifier {
  RecommendationProvider({
    required this.source,
    required this.usageChanges,
    required this.usageBusy,
    required this.userChanges,
    required this.userId,
    required this.configChanges,
    this.additionalChanges = const [],
    this.updatePreference,
  }) {
    usageChanges.addListener(_onUsage);
    userChanges.addListener(_onContext);
    configChanges.addListener(_onContext);
    for (final changes in additionalChanges) {
      changes.addListener(_onUsage);
    }
    refresh();
  }
  final RecommendationSource source;
  final Listenable usageChanges, userChanges, configChanges;
  final List<Listenable> additionalChanges;
  final Future<bool> Function(String userId)? updatePreference;
  final bool Function() usageBusy;
  final String Function() userId;
  RecommendationReport? report;
  bool loading = false;
  bool aiUpdating = false;
  String? error;
  int _selectedIndex = 0;
  int _generation = 0;
  bool _disposed = false;

  Recommendation? get current {
    final items = report?.recommendations ?? const <Recommendation>[];
    if (items.isEmpty) return null;
    return items[_selectedIndex.clamp(0, items.length - 1)];
  }

  void showNext() {
    final length = report?.recommendations.length ?? 0;
    if (length < 2) return;
    _selectedIndex = (_selectedIndex + 1) % length;
    notifyListeners();
  }

  void _onUsage() {
    if (!usageBusy()) refresh();
  }

  void _onContext() {
    refresh(clear: true);
  }

  Future<void> refresh({bool clear = false}) async {
    if (_disposed) return;
    final generation = ++_generation;
    final user = userId();
    if (clear || report?.userId != user) {
      report = null;
      _selectedIndex = 0;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await source.recommend(user);
      if (_disposed || generation != _generation || user != userId()) return;
      report = result;
      _selectedIndex = 0;
      loading = false;
      notifyListeners();
      if (updatePreference != null) {
        aiUpdating = true;
        notifyListeners();
        var updated = false;
        try {
          updated = await updatePreference!(user);
        } catch (_) {
          // AI 失败不能清空已经可用的离线行为推荐。
        }
        if (_disposed || generation != _generation || user != userId()) return;
        aiUpdating = false;
        notifyListeners();
        if (updated) await refresh();
        return;
      }
    } catch (_) {
      if (_disposed || generation != _generation) return;
      report = null;
      loading = false;
      error = '暂时无法读取推荐，请重试';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    usageChanges.removeListener(_onUsage);
    userChanges.removeListener(_onContext);
    configChanges.removeListener(_onContext);
    for (final changes in additionalChanges) {
      changes.removeListener(_onUsage);
    }
    super.dispose();
  }
}
