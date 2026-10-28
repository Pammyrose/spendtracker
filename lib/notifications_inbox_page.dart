import 'dart:async';

import 'package:flutter/material.dart';

import 'app_data.dart';
import 'app_theme.dart';
import 'bills_page.dart';
import 'entry_widgets.dart';
import 'more_pages.dart';
import 'payment_plan_page.dart';

class BillAlert {
  const BillAlert(this.bill, this.title, this.detail, this.at, this.urgent);
  final Bill bill;
  final String title, detail;
  final DateTime at;
  final bool urgent;
}

String paymentCountdown(DateTime at, DateTime now) {
  final difference = at.difference(now);
  final minutes = (difference.inSeconds.abs() / 60).ceil();
  final duration = minutes < 60
      ? '$minutes ${minutes == 1 ? 'minute' : 'minutes'}'
      : minutes < 1440
      ? '${minutes ~/ 60} ${(minutes ~/ 60) == 1 ? 'hour' : 'hours'}'
      : '${minutes ~/ 1440} ${(minutes ~/ 1440) == 1 ? 'day' : 'days'}';
  return difference.isNegative
      ? 'Payment time passed $duration ago'
      : difference.inSeconds == 0
      ? 'Payment time is now'
      : 'Payment in $duration';
}

// Only due reminders belong in the inbox; upcoming bills stay on Home.
List<BillAlert> billAlerts(Iterable<Bill> bills, DateTime now) {
  DateTime day(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
  final alerts = <BillAlert>[];
  for (final bill in bills) {
    if (bill.paid) continue;
    final planned = bill.paymentPlanAt;
    final at = planned ?? bill.due;
    final days = day(at).difference(day(now)).inDays;
    if (planned != null ? planned.isAfter(now) : days > 0) continue;
    if (planned != null) {
      alerts.add(
        BillAlert(bill, 'Payment follow-up', bill.paymentReason, at, true),
      );
    } else {
      alerts.add(
        BillAlert(
          bill,
          days < 0 ? 'Bill overdue' : 'Bill due today',
          days < 0
              ? '${-days} ${days == -1 ? 'day' : 'days'} overdue'
              : 'Payment is due today',
          at,
          days <= 0,
        ),
      );
    }
  }
  alerts.sort((a, b) {
    final priority = (a.urgent ? 0 : 1).compareTo(b.urgent ? 0 : 1);
    return priority == 0 ? a.at.compareTo(b.at) : priority;
  });
  return alerts;
}

class NotificationsInboxPage extends StatefulWidget {
  const NotificationsInboxPage({super.key});
  @override
  State<NotificationsInboxPage> createState() => _NotificationsInboxPageState();
}

class _NotificationsInboxPageState extends State<NotificationsInboxPage>
    with WidgetsBindingObserver {
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  @override
  void dispose() {
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = AppDataScope.of(context), palette = AppPalette.of(context);
    final now = DateTime.now();
    final alerts = billAlerts(data.bills.bills, now);
    final expenseAlert = data.expenseLimitReached(now);
    final spent = data.spendingThrough(now);
    return FeaturePage(
      title: 'Notifications',
      child: ListView(
        key: const Key('notifications-inbox'),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Your alerts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Transaction activity, spending alerts, and reminders will show here.',
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
          const SizedBox(height: 8),
          Text(
            'Updated ${formatDate(now)} at ${TimeOfDay.fromDateTime(now).format(context)}',
            key: const Key('notifications-updated'),
            style: TextStyle(fontSize: 11, color: palette.muted),
          ),
          const SizedBox(height: 20),
          if (expenseAlert) ...[
            const Text(
              'Spending alert',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Card(
              key: const Key('expense-limit-alert'),
              margin: const EdgeInsets.only(bottom: 20),
              color: palette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: palette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Monthly spending limit reached',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${formatMoney(context, spent)} spent this month',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Limit: ${formatMoney(context, data.expenseAlertAmount)}\n${formatMoney(context, spent - data.expenseAlertAmount)} above your limit.',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const NotificationSettingsPage(),
                        ),
                      ),
                      child: const Text('Manage expense alerts'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (alerts.isEmpty &&
              !expenseAlert &&
              data.transactionActivity.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 44,
                    color: palette.muted,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'You’re all caught up',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'New transactions and due reminders will appear here. Upcoming bills are on Home.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          for (final urgent in [true]) ...[
            if (alerts.any((alert) => alert.urgent == urgent))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Reminders due',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            for (final alert in alerts.where((alert) => alert.urgent == urgent))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: palette.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: palette.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey(
                      'bill-alert-${data.bills.bills.indexOf(alert.bill)}',
                    ),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => BillDetailsSheet(
                        bill: alert.bill,
                        controller: data.bills,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: palette.soft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              alert.urgent
                                  ? Icons.notification_important_outlined
                                  : Icons.schedule_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert.title,
                                  style: TextStyle(
                                    color: palette.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (alert.bill.paymentPlanAt != null)
                                  Text(
                                    paymentCountdown(alert.at, now),
                                    style: TextStyle(
                                      color: palette.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                Text(
                                  alert.bill.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatMoney(context, alert.bill.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  alert.detail,
                                  style: TextStyle(
                                    color: palette.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  alert.bill.paymentPlanAt == null
                                      ? 'Due ${formatDate(alert.at)}'
                                      : '${paymentTime(context, alert.at)} • ${alert.bill.followUpRepeat}',
                                  style: TextStyle(
                                    color: palette.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (data.transactionActivity.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Transaction activity',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 10),
            for (final activity in data.transactionActivity)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: palette.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: palette.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    key: ValueKey(
                      'transaction-activity-${data.transactionActivity.indexOf(activity)}',
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: palette.soft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        activity.kind.startsWith('income')
                            ? Icons.account_balance_wallet_outlined
                            : activity.kind.startsWith('bill')
                            ? Icons.receipt_long_outlined
                            : Icons.shopping_bag_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      activity.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          activity.name,
                          style: TextStyle(color: palette.ink, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatMoney(context, activity.amount),
                          style: TextStyle(
                            color: palette.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          paymentTime(context, activity.recordedAt),
                          style: TextStyle(color: palette.muted, fontSize: 11),
                        ),
                      ],
                    ),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(activity.title),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activity.name),
                            const SizedBox(height: 8),
                            Text(
                              formatMoney(context, activity.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Recorded: ${paymentTime(context, activity.recordedAt)}',
                            ),
                            Text(
                              '${activity.kind.startsWith('bill') ? 'Original bill due' : 'Transaction date'}: ${formatDate(activity.transactionDate)}',
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
