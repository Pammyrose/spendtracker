import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spendtracker/account_greeting.dart';
import 'package:spendtracker/app_data.dart';
import 'package:spendtracker/cloud_api.dart';
import 'package:spendtracker/main.dart';

import 'app_test_helpers.dart';

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
    'Greeting follows local morning, noon, evening and midnight boundaries',
    () {
      for (final hour in [0, 4, 18, 23]) {
        expect(greetingFor(DateTime(2026, 10, 28, hour)), 'Good Evening');
      }
      for (final hour in [5, 11]) {
        expect(greetingFor(DateTime(2026, 10, 28, hour)), 'Good Morning');
      }
      for (final hour in [12, 17]) {
        expect(greetingFor(DateTime(2026, 10, 28, hour)), 'Good Afternoon');
      }
    },
  );

  testWidgets(
    'Greeting updates at the next minute and immediately after resume',
    (tester) async {
      var now = DateTime(2026, 10, 28, 11, 59, 59);
      final data = AppData(seed: false);
      await tester.pumpWidget(
        AppDataScope(
          data: data,
          child: MaterialApp(home: AccountGreeting(now: () => now)),
        ),
      );
      expect(find.text('Good Morning,\nthere!'), findsOneWidget);
      now = DateTime(2026, 10, 28, 12);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Good Afternoon,\nthere!'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 10, 28, 19);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Good Evening,\nthere!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      data.dispose();
    },
  );

  testWidgets(
    'Profile edits support cancel, validation, failure and live greeting updates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var fail = true, edits = 0;
      final cloud = CloudApi(
        client: MockClient((request) async {
          if (request.url.path == '/auth/login') {
            return http.Response(
              jsonEncode({
                'token': 'a' * 64,
                'email': 'learner@example.com',
                'name': 'Pam',
              }),
              200,
            );
          }
          if (request.url.path == '/profile') {
            edits++;
            expect(request.method, 'PATCH');
            expect(jsonDecode(request.body)['name'], 'Alex Reyes');
            if (fail) {
              return http.Response(
                jsonEncode({'error': 'Could not save your name. Try again.'}),
                503,
              );
            }
            return http.Response(
              jsonEncode({
                'email': 'learner@example.com',
                'name': 'Alex Reyes',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({'revision': 0, 'data': null, 'updatedAt': null}),
            200,
          );
        }),
      );
      await tester.pumpWidget(SpendTrackerApp(cloud: cloud));
      await openHomeAfterWelcome(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('home-greeting'))).data,
        endsWith('\nPam!'),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('More'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-profile')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('edit-profile-name')),
        'Unwanted change',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cloud.name, 'Pam');
      expect(edits, 0);
      await tester.tap(find.byKey(const Key('edit-profile')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('edit-profile-name')), ' ');
      await tester.tap(find.byKey(const Key('save-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your name'), findsOneWidget);
      expect(edits, 0);
      await tester.enterText(
        find.byKey(const Key('edit-profile-name')),
        'Alex Reyes',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Could not save your name. Try again.'), findsOneWidget);
      expect(cloud.name, 'Pam');
      fail = false;
      await tester.tap(find.byKey(const Key('save-profile')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(cloud.name, 'Alex Reyes');
      expect(find.text('Alex Reyes'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Home'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('home-greeting'))).data,
        endsWith('\nAlex Reyes!'),
      );
      expect(tester.takeException(), null);
    },
  );
}
