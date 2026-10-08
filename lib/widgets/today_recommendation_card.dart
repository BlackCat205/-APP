import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recommendation.dart';
import '../pages/recommendation_detail_page.dart';
import '../pages/recommendation_list_page.dart';
import '../providers/recommendation_provider.dart';

class TodayRecommendationCard extends StatelessWidget {
  const TodayRecommendationCard({super.key, this.onStart});
  final Future<void> Function(Recommendation)? onStart;

  @override
  Widget build(BuildContext context) => Consumer<RecommendationProvider>(
    builder: (context, state, _) {
      final item = state.current;
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: item == null
              ? _empty(state)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.hasReliableScore ? '为你推荐' : '开始认识你的气味',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (item.hasReliableScore)
                          Text(
                            '${item.overallScore!.round()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        else
                          const Text(
                            '探索建议',
                            style: TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.candidate.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _shortReason(item.displayReason),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: [
                        FilledButton.icon(
                          onPressed: onStart == null
                              ? null
                              : () => onStart!(item),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('开始使用'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecommendationDetailPage(
                                item: item,
                                onStart: onStart,
                              ),
                            ),
                          ),
                          child: const Text('为什么推荐'),
                        ),
                        TextButton(
                          onPressed: state.report!.recommendations.length < 2
                              ? null
                              : state.showNext,
                          child: const Text('换一个'),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecommendationListPage(
                              report: state.report!,
                              onStart: onStart,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.list, size: 18),
                        label: const Text('查看更多推荐'),
                      ),
                    ),
                  ],
                ),
        ),
      );
    },
  );

  Widget _empty(RecommendationProvider state) {
    if (state.loading) return const LinearProgressIndicator();
    if (state.error != null) {
      return Row(
        children: [
          Expanded(child: Text(state.error!)),
          TextButton(onPressed: state.refresh, child: const Text('重试')),
        ],
      );
    }
    return const Text('请先配置设备气味');
  }

  String _shortReason(String reason) {
    final end = reason.indexOf(RegExp('[。！？]'));
    return end < 0 ? reason : reason.substring(0, end + 1);
  }
}
