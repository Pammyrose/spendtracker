import 'package:flutter/material.dart';

import 'app_theme.dart';

import 'entry_widgets.dart';
import 'app_data.dart';
import 'category_catalog.dart';
import 'category_picker.dart';

class IncomePage extends StatefulWidget {
  const IncomePage({super.key});
  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  List<AppCategory> get _catalog => AppDataScope.of(context).incomeCategories;
  List<Color> get _colors =>
      _catalog.map((category) => category.color).toList();
  List<IconData> get _icons =>
      _catalog.map((category) => category.icon).toList();
  String _filter = 'All';
  // Sample entries match the reference. Changes are kept while the app runs.
  List<IncomeRecord> get _entries => AppDataScope.of(context).incomes;

  Future<void> _openForm([IncomeRecord? existing]) async {
    final entry = await Navigator.push<IncomeRecord>(
      context,
      MaterialPageRoute(builder: (_) => _IncomeForm(initialEntry: existing)),
    );
    if (entry != null && mounted) {
      setState(() {
        AppDataScope.of(context).saveIncome(entry, existing: existing);
        _filter = 'All';
      });
    }
  }

  Future<void> _delete(IncomeRecord entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete income?'),
        content: Text(
          'Remove ${entry.name} (${formatMoney(context, entry.amount)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      AppDataScope.of(context).deleteIncome(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final entries =
        _entries
            .where(
              (e) =>
                  _filter == 'All' ||
                  (_filter == 'Past Month'
                      ? e.date.isBefore(month)
                      : e.date.year == month.year &&
                            e.date.month == month.month),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Income',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton.filled(
                tooltip: 'Add income',
                onPressed: () => _openForm(),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (final filter in ['All', 'This Month', 'Past Month'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: TextButton(
                      onPressed: () => setState(() => _filter = filter),
                      style: TextButton.styleFrom(
                        backgroundColor: _filter == filter
                            ? Theme.of(context).colorScheme.primary
                            : AppPalette.of(context).soft,
                        foregroundColor: _filter == filter
                            ? Theme.of(context).colorScheme.onPrimary
                            : AppPalette.of(context).muted,
                        shape: const StadiumBorder(),
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: Text(filter, style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    'No income in this period.',
                    style: TextStyle(color: AppPalette.of(context).muted),
                  ),
                )
              : _filter == 'Past Month'
              ? _pastIncomeByMonth(entries)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: entries.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _incomeCard(entries[i]),
                ),
        ),
      ],
    );
  }

  // Group by both year and month, with the newest past month first.
  Widget _pastIncomeByMonth(List<IncomeRecord> entries) {
    final groups = <DateTime, List<IncomeRecord>>{};
    for (final entry in entries) {
      final month = DateTime(entry.date.year, entry.date.month);
      groups.putIfAbsent(month, () => []).add(entry);
    }
    final months = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: months.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final month = months[index];
        final entries = groups[month]!;
        final total = entries.fold(0.0, (sum, entry) => sum + entry.amount);
        return ExpansionTile(
          key: PageStorageKey(month),
          title: Text(
            MaterialLocalizations.of(context).formatMonthYear(month),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'} • ${formatMoney(context, total)}',
              style: TextStyle(
                fontSize: 12,
                color: AppPalette.of(context).muted,
              ),
            ),
          ),
          iconColor: Theme.of(context).colorScheme.primary,
          collapsedIconColor: Theme.of(context).colorScheme.primary,
          backgroundColor: AppPalette.of(context).soft,
          collapsedBackgroundColor: AppPalette.of(context).surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          children: [
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _incomeCard(entry),
              ),
          ],
        );
      },
    );
  }

  Widget _incomeCard(IncomeRecord entry) {
    final color = _colors[entry.category];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 2, 12),
      decoration: BoxDecoration(
        color: AppPalette.of(context).surface,
        border: Border.all(color: AppPalette.of(context).border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(_icons[entry.category], color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formatMoney(context, entry.amount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatDate(entry.date),
                  style: TextStyle(
                    color: AppPalette.of(context).muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Options for ${entry.name}',
            icon: const Icon(Icons.more_horiz_rounded, size: 20),
            onSelected: (value) {
              if (value == 'edit') {
                _openForm(entry);
              } else {
                _delete(entry);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomeForm extends StatefulWidget {
  const _IncomeForm({this.initialEntry});
  final IncomeRecord? initialEntry;
  @override
  State<_IncomeForm> createState() => _IncomeFormState();
}

class _IncomeFormState extends State<_IncomeForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialEntry?.name);
  late final _amount = TextEditingController(
    text: widget.initialEntry?.amount.toStringAsFixed(2),
  );
  late final _notes = TextEditingController(text: widget.initialEntry?.notes);
  late DateTime? _date = widget.initialEntry?.date;
  late int? _category = widget.initialEntry?.category;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.pop(
        context,
        IncomeRecord(
          name: _name.text.trim(),
          amount: double.parse(
            double.parse(_amount.text.trim()).toStringAsFixed(2),
          ),
          date: _date!,
          category: _category!,
          notes: _notes.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => EntryPage(
    title: widget.initialEntry == null ? 'Add Income' : 'Edit Income',
    saveLabel: 'Save Income',
    onSave: _save,
    children: [
      Form(
        key: _form,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppPalette.of(context).surface,
            border: Border.all(color: AppPalette.of(context).border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              EntryField(
                label: 'Income Name',
                child: TextFormField(
                  key: const Key('income-name'),
                  controller: _name,
                  decoration: entryDecoration(context, 'e.g. Salary'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter an income name'
                      : null,
                ),
              ),
              EntryField(
                label: 'Amount',
                child: TextFormField(
                  key: const Key('income-amount'),
                  controller: _amount,
                  decoration: entryDecoration(
                    context,
                    '0.00',
                  ).copyWith(prefixText: '${AppDataScope.of(context).symbol} '),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: validateAmount,
                ),
              ),
              EntryField(
                label: 'Income Date',
                child: FormField<DateTime>(
                  validator: (_) =>
                      _date == null ? 'Choose an income date' : null,
                  builder: (field) => InkWell(
                    key: const Key('income-date'),
                    onTap: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate:
                            _date ?? DateTime(now.year, now.month, now.day),
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
                        errorText: field.errorText,
                        suffixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
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
              EntryField(
                label: 'Category',
                child: CategoryField(
                  key: const Key('income-category'),
                  kind: CategoryKind.income,
                  value: _category,
                  onChanged: (value) => setState(() => _category = value),
                ),
              ),

              EntryField(
                label: 'Notes (Optional)',
                child: TextFormField(
                  key: const Key('income-notes'),
                  controller: _notes,
                  maxLines: 2,
                  decoration: entryDecoration(context, 'e.g. October salary'),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
