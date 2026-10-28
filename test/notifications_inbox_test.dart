import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendtracker/app_data.dart';
import 'package:spendtracker/main.dart';

import 'app_test_helpers.dart';

import 'package:spendtracker/notifications_inbox_page.dart';

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
    'Inbox selects unpaid due alerts and prioritizes active payment plans',
    () {
      final now = DateTime(2026, 10, 28, 12);
      Bill bill(String name, int days) => Bill(
        name: name,
        amount: 100,
        due: now.add(Duration(days: days)),
      );
      final overdue = bill('Rent', -2);
      final today = bill('Water', 0);
      final soon = bill('Internet', 7);
      final later = bill('Phone', 8);
      final paid = bill('Paid bill', -10)..paid = true;
      final deferred = bill('Deferred rent', -4)
        ..paymentPlanAt = now.add(const Duration(days: 1))
        ..paymentReason = 'Landlord is away'
        ..followUpRepeat = 'Weekly';
      final followup = bill('Follow-up rent', -5)
        ..paymentPlanAt = now.subtract(const Duration(hours: 1))
        ..paymentReason = 'Waiting for landlord';
      final farPlan = bill('Later plan', -1)
        ..paymentPlanAt = now.add(const Duration(days: 9));
      final alerts = billAlerts([
        soon,
        later,
        paid,
        deferred,
        overdue,
        today,
        followup,
        farPlan,
      ], now);
      expect(alerts.map((a) => a.bill.name), [
        'Rent',
        'Follow-up rent',
        'Water',
      ]);
      expect(alerts.map((a) => a.title), [
        'Bill overdue',
        'Payment follow-up',
        'Bill due today',
      ]);
      expect(alerts[1].detail, 'Waiting for landlord');
      expect(alerts[0].detail, '2 days overdue');
      expect(alerts[0].urgent, true);
      expect(alerts.last.urgent, true);
      deferred.paid = true;
      expect(billAlerts([deferred], now), isEmpty);
    },
  );

  testWidgets(
    'Home bell opens alerts, opens a bill, and removes its paid alert',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(SpendTrackerApp(data: testAppData()));
      await openHomeAfterWelcome(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsInboxPage), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      final inbox = find.byKey(const Key('notifications-inbox'));
      final data = AppDataScope.of(tester.element(inbox));
      expect(find.text('Bill due soon'), findsNothing);
      expect(find.text('Upcoming'), findsNothing);
      expect(find.byKey(const ValueKey('bill-alert-0')), findsNothing);
      final due = Bill(
        name: 'Due rent',
        amount: 900,
        due: DateTime.now().subtract(const Duration(days: 1)),
      );
      data.bills.add(due);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bill-alert-6')));
      await tester.pumpAndSettle();
      expect(find.text('Mark as paid'), findsOneWidget);
      await tester.tap(find.text('Mark as paid'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bill-alert-6')), findsNothing);
      expect(find.text('Bill marked paid'), findsOneWidget);
      final bill = data.bills.bills[1];
      data.bills.postpone(
        bill,
        reason: 'The collector is away',
        at: DateTime.now().add(const Duration(days: 1)),
        repeat: 'Daily',
      );
      await tester.pumpAndSettle();
      expect(find.text('Upcoming payment'), findsNothing);
      expect(find.text('The collector is away'), findsNothing);
      bill.paymentPlanAt = DateTime.now().subtract(const Duration(minutes: 1));
      data.bills.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Payment follow-up'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bill-alert-1')));
      await tester.pumpAndSettle();
      expect(find.text('Payment note'), findsOneWidget);
      expect(find.text('The collector is away'), findsWidgets);
      expect(tester.takeException(), null);
      // Dispose the inbox timer before the test ends.
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'Transaction activity persists without replaying imported transactions',
    () {
      final data = AppData(seed: false);
      final originalDate = DateTime(2026, 1, 1);
      data.addExpense(ExpenseRecord('Lunch', 0, 100, originalDate));
      final income = IncomeRecord(
        name: 'Salary',
        amount: 1000,
        date: originalDate,
        category: 0,
      );
      data.saveIncome(income);
      final bill = Bill(name: 'Rent', amount: 300, due: originalDate);
      data.bills.add(bill);
      data.bills.togglePaid(bill);
      expect(data.transactionActivity.map((a) => a.kind), [
        'billPaid',
        'incomeAdded',
        'expenseAdded',
      ]);
      expect(data.transactionActivity.last.transactionDate, originalDate);
      expect(
        data.transactionActivity.last.recordedAt.year,
        DateTime.now().year,
      );
      final restored = AppData(seed: false)..restore(data.backupJson());
      expect(restored.transactionActivity.length, 3);
      expect(restored.transactionActivity.first.name, 'Rent');
      final invalid = jsonDecode(data.backupJson()) as Map<String, dynamic>;
      invalid['transactionActivity'][0]['kind'] = 'unknown';
      expect(
        () => restored.restore(jsonEncode(invalid)),
        throwsFormatException,
      );
      expect(restored.transactionActivity.length, 3);
      final legacy = jsonDecode(data.backupJson()) as Map<String, dynamic>;
      legacy.remove('transactionActivity');
      restored.restore(jsonEncode(legacy));
      expect(restored.expenses.length, 1);
      expect(restored.transactionActivity, isEmpty);
      data.bills.togglePaid(bill);
      expect(data.transactionActivity.first.kind, 'billUnpaid');
      data.clearRecords();
      expect(data.transactionActivity, isEmpty);
      data.dispose();
      restored.dispose();
    },
  );

  testWidgets(
    'Transaction feed shows saved actions newest first with original dates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final data = AppData(seed: false);
      data.addExpense(ExpenseRecord('Lunch', 0, 120, DateTime(2026, 1, 1)));
      data.saveIncome(
        IncomeRecord(
          name: 'Salary',
          amount: 500,
          date: DateTime(2026, 1, 2),
          category: 0,
        ),
      );
      await tester.pumpWidget(
        AppDataScope(
          data: data,
          child: const MaterialApp(home: NotificationsInboxPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Transaction activity'), findsOneWidget);
      expect(find.text('Upcoming'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Income recorded')).dy,
        lessThan(tester.getTopLeft(find.text('Expense added')).dy),
      );
      await tester.tap(find.text('Expense added'));
      await tester.pumpAndSettle();
      expect(find.text('Transaction date: Jan 1, 2026'), findsOneWidget);
      expect(find.textContaining('Recorded:'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      data.dispose();
    },
  );
}
