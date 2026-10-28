import 'package:flutter/material.dart';

import 'app_theme.dart';

import 'entry_widgets.dart';
import 'app_data.dart';
import 'category_catalog.dart';
import 'category_picker.dart';
import 'payment_plan_page.dart';

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
      MaterialPageRoute(
        builder: (_) => AddBillPage(
          defaultReminder: AppDataScope.of(context).billReminderTime,
        ),
      ),
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
                  'Due Soon' =>
                    !b.paid &&
                        (b.daysLeft <= 7 ||
                            b.paymentPlanAt != null &&
                                b.paymentPlanAt!
                                        .difference(DateTime.now())
                                        .inDays <=
                                    7),
                  _ => true,
                },
              )
              .toList()
            ..sort((a, b) => a.nextActionAt.compareTo(b.nextActionAt));
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
                for (final filter in ['All', 'Paid', 'Due Soon', 'Unpaid'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: TextButton(
                        onPressed: () => setState(() => _filter = filter),
                        style: TextButton.styleFrom(
                          backgroundColor: _filter == filter
                              ? Theme.of(context).colorScheme.primary
                              : AppPalette.of(context).soft,
                          foregroundColor: _filter == filter
                              ? Theme.of(context).colorScheme.onPrimary
                              : AppPalette.of(context).muted,
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
                          : widget.controller.bills.isEmpty
                          ? 'No bills yet. Tap + to add your first bill.'
                          : 'No bills in this filter.',
                      style: TextStyle(color: AppPalette.of(context).muted),
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
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BillDetailsSheet(bill: bill, controller: controller),
  );
}

class BillDetailsSheet extends StatelessWidget {
  const BillDetailsSheet({
    super.key,
    required this.bill,
    required this.controller,
  });
  final Bill bill;
  final BillsController controller;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                bill.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                formatMoney(context, bill.amount),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text('Original due: ${formatDate(bill.due)}'),
              Text('Bill repeats: ${bill.repeat}'),
              Text('Reminder preference: ${bill.reminder}'),
              if (bill.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Notes',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(bill.notes),
              ],
              if (bill.paymentReason.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.of(context).soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment note',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(bill.paymentReason),
                      if (bill.paymentPlanAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Planned payment: ${paymentTime(context, bill.paymentPlanAt!)}',
                        ),
                        Text(
                          bill.paid
                              ? 'Reminders stopped (paid)'
                              : 'Follow-up: ${bill.followUpRepeat}${bill.followUpRepeat == 'Once' ? '' : ' until paid'}',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  controller.togglePaid(bill);
                  Navigator.pop(context);
                },
                child: Text(bill.paid ? 'Mark as unpaid' : 'Mark as paid'),
              ),
              if (!bill.paid) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('pay-later'),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(
                    bill.paymentPlanAt == null
                        ? 'Pay later / Add reason'
                        : 'Edit payment plan',
                  ),
                  onPressed: () async {
                    final message = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PaymentPlanPage(bill: bill, controller: controller),
                      ),
                    );
                    if (message != null && context.mounted) {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text(message)));
                    }
                  },
                ),
                if (bill.paymentPlanAt != null)
                  TextButton(
                    onPressed: () => controller.removePaymentPlan(bill),
                    child: const Text('Remove payment plan'),
                  ),
              ],
            ],
          ),
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
        ..sort((a, b) => a.nextActionAt.compareTo(b.nextActionAt));
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
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: const Text('See All'),
              ),
            ],
          ),
          if (bills.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No upcoming bills.',
                style: TextStyle(color: AppPalette.of(context).muted),
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
    final deferred = !bill.paid && bill.paymentPlanAt != null;
    final urgent = deferred
        ? !bill.paymentPlanAt!.isAfter(DateTime.now())
        : days <= 7;
    final color = categoryIcons[bill.icon].color;
    final status = bill.paid
        ? 'Paid'
        : deferred
        ? (urgent ? 'Reminder due' : 'Pay later')
        : days < 0
        ? '${-days} days overdue'
        : days == 0
        ? 'Due today'
        : '$days days left';
    return Material(
      color: AppPalette.of(context).surface,
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
                child: Icon(
                  categoryIcons[bill.icon].icon,
                  color: color,
                  size: 30,
                ),
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
                      formatMoney(context, bill.amount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Due ${formatDate(bill.due)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppPalette.of(context).muted,
                      ),
                    ),
                    if (deferred) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Pay on ${formatDate(bill.paymentPlanAt!)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.of(context).muted,
                        ),
                      ),
                      Tooltip(
                        message: bill.paymentReason,
                        child: Text(
                          bill.paymentReason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                // Put the badge at the card's right edge, within its padding.
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          AppPalette.of(context).brightness == Brightness.dark
                          ? AppPalette.of(context).soft
                          : bill.paid
                          ? const Color(0xFFD9F8EF)
                          : deferred
                          ? const Color(0xFFFFEDD9)
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
                            ? AppPalette.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF52D8B0)
                                  : const Color(0xFF008C69)
                            : urgent
                            ? Theme.of(context).colorScheme.primary
                            : deferred
                            ? (AppPalette.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFFFD69B)
                                  : const Color(0xFF9B5B23))
                            : AppPalette.of(context).muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
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
  const AddBillPage({super.key, this.defaultReminder = '3 days before'});
  final String defaultReminder;
  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _due;
  String _repeat = 'Monthly';
  late String _reminder = widget.defaultReminder;
  int _icon = 0;
  int? _category;

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
        Bill(
          name: _name.text.trim(),
          notes: _notes.text.trim(),
          amount: double.parse(
            double.parse(_amount.text.trim()).toStringAsFixed(2),
          ),
          due: _due!,
          icon: _icon,
          category: _category,
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
            color: AppPalette.of(context).surface,
            border: Border.all(color: AppPalette.of(context).border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              EntryField(
                label: 'Bill Name',
                child: TextFormField(
                  key: const Key('bill-name'),
                  controller: _name,
                  decoration: entryDecoration(context, 'e.g. Internet'),
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
                      decoration: entryDecoration(context, '').copyWith(
                        errorText: field.errorText,
                        suffixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                      ),
                      child: Text(
                        _due == null ? 'Select date' : formatDate(_due!),
                        style: TextStyle(
                          color: AppPalette.of(context).muted,
                          fontSize: 13,
                        ),
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
                  decoration: entryDecoration(context, '').copyWith(
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
                label: 'Category (Optional)',
                child: CategoryField(
                  key: const Key('bill-category'),
                  kind: CategoryKind.bill,
                  value: _category,
                  isRequired: false,
                  onChanged: (value) => setState(() {
                    _category = value;
                    _icon = AppDataScope.of(context)
                        .billCategories[value]
                        .iconIndex;
                  }),
                ),
              ),
              EntryField(
                label: 'Icon',
                child: InkWell(
                  key: const Key('bill-icon'),
                  onTap: () async {
                    final choice = await chooseIcon(context, selected: _icon);
                    if (choice != null && mounted) {
                      setState(() => _icon = choice);
                    }
                  },
                  child: InputDecorator(
                    decoration: entryDecoration(context, '').copyWith(
                      suffixIcon: const Icon(Icons.chevron_right_rounded),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          categoryIcons[_icon].icon,
                          color: categoryIcons[_icon].color,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            categoryIcons[_icon].label,
                            style: TextStyle(
                              color: AppPalette.of(context).muted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              EntryField(
                label: 'Notes (Optional)',
                child: TextFormField(
                  key: const Key('bill-notes'),
                  controller: _notes,
                  maxLength: 1000,
                  maxLines: 2,
                  decoration: entryDecoration(
                    context,
                    'e.g. Contact the landlord before paying',
                  ),
                ),
              ),
              EntryField(
                label: 'Remind Me',
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _reminder,
                  decoration: entryDecoration(context, '').copyWith(
                    prefixIcon: const Icon(
                      Icons.notifications_none_rounded,
                      size: 20,
                    ),
                  ),
                  items: ['Never', ...reminderTimes]
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v, style: const TextStyle(fontSize: 13)),
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
