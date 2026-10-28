import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendtracker/app_data.dart';
import 'package:spendtracker/more_pages.dart';
import 'package:spendtracker/notifications_inbox_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          deviceStorage,
          (call) async => call.method == 'requestNotifications' ? true : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceStorage, null);
  });
  test('Monthly expense alerts exclude other months and future entries', () {
    final data = AppData(seed: false)
      ..expenseAlerts = true
      ..expenseAlertAmount = 1000;
    final now = DateTime(2026, 10, 28, 12);
    data.expenses.addAll([
      ExpenseRecord('Earlier', 0, 600, DateTime(2026, 10, 1)),
      ExpenseRecord('Today', 0, 400, DateTime(2026, 10, 28)),
      ExpenseRecord('Future', 0, 300, DateTime(2026, 10, 29)),
      ExpenseRecord('Previous month', 0, 2000, DateTime(2026, 9, 1)),
    ]);
    expect(data.spendingThrough(now), 1000);
    expect(data.expenseLimitReached(now), true);
    expect(data.spendingThrough(DateTime(2026, 10, 29)), 1300);
    expect(data.expenseLimitReached(DateTime(2026, 11, 1)), false);
    data.expenseAlertAmount = 1001;
    expect(data.expenseLimitReached(now), false);
    data.expenseAlertAmount = 1000;
    data.notificationsEnabled = false;
    expect(data.expenseLimitReached(now), false);
    data.notificationsEnabled = true;
    data.expenseAlerts = false;
    expect(data.expenseLimitReached(now), false);
    data.dispose();
  });

  test('Payment alerts switch as the actual reminder time passes', () {
    final at = DateTime(2026, 10, 28, 15);
    final bill = Bill(
      name: 'Rent',
      amount: 1000,
      due: DateTime(2026, 10, 20),
      paymentPlanAt: at,
      paymentReason: 'Landlord is away',
    );
    final before = at.subtract(const Duration(minutes: 30));
    expect(billAlerts([bill], before), isEmpty);
    expect(paymentCountdown(at, before), 'Payment in 30 minutes');
    expect(billAlerts([bill], at).single.title, 'Payment follow-up');
    expect(paymentCountdown(at, at), 'Payment time is now');
    expect(
      paymentCountdown(at, at.add(const Duration(minutes: 2))),
      'Payment time passed 2 minutes ago',
    );
    expect(billAlerts([bill], at).single.urgent, true);
  });

  testWidgets(
    'Expense inbox updates after expenses, limit changes, and disabling',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final data = AppData(seed: false)
        ..expenseAlerts = true
        ..expenseAlertAmount = 100;
      await tester.pumpWidget(
        AppDataScope(
          data: data,
          child: const MaterialApp(home: NotificationsInboxPage()),
        ),
      );
      expect(find.byKey(const Key('notifications-updated')), findsOneWidget);
      expect(find.byKey(const Key('expense-limit-alert')), findsNothing);
      data.expenses.add(ExpenseRecord('Lunch', 0, 100, DateTime.now()));
      data.changed();
      await tester.pumpAndSettle();
      expect(find.text('Monthly spending limit reached'), findsOneWidget);
      expect(find.textContaining('100.00 spent this month'), findsOneWidget);
      await tester.tap(find.text('Manage expense alerts'));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('expense-alert-limit'));
      await tester.scrollUntilVisible(
        field,
        160,
        scrollable: find
            .descendant(
              of: find.byType(NotificationSettingsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(field, '200');
      expect(
        data.expenseAlertAmount,
        100,
      ); // Typing alone cannot trigger notifications.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(data.expenseAlertAmount, 200);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expense-limit-alert')), findsNothing);
      data.expenseAlertAmount = 100;
      data.changed();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expense-limit-alert')), findsOneWidget);
      data.expenseAlerts = false;
      data.changed();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expense-limit-alert')), findsNothing);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      data.dispose();
    },
  );
}
