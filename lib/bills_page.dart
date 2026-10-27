import 'package:flutter/material.dart';

import 'entry_widgets.dart';

const _billIcons = [
  Icons.language_rounded,
  Icons.bolt_rounded,
  Icons.water_drop_rounded,
  Icons.movie_rounded,
  Icons.phone_android_rounded,
  Icons.home_work_rounded,
];
const _billColors = [
  Color(0xFF087BFF),
  Color(0xFFFF9A1F),
  Color(0xFF087BFF),
  Color(0xFFFF426B),
  Color(0xFF5366FF),
  Color(0xFFFF8C32),
];

class Bill {
  Bill({
    required this.name,
    required this.amount,
    required this.due,
    this.icon = 0,
    this.repeat = 'Monthly',
    this.reminder = '3 days before',
    this.paid = false,
  });
  final String name, repeat, reminder;
  final double amount;
  final DateTime due;
  final int icon;
  bool paid;
  int get daysLeft {
    final now = DateTime.now();
    // Compare calendar dates, rather than rounding a partial day.
    return DateTime.utc(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  }
}

// The home preview and Bills tab listen to the same list.
class BillsController extends ChangeNotifier {
  BillsController() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final names = [
      'Internet',
      'Electricity',
      'Water',
      'Netflix',
      'Phone Plan',
      'Rent',
    ];
    final amounts = [1500.0, 2000.0, 800.0, 549.0, 999.0, 8000.0];
    final days = [5, 10, 15, 18, 20, 22];
    bills = List.generate(
      names.length,
      (i) => Bill(
        name: names[i],
        amount: amounts[i],
        due: today.add(Duration(days: days[i])),
        icon: i,
      ),
    );
  }
  late final List<Bill> bills;
  void add(Bill bill) {
    bills.add(bill);
    notifyListeners();
  }

  void togglePaid(Bill bill) {
    bill.paid = !bill.paid;
    notifyListeners();
  }
}

class BillsPage extends StatefulWidget {
  const BillsPage({super.key, required this.controller});
  final BillsController controller;
  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  String _filter = 'All';

  Future<void> _add() async {
    final bill = await Navigator.push<Bill>(
      context,
      MaterialPageRoute(builder: (_) => const AddBillPage()),
    );
    if (bill != null && mounted) {
      widget.controller.add(bill);
      setState(() => _filter = 'All');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final bills =
          widget.controller.bills
              .where(
                (b) => switch (_filter) {
                  'Paid' => b.paid,
                  'Unpaid' => !b.paid,
                  'Due Soon' => !b.paid && b.daysLeft <= 7,
                  _ => true,
                },
              )
              .toList()
            ..sort((a, b) => a.due.compareTo(b.due));
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bills',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Add bill',
                  onPressed: _add,
                  style: IconButton.styleFrom(
                    backgroundColor: appPink,
                    foregroundColor: Colors.white,
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
                for (final filter in ['All', 'Paid', 'Due Soon', 'Unpaid'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: TextButton(
                        onPressed: () => setState(() => _filter = filter),
                        style: TextButton.styleFrom(
                          backgroundColor: _filter == filter
                              ? appPink
                              : const Color(0xFFECF0F5),
                          foregroundColor: _filter == filter
                              ? Colors.white
                              : appMuted,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          filter,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: bills.isEmpty
                ? Center(
                    child: Text(
                      _filter == 'Paid'
                          ? 'No paid bills yet.'
                          : 'No bills in this filter.',
                      style: const TextStyle(color: appMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: bills.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => BillCard(
                      bill: bills[i],
                      onTap: () =>
                          _showBill(context, bills[i], widget.controller),
                    ),
                  ),
          ),
        ],
      );
    },
  );
}

void _showBill(BuildContext context, Bill bill, BillsController controller) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              bill.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              formatMoney(bill.amount),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text('Due ${formatDate(bill.due)}'),
            Text('Repeat: ${bill.repeat}'),
            Text('Reminder preference: ${bill.reminder}'),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: appPink),
              onPressed: () {
                controller.togglePaid(bill);
                Navigator.pop(context);
              },
              child: Text(bill.paid ? 'Mark as unpaid' : 'Mark as paid'),
            ),
          ],
        ),
      ),
    ),
  );
}

class BillsPreview extends StatelessWidget {
  const BillsPreview({
    super.key,
    required this.controller,
    required this.onSeeAll,
  });
  final BillsController controller;
  final VoidCallback onSeeAll;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final bills = controller.bills.where((b) => !b.paid).toList()
        ..sort((a, b) => a.due.compareTo(b.due));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Upcoming Bills',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(foregroundColor: appPink),
                child: const Text('See All'),
              ),
            ],
          ),
          if (bills.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No upcoming bills.',
                style: TextStyle(color: appMuted),
              ),
            ),
          for (final bill in bills.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BillCard(
                bill: bill,
                onTap: () => _showBill(context, bill, controller),
              ),
            ),
        ],
      );
    },
  );
}

class BillCard extends StatelessWidget {
  const BillCard({super.key, required this.bill, this.onTap});
  final Bill bill;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final days = bill.daysLeft;
    final urgent = days <= 7;
    final color = _billColors[bill.icon];
    final status = bill.paid
        ? 'Paid'
        : days < 0
        ? '${-days} days overdue'
        : days == 0
        ? 'Due today'
        : '$days days left';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: color.withValues(alpha: 0.09),
                child: Icon(_billIcons[bill.icon], color: color, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatMoney(bill.amount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Due ${formatDate(bill.due)}',
                      style: const TextStyle(fontSize: 10, color: appMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: bill.paid
                        ? const Color(0xFFD9F8EF)
                        : urgent
                        ? const Color(0xFFFFE4EB)
                        : days <= 10
                        ? const Color(0xFFFFEDD9)
                        : const Color(0xFFEAF0F5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: bill.paid
                          ? const Color(0xFF008C69)
                          : urgent
                          ? appPink
                          : appMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddBillPage extends StatefulWidget {
  const AddBillPage({super.key});
  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  DateTime? _due;
  String _repeat = 'Monthly';
  String _reminder = '3 days before';
  int _icon = 0;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.pop(
        context,
        Bill(
          name: _name.text.trim(),
          amount: double.parse(
            double.parse(_amount.text.trim()).toStringAsFixed(2),
          ),
          due: _due!,
          icon: _icon,
          repeat: _repeat,
          reminder: _reminder,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => EntryPage(
    title: 'Add Bill',
    saveLabel: 'Save Bill',
    onSave: _save,
    children: [
      Form(
        key: _form,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              EntryField(
                label: 'Bill Name',
                child: TextFormField(
                  key: const Key('bill-name'),
                  controller: _name,
                  decoration: entryDecoration('e.g. Internet'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter a bill name'
                      : null,
                ),
              ),
              EntryField(
                label: 'Amount',
                child: TextFormField(
                  key: const Key('bill-amount'),
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
                label: 'Due Date',
                child: FormField<DateTime>(
                  validator: (_) => _due == null ? 'Choose a due date' : null,
                  builder: (field) => InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate:
                            _due ?? DateTime(now.year, now.month, now.day),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100, 12, 31),
                      );
                      if (date != null && mounted) {
                        setState(() => _due = date);
                        field.didChange(date);
                      }
                    },
                    child: InputDecorator(
                      decoration: entryDecoration('').copyWith(
                        errorText: field.errorText,
                        suffixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                      ),
                      child: Text(
                        _due == null ? 'Select date' : formatDate(_due!),
                        style: const TextStyle(color: appMuted, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
              EntryField(
                label: 'Repeat',
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _repeat,
                  decoration: entryDecoration('').copyWith(
                    prefixIcon: const Icon(Icons.sync_rounded, size: 20),
                  ),
                  items: ['Never', 'Weekly', 'Monthly', 'Yearly']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v, style: const TextStyle(fontSize: 13)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _repeat = v!),
                ),
              ),
              EntryField(
                label: 'Icon',
                child: InkWell(
                  onTap: () async {
                    final choice = await showModalBottomSheet<int>(
                      context: context,
                      useSafeArea: true,
                      builder: (context) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: List.generate(
                              _billIcons.length,
                              (i) => IconButton(
                                tooltip: [
                                  'Internet',
                                  'Electricity',
                                  'Water',
                                  'Streaming',
                                  'Phone',
                                  'Rent',
                                ][i],
                                onPressed: () => Navigator.pop(context, i),
                                icon: Icon(
                                  _billIcons[i],
                                  color: _billColors[i],
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                    if (choice != null && mounted) {
                      setState(() => _icon = choice);
                    }
                  },
                  child: InputDecorator(
                    decoration: entryDecoration('').copyWith(
                      suffixIcon: const Icon(Icons.chevron_right_rounded),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _billIcons[_icon],
                          color: _billColors[_icon],
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Choose an icon',
                            style: TextStyle(color: appMuted, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              EntryField(
                label: 'Remind Me',
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _reminder,
                  decoration: entryDecoration('').copyWith(
                    prefixIcon: const Icon(
                      Icons.notifications_none_rounded,
                      size: 20,
                    ),
                  ),
                  items:
                      [
                            'Never',
                            'On due date',
                            '1 day before',
                            '3 days before',
                            '7 days before',
                          ]
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                v,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _reminder = v!),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
