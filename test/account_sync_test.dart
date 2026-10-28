import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spendtracker/app_data.dart';
import 'package:spendtracker/cloud_api.dart';
import 'package:spendtracker/main.dart';

import 'app_test_helpers.dart';

class FakeAccountServer {
  final documents = <String, Map<String, dynamic>>{};
  final revisions = <String, int>{};
  final cache = <String, String>{};
  String? active;
  bool offline = false;
  String key(dynamic value) => '${value['server']}\n${value['email']}';
  Future<dynamic> native(dynamic call) async {
    if (call.method == 'setActiveAccount') {
      active = call.arguments == null ? null : key(call.arguments);
    }
    if (call.method == 'loadAccountData') return cache[key(call.arguments)];
    if (call.method == 'saveAccountData') {
      final value = call.arguments;
      cache[key(value)] = jsonEncode({
        'data': value['data'],
        'revision': value['revision'],
        'dirty': value['dirty'],
      });
    }
    return null;
  }

  CloudApi client() => CloudApi(
    client: MockClient((request) async {
      if (offline) throw http.ClientException('offline');
      if (request.url.path == '/auth/login') {
        final email = jsonDecode(request.body)['email'] as String;
        return http.Response(
          jsonEncode({
            'email': email,
            'name': email.split('@').first,
            'token': email.startsWith('other') ? 'b' * 64 : 'a' * 64,
          }),
          200,
        );
      }
      if (request.method == 'DELETE') return http.Response('', 204);
      final owner = request.headers['Authorization']!.endsWith('b' * 64)
          ? 'other'
          : 'owner';
      final revision = revisions[owner] ?? 0;
      if (request.method == 'PUT') {
        final body = jsonDecode(request.body);
        if (body['revision'] != revision) {
          return http.Response(
            jsonEncode({'error': 'The server backup changed.'}),
            409,
          );
        }
        documents[owner] = body['data'];
        revisions[owner] = revision + 1;
        return http.Response(jsonEncode({'revision': revision + 1}), 200);
      }
      return http.Response(
        jsonEncode({
          'data': documents[owner],
          'revision': revision,
          'updatedAt': null,
        }),
        200,
      );
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAccountServer server;
  setUp(() {
    server = FakeAccountServer();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceStorage, server.native);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceStorage, null),
  );
  Future<void> login(AppData data, [String email = 'owner@example.com']) async {
    await data.cloud.authenticate(
      'http://127.0.0.1:3000',
      email,
      'password123',
      register: false,
    );
    for (var attempts = 0; attempts < 100 && !data.sync.ready; attempts++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(data.sync.ready, true);
  }

  test('Real accounts start empty, automatically save bills, and reload payment status', () async {
    final data = AppData(liveAccount: true, cloud: server.client());
    await data.load();
    await login(data);
    expect(data.bills.bills, isEmpty);
    expect(data.expenses, isEmpty);
    expect(data.incomes, isEmpty);
    final bill = Bill(
      name: 'My actual rent',
      amount: 4200,
      due: DateTime(2026, 11, 10),
      repeat: 'Never',
      notes: 'Pay my landlord',
    );
    data.bills.add(bill);
    await data.sync.flushServer();
    expect(server.documents['owner']!['bills'][0]['name'], 'My actual rent');
    expect(server.documents['owner']!['bills'][0]['notes'], 'Pay my landlord');
    expect(data.sync.dirty, false);
    data.bills.togglePaid(bill);
    await data.sync.flushServer();
    expect(server.documents['owner']!['bills'][0]['paid'], true);
    await data.cloud.signOut();
    expect(data.bills.bills, isEmpty);
    await login(data, 'other@example.com');
    expect(data.bills.bills, isEmpty);
    await data.cloud.signOut();
    await login(data);
    expect(data.bills.bills.single.name, 'My actual rent');
    expect(data.bills.bills.single.paid, true);
    data.dispose();
  });

  test(
    'Failed saves survive reopening and retry only for the original account',
    () async {
      final data = AppData(liveAccount: true, cloud: server.client());
      await login(data);
      server.offline = true;
      data.bills.add(
        Bill(
          name: 'Pending electricity',
          amount: 800,
          due: DateTime(2026, 11, 1),
        ),
      );
      await data.sync.flushServer();
      await data.flush();
      expect(data.sync.error, isNotNull);
      expect(data.sync.dirty, true);
      data.dispose();
      server.offline = false;
      final reopened = AppData(liveAccount: true, cloud: server.client());
      await login(reopened, 'other@example.com');
      expect(reopened.bills.bills, isEmpty);
      expect(server.documents['other'], null);
      await reopened.cloud.signOut();
      await login(reopened);
      await reopened.sync.flushServer();
      expect(reopened.bills.bills.single.name, 'Pending electricity');
      expect(
        server.documents['owner']!['bills'][0]['name'],
        'Pending electricity',
      );
      expect(reopened.sync.dirty, false);
      reopened.dispose();
    },
  );

  test(
    'Conflicts preserve pending device records until an explicit server reload',
    () async {
      final data = AppData(liveAccount: true, cloud: server.client());
      await login(data);
      final remote = AppData(seed: false);
      remote.bills.add(
        Bill(
          name: 'Other device bill',
          amount: 500,
          due: DateTime(2026, 11, 1),
        ),
      );
      server.documents['owner'] = jsonDecode(remote.backupJson());
      server.revisions['owner'] = 1;
      data.bills.add(
        Bill(name: 'Device bill', amount: 100, due: DateTime(2026, 11, 1)),
      );
      await data.sync.flushServer();
      expect(data.sync.error, isNotNull);
      expect(data.bills.bills.single.name, 'Device bill');
      await data.sync.retry();
      expect(
        server.documents['owner']!['bills'][0]['name'],
        'Other device bill',
      );
      await data.sync.reload();
      expect(data.bills.bills.single.name, 'Other device bill');
      expect(data.sync.dirty, false);
      data.dispose();
      remote.dispose();
    },
  );

  test(
    'A delayed expired-session response cannot sign out a different account',
    () async {
      final release = Completer<void>();
      var delay = false;
      final client = CloudApi(
        client: MockClient((request) async {
          if (request.url.path == '/auth/login') {
            final email = jsonDecode(request.body)['email'] as String;
            return http.Response(
              jsonEncode({
                'email': email,
                'token': email.startsWith('other') ? 'b' * 64 : 'a' * 64,
              }),
              200,
            );
          }
          if (request.method == 'DELETE') return http.Response('', 204);
          if (delay &&
              request.headers['Authorization'] == 'Bearer ${'a' * 64}') {
            await release.future;
            return http.Response(
              jsonEncode({'error': 'Expired old session'}),
              401,
            );
          }
          return http.Response(
            jsonEncode({'data': null, 'revision': 0, 'updatedAt': null}),
            200,
          );
        }),
      );
      await client.authenticate(
        'http://127.0.0.1:3000',
        'owner@example.com',
        'password123',
        register: false,
      );
      delay = true;
      final previous = client.refresh();
      final previousResult = expectLater(
        previous,
        throwsA(isA<CloudApiException>()),
      );
      await client.signOut();
      await client.authenticate(
        'http://127.0.0.1:3000',
        'other@example.com',
        'password123',
        register: false,
      );
      release.complete();
      await previousResult;
      expect(client.signedIn, true);
      expect(client.email, 'other@example.com');
      client.dispose();
    },
  );

  testWidgets(
    'The live Bills page contains no sample records and Save Bill updates the server',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(SpendTrackerApp(cloud: server.client()));
      await openHomeAfterWelcome(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Bills'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Internet'), findsNothing);
      expect(find.text('Electricity'), findsNothing);
      expect(
        find.text('No bills yet. Tap + to add your first bill.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Add bill'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('bill-name')), 'Actual rent');
      await tester.enterText(find.byKey(const Key('bill-amount')), '4500');
      await tester.ensureVisible(find.text('Select date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Bill'));
      await tester.pumpAndSettle();
      expect(find.text('Actual rent'), findsOneWidget);
      expect(server.documents['owner']!['bills'][0]['name'], 'Actual rent');
      expect(server.documents['owner']!['bills'][0]['amount'], 4500);
      expect(tester.takeException(), null);
    },
  );
}
