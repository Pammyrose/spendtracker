import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'entry_widgets.dart';

const _pink = Color(0xFFFF5C83);
const _muted = Color(0xFF788396);
const _categories = [
  'Food',
  'Shopping',
  'Transportation',
  'Bills',
  'Entertainment',
  'Others',
  'Health',
  'Education',
];
const _colors = [
  Color(0xFFFF5C83),
  Color(0xFFFFC56D),
  Color(0xFF57CFBA),
  Color(0xFFA48BFA),
  Color(0xFF6687F5),
  Color(0xFF98A1AF),
  Color(0xFFFF5C83),
  Color(0xFFFF943B),
];
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
class _Expense {
  const _Expense(this.title, this.category, this.amount, this.date);
  final String title;
  final int category;
  final double amount;
  final DateTime date;
}

String _money(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]},',
  );
  return '\u20b1 $whole.${parts.last}';
}

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  DateTime _month = DateTime(2026, 10);
  bool _transactions = false;
  final List<_Expense> _expenses = [
    _Expense('Food and groceries', 0, 3100, DateTime(2026, 10, 24)),
    _Expense('Shopping', 1, 2050, DateTime(2026, 10, 22)),
    _Expense('Transportation', 2, 1550, DateTime(2026, 10, 20)),
    _Expense('Monthly bills', 3, 2050, DateTime(2026, 10, 18)),
    _Expense('Entertainment', 4, 1000, DateTime(2026, 10, 16)),
    _Expense('Other expenses', 5, 500, DateTime(2026, 10, 14)),
    _Expense('September expenses', 0, 12850, DateTime(2026, 9, 30)),
  ];

  List<_Expense> _forMonth(DateTime month) => _expenses
      .where((e) => e.date.year == month.year && e.date.month == month.month)
      .toList();
  double _total(List<_Expense> entries) =>
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
    final expense = await Navigator.push<_Expense>(
      context,
      MaterialPageRoute(builder: (_) => _ExpenseForm(initialDate: _month)),
    );
    if (expense != null && mounted) {
      setState(() {
        _expenses.add(expense);
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
                  backgroundColor: _pink,
                  foregroundColor: Colors.white,
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
                        style: const TextStyle(
                          color: Color(0xFF151826),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF151826),
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
                    color: Colors.white,
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
                            const Text(
                              'Total Spent',
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _money(total),
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
                                color: difference <= 0
                                    ? const Color(0xFFD9F8EF)
                                    : const Color(0xFFFFDFE7),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                previous == 0
                                    ? 'No spending recorded last month'
                                    : difference == 0
                                    ? 'Same as last month'
                                    : '${difference < 0 ? '\u2193' : '\u2191'} ${_money(difference.abs())} ${difference < 0 ? 'less' : 'more'} than last month',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: difference <= 0
                                      ? const Color(0xFF008C69)
                                      : _pink,
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
                    color: const Color(0xFFEBEEF3),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Text(
                      'No expenses this month.\nTap + to add your first expense.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted),
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
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                      trailing: Text(
                        _money(e.amount),
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
                    label: 'Category spending chart. Total ${_money(total)}',
                    child: SizedBox(
                      width: 190,
                      height: 190,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(painter: _DonutPainter(amounts)),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _money(total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Total Spent',
                                style: TextStyle(color: _muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _categories.length; i++)
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
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            _money(amounts[i]),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
          backgroundColor: selected ? _pink : Colors.transparent,
          foregroundColor: selected ? Colors.white : _muted,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: const StadiumBorder(),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    ),
  );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.amounts);
  final List<double> amounts;

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
            ..color = _colors[i]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 26,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}

// The form returns a new expense to the page that opened it.
class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({required this.initialDate});
  final DateTime initialDate;
  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  int? _category;
  DateTime? _date;
  static const _icons = [
    Icons.rice_bowl_rounded,
    Icons.shopping_bag_rounded,
    Icons.directions_bus_rounded,
    Icons.bar_chart_rounded,
    Icons.sports_esports_rounded,
    Icons.add_circle_rounded,
    Icons.favorite_rounded,
    Icons.school_rounded,
  ];

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
        _Expense(
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
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  EntryField(
                    label: 'Amount',
                    child: TextFormField(
                      key: const Key('expense-amount'),
                      controller: _amount,
                      decoration: entryDecoration('0.00')
                          .copyWith(prefixText: '\u20b1 '),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: validateAmount,
                    ),
                  ),
                  EntryField(
                    label: 'Category',
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      key: ValueKey(_category),
                      initialValue: _category,
                      decoration: entryDecoration('Choose a category').copyWith(
                        prefixIcon: Icon(
                          _category == null
                              ? Icons.work_rounded
                              : _icons[_category!],
                          color: _category == null
                              ? const Color(0xFF8856DE)
                              : _colors[_category!],
                          size: 20,
                        ),
                      ),
                      hint: const Text(
                        'Choose a category',
                        style: TextStyle(fontSize: 13, color: appMuted),
                      ),
                      items: List.generate(
                        _categories.length,
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text(
                            _categories[i],
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      onChanged: (v) => setState(() => _category = v),
                      validator: (v) => v == null ? 'Choose a category' : null,
                    ),
                  ),
                  EntryField(
                    label: 'Description',
                    child: TextFormField(
                      key: const Key('expense-description'),
                      controller: _description,
                      decoration: entryDecoration('e.g. Lunch with friends'),
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
                          decoration: entryDecoration('').copyWith(
                            suffixIcon: const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                            ),
                            errorText: field.errorText,
                          ),
                          child: Text(
                            _date == null ? 'Select date' : formatDate(_date!),
                            style: const TextStyle(
                              fontSize: 13,
                              color: appMuted,
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
