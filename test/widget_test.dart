import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendtracker/main.dart';

void main() {
  testWidgets('Home header and navigation work on a small screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const SpendTrackerApp());
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Good Morning,\nPamela!'), findsNothing);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Get Started'), findsNothing);

    expect(find.text('Good Morning,\nPamela!'), findsOneWidget);
    for (final label in ['Home', 'Expenses', 'Bills', 'Income', 'More']) {
      expect(find.text(label), findsOneWidget);
    }

    expect(find.text('\u20b1 12,500.00'), findsOneWidget);
    expect(find.text('Total Income'), findsOneWidget);
    expect(find.text('Total Spent'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide balance'));
    await tester.pump();
    expect(find.text('\u20b1 12,500.00'), findsNothing);
    await tester.tap(find.byTooltip('Show balance'));
    await tester.pump();
    expect(find.text('\u20b1 12,500.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet.'), findsOneWidget);

    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      1,
    );

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Good Morning,\nPamela!'), findsOneWidget);
    await tester.ensureVisible(find.text('See All'));
    await tester.tap(find.text('See All'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      2,
    );
    expect(find.text('Internet'), findsOneWidget);
    expect(find.text('Electricity'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
  });

  testWidgets('Expenses filter by month and added entries update totals', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const SpendTrackerApp());
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Good Morning,\nPamela!'), findsNothing);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Get Started'), findsNothing);
    await tester.tap(find.byIcon(Icons.description_rounded));
    await tester.pumpAndSettle();
    expect(find.text('\u20b1 10,250.00'), findsNWidgets(2));
    expect(find.text('30%'), findsOneWidget);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.textContaining('No expenses this month.'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(find.text('Food and groceries'), findsOneWidget);

    await tester.tap(find.byTooltip('Add expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a description'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('expense-description')),
      'Lunch',
    );
    await tester.enterText(find.byKey(const Key('expense-amount')), '100');
    await tester.ensureVisible(find.text('Food'));
    await tester.tap(find.text('Food'));
    await tester.ensureVisible(find.text('Select date'));
    await tester.tap(find.text('Select date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();
    expect(find.text('\u20b1 10,350.00'), findsOneWidget);
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.text('\u20b1 3,200.00'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.description_rounded));
    await tester.pumpAndSettle();
    expect(find.text('\u20b1 10,350.00'), findsNWidgets(2));
  });

  testWidgets('Bills can be added, filtered, and marked paid', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const SpendTrackerApp());
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Good Morning,\nPamela!'), findsNothing);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Get Started'), findsNothing);
    await tester.tap(find.byIcon(Icons.account_balance_wallet_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Due Soon'));
    await tester.pumpAndSettle();
    expect(find.text('Internet'), findsOneWidget);
    expect(find.text('Electricity'), findsNothing);
    await tester.tap(find.text('Internet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as paid'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Paid'));
    await tester.pumpAndSettle();
    expect(find.text('Internet'), findsOneWidget);

    await tester.tap(find.byTooltip('Add bill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Bill'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a bill name'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('bill-name')), 'Test bill');
    await tester.enterText(find.byKey(const Key('bill-amount')), '250');
    await tester.ensureVisible(find.text('Select date'));
    await tester.tap(find.text('Select date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Bill'));
    await tester.pumpAndSettle();
    expect(find.text('Test bill'), findsOneWidget);
    expect(find.text('\u20b1 250.00'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Test bill'), findsOneWidget);
    expect(find.text('Internet'), findsNothing);
  });
}
