import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/models/recommendation.dart';
import 'package:perfume_app/providers/recommendation_provider.dart';
import 'package:perfume_app/services/recommendation_service.dart';

class _Changes extends ChangeNotifier {
  void emit() => notifyListeners();
}

class _DeferredSource implements RecommendationSource {
  final requests = <(String, Completer<RecommendationReport>)>[];
  @override
  Future<RecommendationReport> recommend(String userId) {
    final completer = Completer<RecommendationReport>();
    requests.add((userId, completer));
    return completer.future;
  }
}

RecommendationReport _report(String user) => RecommendationReport(
  userId: user,
  generatedAt: DateTime(2026),
  recommendations: [],
  excludedSessions: 0,
);

void main() {
  late _Changes usage, users, config, deletion;
  late _DeferredSource source;
  late RecommendationProvider provider;
  var currentUser = 'alice';
  var busy = false;
  setUp(() {
    usage = _Changes();
    users = _Changes();
    config = _Changes();
    deletion = _Changes();
    currentUser = 'alice';
    busy = false;
    source = _DeferredSource();
    provider = RecommendationProvider(
      source: source,
      usageChanges: usage,
      usageBusy: () => busy,
      userChanges: users,
      userId: () => currentUser,
      configChanges: config,
      additionalChanges: [deletion],
    );
  });
  tearDown(() {
    provider.dispose();
    usage.dispose();
    users.dispose();
    config.dispose();
    deletion.dispose();
  });
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'user switch clears old profile and late results cannot overwrite new user',
    () async {
      final old = source.requests.single.$2;
      currentUser = 'bob';
      users.emit();
      expect(provider.report, isNull);
      source.requests.last.$2.complete(_report('bob'));
      await settle();
      old.complete(_report('alice'));
      await settle();
      expect(provider.report!.userId, 'bob');
    },
  );

  test(
    'configuration switch clears unavailable candidates and supersedes older refresh',
    () async {
      source.requests.single.$2.complete(_report('alice'));
      await settle();
      usage.emit();
      final older = source.requests.last.$2;
      config.emit();
      expect(provider.report, isNull);
      final latest = _report('alice');
      source.requests.last.$2.complete(latest);
      await settle();
      older.complete(_report('alice'));
      await settle();
      expect(provider.report, same(latest));
    },
  );

  test(
    'only committed usage changes refresh; record deletion also invalidates',
    () async {
      source.requests.single.$2.complete(_report('alice'));
      await settle();
      busy = true;
      usage.emit();
      expect(source.requests, hasLength(1));
      busy = false;
      usage.emit();
      expect(source.requests, hasLength(2));
      source.requests.last.$2.complete(_report('alice'));
      await settle();
      deletion.emit();
      expect(source.requests, hasLength(3));
      source.requests.last.$2.complete(_report('alice'));
      await settle();
      expect(provider.error, isNull);
    },
  );

  test(
    'read failure has explicit error, retry recovers and clears loading',
    () async {
      source.requests.single.$2.completeError(
        StateError('database unavailable'),
      );
      await settle();
      expect(provider.error, isNotNull);
      expect(provider.loading, isFalse);
      final retry = provider.refresh();
      source.requests.last.$2.complete(_report('alice'));
      await retry;
      expect(provider.error, isNull);
      expect(provider.loading, isFalse);
    },
  );
}
