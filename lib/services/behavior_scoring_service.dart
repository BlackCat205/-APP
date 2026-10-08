import 'dart:math' as math;
import '../models/recommendation.dart';

class BehaviorScoringConfig {
  const BehaviorScoringConfig({
    this.likingWeight = .4,
    this.changeWeight = .3,
    this.reuseWeight = .2,
    this.usageWeight = .1,
    this.halfLifeDays = 30,
    this.durationCapSeconds = 600,
    this.repeatCap = 5,
    this.priorSamples = 2,
  });
  final double likingWeight, changeWeight, reuseWeight, usageWeight;
  final double halfLifeDays, durationCapSeconds, repeatCap, priorSamples;
}

/// 纯 Dart 行为评分，不联网、不依赖 UI 或硬件。
class BehaviorScoringService {
  const BehaviorScoringService({this.config = const BehaviorScoringConfig()});
  final BehaviorScoringConfig config;

  Recommendation score(
    ScentCandidate candidate,
    List<BehaviorObservation> samples,
    DateTime now,
  ) {
    final usable = <String, BehaviorObservation>{
      for (final sample in samples)
        if (sample.seconds > 0 &&
            sample.seconds.isFinite &&
            !sample.endTime.isAfter(now))
          sample.sessionId: sample,
    }.values.toList();
    if (usable.isEmpty) {
      return Recommendation(
        candidate: candidate,
        behaviorScore: null,
        useCount: 0,
        feedbackCount: 0,
        effectiveEvidence: 0,
        components: const {},
        reason: '当前已装载这些气味，但没有可靠的组合使用记录。这是尚未个性化的探索建议。',
      );
    }
    final liking = _Signal(), change = _Signal(), reuse = _Signal();
    var evidence = 0.0, effectiveUses = 0.0, effectiveDuration = 0.0;
    var feedbackCount = 0;
    final feedbackWeight =
        config.likingWeight + config.changeWeight + config.reuseWeight;
    for (final sample in usable) {
      final days =
          now.difference(sample.endTime).inMilliseconds /
          Duration.millisecondsPerDay;
      final decay = math.pow(.5, days / config.halfLifeDays).toDouble();
      effectiveUses += decay;
      effectiveDuration +=
          decay * (sample.seconds / config.durationCapSeconds).clamp(0, 1);
      final coverage = sample.feedbackCoverage.clamp(0.0, 1.0);
      if (coverage == 0) continue;
      final weight = decay * coverage;
      var completeness = 0.0;
      if (_scale(sample.liking)) {
        liking.add((sample.liking! - 1) * 25.0, weight);
        completeness += config.likingWeight;
      }
      if (_scale(sample.before) &&
          _scale(sample.after) &&
          ['before_use', 'recalled'].contains(sample.beforeSource)) {
        final quality = sample.beforeSource == 'recalled' ? .5 : 1.0;
        change.add(
          50 + (sample.after! - sample.before!) * 12.5,
          weight,
          quality,
        );
        completeness += config.changeWeight * quality;
      }
      if (sample.reuseIntent != null &&
          sample.reuseIntent! >= 0 &&
          sample.reuseIntent! <= 2) {
        reuse.add(sample.reuseIntent! * 50.0, weight);
        completeness += config.reuseWeight;
      }
      if (completeness > 0) {
        feedbackCount++;
        evidence += weight * completeness / feedbackWeight;
      }
    }
    // 次数和时长只提供弱正向信号，短时/少用本身不视为不喜欢。
    final usage =
        50.0 +
        25.0 * (effectiveUses / config.repeatCap).clamp(0.0, 1.0) +
        25.0 * (effectiveUses == 0 ? 0.0 : effectiveDuration / effectiveUses);
    evidence += config.usageWeight * math.min(effectiveUses, config.repeatCap);
    final components = <String, double?>{
      '喜欢程度': liking.value,
      '状态变化': change.value,
      '再次使用意愿': reuse.value,
      '使用次数与时长': usage,
    };
    var numerator = usage * config.usageWeight;
    var denominator = config.usageWeight;
    for (final entry in [
      (liking, config.likingWeight),
      (change, config.changeWeight),
      (reuse, config.reuseWeight),
    ]) {
      if (entry.$1.value != null) {
        final weight = entry.$2 * entry.$1.quality;
        numerator += entry.$1.value! * weight;
        denominator += weight;
      }
    }
    final raw = numerator / denominator;
    final reliability = evidence / (evidence + config.priorSamples);
    final adjusted = (50 + (raw - 50) * reliability).clamp(0.0, 100.0);
    final preference = liking.value == null
        ? ''
        : liking.value! >= 75
        ? '近期喜欢程度偏高。'
        : liking.value! <= 25
        ? '近期喜欢程度偏低。'
        : '喜欢程度居中。';
    return Recommendation(
      candidate: candidate,
      behaviorScore: adjusted,
      useCount: usable.length,
      feedbackCount: feedbackCount,
      effectiveEvidence: evidence,
      components: components,
      reason:
          '${usable.length} 次使用记录，$feedbackCount 次反馈可归属到此组合。$preference'
          '${feedbackCount == 0 ? '只有使用行为，尚不能判断明确偏好。' : ''}'
          '${evidence < 2 ? '样本较少，评分已向中性值收敛。' : ''}',
    );
  }

  static bool _scale(int? value) => value != null && value >= 1 && value <= 5;
}

class _Signal {
  double numerator = 0, denominator = 0, baseWeight = 0;
  void add(double value, double weight, [double quality = 1]) {
    numerator += value * weight * quality;
    denominator += weight * quality;
    baseWeight += weight;
  }

  double? get value => denominator > 0 ? numerator / denominator : null;
  double get quality => baseWeight > 0 ? denominator / baseWeight : 0;
}
