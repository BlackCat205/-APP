import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:perfume_app/pages/usage_feedback_page.dart';
import 'package:perfume_app/providers/user_provider.dart';
import 'package:perfume_app/services/usage_session_service.dart';

class _UnusedDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('UI 不应访问数据库');
}

class _FeedbackService extends UsageSessionService {
  _FeedbackService()
    : super(
        db: _UnusedDatabase(),
        send: (_) async => throw StateError('反馈不能触发 BLE'),
        connected: () => false,
        scentForFan: (_) => '雪松',
      );
  Map<String, Object?>? saved;
  @override
  Future<Map<String, Object?>> feedbackDetail(
    String sessionId,
    String userId,
  ) async => {
    'before_state': 2,
    'before_state_source': 'before_use',
    'scene': '睡前',
    'status': 'completed_unverified',
    'duration': 60,
  };
  @override
  Future<void> saveFeedback({
    required String sessionId,
    required String userId,
    int? beforeState,
    int? afterState,
    int? liking,
    int? reuseIntent,
    String? note,
  }) async {
    saved = {
      'before': beforeState,
      'after': afterState,
      'liking': liking,
      'reuse': reuseIntent,
      'note': note,
      'user': userId,
    };
  }
}

void main() {
  testWidgets(
    'before-use dialog distinguishes cancel from optional blank confirmation',
    (tester) async {
      BeforeUseInput? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await askBeforeUse(context);
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认开始'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.state, isNull);
    },
  );

  testWidgets(
    'feedback keeps before-state locked, validates required fields and saves without collection',
    (tester) async {
      final service = _FeedbackService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UsageSessionService>.value(value: service),
            ChangeNotifierProvider(create: (_) => UserProvider()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UsageFeedbackPage(
                        sessionId: 'session',
                        userId: 'local',
                      ),
                    ),
                  ),
                  child: const Text('反馈'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('反馈'));
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .toList();
      expect(fields.first.onChanged, isNull);
      expect(fields.first.value, 2);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存反馈'));
      await tester.pumpAndSettle();
      expect(find.text('请选择使用后状态、喜欢程度和再次使用意愿'), findsOneWidget);
      expect(service.saved, isNull);
      fields[1].onChanged!(4);
      await tester.pump();
      fields[2].onChanged!(5);
      await tester.pump();
      fields[3].onChanged!(2);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '清爽');
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存反馈'));
      await tester.pumpAndSettle();
      expect(service.saved, {
        'before': 2,
        'after': 4,
        'liking': 5,
        'reuse': 2,
        'note': '清爽',
        'user': 'local',
      });
      expect(find.text('反馈'), findsOneWidget);
    },
  );
}
