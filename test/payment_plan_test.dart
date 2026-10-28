import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendtracker/app_data.dart';
import 'package:spendtracker/bills_page.dart';
import 'package:spendtracker/main.dart';

import 'app_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? saved;
  bool permission = true;
  int permissionRequests = 0;
  setUp(() {
    saved = null;
    permission = true;
    permissionRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceStorage, (call) async {
          if (call.method == 'loadData') return saved;
          if (call.method == 'saveData') {
            saved = call.arguments as String;
            return null;
          }
          if (call.method == 'requestNotifications') {
            permissionRequests++;
            return permission;
          }
          throw PlatformException(code: 'UNKNOWN');
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceStorage, null),
  );

  test(
    'Payment plans preserve due dates, validate reasons, and survive backup',
    () async {
      final data = AppData();
      final bill = data.bills.bills.first;
      final due = bill.due;
      final at = DateTime.now().add(const Duration(days: 2));
      expect(
        () => data.bills.postpone(bill, reason: ' ', at: at, repeat: 'Daily'),
        throwsFormatException,
      );
      expect(
        () => data.bills.postpone(
          bill,
          reason: 'Away',
          at: DateTime(2020),
          repeat: 'Daily',
        ),
        throwsFormatException,
      );
      data.bills.postpone(
        bill,
        reason: ' Landlord is away ',
        at: at,
        repeat: 'Every 2 days',
      );
      await data.flush();
      expect(bill.due, due);
      expect(bill.paid, false);
      expect(bill.paymentReason, 'Landlord is away');
      final restored = AppData(seed: false)..restore(saved!);
      final copy = restored.bills.bills.first;
      expect(copy.paymentPlanAt, at);
      expect(copy.followUpRepeat, 'Every 2 days');
      expect(copy.paymentReason, bill.paymentReason);
      expect(copy.due, due);
      final invalid = jsonDecode(saved!) as Map<String, dynamic>;
      invalid['bills'][0]['paymentReason'] = '';
      expect(
        () => restored.restore(jsonEncode(invalid)),
        throwsFormatException,
      );
      expect(restored.bills.bills.first.paymentReason, bill.paymentReason);
      data.bills.togglePaid(bill);
      await data.flush();
      expect(jsonDecode(saved!)['bills'][0]['paid'], true);
      expect(
        () =>
            data.bills.postpone(bill, reason: 'Away', at: at, repeat: 'Daily'),
        throwsFormatException,
      );
      data.bills.togglePaid(bill);
      data.bills.removePaymentPlan(bill);
      await data.flush();
      expect(bill.paymentPlanAt, null);
      expect(bill.paymentReason, 'Landlord is away');
      expect(jsonDecode(saved!)['bills'][0]['paymentPlanAtMillis'], null);
      final legacy = jsonDecode(saved!) as Map<String, dynamic>;
      for (final entry in legacy['bills']) {
        for (final key in [
          'notes',
          'paymentReason',
          'paymentPlanAt',
          'paymentPlanAtMillis',
          'followUpRepeat',
        ]) {
          entry.remove(key);
        }
      }
      restored.restore(jsonEncode(legacy));
      expect(restored.bills.bills.first.paymentPlanAt, null);
      await restored.flush();
    },
  );

  Future<void> start(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SpendTrackerApp(data: testAppData()));
    await tester.pumpAndSettle();
    await openHomeAfterWelcome(tester);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Bills'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BillCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pay-later')));
    await tester.pumpAndSettle();
  }

  for (final allowed in [true, false]) {
    testWidgets('Pay later saves an unpaid bill, permission $allowed', (
      tester,
    ) async {
      permission = allowed;
      await start(tester);
      await tester.tap(find.text('Save payment plan'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a reason for paying later'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('payment-reason')),
        'The landlord is away',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.ensureVisible(find.byKey(const Key('payment-repeat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('payment-repeat')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save payment plan'));
      await tester.pumpAndSettle();
      expect(permissionRequests, 1);
      expect(find.text('The landlord is away'), findsWidgets);
      final record = (jsonDecode(saved!)['bills'] as List).firstWhere(
        (e) => e['paymentPlanAt'] != null,
      );
      expect(record['paid'], false);
      expect(record['followUpRepeat'], 'Weekly');
      expect(record['paymentReason'], 'The landlord is away');
      expect(
        DateTime.parse(record['paymentPlanAt']).isAfter(DateTime.now()),
        true,
      );
      if (!allowed) {
        expect(
          find.textContaining('Enable Android notifications'),
          findsOneWidget,
        );
      }
      await tester.tap(find.byType(BillCard).first);
      await tester.pumpAndSettle();
      expect(find.text('Payment note'), findsOneWidget);
      await tester.ensureVisible(find.text('Mark as paid'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as paid'));
      await tester.pumpAndSettle();
      expect(jsonDecode(saved!)['bills'][0]['paid'], true);
      expect(tester.takeException(), null);
    });
  }
}
