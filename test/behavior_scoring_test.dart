import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/models/recommendation.dart';
import 'package:perfume_app/services/behavior_scoring_service.dart';
import 'package:perfume_app/services/scent_catalog.dart';

void main() {
  final now = DateTime(2026, 9, 22);
  final candidate = ScentCandidate(id: 'cedar', fans: {1: '雪松'});
  const service = BehaviorScoringService();
  BehaviorObservation sample({
    String id = 'session',
    int? liking = 5,
    int? before = 2,
    int? after = 4,
    int? reuse = 2,
    double seconds = 600,
    int ageDays = 0,
    double coverage = 1,
    String beforeSource = 'before_use',
  }) => BehaviorObservation(
    sessionId: id,
    endTime: now.subtract(Duration(days: ageDays)),
    seconds: seconds,
    feedbackCoverage: coverage,
    liking: liking,
    before: before,
    after: after,
    reuseIntent: reuse,
    beforeSource: beforeSource,
  );

  test('cold start has no invented scores', () {
    final result = service.score(candidate, [], now);
    expect(result.isVerified, isFalse);
    expect(result.behaviorScore, isNull);
    expect(result.aiScore, isNull);
    expect(result.overallScore, isNull);
  });

  test('good and bad feedback move score in opposite directions', () {
    final good = service.score(candidate, [sample()], now);
    final bad = service.score(candidate, [
      sample(liking: 1, before: 4, after: 1, reuse: 0),
    ], now);
    expect(good.behaviorScore, greaterThan(50));
    expect(bad.behaviorScore, lessThan(50));
    expect(good.behaviorScore, lessThan(80));
    expect(good.overallScore, good.behaviorScore);
    expect(good.components['状态变化'], 75);
  });

  test('missing feedback is not zero and exposure alone is capped', () {
    final result = service.score(
      candidate,
      List.generate(
        100,
        (i) => sample(
          id: '$i',
          liking: null,
          before: null,
          after: null,
          reuse: null,
          seconds: 100000,
        ),
      ),
      now,
    );
    expect(result.feedbackCount, 0);
    expect(result.components['喜欢程度'], isNull);
    expect(result.components['状态变化'], isNull);
    expect(result.behaviorScore, lessThanOrEqualTo(60));
  });

  test('longer use stops increasing after duration cap', () {
    final normal = service.score(candidate, [sample(seconds: 600)], now);
    final long = service.score(candidate, [sample(seconds: 60000)], now);
    expect(normal.behaviorScore, long.behaviorScore);
  });

  test('recent negative feedback outweighs an old positive observation', () {
    final result = service.score(candidate, [
      sample(id: 'old', ageDays: 120),
      sample(id: 'new', liking: 1, before: 4, after: 1, reuse: 0),
    ], now);
    expect(result.components['喜欢程度'], lessThan(10));
    expect(result.behaviorScore, lessThan(50));
  });

  test(
    'more matching feedback strengthens evidence without counting duplicate sessions',
    () {
      final one = service.score(candidate, [sample(), sample()], now);
      final many = service.score(
        candidate,
        List.generate(10, (i) => sample(id: '$i')),
        now,
      );
      expect(one.useCount, 1);
      expect(one.feedbackCount, 1);
      expect(many.behaviorScore, greaterThan(one.behaviorScore!));
      expect(many.effectiveEvidence, greaterThan(one.effectiveEvidence));
    },
  );

  test(
    'recalled before-state weakens evidence; unknown source is not a measured change',
    () {
      final original = service.score(candidate, [sample()], now);
      final recalled = service.score(candidate, [
        sample(beforeSource: 'recalled'),
      ], now);
      final unknown = service.score(candidate, [
        sample(beforeSource: 'unknown'),
      ], now);
      expect(recalled.effectiveEvidence, lessThan(original.effectiveEvidence));
      expect(unknown.components['状态变化'], isNull);
    },
  );

  test('unattributed fragments cannot inherit overall feedback', () {
    final result = service.score(candidate, [sample(coverage: 0)], now);
    expect(result.useCount, 1);
    expect(result.feedbackCount, 0);
    expect(result.components['喜欢程度'], isNull);
  });

  test('invalid duration and future samples are excluded', () {
    final result = service.score(candidate, [
      sample(seconds: double.nan),
      sample(id: 'future', ageDays: -1),
      sample(id: 'zero', seconds: 0),
    ], now);
    expect(result.isVerified, isFalse);
  });

  test(
    'candidate identity survives channel changes and distinguishes duplicate scents',
    () {
      final first = ScentCatalog.candidates({
        1: '雪松',
        2: '薄荷',
        3: '檀香',
        4: '甜橙',
      });
      expect(first, hasLength(15));
      final swapped = ScentCatalog.candidates({4: '雪松', 1: '薄荷'});
      expect(swapped.map((r) => r.id), contains('cedar+mint'));
      final duplicated = ScentCatalog.candidates({
        1: '雪松',
        2: '雪松',
        5: '薄荷',
        3: '未知',
      });
      expect(duplicated.map((r) => r.id).toSet(), {'cedar', 'cedar+cedar'});
    },
  );
}
