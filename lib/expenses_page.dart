import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

import 'entry_widgets.dart';
import 'app_data.dart';
import 'category_catalog.dart';
import 'category_picker.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

// Expenses are kept in memory for now. One record drives both chart and list.
class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<AppCategory> get _catalog => AppDataScope.of(context).expenseCategories;
  List<String> get _categories =>
      _catalog.map((category) => category.name).toList();
  List<Color> get _colors =>
      _catalog.map((category) => category.color).toList();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _transactions = false;
  List<ExpenseRecord> get _expenses => AppDataScope.of(context).expenses;

  List<ExpenseRecord> _forMonth(DateTime month) => _expenses
      .where((e) => e.date.year == month.year && e.date.month == month.month)
      .toList();
  double _total(List<ExpenseRecord> entries) =>
      entries.fold(0, (sum, e) => sum + e.amount);

  void _changeMonth(int offset) =>
      setState(() => _month = DateTime(_month.year, _month.month + offset));

  Future<void> _pickMonth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select a date in the month to view',
    );
    if (date != null && mounted) {
      setState(() => _month = DateTime(date.year, date.month));
    }
  }

  Future<void> _addExpense() async {
    final expense = await Navigator.push<ExpenseRecord>(
      context,
      MaterialPageRoute(builder: (_) => _ExpenseForm(initialDate: _month)),
    );
    if (expense != null && mounted) {
      setState(() {
        AppDataScope.of(context).addExpense(expense);
        _month = DateTime(expense.date.year, expense.date.month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _forMonth(_month)..sort((a, b) => b.date.compareTo(a.date));
    final total = _total(entries);
    final previous = _total(_forMonth(DateTime(_month.year, _month.month - 1)));
    final difference = total - previous;
    final amounts = List.generate(
      _categories.length,
      (i) => _total(entries.where((e) => e.category == i).toList()),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Expenses',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton.filled(
                tooltip: 'Add expense',
                onPressed: _addExpense,
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Row(
          children: [
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Previous month',
              onPressed: _month.year == 2000 && _month.month == 1
                  ? null
                  : () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: TextButton(
                onPressed: _pickMonth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        '${_months[_month.month - 1]} ${_month.year}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppPalette.of(context).ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppPalette.of(context).ink,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: _month.year == 2100 && _month.month == 12
                  ? null
                  : () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppPalette.of(context).surface,
                    border: Border.all(color: AppPalette.of(context).border),
                    borderRadius: BorderRadius.circular(16),
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
                          size: 34,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Spent',
                              style: TextStyle(
                                color: AppPalette.of(context).muted,
                                fontSize: 12,
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
                                horizontal: 6,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppPalette.of(context).brightness ==
                                        Brightness.dark
                                    ? AppPalette.of(context).soft
                                    : difference <= 0
                                    ? const Color(0xFFD9F8EF)
                                    : const Color(0xFFFFDFE7),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                previous == 0
                                    ? 'No spending recorded last month'
                                    : difference == 0
                                    ? 'Same as last month'
                                    : '${difference < 0 ? '\u2193' : '\u2191'} ${formatMoney(context, difference.abs())} ${difference < 0 ? 'less' : 'more'} than last month',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: difference <= 0
                                      ? AppPalette.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF52D8B0)
                                            : const Color(0xFF008C69)
                                      : Theme.of(context).colorScheme.primary,
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
                // The two tabs share the same data, presented in different ways.
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppPalette.of(context).soft,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      _tab(
                        'Categories',
                        !_transactions,
                        () => setState(() => _transactions = false),
                      ),
                      _tab(
                        'Transactions',
                        _transactions,
                        () => setState(() => _transactions = true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Text(
                      'No expenses this month.\nTap + to add your first expense.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppPalette.of(context).muted),
                    ),
                  )
                else if (_transactions)
                  ...entries.map(
                    (e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 17,
                        backgroundColor: _colors[e.category].withValues(
                          alpha: 0.15,
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: _colors[e.category],
                          size: 19,
                        ),
                      ),
                      title: Text(
                        e.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${_categories[e.category]} \u00b7 ${_months[e.date.month - 1].substring(0, 3)} ${e.date.day}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppPalette.of(context).muted,
                        ),
                      ),
                      trailing: Text(
                        formatMoney(context, e.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else ...[
                  // CustomPainter draws the donut without a chart dependency.
                  Semantics(
                    label:
                        'Category spending chart. Total ${formatMoney(context, total)}',
                    child: SizedBox(
                      width: 190,
                      height: 190,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: SpendingDonutPainter(
                                amounts,
                                colors: _colors,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatMoney(context, total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Total Spent',
                                style: TextStyle(
                                  color: AppPalette.of(context).muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _categories.length; i++)
                    if (i < 8 || amounts[i] > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _colors[i],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              flex: 5,
                              child: Text(
                                _categories[i],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${(amounts[i] / total * 100).round()}%',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: AppPalette.of(context).muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Use the same column widths for every category,
                            // regardless of how many digits its amount contains.
                            Expanded(
                              flex: 4,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  formatMoney(context, amounts[i]),
                                  textAlign: TextAlign.right,
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
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) => Expanded(
    child: Semantics(
      selected: selected,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          foregroundColor: selected
              ? Theme.of(context).colorScheme.onPrimary
              : AppPalette.of(context).muted,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: const StadiumBorder(),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    ),
  );
}

class SpendingDonutPainter extends CustomPainter {
  const SpendingDonutPainter(
    this.amounts, {
    this.colors = expenseCategoryColors,
  });
  final List<double> amounts;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = amounts.fold(0.0, (sum, value) => sum + value);
    if (total == 0) return;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 16,
    );
    var start = -math.pi / 2;
    for (var i = 0; i < amounts.length; i++) {
      final sweep = amounts[i] / total * 2 * math.pi;
      if (sweep > 0) {
        canvas.drawArc(
          rect,
          start,
          math.max(0, sweep - 0.012),
          false,
          Paint()
            ..color = colors[i]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 26,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant SpendingDonutPainter oldDelegate) => true;
}

// The form returns a new expense to the page that opened it.
class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({required this.initialDate});
  final DateTime initialDate;
  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  List<AppCategory> get _catalog => AppDataScope.of(context).expenseCategories;
  List<String> get _categories =>
      _catalog.map((category) => category.name).toList();
  List<Color> get _colors =>
      _catalog.map((category) => category.color).toList();
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  int? _category;
  DateTime? _date;
  List<IconData> get _icons =>
      _catalog.map((category) => category.icon).toList();

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.pop(
        context,
        ExpenseRecord(
          _description.text.trim(),
          _category!,
          double.parse(double.parse(_amount.text.trim()).toStringAsFixed(2)),
          _date!,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => EntryPage(
    title: 'Add Expense',
    saveLabel: 'Save Expense',
    onSave: _save,
    children: [
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPalette.of(context).surface,
                border: Border.all(color: AppPalette.of(context).border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  EntryField(
                    label: 'Amount',
                    child: TextFormField(
                      key: const Key('expense-amount'),
                      controller: _amount,
                      decoration: entryDecoration(context, '0.00').copyWith(
                        prefixText: '${AppDataScope.of(context).symbol} ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: validateAmount,
                    ),
                  ),
                  EntryField(
                    label: 'Category',
                    child: CategoryField(
                      key: ValueKey(_category),
                      kind: CategoryKind.expense,
                      value: _category,
                      onChanged: (value) => setState(() => _category = value),
                    ),
                  ),

                  EntryField(
                    label: 'Description',
                    child: TextFormField(
                      key: const Key('expense-description'),
                      controller: _description,
                      decoration: entryDecoration(
                        context,
                        'e.g. Lunch with friends',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a description'
                          : null,
                    ),
                  ),
                  EntryField(
                    label: 'Date',
                    child: FormField<DateTime>(
                      validator: (_) => _date == null ? 'Choose a date' : null,
                      builder: (field) => InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _date ?? widget.initialDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100, 12, 31),
                          );
                          if (date != null && mounted) {
                            setState(() => _date = date);
                            field.didChange(date);
                          }
                        },
                        child: InputDecorator(
                          decoration: entryDecoration(context, '').copyWith(
                            suffixIcon: const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                            ),
                            errorText: field.errorText,
                          ),
                          child: Text(
                            _date == null ? 'Select date' : formatDate(_date!),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppPalette.of(context).muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Recent Categories',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            // Quick category shortcuts, arranged in two rows as in the reference.
            for (final row in [
              [0, 1, 2, 3],
              [4, 6, 7, 5],
            ])
              Row(
                children: [
                  for (final i in row)
                    Expanded(
                      child: Semantics(
                        selected: _category == i,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _category = i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _colors[i].withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(13),
                                    border: _category == i
                                        ? Border.all(
                                            color: _colors[i],
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: Icon(
                                    _icons[i],
                                    color: _colors[i],
                                    size: 27,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _categories[i] == 'Transportation'
                                      ? 'Transport'
                                      : _categories[i],
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    ],
  );
}
