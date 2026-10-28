import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendtracker/main.dart';

import 'app_test_helpers.dart';

void main() {
  testWidgets('Past income expands by month and regroups edited dates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SpendTrackerApp(data: testAppData()));
    await openHomeAfterWelcome(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.shopping_bag_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Past Month'));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.textContaining('\u20b1 22,000.00'), findsOneWidget);
    expect(find.text('Part Time'), findsNothing);
    await tester.tap(find.text('September 2026'));
    await tester.pumpAndSettle();
    expect(find.text('\u20b1 20,000.00'), findsOneWidget);
    expect(find.text('Part Time'), findsOneWidget);
    await tester.tap(find.text('September 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Part Time'), findsNothing);
    await tester.tap(find.text('September 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Options for Part Time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('income-date')));
    await tester.tap(find.byKey(const Key('income-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Income'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Past Month'));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('August 2026'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('September 2026')).dy,
      lessThan(tester.getTopLeft(find.text('August 2026')).dy),
    );
    await tester.tap(find.text('August 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Part Time'), findsOneWidget);
  });

  testWidgets('Income supports adding, month filters, editing, and deleting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SpendTrackerApp(data: testAppData()));
    await openHomeAfterWelcome(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.shopping_bag_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('\u20b1 25,000.00'), findsOneWidget);
    await tester.tap(find.byTooltip('Add income'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Income'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an income name'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('income-name')),
      'Contract work',
    );
    await tester.enterText(find.byKey(const Key('income-amount')), '1200');
    await tester.ensureVisible(find.byKey(const Key('income-date')));
    await tester.tap(find.byKey(const Key('income-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('income-category')));
    await tester.tap(find.byKey(const Key('income-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Freelance').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Income'));
    await tester.pumpAndSettle();
    expect(find.text('Add Income'), findsNothing);
    await tester.scrollUntilVisible(find.text('Contract work'), 100);
    expect(find.text('\u20b1 1,200.00'), findsOneWidget);
    await tester.tap(find.text('Past Month'));
    await tester.pumpAndSettle();
    expect(find.text('Contract work'), findsNothing);
    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Contract work'), 100);
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.shopping_bag_rounded));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Options for Contract work'),
      100,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Options for Contract work'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Options for Contract work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('income-name')),
      'Updated contract',
    );
    await tester.tap(find.text('Save Income'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Options for Updated contract'),
      100,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Options for Updated contract'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Options for Updated contract'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Updated contract'), findsNothing);
  });

  testWidgets('Home header and navigation work on a small screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SpendTrackerApp(data: testAppData()));
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byKey(const Key('home-greeting')), findsNothing);
    await openHomeAfterWelcome(tester);
    await tester.pumpAndSettle();
    expect(find.text('Get Started'), findsNothing);

    expect(find.byKey(const Key('home-greeting')), findsOneWidget);
    for (final label in ['Home', 'Expenses', 'Bills', 'Income', 'More']) {
      expect(find.text(label), findsOneWidget);
    }

    expect(find.text('\u20b1 24,750.00'), findsOneWidget);
    expect(find.text('Total Income'), findsOneWidget);
    expect(find.text('Total Spent'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide balance'));
    await tester.pump();
    expect(find.text('\u20b1 24,750.00'), findsNothing);
    await tester.tap(find.byTooltip('Show balance'));
    await tester.pump();
    expect(find.text('\u20b1 24,750.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Your alerts'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

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
    expect(find.byKey(const Key('home-greeting')), findsOneWidget);
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
    await tester.pumpWidget(SpendTrackerApp(data: testAppData()));
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byKey(const Key('home-greeting')), findsNothing);
    await openHomeAfterWelcome(tester);
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
    await tester.pumpWidget(SpendTrackerApp(data: testAppData()));
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byKey(const Key('home-greeting')), findsNothing);
    await openHomeAfterWelcome(tester);
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
