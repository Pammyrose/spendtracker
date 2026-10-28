import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendtracker/app_data.dart';
import 'package:spendtracker/bills_page.dart';
import 'package:spendtracker/category_catalog.dart';
import 'package:spendtracker/category_picker.dart';
import 'package:spendtracker/expenses_page.dart';
import 'package:spendtracker/main.dart';

import 'app_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? saved;
  setUp(() {
    saved = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceStorage, (call) async {
          if (call.method == 'loadData') return saved;
          if (call.method == 'saveData') {
            saved = call.arguments as String;
            return null;
          }
          throw PlatformException(code: 'UNKNOWN');
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceStorage, null),
  );

  Future<void> start(WidgetTester tester, String tab) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SpendTrackerApp(data: testAppData()));
    await tester.pumpAndSettle();
    await openHomeAfterWelcome(tester);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(tab),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickPets(WidgetTester tester) async {
    expect(find.byType(IconPickerDialog), findsOneWidget);
    final center = tester.getCenter(find.byType(Dialog).last);
    expect(center.dx, closeTo(160, 2));
    expect(center.dy, closeTo(284, 2));
    await tester.enterText(find.byKey(const Key('icon-search')), 'Pets');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('icon-pets')));
    await tester.pumpAndSettle();
  }

  Future<void> createCategory(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const Key('add-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-category')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a category name'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('category-name')), name);
    await tester.tap(find.byKey(const Key('category-icon')));
    await tester.pumpAndSettle();
    await pickPets(tester);
    await tester.tap(find.byKey(const Key('save-category')));
    await tester.pumpAndSettle();
  }

  test('New category metadata and record references survive backup and legacy data', () async {
    final data = AppData();
    final expenseIndex = data.addCategory(
      CategoryKind.expense,
      'Pet food',
      'pets',
    );
    final incomeIndex = data.addCategory(
      CategoryKind.income,
      'Side business',
      'savings',
    );
    final billIndex = data.addCategory(CategoryKind.bill, 'Vet care', 'pets');
    expect(
      () => data.addCategory(CategoryKind.expense, '  PET FOOD  ', 'pets'),
      throwsFormatException,
    );
    data.expenses.add(
      ExpenseRecord('Kibbles', expenseIndex, 75, DateTime(2026, 10, 1)),
    );
    data.incomes.add(
      IncomeRecord(
        name: 'Side business',
        amount: 100,
        date: DateTime(2026, 10, 1),
        category: incomeIndex,
      ),
    );
    data.bills.add(
      Bill(
        name: 'Vet plan',
        amount: 250,
        due: DateTime(2026, 11, 1),
        category: billIndex,
        icon: data.billCategories[billIndex].iconIndex,
      ),
    );
    final copy = AppData(seed: false)..restore(data.backupJson());
    expect(
      copy.expenseCategories[copy.expenses.last.category].name,
      'Pet food',
    );
    expect(copy.incomeCategories[copy.incomes.last.category].iconId, 'savings');
    expect(
      copy.billCategories[copy.bills.bills.last.category!].name,
      'Vet care',
    );
    expect(categoryIcons[copy.bills.bills.last.icon].id, 'pets');
    final original = copy.backupJson();
    final broken = jsonDecode(original) as Map<String, dynamic>;
    broken['categories']['expense'].last['icon'] = 'not-an-icon';
    expect(() => copy.restore(jsonEncode(broken)), throwsFormatException);
    expect(copy.backupJson(), original);
    final legacyData = AppData();
    final legacy = jsonDecode(legacyData.backupJson()) as Map<String, dynamic>;
    legacy.remove('categories');
    for (final bill in legacy['bills']) {
      (bill as Map).remove('category');
    }
    copy.restore(jsonEncode(legacy));
    expect(copy.expenseCategories.first.name, 'Food');
    expect(copy.bills.bills.first.icon, 0);
    await data.flush();
    await copy.flush();
    data.dispose();
    copy.dispose();
    legacyData.dispose();
  });

  testWidgets(
    'Centered bill icon chooser supports added categories and saves the selected icon',
    (tester) async {
      await start(tester, 'Bills');
      final data = AppDataScope.of(tester.element(find.byType(BillsPage)));
      await tester.tap(find.byTooltip('Add bill'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('bill-icon')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bill-icon')));
      await tester.pumpAndSettle();
      await pickPets(tester);
      expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('bill-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bill-category')));
      await tester.pumpAndSettle();
      await createCategory(tester, 'Vet care');
      expect(find.text('Vet care'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('bill-name')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('bill-name')), 'Vet plan');
      await tester.enterText(find.byKey(const Key('bill-amount')), '250');
      await tester.ensureVisible(find.text('Select date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Bill'));
      await tester.pumpAndSettle();
      expect(data.bills.bills.last.name, 'Vet plan');
      expect(
        data.billCategories[data.bills.bills.last.category!].name,
        'Vet care',
      );
      expect(categoryIcons[data.bills.bills.last.icon].id, 'pets');
      await data.flush();
      final reloaded = AppData(seed: false);
      await reloaded.load();
      expect(reloaded.billCategories.last.name, 'Vet care');
      reloaded.dispose();
    },
  );

  testWidgets(
    'A new expense category can be selected, saved, and opened in History',
    (tester) async {
      await start(tester, 'Expenses');
      final data = AppDataScope.of(tester.element(find.byType(ExpensesPage)));
      await tester.tap(find.byTooltip('Add expense'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CategoryField));
      await tester.pumpAndSettle();
      await createCategory(tester, 'Pet food');
      expect(find.text('Pet food'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('expense-amount')), '75');
      await tester.enterText(
        find.byKey(const Key('expense-description')),
        'Kibbles',
      );
      await tester.ensureVisible(find.text('Select date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();
      expect(
        data.expenseCategories[data.expenses.last.category].name,
        'Pet food',
      );
      expect(find.text('\u20b1 10,325.00'), findsNWidgets(2));
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('More'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View full history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View full history'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Pet food'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pet food'));
      await tester.pumpAndSettle();
      expect(find.text('Kibbles'), findsOneWidget);
    },
  );
}
