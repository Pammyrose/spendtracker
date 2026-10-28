import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spendtracker/app_data.dart';
import 'package:spendtracker/cloud_api.dart';
import 'package:spendtracker/cloud_backup_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceStorage, (_) async => null),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceStorage, null),
  );

  test(
    'Cloud client keeps stale revisions and clears an expired session',
    () async {
      var revision = 3, expired = false;
      final cloud = CloudApi(
        client: MockClient((request) async {
          if (request.url.path == '/auth/login') {
            return http.Response(
              jsonEncode({'token': 'a' * 64, 'email': 'learner@example.com'}),
              200,
            );
          }
          expect(request.headers['Authorization'], 'Bearer ${'a' * 64}');
          if (expired) {
            return http.Response(jsonEncode({'error': 'Session expired'}), 401);
          }
          if (request.method == 'PUT') {
            expect(jsonDecode(request.body)['revision'], 3);
            return http.Response(
              jsonEncode({'error': 'The server backup changed.'}),
              409,
            );
          }
          return http.Response(
            jsonEncode({'revision': revision, 'updatedAt': null, 'data': null}),
            200,
          );
        }),
      );
      expect(
        () => cloud.configure('http://public.example.com'),
        throwsA(isA<CloudApiException>()),
      );
      await cloud.authenticate(
        'http://127.0.0.1:3000',
        'learner@example.com',
        'password123',
        register: false,
      );
      revision = 4;
      await expectLater(cloud.upload('{}'), throwsA(isA<CloudApiException>()));
      expect(cloud.latest!.revision, 3);
      await cloud.refresh();
      expect(cloud.latest!.revision, 4);
      expired = true;
      await expectLater(cloud.refresh(), throwsA(isA<CloudApiException>()));
      expect(cloud.signedIn, false);
      cloud.dispose();
    },
  );

  testWidgets(
    'Account login, confirmed save, cancelled restore, and confirmed restore',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, dynamic>? remote;
      var revision = 0;
      final cloud = CloudApi(
        client: MockClient((request) async {
          if (request.url.path == '/auth/login') {
            return http.Response(
              jsonEncode({'token': 'a' * 64, 'email': 'learner@example.com'}),
              200,
            );
          }
          if (request.method == 'PUT') {
            final payload = jsonDecode(request.body);
            expect(payload['revision'], revision);
            remote = payload['data'];
            return http.Response(jsonEncode({'revision': ++revision}), 200);
          }
          if (request.method == 'DELETE') return http.Response('', 204);
          return http.Response(
            jsonEncode({
              'revision': revision,
              'updatedAt': null,
              'data': remote,
            }),
            200,
          );
        }),
      );
      final data = AppData(seed: false, cloud: cloud);
      data.addExpense(ExpenseRecord('Lunch', 0, 120, DateTime(2026, 10, 28)));
      await tester.pumpWidget(
        AppDataScope(
          data: data,
          child: const MaterialApp(home: CloudBackupPage()),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('cloud-url')),
        'http://127.0.0.1:3000',
      );
      await tester.enterText(
        find.byKey(const Key('cloud-email')),
        'learner@example.com',
      );
      await tester.ensureVisible(find.byKey(const Key('cloud-password')));
      await tester.enterText(
        find.byKey(const Key('cloud-password')),
        'password123',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.ensureVisible(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('No server backup yet.'), findsOneWidget);
      expect(data.expenses.length, 1);
      await tester.ensureVisible(find.text('Save to server'));
      await tester.tap(find.text('Save to server'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(remote!['expenses'].length, 1);
      expect(data.backupJson().contains('password123'), false);
      expect(data.backupJson().contains('a' * 64), false);
      data.addExpense(ExpenseRecord('Coffee', 0, 70, DateTime(2026, 10, 28)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Restore from server'));
      await tester.tap(find.text('Restore from server'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(data.expenses.length, 2);
      await tester.tap(find.text('Restore from server'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(data.expenses.length, 1);
      expect(data.expenses.single.title, 'Lunch');
      expect(
        find.text('Server backup restored and saved on this device.'),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      data.dispose();
    },
  );
}
