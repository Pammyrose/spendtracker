import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'category_catalog.dart';
import 'cloud_api.dart';
import 'account_sync.dart';

const expenseCategoryNames = [
  'Food',
  'Shopping',
  'Transportation',
  'Bills',
  'Entertainment',
  'Others',
  'Health',
  'Education',
];
const expenseCategoryColors = [
  Color(0xFFFF5C83),
  Color(0xFFFFC56D),
  Color(0xFF57CFBA),
  Color(0xFFA48BFA),
  Color(0xFF6687F5),
  Color(0xFF98A1AF),
  Color(0xFFFF5C83),
  Color(0xFFFF943B),
];
const incomeCategoryNames = [
  'Salary',
  'Freelance',
  'Part-time',
  'Bonus',
  'Others',
];
const incomeCategoryColors = [
  Color(0xFF079D80),
  Color(0xFF167BFF),
  Color(0xFFFF4F7F),
  Color(0xFFFF8D24),
  Color(0xFF9570DF),
];
const deviceStorage = MethodChannel('spendtracker/storage');
const paymentReminderOptions = ['Daily', 'Every 2 days', 'Weekly', 'Once'];
// Share the same choices between reminder menus and backup validation.
final reminderTimes = List<String>.unmodifiable([
  'On due date',
  for (var day = 1; day <= 31; day++)
    '$day ${day == 1 ? 'day' : 'days'} before',
]);

class ExpenseRecord {
  const ExpenseRecord(this.title, this.category, this.amount, this.date);
  final String title;
  final int category;
  final double amount;
  final DateTime date;
  Map<String, dynamic> toJson() => {
    'title': title,
    'category': category,
    'amount': amount,
    'date': date.toIso8601String(),
  };
}

class IncomeRecord {
  const IncomeRecord({
    required this.name,
    required this.amount,
    required this.date,
    required this.category,
    this.notes = '',
  });
  final String name, notes;
  final double amount;
  final DateTime date;
  final int category;
  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'amount': amount,
    'date': date.toIso8601String(),
    'notes': notes,
  };
}

class Bill {
  Bill({
    required this.name,
    required this.amount,
    required this.due,
    this.icon = 0,
    this.repeat = 'Monthly',
    this.reminder = '3 days before',
    this.paid = false,
    this.category,
    this.notes = '',
    this.paymentReason = '',
    this.paymentPlanAt,
    this.followUpRepeat = 'Daily',
  });
  final String name, repeat, reminder;
  final double amount;
  final DateTime due;
  final int icon;
  final int? category;
  bool paid;
  String notes, paymentReason, followUpRepeat;
  DateTime? paymentPlanAt;
  DateTime get nextActionAt => paymentPlanAt ?? due;
  int get daysLeft {
    final now = DateTime.now();
    return DateTime.utc(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'due': due.toIso8601String(),
    'icon': icon,
    'repeat': repeat,
    'reminder': reminder,
    'paid': paid,
    'category': category,
    'notes': notes,
    'paymentReason': paymentReason,
    'paymentPlanAt': paymentPlanAt?.toIso8601String(),
    'paymentPlanAtMillis': paymentPlanAt?.millisecondsSinceEpoch,
    'followUpRepeat': followUpRepeat,
  };
}

const transactionActivityKinds = [
  'expenseAdded',
  'incomeAdded',
  'incomeUpdated',
  'incomeDeleted',
  'billPaid',
  'billUnpaid',
];

class TransactionActivity {
  const TransactionActivity({
    required this.kind,
    required this.name,
    required this.amount,
    required this.recordedAt,
    required this.transactionDate,
  });
  final String kind, name;
  final double amount;
  final DateTime recordedAt, transactionDate;
  String get title => switch (kind) {
    'expenseAdded' => 'Expense added',
    'incomeAdded' => 'Income recorded',
    'incomeUpdated' => 'Income updated',
    'incomeDeleted' => 'Income deleted',
    'billPaid' => 'Bill marked paid',
    _ => 'Bill marked unpaid',
  };
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'name': name,
    'amount': amount,
    'recordedAt': recordedAt.toIso8601String(),
    'transactionDate': transactionDate.toIso8601String(),
  };
}

class BillsController extends ChangeNotifier {
  final List<Bill> bills = [];
  void Function(Bill)? onPaymentChanged;
  void add(Bill bill) {
    bills.add(bill);
    notifyListeners();
  }

  void togglePaid(Bill bill) {
    bill.paid = !bill.paid;
    onPaymentChanged?.call(bill);
    notifyListeners();
  }

  void postpone(
    Bill bill, {
    required String reason,
    required DateTime at,
    required String repeat,
  }) {
    if (bill.paid) throw const FormatException('This bill is already paid.');
    if (reason.trim().isEmpty || reason.trim().length > 500) {
      throw const FormatException('Enter a reason up to 500 characters.');
    }
    if (!at.isAfter(DateTime.now())) {
      throw const FormatException('Choose a future payment date and time.');
    }
    if (!paymentReminderOptions.contains(repeat)) {
      throw const FormatException('Choose a reminder frequency.');
    }
    bill.paymentReason = reason.trim();
    bill.paymentPlanAt = at;
    bill.followUpRepeat = repeat;
    notifyListeners();
  }

  void removePaymentPlan(Bill bill) {
    bill.paymentPlanAt = null;
    notifyListeners();
  }

  void refresh() => notifyListeners();
}

// A single source of records connects the dashboard, history, and backup tools.
class AppData extends ChangeNotifier {
  AppData({bool seed = true, CloudApi? cloud, bool liveAccount = false})
    : cloud = cloud ?? CloudApi() {
    if (seed && !liveAccount) _seed();
    bills.onPaymentChanged = (bill) => _recordTransaction(
      bill.paid ? 'billPaid' : 'billUnpaid',
      bill.name,
      bill.amount,
      bill.due,
    );
    bills.addListener(changed);
    sync = AccountSync(
      enabled: liveAccount,
      cloud: this.cloud,
      document: backupJson,
      emptyDocument: backupJson(),
      apply: (source) {
        _readBackup(source);
        bills.refresh();
      },
      onChanged: notifyListeners,
      onStorageUnavailable: () => storageAvailable = false,
    );
  }
  final List<ExpenseRecord> expenses = [];
  final CloudApi cloud;
  late final AccountSync sync;
  final List<IncomeRecord> incomes = [];
  final List<TransactionActivity> transactionActivity = [];
  // Record actions when they happen, rather than inventing notifications from sample or imported data.
  void _recordTransaction(
    String kind,
    String name,
    double amount,
    DateTime date,
  ) {
    transactionActivity.insert(
      0,
      TransactionActivity(
        kind: kind,
        name: name,
        amount: amount,
        recordedAt: DateTime.now(),
        transactionDate: date,
      ),
    );
    if (transactionActivity.length > 200) {
      transactionActivity.removeRange(200, transactionActivity.length);
    }
  }

  void addExpense(ExpenseRecord entry) {
    expenses.add(entry);
    _recordTransaction('expenseAdded', entry.title, entry.amount, entry.date);
    changed();
  }

  void saveIncome(IncomeRecord entry, {IncomeRecord? existing}) {
    if (existing == null) {
      incomes.add(entry);
    } else {
      incomes[incomes.indexOf(existing)] = entry;
    }
    _recordTransaction(
      existing == null ? 'incomeAdded' : 'incomeUpdated',
      entry.name,
      entry.amount,
      entry.date,
    );
    changed();
  }

  void deleteIncome(IncomeRecord entry) {
    if (!incomes.remove(entry)) return;
    _recordTransaction('incomeDeleted', entry.name, entry.amount, entry.date);
    changed();
  }

  final BillsController bills = BillsController();
  final List<AppCategory> expenseCategories = [...defaultExpenseCategories];
  final List<AppCategory> incomeCategories = [...defaultIncomeCategories];
  final List<AppCategory> billCategories = [...defaultBillCategories];
  List<AppCategory> categoriesFor(CategoryKind kind) => switch (kind) {
    CategoryKind.expense => expenseCategories,
    CategoryKind.income => incomeCategories,
    CategoryKind.bill => billCategories,
  };
  int addCategory(CategoryKind kind, String name, String iconId) {
    final categories = categoriesFor(kind), cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 40) {
      throw const FormatException('Enter a category name up to 40 characters.');
    }
    if (categories.any(
      (category) => category.name.toLowerCase() == cleanName.toLowerCase(),
    )) {
      throw const FormatException('This category already exists.');
    }
    if (categories.length >= 200) {
      throw const FormatException('You can add up to 200 categories.');
    }
    final icon = categoryIcons.firstWhere(
      (choice) => choice.id == iconId,
      orElse: () => throw const FormatException('Choose an icon.'),
    );
    categories.add(AppCategory(cleanName, icon.id, icon.color.toARGB32()));
    changed();
    return categories.length - 1;
  }

  String currency = 'PHP';
  String theme = 'White';
  int customColor = 0xFF5C66D6;
  bool customDark = false;
  bool notificationsEnabled = true,
      billReminders = true,
      incomeReminders = true,
      expenseAlerts = false,
      monthlySummary = true;
  String billReminderTime = '3 days before',
      incomeReminderTime = '1 day before';
  double expenseAlertAmount = 10000;
  // Only recorded spending through today counts; future entries are not spent yet.
  double spendingThrough(DateTime now) => expenses
      .where(
        (entry) =>
            entry.date.year == now.year &&
            entry.date.month == now.month &&
            entry.date.day <= now.day,
      )
      .fold(0.0, (total, entry) => total + entry.amount);
  bool expenseLimitReached(DateTime now) =>
      notificationsEnabled &&
      expenseAlerts &&
      spendingThrough(now) >= expenseAlertAmount;
  bool storageAvailable = true;
  Future<void> _saveQueue = Future.value();

  AppPalette get palette => theme == 'Custom'
      ? AppPalette.custom(Color(customColor), dark: customDark)
      : appPalettes.firstWhere(
          (palette) => palette.name == theme,
          orElse: () => appPalettes.first,
        );
  Color get accent => palette.accent;
  String get symbol => switch (currency) {
    'USD' => '\$',
    'EUR' => '\u20ac',
    _ => '\u20b1',
  };

  void _seed() {
    expenses.addAll([
      ExpenseRecord('Food and groceries', 0, 3100, DateTime(2026, 10, 24)),
      ExpenseRecord('Shopping', 1, 2050, DateTime(2026, 10, 22)),
      ExpenseRecord('Transportation', 2, 1550, DateTime(2026, 10, 20)),
      ExpenseRecord('Monthly bills', 3, 2050, DateTime(2026, 10, 18)),
      ExpenseRecord('Entertainment', 4, 1000, DateTime(2026, 10, 16)),
      ExpenseRecord('Other expenses', 5, 500, DateTime(2026, 10, 14)),
      ExpenseRecord('Grab Food', 0, 350, DateTime(2026, 9, 30)),
      ExpenseRecord('Coffee Project', 0, 180, DateTime(2026, 9, 30)),
      ExpenseRecord('Watsons', 1, 420, DateTime(2026, 9, 30)),
      ExpenseRecord('MRT', 2, 50, DateTime(2026, 9, 29)),
      ExpenseRecord('Netflix', 3, 549, DateTime(2026, 9, 29)),
      ExpenseRecord('Grocery', 0, 1200, DateTime(2026, 9, 28)),
      ExpenseRecord('Dining', 0, 2470, DateTime(2026, 9, 27)),
      ExpenseRecord('Clothes', 1, 2680, DateTime(2026, 9, 26)),
      ExpenseRecord('Transport pass', 2, 1500, DateTime(2026, 9, 25)),
      ExpenseRecord('Utilities', 3, 2451, DateTime(2026, 9, 24)),
      ExpenseRecord('Cinema', 4, 1000, DateTime(2026, 9, 23)),
    ]);
    incomes.addAll([
      IncomeRecord(
        name: 'Salary',
        amount: 25000,
        date: DateTime(2026, 10, 1),
        category: 0,
      ),
      IncomeRecord(
        name: 'Freelance',
        amount: 5000,
        date: DateTime(2026, 10, 10),
        category: 1,
      ),
      IncomeRecord(
        name: 'Part-time',
        amount: 3000,
        date: DateTime(2026, 10, 20),
        category: 2,
      ),
      IncomeRecord(
        name: 'Bonus',
        amount: 2000,
        date: DateTime(2026, 10, 25),
        category: 3,
      ),
      IncomeRecord(
        name: 'Salary',
        amount: 20000,
        date: DateTime(2026, 9, 1),
        category: 0,
      ),
      IncomeRecord(
        name: 'Part Time',
        amount: 2000,
        date: DateTime(2026, 9, 15),
        category: 2,
      ),
    ]);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const names = [
      'Internet',
      'Electricity',
      'Water',
      'Netflix',
      'Phone Plan',
      'Rent',
    ];
    const amounts = [1500.0, 2000.0, 800.0, 549.0, 999.0, 8000.0];
    const days = [5, 10, 15, 18, 20, 22];
    bills.bills.addAll(
      List.generate(
        6,
        (i) => Bill(
          name: names[i],
          amount: amounts[i],
          due: today.add(Duration(days: days[i])),
          icon: i,
        ),
      ),
    );
  }

  void changed() {
    notifyListeners();
    if (sync.enabled) {
      sync.changed();
      return;
    }
    final snapshot = backupJson();
    // Serialize writes so a slow save cannot overwrite a more recent edit.
    _saveQueue = _saveQueue.then((_) async {
      try {
        await deviceStorage.invokeMethod<void>('saveData', snapshot);
      } on MissingPluginException {
        storageAvailable = false;
      } on PlatformException {
        storageAvailable = false;
      }
    });
  }

  Future<void> load() async {
    if (sync.enabled) {
      await sync.initializeDevice();
      return;
    }
    try {
      final saved = await deviceStorage.invokeMethod<String>('loadData');
      if (saved != null) {
        _readBackup(saved);
        notifyListeners();
      }
    } on MissingPluginException {
      storageAvailable = false;
    } on PlatformException {
      storageAvailable = false;
    } on FormatException {
      storageAvailable = false;
    }
  }

  Future<void> flush() => sync.enabled ? sync.flushLocal() : _saveQueue;
  Future<bool> requestPaymentNotifications() async {
    try {
      return await deviceStorage.invokeMethod<bool>('requestNotifications') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestExpenseNotifications() async {
    try {
      return await deviceStorage.invokeMethod<bool>(
            'requestNotifications',
            'expenses',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Map<String, dynamic> get settings => {
    'currency': currency,
    'theme': theme,
    'customColor': customColor,
    'customDark': customDark,
    'notificationsEnabled': notificationsEnabled,
    'billReminders': billReminders,
    'incomeReminders': incomeReminders,
    'expenseAlerts': expenseAlerts,
    'monthlySummary': monthlySummary,
    'billReminderTime': billReminderTime,
    'incomeReminderTime': incomeReminderTime,
    'expenseAlertAmount': expenseAlertAmount,
  };
  String backupJson() => jsonEncode({
    'version': 1,
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'incomes': incomes.map((e) => e.toJson()).toList(),
    'bills': bills.bills.map((e) => e.toJson()).toList(),
    'transactionActivity': transactionActivity.map((e) => e.toJson()).toList(),
    'settings': settings,
    'categories': {
      'expense': expenseCategories
          .map((category) => category.toJson())
          .toList(),
      'income': incomeCategories.map((category) => category.toJson()).toList(),
      'bill': billCategories.map((category) => category.toJson()).toList(),
    },
  });
  void restore(String source) {
    _readBackup(source);
    bills.refresh();
  }

  void validateBackup(String source) {
    final probe = AppData(seed: false);
    try {
      probe._readBackup(source);
    } finally {
      probe.dispose();
    }
  }

  // Validate a complete backup before replacing any live records.
  void _readBackup(String source) {
    try {
      final raw = jsonDecode(source) as Map<String, dynamic>;
      if (raw['version'] != 1) {
        throw const FormatException('Unsupported backup version.');
      }
      String name(dynamic v) {
        if (v is! String || v.trim().isEmpty) {
          throw const FormatException('Invalid name.');
        }
        return v;
      }

      double amount(dynamic v) {
        if (v is! num || !v.isFinite || v < 0.01 || v > 999999999) {
          throw const FormatException('Invalid amount.');
        }
        return v.toDouble();
      }

      int category(dynamic v, int length) {
        if (v is! int || v < 0 || v >= length) {
          throw const FormatException('Invalid category.');
        }
        return v;
      }

      DateTime date(dynamic v) {
        final d = v is String ? DateTime.tryParse(v) : null;
        if (d == null || d.year < 2000 || d.year > 2100) {
          throw const FormatException('Invalid date.');
        }
        return d;
      }

      List<AppCategory> readCategories(
        CategoryKind kind,
        List<AppCategory> defaults,
      ) {
        if (raw['categories'] == null) return [...defaults];
        final items = (raw['categories'] as Map)[kind.name];
        if (items is! List || items.isEmpty || items.length > 200) {
          throw const FormatException('Invalid categories.');
        }
        final names = <String>{};
        return items.map((item) {
          final label = name(item['name']).trim();
          final icon = item['icon'];
          final color = item['color'];
          if (label.length > 40 ||
              !names.add(label.toLowerCase()) ||
              !categoryIcons.any((choice) => choice.id == icon) ||
              color is! int ||
              color < 0 ||
              color > 0xFFFFFFFF ||
              color >> 24 != 0xFF) {
            throw const FormatException('Invalid category details.');
          }
          return AppCategory(label, icon as String, color);
        }).toList();
      }

      final newExpenseCategories = readCategories(
        CategoryKind.expense,
        defaultExpenseCategories,
      );
      final newIncomeCategories = readCategories(
        CategoryKind.income,
        defaultIncomeCategories,
      );
      final newBillCategories = readCategories(
        CategoryKind.bill,
        defaultBillCategories,
      );

      final newExpenses = (raw['expenses'] as List)
          .map(
            (e) => ExpenseRecord(
              name(e['title']),
              category(e['category'], newExpenseCategories.length),
              amount(e['amount']),
              date(e['date']),
            ),
          )
          .toList();
      final newIncomes = (raw['incomes'] as List)
          .map(
            (e) => IncomeRecord(
              name: name(e['name']),
              category: category(e['category'], newIncomeCategories.length),
              amount: amount(e['amount']),
              date: date(e['date']),
              notes: e['notes'] as String? ?? '',
            ),
          )
          .toList();
      final newBills = (raw['bills'] as List).map((e) {
        final notes = e['notes'] ?? '', reason = e['paymentReason'] ?? '';
        final followUp = e['followUpRepeat'] ?? 'Daily';
        final planned = e['paymentPlanAt'] == null
            ? null
            : date(e['paymentPlanAt']);
        if (notes is! String ||
            notes.length > 1000 ||
            reason is! String ||
            reason.length > 500 ||
            !paymentReminderOptions.contains(followUp) ||
            planned != null && reason.trim().isEmpty) {
          throw const FormatException('Invalid payment plan.');
        }
        if (!['Never', 'Weekly', 'Monthly', 'Yearly'].contains(e['repeat']) ||
            !['Never', ...reminderTimes].contains(e['reminder']) ||
            e['paid'] is! bool) {
          throw const FormatException('Invalid bill settings.');
        }
        return Bill(
          name: name(e['name']),
          amount: amount(e['amount']),
          due: date(e['due']),
          icon: category(e['icon'], categoryIcons.length),
          category: e['category'] == null
              ? null
              : category(e['category'], newBillCategories.length),
          repeat: e['repeat'],
          reminder: e['reminder'],
          paid: e['paid'],
          notes: notes,
          paymentReason: reason,
          paymentPlanAt: planned,
          followUpRepeat: followUp,
        );
      }).toList();
      final s = raw['settings'] as Map<String, dynamic>;
      if (!['PHP', 'USD', 'EUR'].contains(s['currency']) ||
          !(s['theme'] == 'Custom' ||
              appPalettes.any((palette) => palette.name == s['theme']))) {
        throw const FormatException('Invalid appearance settings.');
      }
      final savedColor = s['customColor'] ?? 0xFF5C66D6;
      final savedDark = s['customDark'] ?? false;
      if (savedColor is! int ||
          savedColor < 0 ||
          savedColor > 0xFFFFFFFF ||
          savedColor >> 24 != 0xFF ||
          savedDark is! bool) {
        throw const FormatException('Invalid custom color.');
      }
      for (final key in [
        'notificationsEnabled',
        'billReminders',
        'incomeReminders',
        'expenseAlerts',
        'monthlySummary',
      ]) {
        if (s[key] is! bool) {
          throw const FormatException('Invalid reminder settings.');
        }
      }
      final times = reminderTimes;
      if (!times.contains(s['billReminderTime']) ||
          !times.contains(s['incomeReminderTime'])) {
        throw const FormatException('Invalid reminder time.');
      }
      final threshold = amount(s['expenseAlertAmount']);
      final activitySource = raw['transactionActivity'] ?? [];
      if (activitySource is! List || activitySource.length > 200) {
        throw const FormatException('Invalid transaction activity.');
      }
      final newActivity = activitySource.map((entry) {
        if (!transactionActivityKinds.contains(entry['kind'])) {
          throw const FormatException('Invalid transaction activity type.');
        }
        return TransactionActivity(
          kind: entry['kind'],
          name: name(entry['name']),
          amount: amount(entry['amount']),
          recordedAt: date(entry['recordedAt']),
          transactionDate: date(entry['transactionDate']),
        );
      }).toList()..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      transactionActivity
        ..clear()
        ..addAll(newActivity);
      expenseCategories
        ..clear()
        ..addAll(newExpenseCategories);
      incomeCategories
        ..clear()
        ..addAll(newIncomeCategories);
      billCategories
        ..clear()
        ..addAll(newBillCategories);
      expenses
        ..clear()
        ..addAll(newExpenses);
      incomes
        ..clear()
        ..addAll(newIncomes);
      bills.bills
        ..clear()
        ..addAll(newBills);
      currency = s['currency'];
      theme = s['theme'];
      customColor = savedColor;
      customDark = savedDark;
      notificationsEnabled = s['notificationsEnabled'];
      billReminders = s['billReminders'];
      incomeReminders = s['incomeReminders'];
      expenseAlerts = s['expenseAlerts'];
      monthlySummary = s['monthlySummary'];
      billReminderTime = s['billReminderTime'];
      incomeReminderTime = s['incomeReminderTime'];
      expenseAlertAmount = threshold;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('This is not a valid SpendTracker backup.');
    }
  }

  void clearRecords() {
    transactionActivity.clear();
    expenses.clear();
    incomes.clear();
    bills.bills.clear();
    expenseCategories
      ..clear()
      ..addAll(defaultExpenseCategories);
    incomeCategories
      ..clear()
      ..addAll(defaultIncomeCategories);
    billCategories
      ..clear()
      ..addAll(defaultBillCategories);
    currency = 'PHP';
    theme = 'White';
    customColor = 0xFF5C66D6;
    customDark = false;
    notificationsEnabled = true;
    billReminders = true;
    incomeReminders = true;
    expenseAlerts = false;
    monthlySummary = true;
    billReminderTime = '3 days before';
    incomeReminderTime = '1 day before';
    expenseAlertAmount = 10000;
    bills.refresh();
  }

  @override
  void dispose() {
    sync.dispose();
    cloud.dispose();
    bills.removeListener(changed);
    bills.dispose();
    super.dispose();
  }
}

class AppDataScope extends InheritedNotifier<AppData> {
  const AppDataScope({super.key, required AppData data, required super.child})
    : super(notifier: data);
  static AppData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppDataScope>()!.notifier!;
}
