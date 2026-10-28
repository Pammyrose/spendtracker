import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spendtracker/cloud_api.dart';
import 'package:spendtracker/app_data.dart';

AppData testAppData() => AppData(cloud: testCloudApi());

CloudApi testCloudApi() => CloudApi(
  client: MockClient((request) async {
    if (request.url.path == '/auth/login' ||
        request.url.path == '/auth/register') {
      return http.Response(
        jsonEncode({
          'token': 'a' * 64,
          'email': 'learner@example.com',
          'name': 'Pamela',
        }),
        200,
      );
    }
    return http.Response(
      jsonEncode({'revision': 0, 'updatedAt': null, 'data': null}),
      200,
    );
  }),
);

// Feature tests still use the real welcome and sign-in flow, with a local mock API.
Future<void> openHomeAfterWelcome(WidgetTester tester) async {
  await tester.tap(find.text('Get Started'));
  await tester.pumpAndSettle();
  if (find.byKey(const Key('login-email')).evaluate().isEmpty) return;
  await tester.enterText(
    find.byKey(const Key('login-email')),
    'learner@example.com',
  );
  await tester.ensureVisible(find.byKey(const Key('login-password')));
  await tester.enterText(
    find.byKey(const Key('login-password')),
    'password123',
  );
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}
