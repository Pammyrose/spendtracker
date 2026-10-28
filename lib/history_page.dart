import 'package:flutter/material.dart';

import 'app_theme.dart';

import 'app_data.dart';
import 'category_catalog.dart';
import 'entry_widgets.dart';
import 'expenses_page.dart';

class _HistoryRecord {
  const _HistoryRecord(
    this.name,
    this.amount,
    this.date,
    this.category,
    this.color,
    this.icon, {
    this.status = '',
  });
  final String name, category, status;
  final double amount;
  final DateTime date;
  final Color color;
  final IconData icon;
}

List<_HistoryRecord> _records(AppData data, String type) {
  if (type == 'Expenses') {
    return data.expenses
        .map(
          (e) => _HistoryRecord(
            e.title,
            e.amount,
            e.date,
            data.expenseCategories[e.category].name,
            data.expenseCategories[e.category].color,
            data.expenseCategories[e.category].icon,
          ),
        )
        .toList();
  }
  if (type == 'Income') {
    return data.incomes
        .map(
          (e) => _HistoryRecord(
            e.name,
            e.amount,
            e.date,
            data.incomeCategories[e.category].name,
            data.incomeCategories[e.category].color,
            data.incomeCategories[e.category].icon,
          ),
        )
        .toList();
  }
  return data.bills.bills
      .map(
        (b) => _HistoryRecord(
          b.name,
          b.amount,
          b.due,
          b.category == null ? 'Bills' : data.billCategories[b.category!].name,
          categoryIcons[b.icon].color,
          categoryIcons[b.icon].icon,
          status: b.paid
              ? 'Paid'
              : b.paymentPlanAt == null
              ? 'Unpaid'
              : 'Pay later: ${formatDate(b.paymentPlanAt!)}',
        ),
      )
      .toList();
}

List<_HistoryRecord> _inMonth(List<_HistoryRecord> entries, DateTime month) =>
    entries
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .toList();
double _total(List<_HistoryRecord> entries) =>
    entries.fold(0, (sum, e) => sum + e.amount);

Future<DateTime?> _pickMonth(BuildContext context, DateTime month) async {
  final date = await showDatePicker(
    context: context,
    initialDate: month,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100, 12, 31),
    helpText: 'Select a date in the month to view',
  );
  return date == null ? null : DateTime(date.year, date.month);
}

Widget _monthBar(
  BuildContext context,
  DateTime month,
  ValueChanged<DateTime> onChanged,
) => Row(
  children: [
    IconButton(
      tooltip: 'Previous month',
      onPressed: month.year == 2000 && month.month == 1
          ? null
          : () => onChanged(DateTime(month.year, month.month - 1)),
      icon: const Icon(Icons.chevron_left_rounded),
    ),
    Expanded(
      child: TextButton(
        onPressed: () async {
          final selected = await _pickMonth(context, month);
          if (selected != null && context.mounted) onChanged(selected);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                MaterialLocalizations.of(context).formatMonthYear(month),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppPalette.of(context).ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppPalette.of(context).ink,
            ),
          ],
        ),
      ),
    ),
    IconButton(
      tooltip: 'Next month',
      onPressed: month.year == 2100 && month.month == 12
          ? null
          : () => onChanged(DateTime(month.year, month.month + 1)),
      icon: const Icon(Icons.chevron_right_rounded),
    ),
  ],
);

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.initialMonth});
  final DateTime? initialMonth;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _type = 'Expenses';
  late DateTime _month =
      widget.initialMonth ??
      DateTime(DateTime.now().year, DateTime.now().month - 1);

  void _transactions([String? category]) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => HistoryTransactionsPage(
        type: _type,
        initialMonth: _month,
        initialCategory: category,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final data = AppDataScope.of(context);
    final all = _records(data, _type);
    final entries = _inMonth(all, _month);
    final total = _total(entries);
    final previous = _total(
      _inMonth(all, DateTime(_month.year, _month.month - 1)),
    );
    final categories =
        (_type == 'Expenses'
                ? data.expenseCategories
                      .map((category) => category.name)
                      .toList()
                : _type == 'Income'
                ? data.incomeCategories
                      .map((category) => category.name)
                      .toList()
                : [
                    'Bills',
                    ...data.billCategories.map((category) => category.name),
                  ])
            .where((c) => entries.any((e) => e.category == c))
            .toList();
    final colors = categories
        .map((c) => entries.firstWhere((e) => e.category == c).color)
        .toList();
    final amounts = categories
        .map((c) => _total(entries.where((e) => e.category == c).toList()))
        .toList();
    final difference = total - previous;
    final beneficial = _type == 'Income' ? difference >= 0 : difference <= 0;
    final changeColor = beneficial
        ? AppPalette.of(context).brightness == Brightness.dark
              ? const Color(0xFF52D8B0)
              : const Color(0xFF009B75)
        : Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 21),
        ),
        title: const Text(
          'History',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      for (final type in ['Expenses', 'Income', 'Bills'])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: TextButton(
                              onPressed: () => setState(() => _type = type),
                              style: TextButton.styleFrom(
                                backgroundColor: _type == type
                                    ? data.accent
                                    : AppPalette.of(context).soft,
                                foregroundColor: _type == type
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : AppPalette.of(context).muted,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                              ),
                              child: Text(
                                type,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _monthBar(
                    context,
                    _month,
                    (month) => setState(() => _month = month),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppPalette.of(context).surface,
                            border: Border.all(
                              color: AppPalette.of(context).border,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2FAF2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.bar_chart_rounded,
                                  color: Color(0xFF19B58B),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _type == 'Expenses'
                                          ? 'Total Spent'
                                          : _type == 'Income'
                                          ? 'Total Income'
                                          : 'Total Bills',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppPalette.of(context).muted,
                                      ),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        formatMoney(context, total),
                                        style: const TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: changeColor.withValues(
                                          alpha: .10,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        previous == 0
                                            ? 'No records in previous month'
                                            : '${difference < 0 ? '\u2193' : '\u2191'} ${(difference.abs() / previous * 100).round()}% from previous month',
                                        style: TextStyle(
                                          color: changeColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppPalette.of(context).soft,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    backgroundColor: data.accent,
                                    foregroundColor: Theme.of(context)
                                        .colorScheme
                                        .onPrimary,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: const Text(
                                    'Categories',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextButton(
                                  onPressed: () => _transactions(),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppPalette.of(context)
                                        .muted,
                                  ),
                                  child: const Text(
                                    'Transactions',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (entries.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Text(
                              'No records in this month.',
                              style: TextStyle(
                                color: AppPalette.of(context).muted,
                              ),
                            ),
                          )
                        else ...[
                          const SizedBox(height: 16),
                          Semantics(
                            label:
                                '$_type category chart. Total ${formatMoney(context, total)}',
                            child: SizedBox(
                              width: 180,
                              height: 180,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: SpendingDonutPainter(
                                        amounts,
                                        colors: colors,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        formatMoney(context, total),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _type == 'Expenses'
                                            ? 'Total Spent'
                                            : _type == 'Income'
                                            ? 'Total Income'
                                            : 'Total Bills',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppPalette.of(context).muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (var i = 0; i < categories.length; i++)
                            InkWell(
                              onTap: () => _transactions(categories[i]),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: colors[i],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        categories[i],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${(amounts[i] / total * 100).round()}%',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppPalette.of(context).muted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 4,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          formatMoney(context, amounts[i]),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HistoryTransactionsPage extends StatefulWidget {
  const HistoryTransactionsPage({
    super.key,
    required this.type,
    required this.initialMonth,
    this.initialCategory,
  });
  final String type;
  final DateTime initialMonth;
  final String? initialCategory;
  @override
  State<HistoryTransactionsPage> createState() =>
      _HistoryTransactionsPageState();
}

class _HistoryTransactionsPageState extends State<HistoryTransactionsPage> {
  late DateTime _month = widget.initialMonth;
  late String _category = widget.initialCategory ?? 'All';
  @override
  Widget build(BuildContext context) {
    final data = AppDataScope.of(context);
    final monthRecords = _inMonth(_records(data, widget.type), _month);
    final categories = ['All', ...monthRecords.map((e) => e.category).toSet()];
    final selected = categories.contains(_category) ? _category : 'All';
    final entries =
        monthRecords
            .where((e) => selected == 'All' || e.category == selected)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final grouped = <DateTime, List<_HistoryRecord>>{};
    for (final e in entries) {
      grouped
          .putIfAbsent(
            DateTime(e.date.year, e.date.month, e.date.day),
            () => [],
          )
          .add(e);
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.type == 'Expenses'
              ? 'Expense Transactions'
              : '${widget.type} Transactions',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                _monthBar(
                  context,
                  _month,
                  (month) => setState(() {
                    _month = month;
                    _category = 'All';
                  }),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final category in categories)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _category = category),
                            style: TextButton.styleFrom(
                              backgroundColor: selected == category
                                  ? data.accent
                                  : AppPalette.of(context).soft,
                              foregroundColor: selected == category
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : AppPalette.of(context).muted,
                              shape: const StadiumBorder(),
                              minimumSize: const Size(0, 36),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? Center(
                          child: Text(
                            'No records in this month.',
                            style: TextStyle(
                              color: AppPalette.of(context).muted,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            for (final day in grouped.entries) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 6,
                                  bottom: 10,
                                ),
                                child: Text(
                                  formatDate(day.key),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              for (final entry in day.value)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppPalette.of(context).surface,
                                    border: Border.all(
                                      color: AppPalette.of(context).border,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: entry.color.withValues(
                                          alpha: .12,
                                        ),
                                        child: Icon(
                                          entry.icon,
                                          color: entry.color,
                                          size: 21,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 5,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.name,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '${entry.category}${entry.status.isEmpty ? '' : ' • ${entry.status}'}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppPalette.of(context)
                                                    .muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 4,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            '${widget.type == 'Income'
                                                ? '+'
                                                : widget.type == 'Expenses'
                                                ? '-'
                                                : ''}${formatMoney(context, entry.amount)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A compact, interactive history view for the More page.
class HistorySummaryPanel extends StatefulWidget {
  const HistorySummaryPanel({super.key});
  @override
  State<HistorySummaryPanel> createState() => _HistorySummaryPanelState();
}

class _HistorySummaryPanelState extends State<HistorySummaryPanel> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  Widget build(BuildContext context) {
    final data = AppDataScope.of(context), palette = AppPalette.of(context);
    final expenses = _inMonth(_records(data, 'Expenses'), _month);
    final incomes = _inMonth(_records(data, 'Income'), _month);
    final recent = [
      for (final entry in expenses) (entry: entry, income: false),
      for (final entry in incomes) (entry: entry, income: true),
    ]..sort((a, b) => b.entry.date.compareTo(a.entry.date));
    Widget total(String label, double amount) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.soft.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: palette.muted, fontSize: 12)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatMoney(context, amount),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _monthBar(context, _month, (month) => setState(() => _month = month)),
          Row(
            children: [
              total('Income', _total(incomes)),
              const SizedBox(width: 10),
              total('Expenses', _total(expenses)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Recent activity',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No records in this month.',
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            ),
          for (final item in recent.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: item.entry.color.withValues(alpha: .12),
                    child: Icon(
                      item.entry.icon,
                      color: item.entry.color,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.entry.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          formatDate(item.entry.date),
                          style: TextStyle(color: palette.muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${item.income ? '+' : '-'}${formatMoney(context, item.entry.amount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryPage(initialMonth: _month),
              ),
            ),
            child: const Text('View full history'),
          ),
        ],
      ),
    );
  }
}
