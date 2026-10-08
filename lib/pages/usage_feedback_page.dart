import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/usage_session_service.dart';
import '../services/smell_moment_repository.dart';
import '../providers/user_provider.dart';
import 'smell_memory/smell_edit_page.dart';

String feedbackUserId(BuildContext context) =>
    context.read<UserProvider>().currentUser?.id ?? 'local';

class BeforeUseInput {
  const BeforeUseInput(this.state, this.scene);
  final int? state;
  final String? scene;
}

Future<BeforeUseInput?> askBeforeUse(BuildContext context) {
  int? state;
  String? scene;
  return showDialog<BeforeUseInput>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('开始这次气味体验'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('记录此刻的舒适程度，结束后对比。可以不填写。'),
            DropdownButton<int>(
              isExpanded: true,
              value: state,
              hint: const Text('使用前舒适程度'),
              items: List.generate(
                5,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(
                    '${i + 1} · ${i == 0
                        ? "很不舒适"
                        : i == 4
                        ? "很舒适"
                        : ""}',
                  ),
                ),
              ),
              onChanged: (value) => setState(() => state = value),
            ),
            DropdownButton<String>(
              isExpanded: true,
              value: scene,
              hint: const Text('场景（可选）'),
              items: [
                '下班回家',
                '工作学习',
                '睡前',
                '周末放松',
                '其他',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (value) => setState(() => scene = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, BeforeUseInput(state, scene)),
            child: const Text('确认开始'),
          ),
        ],
      ),
    ),
  );
}

class UsageFeedbackPage extends StatefulWidget {
  const UsageFeedbackPage({
    super.key,
    required this.sessionId,
    required this.userId,
  });
  final String sessionId;
  final String userId;
  @override
  State<UsageFeedbackPage> createState() => _UsageFeedbackPageState();
}

class _UsageFeedbackPageState extends State<UsageFeedbackPage> {
  final _note = TextEditingController();
  Map<String, Object?>? _detail;
  int? _before, _after, _liking, _reuse;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await context.read<UsageSessionService>().feedbackDetail(
        widget.sessionId,
        widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _before = detail['before_state'] as int?;
        _after = detail['after_state'] as int?;
        _liking = detail['liking'] as int?;
        _reuse = detail['reuse_intent'] as int?;
        _note.text = detail['note'] as String? ?? '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _save({bool collect = false}) async {
    if (_saving) return;
    if (feedbackUserId(context) != widget.userId) {
      setState(() => _error = '用户已切换，请返回后重新打开');
      return;
    }
    if (_after == null || _liking == null || _reuse == null) {
      setState(() => _error = '请选择使用后状态、喜欢程度和再次使用意愿');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = context.read<UsageSessionService>();
      await service.saveFeedback(
        sessionId: widget.sessionId,
        userId: widget.userId,
        beforeState: _before,
        afterState: _after,
        liking: _liking,
        reuseIntent: _reuse,
        note: _note.text,
      );
      final ids = collect
          ? await service.recordIds(widget.sessionId, widget.userId)
          : <int>[];
      if (!mounted) return;
      if (collect) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SmellEditPage(usageRecordIds: ids)),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _saving = false;
        });
      }
    }
  }

  Widget _scale(
    String label,
    int? value,
    ValueChanged<int?> changed, {
    bool locked = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        DropdownButton<int>(
          isExpanded: true,
          value: value,
          hint: const Text('未记录'),
          items: List.generate(
            5,
            (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1} 分')),
          ),
          onChanged: locked || _saving ? null : changed,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('这次气味体验')),
    body: _detail == null
        ? Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Text(_error!),
          )
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('场景：${_detail!['scene'] ?? '未记录'}'),
              Text(
                '使用时长：${SmellMomentRepository.formatDuration(_detail!['duration'] as int?)}',
              ),
              if (_detail!['source'] == 'recommendation_simulation')
                const Text('这是推荐算法模拟记录，提交的反馈会参与测试评分。'),
              if (_detail!['status'] != 'completed_unverified')
                const Text('这次使用的结束时间不确定。反馈会保留，时长不作为已确认数据。'),
              const SizedBox(height: 20),
              _scale(
                _detail!['before_state_source'] == 'before_use'
                    ? '使用前舒适程度（开始时记录）'
                    : '使用前舒适程度（回忆补填，可留空）',
                _before,
                (v) => setState(() => _before = v),
                locked: _detail!['before_state_source'] == 'before_use',
              ),
              _scale(
                '使用后舒适程度（1 很不舒适，5 很舒适）',
                _after,
                (v) => setState(() => _after = v),
              ),
              _scale(
                '喜欢程度（1 不喜欢，5 很喜欢）',
                _liking,
                (v) => setState(() => _liking = v),
              ),
              const Text('再次使用意愿'),
              DropdownButton<int>(
                value: _reuse,
                isExpanded: true,
                hint: const Text('请选择'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('不愿意')),
                  DropdownMenuItem(value: 1, child: Text('不确定')),
                  DropdownMenuItem(value: 2, child: Text('愿意')),
                ],
                onChanged: _saving ? null : (v) => setState(() => _reuse = v),
              ),
              TextField(
                controller: _note,
                enabled: !_saving,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '一句话感受（可选）',
                  hintText: '例如：比较清爽，但有点浓',
                ),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: _saving ? null : () => _save(),
                child: const Text('保存反馈'),
              ),
              TextButton(
                onPressed: _saving ? null : () => _save(collect: true),
                child: const Text('保存反馈并收藏为气味瞬间'),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('稍后填写'),
              ),
            ],
          ),
  );
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }
}

class UsageFeedbackHistoryPage extends StatefulWidget {
  const UsageFeedbackHistoryPage({super.key});
  @override
  State<UsageFeedbackHistoryPage> createState() =>
      _UsageFeedbackHistoryPageState();
}

class _UsageFeedbackHistoryPageState extends State<UsageFeedbackHistoryPage> {
  @override
  Widget build(BuildContext context) {
    context.watch<UserProvider>();
    final user = feedbackUserId(context);
    return Scaffold(
      appBar: AppBar(title: const Text('使用反馈')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: context.read<UsageSessionService>().feedbackSessions(user),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('加载失败，请返回重试'));
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return const Center(child: Text('暂时没有已结束的使用'));
          }
          return ListView(
            children: snapshot.data!
                .map(
                  (row) => ListTile(
                    title: Text(
                      '${row['scene'] ?? '气味体验'} · ${row['feedback_id'] == null ? '待反馈' : '已反馈'}',
                    ),
                    subtitle: Text(
                      DateTime.fromMillisecondsSinceEpoch(
                        row['start_time'] as int,
                      ).toLocal().toString().split('.').first,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UsageFeedbackPage(
                            sessionId: row['id'] as String,
                            userId: user,
                          ),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
