import 'package:flutter/material.dart';
import '../models/recommendation.dart';
import 'recommendation_detail_page.dart';

class RecommendationListPage extends StatelessWidget {
  const RecommendationListPage({super.key, required this.report, this.onStart});
  final RecommendationReport report;
  final Future<void> Function(Recommendation)? onStart;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('更多推荐')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (report.verified.isNotEmpty) ...[
          const _Heading('已验证推荐'),
          for (final item in report.verified) _tile(context, item),
        ],
        if (report.exploration.isNotEmpty) ...[
          const _Heading('探索建议'),
          for (final item in report.exploration) _tile(context, item),
        ],
      ],
    ),
  );

  Widget _tile(BuildContext context, Recommendation item) => Card(
    child: ListTile(
      title: Text(item.candidate.name),
      subtitle: Text(
        item.displayReason,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: item.hasReliableScore
          ? Text('${item.overallScore!.round()}%')
          : const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RecommendationDetailPage(item: item, onStart: onStart),
        ),
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}
