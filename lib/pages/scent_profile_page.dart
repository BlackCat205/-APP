import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/scent_profile.dart';
import '../providers/user_provider.dart';
import '../services/scent_profile_service.dart';

class ScentProfilePage extends StatefulWidget {
  const ScentProfilePage({super.key});
  @override
  State<ScentProfilePage> createState() => _ScentProfilePageState();
}

class _ScentProfilePageState extends State<ScentProfilePage> {
  Future<ScentProfile>? _profile;
  String? _user;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.watch<UserProvider>().currentUser?.id ?? 'local';
    if (_user != next) {
      _user = next;
      _profile = AppDatabase().database.then(
        (db) => ScentProfileService(db).load(next),
      );
    }
  }

  Future<void> _reload() async {
    final next = AppDatabase().database.then(
      (db) => ScentProfileService(db).load(_user!),
    );
    setState(() => _profile = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('我的气味画像')),
    body: FutureBuilder<ScentProfile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('暂时无法读取气味画像'),
                TextButton(onPressed: _reload, child: const Text('重试')),
              ],
            ),
          );
        }
        final profile = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _overview(profile),
              _traits(profile),
              _combinations(profile),
              _trend(profile),
              _ai(profile),
            ],
          ),
        );
      },
    ),
  );

  Widget _overview(ScentProfile p) => _card(
    '使用概览',
    Row(
      children: [
        Expanded(child: _metric('${p.useCount}', '可靠使用次数')),
        Expanded(child: _metric(_duration(p.totalSeconds), '累计使用时长')),
      ],
    ),
  );

  Widget _traits(ScentProfile p) => _card(
    '偏好标签',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.preferredTraits.isEmpty && p.dislikedTraits.isEmpty)
          const Text('完成更多反馈并生成 AI 分析后显示；这里不会根据气味名称猜测标签。'),
        if (p.preferredTraits.isNotEmpty) ...[
          const Text('偏好'),
          Wrap(
            spacing: 8,
            children: p.preferredTraits
                .map((e) => Chip(label: Text(e)))
                .toList(),
          ),
        ],
        if (p.dislikedTraits.isNotEmpty) ...[
          const Text('不偏好'),
          Wrap(
            spacing: 8,
            children: p.dislikedTraits
                .map((e) => Chip(label: Text(e)))
                .toList(),
          ),
        ],
      ],
    ),
  );

  Widget _combinations(ScentProfile p) => _card(
    '常用组合',
    p.commonCombinations.isEmpty
        ? const Text('还没有可靠的组合使用记录')
        : Column(
            children: [
              for (final item in p.commonCombinations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text(_duration(item.seconds)),
                  trailing: Text('${item.count} 次'),
                ),
            ],
          ),
  );

  Widget _trend(ScentProfile p) => _card(
    '偏好变化',
    p.preferenceTrend.isEmpty
        ? const Text('提交喜欢程度后，这里会显示最近的变化')
        : Column(
            children: [
              for (final point in p.preferenceTrend)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text(DateFormat('M/d').format(point.time)),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: point.liking / 5,
                          minHeight: 8,
                        ),
                      ),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${point.liking.toStringAsFixed(0)}/5',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );

  Widget _ai(ScentProfile p) => _card(
    'AI 学习记录',
    p.aiConfidence == null && p.aiReason == null
        ? Text(
            p.aiStatus == 'pending' ? '有新反馈等待分析；断网时不会影响行为推荐。' : '尚无 AI 分析记录。',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.aiUpdatedAt != null)
                Text(
                  '更新时间：${DateFormat('yyyy-MM-dd HH:mm').format(p.aiUpdatedAt!)}',
                ),
              if (p.aiConfidence != null)
                Text('置信度：${(p.aiConfidence! * 100).round()}%'),
              if (p.aiReason != null && p.aiReason!.isNotEmpty)
                Text(p.aiReason!),
            ],
          ),
  );

  Widget _card(String title, Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );

  Widget _metric(String value, String label) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      Text(label, style: const TextStyle(color: Colors.grey)),
    ],
  );

  String _duration(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final minutes = seconds ~/ 60;
    return minutes < 60
        ? '$minutes 分钟'
        : '${minutes ~/ 60} 小时 ${minutes % 60} 分钟';
  }
}
