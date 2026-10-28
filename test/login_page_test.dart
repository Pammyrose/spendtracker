import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spendtracker/app_data.dart';
import 'package:spendtracker/cloud_api.dart';
import 'package:spendtracker/cloud_backup_page.dart';
import 'package:spendtracker/login_page.dart';
import 'package:spendtracker/main.dart';

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

  Future<void> start(WidgetTester tester, CloudApi cloud) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SpendTrackerApp(cloud: cloud));
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  }

  Future<void> enter(WidgetTester tester, String key, String value) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, value);
  }

  Future<void> openCloud(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(HomeScreen)))
        .push(MaterialPageRoute<void>(builder: (_) => const CloudBackupPage()));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Welcome opens login; invalid credentials stay; sign out closes protected routes',
    (tester) async {
      final cloud = CloudApi(
        client: MockClient((request) async {
          if (request.url.path == '/auth/login') {
            if (jsonDecode(request.body)['password'] != 'correct-password') {
              return http.Response(
                jsonEncode({'error': 'Email or password is incorrect.'}),
                401,
              );
            }
            return http.Response(
              jsonEncode({'token': 'a' * 64, 'email': 'learner@example.com'}),
              200,
            );
          }
          if (request.method == 'DELETE') return http.Response('', 204);
          return http.Response(
            jsonEncode({'revision': 0, 'updatedAt': null, 'data': null}),
            200,
          );
        }),
      );
      await start(tester, cloud);
      await tester.ensureVisible(find.byKey(const Key('login-submit')));
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      await enter(tester, 'login-email', 'learner@example.com');
      await enter(tester, 'login-password', 'wrong-password');
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('login-password')),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        false,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      await enter(tester, 'login-password', 'correct-password');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
        false,
      );
      await openCloud(tester);
      await tester.ensureVisible(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(CloudBackupPage), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(LoginPage))).canPop(),
        false,
      );
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'Create account validates confirmation and expired sessions return to login',
    (tester) async {
      var registrations = 0, expired = false;
      final cloud = CloudApi(
        client: MockClient((request) async {
          if (request.url.path == '/auth/register') {
            registrations++;
            final body = jsonDecode(request.body);
            expect(body['email'], 'new@example.com');
            expect(body['password'], 'new-password-123');
            expect(body['name'], 'Alex Reyes');
            return http.Response(
              jsonEncode({
                'token': 'b' * 64,
                'email': 'new@example.com',
                'name': 'Alex Reyes',
              }),
              201,
            );
          }
          if (expired) {
            return http.Response(
              jsonEncode({'error': 'Your session expired. Sign in again.'}),
              401,
            );
          }
          return http.Response(
            jsonEncode({'revision': 0, 'updatedAt': null, 'data': null}),
            200,
          );
        }),
      );
      await start(tester, cloud);
      await tester.ensureVisible(find.byKey(const Key('login-switch-mode')));
      await tester.tap(find.byKey(const Key('login-switch-mode')));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      await enter(tester, 'login-name', 'Alex Reyes');
      await enter(tester, 'login-email', 'new@example.com');
      await enter(tester, 'login-password', 'new-password-123');
      await enter(tester, 'login-confirm-password', 'different-password');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(registrations, 0);
      await enter(tester, 'login-confirm-password', 'new-password-123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(registrations, 1);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('home-greeting'))).data,
        endsWith('\nAlex Reyes!'),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('More'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alex Reyes'), findsOneWidget);
      expect(find.text('new@example.com'), findsOneWidget);
      expect(find.byKey(const Key('account-profile')), findsOneWidget);
      await openCloud(tester);
      expired = true;
      await tester.ensureVisible(find.text('Refresh server status'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh server status'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(CloudBackupPage), findsNothing);
      expect(tester.takeException(), null);
    },
  );
}
