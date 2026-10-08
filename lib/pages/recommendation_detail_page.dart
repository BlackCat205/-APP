import 'package:flutter/material.dart';
import '../models/recommendation.dart';

class RecommendationDetailPage extends StatelessWidget {
  const RecommendationDetailPage({super.key, required this.item, this.onStart});
  final Recommendation item;
  final Future<void> Function(Recommendation)? onStart;

  String _score(double? value) =>
      value == null ? '尚无分析结果' : '${value.toStringAsFixed(1)} / 100';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('为什么推荐给我')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          item.candidate.name,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(item.isVerified ? '已验证推荐 · ${item.evidenceLabel}' : '探索建议'),
        if (item.hasReliableScore) ...[
          const SizedBox(height: 12),
          Text(
            '综合推荐度 ${_score(item.overallScore)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
        const SizedBox(height: 20),
        _Section(
          title: '推荐理由',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.reason),
              if (item.aiReason != null) ...[
                const SizedBox(height: 8),
                Text('AI 偏好理解：${item.aiReason}'),
              ],
            ],
          ),
        ),
        _Section(
          title: '评分依据',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('行为适配度：${_score(item.behaviorScore)}'),
              Text('AI 偏好匹配度：${_score(item.aiScore)}'),
              Text(
                'AI confidence：${item.aiConfidence == null ? '尚无分析结果' : '${(item.aiConfidence! * 100).round()}%'}',
              ),
              if (item.behaviorScore != null && item.aiScore != null)
                Text(
                  '融合权重：行为 ${(item.behaviorShare! * 100).round()}% · AI ${((1 - item.behaviorShare!) * 100).round()}%',
                ),
              const SizedBox(height: 8),
              for (final part in item.components.entries)
                Text(
                  '${part.key}：${part.value == null ? '待反馈' : part.value!.toStringAsFixed(1)}',
                ),
            ],
          ),
        ),
        _Section(
          title: '数据依据',
          child: Text(
            '${item.useCount} 次使用 · ${item.feedbackCount} 次可归属反馈\n'
            '近期反馈权重更高，缺失项不按零分处理。',
          ),
        ),
        if (onStart != null)
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await onStart!(item);
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始使用'),
          ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );
}
