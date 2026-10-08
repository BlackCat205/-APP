import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:perfume_app/models/recommendation.dart';
import 'package:perfume_app/providers/recommendation_provider.dart';
import 'package:perfume_app/services/behavior_scoring_service.dart';
import 'package:perfume_app/services/recommendation_service.dart';
import 'package:perfume_app/widgets/today_recommendation_card.dart';

class _Source implements RecommendationSource {
  _Source(this.result);
  RecommendationReport result;
  bool fail = false;
  @override
  Future<RecommendationReport> recommend(String userId) async {
    if (fail) throw StateError('offline storage error');
    return result;
  }
}

void main() {
  final now = DateTime(2026);
  final candidate = ScentCandidate(id: 'cedar', fans: {1: '雪松'});
  RecommendationReport report(List<BehaviorObservation> samples) =>
      RecommendationReport(
        userId: 'local',
        generatedAt: now,
        excludedSessions: 0,
        recommendations: [
          const BehaviorScoringService().score(candidate, samples, now),
        ],
      );
  Future<void> mount(WidgetTester tester, _Source source) async {
    final changes = ChangeNotifier();
    final provider = RecommendationProvider(
      source: source,
      usageChanges: changes,
      usageBusy: () => false,
      userChanges: changes,
      userId: () => 'local',
      configChanges: changes,
    );
    addTearDown(() {
      provider.dispose();
      changes.dispose();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: TodayRecommendationCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cold start shows one compact exploration card without empty metrics',
    (tester) async {
      await mount(tester, _Source(report([])));
      expect(find.text('开始认识你的气味'), findsOneWidget);
      expect(find.text('探索建议'), findsOneWidget);
      expect(find.textContaining('暂无数据'), findsNothing);
      expect(find.textContaining('AI'), findsNothing);
      expect(find.text('开始使用'), findsOneWidget);
      expect(find.text('为什么推荐'), findsOneWidget);
      expect(find.text('查看更多推荐'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('verified result displays real score and expandable evidence', (
    tester,
  ) async {
    final result = report([
      BehaviorObservation(
        sessionId: 'one',
        endTime: now,
        seconds: 600,
        feedbackCoverage: 1,
        liking: 5,
        before: 2,
        after: 4,
        beforeSource: 'before_use',
        reuseIntent: 2,
      ),
      BehaviorObservation(
        sessionId: 'two',
        endTime: now,
        seconds: 600,
        feedbackCoverage: 1,
        liking: 5,
        before: 2,
        after: 4,
        beforeSource: 'before_use',
        reuseIntent: 2,
      ),
    ]);
    await mount(tester, _Source(result));
    expect(find.text('为你推荐'), findsOneWidget);
    expect(
      find.text('${result.verified.single.behaviorScore!.round()}%'),
      findsOneWidget,
    );
    expect(find.text('行为适配度：'), findsNothing);
    await tester.tap(find.text('为什么推荐'));
    await tester.pumpAndSettle();
    expect(find.text('为什么推荐给我'), findsOneWidget);
    expect(find.text('评分依据'), findsOneWidget);
    expect(find.text('喜欢程度：100.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read error can be retried from card', (tester) async {
    final source = _Source(report([]))..fail = true;
    await mount(tester, source);
    expect(find.text('暂时无法读取推荐，请重试'), findsOneWidget);
    source.fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('暂时无法读取推荐，请重试'), findsNothing);
    expect(find.text('雪松'), findsOneWidget);
  });

  testWidgets('home shows one candidate and switch rotates locally', (
    tester,
  ) async {
    final first = const BehaviorScoringService().score(candidate, [], now);
    final second = const BehaviorScoringService().score(
      ScentCandidate(id: 'mint', fans: {2: '薄荷'}),
      [],
      now,
    );
    final source = _Source(
      RecommendationReport(
        userId: 'local',
        generatedAt: now,
        recommendations: [first, second],
        excludedSessions: 0,
      ),
    );
    await mount(tester, source);
    expect(find.text('雪松'), findsOneWidget);
    expect(find.text('薄荷'), findsNothing);
    await tester.tap(find.text('换一个'));
    await tester.pump();
    expect(find.text('雪松'), findsNothing);
    expect(find.text('薄荷'), findsOneWidget);
  });
}
