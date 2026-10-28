import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendtracker/app_data.dart';
import 'package:spendtracker/app_theme.dart';
import 'package:spendtracker/entry_widgets.dart';
import 'package:spendtracker/welcome_screen.dart';
import 'package:spendtracker/custom_color_picker.dart';
import 'package:spendtracker/main.dart';

import 'app_test_helpers.dart';

import 'package:spendtracker/history_page.dart';
import 'package:spendtracker/more_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? saved;
  String? selectedBackup;
  Map<dynamic, dynamic>? export;
  setUp(() {
    saved = null;
    selectedBackup = null;
    export = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceStorage, (call) async {
          switch (call.method) {
            case 'loadData':
              return saved;
            case 'saveData':
              saved = call.arguments as String;
              return null;
            case 'exportData':
              export = call.arguments as Map;
              return true;
            case 'readBackup':
              return selectedBackup;
            default:
              throw PlatformException(code: 'UNKNOWN');
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceStorage, null),
  );

  test(
    'Backup validation is atomic, and records and settings survive reload',
    () async {
      final data = AppData();
      final original = data.backupJson();
      final damaged = jsonDecode(original) as Map<String, dynamic>;
      damaged['incomes'][0]['amount'] = -50;
      expect(() => data.restore(jsonEncode(damaged)), throwsFormatException);
      expect(data.backupJson(), original);
      data.currency = 'EUR';
      data.theme = 'Brown';
      data.monthlySummary = false;
      data.billReminderTime = '31 days before';
      data.incomeReminderTime = '2 days before';
      data.changed();
      await data.flush();
      final reloaded = AppData(seed: false);
      await reloaded.load();
      expect(reloaded.incomes.length, data.incomes.length);
      expect(reloaded.expenses.length, data.expenses.length);
      expect(reloaded.bills.bills.length, 6);
      expect(reloaded.currency, 'EUR');
      expect(reloaded.theme, 'Brown');
      expect(reloaded.monthlySummary, false);
      expect(reloaded.billReminderTime, '31 days before');
      expect(reloaded.incomeReminderTime, '2 days before');
      reloaded.clearRecords();
      await reloaded.flush();
      expect(reloaded.expenses, isEmpty);
      expect(reloaded.incomes, isEmpty);
      expect(reloaded.bills.bills, isEmpty);
      reloaded.restore(original);
      await reloaded.flush();
      expect(reloaded.expenses.length, data.expenses.length);
      expect(reloaded.currency, 'PHP');
      data.dispose();
      reloaded.dispose();
    },
  );

  Future<void> start(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SpendTrackerApp(data: testAppData()));
    await tester.pumpAndSettle();
    await openHomeAfterWelcome(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
  }

  Future<void> showFeatureForTest(WidgetTester tester, String title) async {
    final heading = find.byKey(ValueKey('more-${title.toLowerCase()}-heading'));
    final scrollable = find
        .descendant(
          of: find.byKey(const Key('more-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(heading, 220, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.ensureVisible(heading);
    await tester.pumpAndSettle();
    // Headings are static; mount standalone views only for focused feature tests.
    await tester.tap(heading);
    await tester.pumpAndSettle();
    expect(Navigator.of(tester.element(heading)).canPop(), false);
    final Widget page = switch (title) {
      'History' => const HistoryPage(),
      'Notification settings' => const NotificationSettingsPage(),
      _ => const SettingsPage(),
    };
    Navigator.of(tester.element(heading))
        .push(MaterialPageRoute<void>(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  test('Every theme keeps button labels and secondary text readable', () {
    for (final palette in appPalettes) {
      final foreground = palette.onAccent.computeLuminance();
      final background = palette.accent.computeLuminance();
      final contrast =
          ((foreground > background ? foreground : background) + .05) /
          ((foreground < background ? foreground : background) + .05);
      expect(contrast, greaterThanOrEqualTo(4.5), reason: palette.name);
      final muted = palette.muted.computeLuminance();
      final surface = palette.surface.computeLuminance();
      expect(
        ((muted > surface ? muted : surface) + .05) /
            ((muted < surface ? muted : surface) + .05),
        greaterThanOrEqualTo(4.5),
        reason: '${palette.name} secondary text',
      );
    }
  });

  test(
    'Custom colors remain readable in light and dark themes and survive backup',
    () async {
      for (final dark in [false, true]) {
        for (final color in [
          Colors.white,
          Colors.black,
          Colors.yellow,
          Colors.grey,
          Colors.cyan,
          const Color(0xFF22AA88),
        ]) {
          final palette = AppPalette.custom(color, dark: dark);
          final first = palette.accent.computeLuminance(),
              second = palette.onAccent.computeLuminance();
          expect(
            ((first > second ? first : second) + .05) /
                ((first < second ? first : second) + .05),
            greaterThanOrEqualTo(4.5),
          );
          expect(palette.brightness, dark ? Brightness.dark : Brightness.light);
        }
      }
      final data = AppData()
        ..theme = 'Custom'
        ..customColor = 0xFF22AA88
        ..customDark = true;
      final copy = AppData(seed: false)..restore(data.backupJson());
      expect(copy.theme, 'Custom');
      expect(copy.customColor, 0xFF22AA88);
      expect(copy.customDark, true);
      expect(copy.palette.accent, data.palette.accent);
      final legacy = jsonDecode(AppData().backupJson()) as Map<String, dynamic>;
      (legacy['settings'] as Map)
        ..remove('customColor')
        ..remove('customDark');
      copy.restore(jsonEncode(legacy));
      expect(copy.theme, 'White');
      expect(copy.customDark, false);
      await copy.flush();
      data.dispose();
      copy.dispose();
    },
  );

  testWidgets('More exposes controls and a saved custom color wheel', (
    tester,
  ) async {
    await start(tester);
    expect(find.text('Recent activity'), findsOneWidget);
    final data = AppDataScope.of(tester.element(find.byType(MorePage)));
    final scrollable = find
        .descendant(
          of: find.byKey(const Key('more-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final reminders = find.text('Bill Reminders');
    await tester.scrollUntilVisible(reminders, 180, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(data.billReminders, false);
    Future<void> openWheel() async {
      await tester.scrollUntilVisible(
        find.text('Theme'),
        220,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Theme'));
      await tester.pumpAndSettle();
      expect(find.text('Color wheel'), findsNothing);
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      final wheelOption = find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Color wheel'),
      );
      await tester.ensureVisible(wheelOption);
      await tester.pumpAndSettle();
      await tester.tap(wheelOption);
      await tester.pumpAndSettle();
    }

    await openWheel();
    expect(find.byType(CustomColorDialog), findsOneWidget);
    final wheel = find.byKey(const Key('custom-color-wheel'));
    await tester.tapAt(tester.getCenter(wheel) + const Offset(35, 0));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('custom-hex')))
          .controller!
          .text,
      isNot('#5C66D6'),
    );
    await tester.ensureVisible(find.byKey(const Key('custom-hex')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('custom-hex')), '#22AA88');
    await tester.ensureVisible(find.byKey(const Key('custom-dark')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom-dark')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply color'));
    await tester.pumpAndSettle();
    expect(data.theme, 'Custom');
    expect(data.customColor, 0xFF22AA88);
    expect(data.customDark, true);
    expect(
      Theme.of(tester.element(find.byType(MorePage))).colorScheme.primary,
      data.palette.accent,
    );
    await data.flush();
    final reloaded = AppData(seed: false);
    await reloaded.load();
    expect(reloaded.customColor, data.customColor);
    expect(reloaded.customDark, true);
    reloaded.dispose();
    await openWheel();
    await tester.ensureVisible(find.byKey(const Key('custom-hex')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('custom-hex')), '#CC0033');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(data.customColor, 0xFF22AA88);
  });

  testWidgets('Themes restyle the app while pink welcome artwork stays fixed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SpendTrackerApp(data: testAppData()));
    await tester.pumpAndSettle();
    final data = AppDataScope.of(tester.element(find.byType(WelcomeScreen)));
    expect(data.theme, 'White');
    expect(
      Theme.of(tester.element(find.byType(WelcomeScreen)))
          .scaffoldBackgroundColor,
      Colors.white,
    );
    final originalBackground = tester
        .widget<CustomPaint>(find.byKey(const Key('welcome-background')))
        .painter!;
    final originalWallet = tester
        .widget<CustomPaint>(find.byKey(const Key('welcome-wallet')))
        .painter!;
    for (final palette in appPalettes) {
      data.theme = palette.name;
      data.changed();
      await tester.pumpAndSettle();
      final logo =
          tester.widget<Text>(find.text('SpendTracker')).textSpan! as TextSpan;
      expect(logo.children!.last.style!.color, const Color(0xFFFF5C83));
      expect(
        tester
            .widget<CustomPaint>(find.byKey(const Key('welcome-background')))
            .painter!
            .shouldRepaint(originalBackground),
        false,
      );
      expect(
        tester
            .widget<CustomPaint>(find.byKey(const Key('welcome-wallet')))
            .painter!
            .shouldRepaint(originalWallet),
        false,
      );
      final button =
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.text('Get Started'),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect((button.gradient! as LinearGradient).colors, [
        const Color(0xFFFF698C),
        const Color(0xFFEF5C80),
      ]);
    }
    await openHomeAfterWelcome(tester);
    await tester.pumpAndSettle();

    final backgrounds = <Color>{};
    final cards = <Color>{};
    final balances = <Color>{};
    for (final palette in appPalettes) {
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byIcon(Icons.more_horiz_rounded),
        ),
      );
      await tester.pumpAndSettle();
      await showFeatureForTest(tester, 'Settings');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      final choice = find.descendant(
        of: find.byType(Dialog),
        matching: find.text(palette.name),
      );
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(data.theme, palette.name);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.home_rounded));
      await tester.pumpAndSettle();
      backgrounds.add(
        Theme.of(tester.element(find.text('Current Balance')))
            .scaffoldBackgroundColor,
      );
      final balance =
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.text('Current Balance'),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      final gradient = balance.gradient! as LinearGradient;
      balances.add(gradient.colors.first);
      if (palette.name == 'White') {
        expect(gradient.colors.first, gradient.colors.last);
      }
      final card =
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.text('Total Income'),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      cards.add(card.color!);
      if (['White', 'Teal', 'Black', 'Brown'].contains(palette.name)) {
        await tester.tap(find.byIcon(Icons.shopping_bag_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Add income'));
        await tester.pumpAndSettle();
        expect(find.byType(EntryPage), findsOneWidget);
        final formBackground =
            tester
                    .widget<Container>(
                      find
                          .ancestor(
                            of: find.text('Add Income'),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        expect(formBackground.color, palette.background);
        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('income-name')),
            matching: find.byType(TextField),
          ),
        );
        expect(field.decoration!.fillColor, palette.surface);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
    }
    expect(backgrounds.length, appPalettes.length);
    expect(cards.length, appPalettes.length);
    expect(balances.length, appPalettes.length);
  });

  testWidgets('History charts and daily category filters use shared records', (
    tester,
  ) async {
    await start(tester);
    await showFeatureForTest(tester, 'History');
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('\u20b1 12,850.00'), findsNWidgets(2));
    final data = AppDataScope.of(tester.element(find.byType(HistoryPage)));
    data.expenses.add(
      ExpenseRecord('Fresh groceries', 0, 42, DateTime(2026, 9, 30)),
    );
    data.changed();
    await tester.pumpAndSettle();
    expect(find.text('\u20b1 12,892.00'), findsNWidgets(2));
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(find.text('Grab Food'), findsOneWidget);
    expect(find.text('Watsons'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Food'));
    await tester.pumpAndSettle();
    expect(find.text('Watsons'), findsNothing);
    expect(find.text('Fresh groceries'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Food and groceries'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Income'));
    await tester.pumpAndSettle();
    expect(find.text('\u20b1 22,000.00'), findsNWidgets(2));
  });

  testWidgets(
    'Settings and reminders persist and file tools use the Android bridge',
    (tester) async {
      await start(tester);
      await showFeatureForTest(tester, 'Notification settings');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      final data = AppDataScope.of(
        tester.element(find.byType(NotificationSettingsPage)),
      );
      expect(data.billReminders, false);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await showFeatureForTest(tester, 'Settings');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lavender'));
      await tester.pumpAndSettle();
      expect(data.theme, 'Lavender');
      expect(
        Theme.of(tester.element(find.text('Settings'))).colorScheme.primary,
        const Color(0xFF7652B6),
      );
      await tester.tap(find.text('Currency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();
      expect(data.currency, 'USD');
      await tester.scrollUntilVisible(find.text('Export Data'), 180);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export Data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CSV'));
      await tester.pumpAndSettle();
      expect(export?['format'], 'csv');
      expect(export?['content'], contains('Food and groceries'));
      expect(export?['content'], contains('USD'));
      selectedBackup = data.backupJson();
      await tester.scrollUntilVisible(find.text('Clear All Data'), 180);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear All Data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(data.incomes, isNotEmpty);
      await tester.tap(find.text('Clear All Data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete All Data'));
      await tester.pumpAndSettle();
      expect(data.incomes, isEmpty);
      expect(data.expenses, isEmpty);
      expect(data.bills.bills, isEmpty);
      await tester.scrollUntilVisible(find.text('Backup & Restore'), 180);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Backup & Restore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore JSON Backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(data.incomes, isNotEmpty);
      expect(data.currency, 'USD');
      await data.flush();
      expect(saved, isNotNull);
    },
  );
}
