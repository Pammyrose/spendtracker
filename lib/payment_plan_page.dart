import 'package:flutter/material.dart';

import 'app_data.dart';
import 'app_theme.dart';
import 'entry_widgets.dart';

String paymentTime(BuildContext context, DateTime at) =>
    '${formatDate(at)} at ${TimeOfDay.fromDateTime(at).format(context)}';

class PaymentPlanPage extends StatefulWidget {
  const PaymentPlanPage({
    super.key,
    required this.bill,
    required this.controller,
  });
  final Bill bill;
  final BillsController controller;
  @override
  State<PaymentPlanPage> createState() => _PaymentPlanPageState();
}

class _PaymentPlanPageState extends State<PaymentPlanPage> {
  final _form = GlobalKey<FormState>();
  late final _reason = TextEditingController(text: widget.bill.paymentReason);
  late DateTime _day =
      widget.bill.paymentPlanAt != null &&
          widget.bill.paymentPlanAt!.isAfter(DateTime.now())
      ? widget.bill.paymentPlanAt!
      : DateTime.now().add(const Duration(days: 1));
  late TimeOfDay _time = widget.bill.paymentPlanAt != null
      ? TimeOfDay.fromDateTime(widget.bill.paymentPlanAt!)
      : const TimeOfDay(hour: 9, minute: 0);
  late String _repeat = widget.bill.followUpRepeat;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final at = DateTime(
      _day.year,
      _day.month,
      _day.day,
      _time.hour,
      _time.minute,
    );
    if (!at.isAfter(DateTime.now())) {
      setState(() => _error = 'Choose a future payment date and time.');
      return;
    }
    final data = AppDataScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    final enabled = data.notificationsEnabled && data.billReminders;
    final allowed = enabled && await data.requestPaymentNotifications();
    if (!mounted) return;
    try {
      widget.controller.postpone(
        widget.bill,
        reason: _reason.text,
        at: at,
        repeat: _repeat,
      );
      await data.flush();
      if (!mounted) return;
      Navigator.pop(
        context,
        !data.storageAvailable
            ? 'Payment plan added for this session. Device storage is unavailable; reminders could not be scheduled.'
            : !enabled
            ? 'Payment plan saved. Bill reminders are off in Settings.'
            : !allowed
            ? 'Payment plan saved. Enable Android notifications for SpendTracker to receive reminders.'
            : _repeat == 'Once'
            ? 'Payment plan saved. One reminder is scheduled.'
            : 'Payment plan saved. Reminders repeat until the bill is paid.',
      );
    } on FormatException catch (error) {
      setState(() {
        _error = error.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = AppDataScope.of(context), palette = AppPalette.of(context);
    final remindersOff = !data.notificationsEnabled || !data.billReminders;
    return EntryPage(
      title: 'Pay later',
      saveLabel: _saving ? 'Saving...' : 'Save payment plan',
      onSave: _save,
      children: [
        Text(
          widget.bill.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Original due: ${formatDate(widget.bill.due)}',
          style: TextStyle(color: palette.muted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Text(
          formatMoney(context, widget.bill.amount),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EntryField(
                label: 'Why can\u2019t you pay yet?',
                child: TextFormField(
                  key: const Key('payment-reason'),
                  controller: _reason,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: entryDecoration(
                    context,
                    'e.g. The landlord is away. I will pay when they return.',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a reason for paying later'
                      : null,
                ),
              ),
              EntryField(
                label: 'New payment date',
                child: InkWell(
                  key: const Key('payment-date'),
                  onTap: () async {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _day.isBefore(today) ? today : _day,
                      firstDate: today,
                      lastDate: DateTime(2100, 12, 31),
                    );
                    if (date != null && mounted) setState(() => _day = date);
                  },
                  child: InputDecorator(
                    decoration: entryDecoration(context, '').copyWith(
                      suffixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                      ),
                    ),
                    child: Text(
                      formatDate(_day),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
              EntryField(
                label: 'Reminder time',
                child: InkWell(
                  key: const Key('payment-time'),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (time != null && mounted) setState(() => _time = time);
                  },
                  child: InputDecorator(
                    decoration: entryDecoration(context, '').copyWith(
                      suffixIcon: const Icon(Icons.schedule_rounded, size: 20),
                    ),
                    child: Text(
                      _time.format(context),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
              EntryField(
                label: 'Remind me until paid',
                child: DropdownButtonFormField<String>(
                  key: const Key('payment-repeat'),
                  initialValue: _repeat,
                  isExpanded: true,
                  decoration: entryDecoration(context, ''),
                  items: paymentReminderOptions
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _repeat = value!),
                ),
              ),
              if (remindersOff)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bill reminders are turned off.',
                        style: TextStyle(fontSize: 12),
                      ),
                      TextButton(
                        onPressed: () {
                          data.notificationsEnabled = true;
                          data.billReminders = true;
                          data.changed();
                        },
                        child: const Text('Enable bill reminders'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                'This bill stays unpaid and keeps its original due date. Repeat reminders stop when you mark it as paid or remove the payment plan.',
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
