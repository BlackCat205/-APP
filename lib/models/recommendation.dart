/// 本阶段分数来自行为规则；null 表示没有依据，不代表零分。
class ScentCandidate {
  ScentCandidate({required this.id, required Map<int, String> fans})
    : fans = Map.unmodifiable(fans);
  final String id;
  final Map<int, String> fans;
  String get name => fans.values.join(' + ');
}

class BehaviorObservation {
  const BehaviorObservation({
    required this.sessionId,
    required this.endTime,
    required this.seconds,
    this.feedbackCoverage = 0,
    this.liking,
    this.before,
    this.after,
    this.beforeSource,
    this.reuseIntent,
  });
  final String sessionId;
  final DateTime endTime;
  final double seconds;

  /// 只有唯一或明确占主导的组合才能获得整次反馈，其他片段为 0。
  final double feedbackCoverage;
  final int? liking, before, after, reuseIntent;
  final String? beforeSource;
}

class Recommendation {
  Recommendation({
    required this.candidate,
    required this.behaviorScore,
    required this.useCount,
    required this.feedbackCount,
    required this.effectiveEvidence,
    required Map<String, double?> components,
    required this.reason,
    this.aiScore,
    this.aiConfidence,
    this.aiReason,
  }) : components = Map.unmodifiable(components);
  final ScentCandidate candidate;
  final double? behaviorScore;
  final double? aiScore, aiConfidence;
  final String? aiReason;
  double? get overallScore {
    if (behaviorScore == null) return aiScore;
    if (aiScore == null || aiConfidence == null) return behaviorScore;
    final behaviorWeight =
        effectiveEvidence / (effectiveEvidence + aiConfidence! * 3);
    return behaviorScore! * behaviorWeight + aiScore! * (1 - behaviorWeight);
  }

  double? get behaviorShare {
    if (behaviorScore == null) return 0;
    if (aiScore == null || aiConfidence == null) return 1;
    return effectiveEvidence / (effectiveEvidence + aiConfidence! * 3);
  }

  String get displayReason =>
      behaviorScore == null && aiReason != null ? aiReason! : reason;
  final int useCount, feedbackCount;
  final double effectiveEvidence;
  final Map<String, double?> components;
  final String reason;
  bool get isVerified => useCount > 0;
  bool get hasReliableScore =>
      overallScore != null &&
      ((feedbackCount > 0 && effectiveEvidence >= 2) ||
          (aiScore != null && (aiConfidence ?? 0) >= .5));
  String get evidenceLabel => effectiveEvidence < 2
      ? '证据较少'
      : effectiveEvidence < 5
      ? '证据积累中'
      : '证据较充足';
}

class RecommendationReport {
  RecommendationReport({
    required this.userId,
    required this.generatedAt,
    required List<Recommendation> recommendations,
    required this.excludedSessions,
  }) : recommendations = List.unmodifiable(recommendations);
  final String userId;
  final DateTime generatedAt;
  final List<Recommendation> recommendations;
  final int excludedSessions;
  List<Recommendation> get verified =>
      recommendations.where((r) => r.isVerified).toList();
  List<Recommendation> get exploration =>
      recommendations.where((r) => !r.isVerified).toList();
}
