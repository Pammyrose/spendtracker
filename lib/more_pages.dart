import 'package:flutter/material.dart';

import 'app_theme.dart';

import 'package:flutter/services.dart';

import 'app_data.dart';
import 'entry_widgets.dart';
import 'history_page.dart';
import 'custom_color_picker.dart';
import 'cloud_backup_page.dart';
import 'edit_profile_dialog.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});
  Widget _heading(String title, IconData icon) => Semantics(
    key: ValueKey('more-${title.toLowerCase()}-heading'),
    header: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('more-scroll'),
    primary: false,
    padding: const EdgeInsets.all(20),
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 12),
        child: Text(
          'More',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      const _AccountProfileCard(),
      _heading('History', Icons.history_rounded),
      const HistorySummaryPanel(),
      const SizedBox(height: 16),
      _heading('Notification settings', Icons.notifications_none_rounded),
      const NotificationSettingsPage(embedded: true),
      const SizedBox(height: 16),
      _heading('Settings', Icons.settings_outlined),
      const SettingsPage(embedded: true),
    ],
  );
}

class _AccountProfileCard extends StatelessWidget {
  const _AccountProfileCard();
  @override
  Widget build(BuildContext context) {
    final cloud = AppDataScope.of(context).cloud,
        palette = AppPalette.of(context);
    return AnimatedBuilder(
      animation: cloud,
      builder: (context, _) {
        if (!cloud.signedIn) return const SizedBox.shrink();
        return Container(
          key: const Key('account-profile'),
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: palette.soft,
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 30,
                  color: palette.ink,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account profile',
                      style: TextStyle(color: palette.muted, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cloud.displayName,
                      key: const Key('profile-name'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cloud.email ?? '',
                      key: const Key('profile-email'),
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('edit-profile'),
                onPressed: () => showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const EditProfileDialog(),
                ),
                child: const Text('Edit'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FeaturePage extends StatelessWidget {
  const FeaturePage({
    super.key,
    required this.title,
    required this.child,
    this.embedded = false,
  });
  final bool embedded;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => embedded
      ? child
      : Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Text(
              title,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 21),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: child,
              ),
            ),
          ),
        );
}

Widget _section(BuildContext context, String title, List<Widget> children) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.of(context).surface,
          border: Border.all(color: AppPalette.of(context).border),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ...children,
          ],
        ),
      ),
    );

Widget _link(
  BuildContext context,
  IconData icon,
  String label,
  VoidCallback onTap, {
  String? value,
  bool danger = false,
}) => Material(
  color: Colors.transparent,
  child: ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: Icon(
      icon,
      size: 20,
      color: danger
          ? Theme.of(context).colorScheme.primary
          : AppPalette.of(context).ink,
    ),
    title: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: danger ? Theme.of(context).colorScheme.primary : null,
      ),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          Text(
            value,
            style: TextStyle(color: AppPalette.of(context).muted, fontSize: 10),
          ),
        const SizedBox(width: 3),
        Icon(
          Icons.chevron_right_rounded,
          size: 17,
          color: AppPalette.of(context).muted,
        ),
      ],
    ),
    onTap: onTap,
  ),
);

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key, this.embedded = false});
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final data = AppDataScope.of(context);
    final enabled = data.notificationsEnabled;
    Widget toggle(
      String title,
      String subtitle,
      bool value,
      ValueChanged<bool> onChanged,
    ) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppPalette.of(context).muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        Switch(
          value: value,
          activeTrackColor: Theme.of(context).colorScheme.primary,
          onChanged: enabled
              ? (value) {
                  onChanged(value);
                  data.changed();
                }
              : null,
        ),
      ],
    );
    Widget time(String value, ValueChanged<String> onChanged, bool active) =>
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Default Reminder Time',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: ValueKey('reminder-$value'),
                initialValue: value,
                isExpanded: true,
                decoration: entryDecoration(context, ''),
                items: reminderTimes
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          v,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppPalette.of(context).muted,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: enabled && active
                    ? (v) {
                        onChanged(v!);
                        data.changed();
                      }
                    : null,
              ),
            ],
          ),
        );
    return FeaturePage(
      title: 'Notification settings',
      embedded: embedded,
      child: ListView(
        shrinkWrap: embedded,
        primary: !embedded,
        physics: embedded ? const NeverScrollableScrollPhysics() : null,
        padding: embedded ? EdgeInsets.zero : const EdgeInsets.all(20),
        children: [
          if (!enabled)
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Notifications are turned off in Settings.',
                style: TextStyle(
                  color: AppPalette.of(context).muted,
                  fontSize: 12,
                ),
              ),
            ),
          _section(context, '', [
            toggle(
              'Bill Reminders',
              'Get notified before your bills are due.',
              data.billReminders,
              (v) => data.billReminders = v,
            ),
            time(
              data.billReminderTime,
              (v) => data.billReminderTime = v,
              data.billReminders,
            ),
          ]),
          _section(context, '', [
            toggle(
              'Income Reminders',
              'Get notified on your income date.',
              data.incomeReminders,
              (v) => data.incomeReminders = v,
            ),
            time(
              data.incomeReminderTime,
              (v) => data.incomeReminderTime = v,
              data.incomeReminders,
            ),
          ]),
          _section(context, '', [
            toggle(
              'Expense Alerts',
              'Alert when this month’s spending reaches your saved limit.',
              data.expenseAlerts,
              (v) async {
                data.expenseAlerts = v;
                if (v) {
                  final allowed = await data.requestExpenseNotifications();
                  if (context.mounted && !allowed) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Expense alerts are visible in the bell. Allow Android notifications for alerts outside the app.',
                        ),
                      ),
                    );
                  }
                  data.changed();
                }
              },
            ),
            if (data.expenseAlerts) _ExpenseLimitField(enabled: enabled),
          ]),
          _section(context, '', [
            toggle(
              'Monthly Summary',
              'Receive a summary of your spending every month.',
              data.monthlySummary,
              (v) => data.monthlySummary = v,
            ),
          ]),
          Text(
            'Pay later follow-ups and expense alerts use Android notifications when permission is allowed. Regular bill, income, and monthly summary options are saved preferences.',
            style: TextStyle(fontSize: 11, color: AppPalette.of(context).muted),
          ),
        ],
      ),
    );
  }
}

class _ExpenseLimitField extends StatefulWidget {
  const _ExpenseLimitField({required this.enabled});
  final bool enabled;
  @override
  State<_ExpenseLimitField> createState() => _ExpenseLimitFieldState();
}

class _ExpenseLimitFieldState extends State<_ExpenseLimitField> {
  final _form = GlobalKey<FormState>();
  String? _draft;
  void _save() {
    if (!_form.currentState!.validate()) return;
    final data = AppDataScope.of(context);
    data.expenseAlertAmount = double.parse(
      _draft ?? data.expenseAlertAmount.toString(),
    );
    data.changed();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Monthly expense limit saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = AppDataScope.of(context);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EntryField(
            label: 'Monthly spending limit',
            child: TextFormField(
              key: const Key('expense-alert-limit'),
              initialValue: data.expenseAlertAmount.toStringAsFixed(2),
              decoration: entryDecoration(
                context,
                '0.00',
              ).copyWith(prefixText: '${data.symbol} '),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: validateAmount,
              enabled: widget.enabled,
              onChanged: (value) => _draft = value,
              onFieldSubmitted: widget.enabled ? (_) => _save() : null,
            ),
          ),
          OutlinedButton(
            onPressed: widget.enabled ? _save : null,
            child: const Text('Save limit'),
          ),
          const SizedBox(height: 6),
          Text(
            'One Android alert per month for each saved limit. The bell shows the alert while this month’s spending is at or above the limit. Next month starts a new total.',
            style: TextStyle(fontSize: 11, color: AppPalette.of(context).muted),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.embedded = false});
  final bool embedded;

  Future<void> _customTheme(BuildContext context) async {
    final data = AppDataScope.of(context);
    final choice = await showDialog<CustomThemeChoice>(
      context: context,
      builder: (_) => CustomColorDialog(
        initialColor: Color(data.customColor),
        initialDark: data.customDark,
      ),
    );
    if (choice != null && context.mounted) {
      data.customColor = choice.color.toARGB32();
      data.customDark = choice.dark;
      data.theme = 'Custom';
      data.changed();
    }
  }

  Future<String?> _choose(
    BuildContext context,
    String title,
    List<String> values,
    String selected, {
    String? note,
  }) => showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        if (note != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              note,
              style: TextStyle(
                color: AppPalette.of(context).muted,
                fontSize: 12,
              ),
            ),
          ),
        for (final value in values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, value),
            child: Row(
              children: [
                Expanded(child: Text(value)),
                if (value == selected)
                  Icon(
                    Icons.check_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
      ],
    ),
  );

  Future<void> _export(
    BuildContext context,
    String format, {
    String? source,
  }) async {
    final data = AppDataScope.of(context);
    final now = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final content = format == 'json'
          ? source ?? data.backupJson()
          : format == 'csv'
          ? _csv(data)
          : _report(context, data);
      final saved = await deviceStorage.invokeMethod<bool>('exportData', {
        'name': 'spendtracker-$now.$format',
        'format': format,
        'content': content,
      });
      if (context.mounted && saved == true) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('File saved.')));
      }
    } on MissingPluginException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'File backup and export are available in the Android app.',
            ),
          ),
        );
      }
    } on PlatformException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'The file could not be saved.'),
          ),
        );
      }
    }
  }

  Future<void> _restore(BuildContext context) async {
    final data = AppDataScope.of(context);
    try {
      final source = await deviceStorage.invokeMethod<String>('readBackup');
      if (source == null || !context.mounted) return;
      data.validateBackup(source);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore backup?'),
          content: Text(
            data.sync.enabled
                ? 'This replaces this account’s records and settings with the selected backup and saves the change to MySQL.'
                : 'This will replace your current records and settings with the selected backup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        data.restore(source);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Backup restored.')));
      }
    } on MissingPluginException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File restore is available in the Android app.'),
          ),
        );
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on PlatformException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'The backup could not be opened.'),
          ),
        );
      }
    }
  }

  Future<void> _clear(BuildContext context) async {
    final data = AppDataScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: Text(
          data.sync.enabled
              ? 'Delete all income, expenses, bills, and settings for this account? This also saves the empty records to MySQL. Export a JSON backup first if you want to keep a copy.'
              : 'Delete all income, expenses, bills, and settings on this device? Create a backup first if you want to keep a copy. An existing server backup will remain in your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All Data'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      data.clearRecords();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('All data cleared.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = AppDataScope.of(context);
    return FeaturePage(
      title: 'Settings',
      embedded: embedded,
      child: ListView(
        shrinkWrap: embedded,
        primary: !embedded,
        physics: embedded ? const NeverScrollableScrollPhysics() : null,
        padding: embedded ? EdgeInsets.zero : const EdgeInsets.all(20),
        children: [
          _section(context, 'General', [
            _link(
              context,
              Icons.currency_exchange_rounded,
              'Currency',
              () async {
                final choice = await _choose(
                  context,
                  'Currency',
                  ['PHP', 'USD', 'EUR'],
                  data.currency,
                  note: 'Changes the displayed currency symbol. Existing amounts are not converted.',
                );
                if (choice != null) {
                  data.currency = choice;
                  data.changed();
                }
              },
              value: '${data.symbol} ${data.currency}',
            ),
            _link(
              context,
              Icons.schedule_rounded,
              'Default Reminder Time',
              () async {
                final choice = await _choose(
                  context,
                  'Default Reminder Time',
                  reminderTimes,
                  data.billReminderTime,
                );
                if (choice != null) {
                  data.billReminderTime = choice;
                  data.changed();
                }
              },
              value: data.billReminderTime,
            ),
            _link(
              context,
              Icons.notifications_none_rounded,
              'Notifications',
              () async {
                final choice = await _choose(context, 'Notifications', [
                  'Enabled',
                  'Disabled',
                ], data.notificationsEnabled ? 'Enabled' : 'Disabled');
                if (choice != null) {
                  data.notificationsEnabled = choice == 'Enabled';
                  data.changed();
                }
              },
              value: data.notificationsEnabled ? 'Enabled' : 'Disabled',
            ),
          ]),
          _section(context, 'Appearance', [
            _link(context, Icons.palette_outlined, 'Theme', () async {
              final choice = await showDialog<String>(
                context: context,
                builder: (context) => _ThemePicker(selected: data.theme),
              );
              if (choice != null) {
                if (choice == 'Custom') {
                  if (context.mounted) await _customTheme(context);
                } else {
                  data.theme = choice;
                  data.changed();
                }
              }
            }, value: data.theme == 'White' ? 'White (Default)' : data.theme),
          ]),
          _section(context, 'Data', [
            _link(
              context,
              Icons.cloud_outlined,
              'Cloud backup',
              () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const CloudBackupPage(),
                ),
              ),
              value: 'Node.js / MySQL',
            ),
            _link(context, Icons.backup_outlined, 'Backup & Restore', () async {
              final action = await _choose(context, 'Backup & Restore', [
                'Create JSON Backup',
                'Restore JSON Backup',
                if (data.sync.enabled) 'Export previous device backup',
              ], '');
              if (!context.mounted) return;
              if (action == 'Create JSON Backup') {
                await _export(context, 'json');
              } else if (action == 'Restore JSON Backup') {
                await _restore(context);
              } else if (action == 'Export previous device backup') {
                final source = await deviceStorage.invokeMethod<String>(
                  'readLegacyData',
                );
                if (!context.mounted) return;
                if (source == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No previous device backup is available for this account.',
                      ),
                    ),
                  );
                } else {
                  await _export(context, 'json', source: source);
                }
              }
            }),
            _link(
              context,
              Icons.file_present_outlined,
              'Export Data',
              () async {
                final format = await _choose(context, 'Export Data', [
                  'CSV',
                  'PDF',
                ], '');
                if (format != null && context.mounted) {
                  await _export(context, format.toLowerCase());
                }
              },
              value: 'PDF / CSV',
            ),
            _link(
              context,
              Icons.delete_outline_rounded,
              'Clear All Data',
              () => _clear(context),
              danger: true,
            ),
          ]),
        ],
      ),
    );
  }
}

String _csv(AppData data) {
  // Escape fields and prevent descriptions from being treated as spreadsheet formulas.
  String cell(Object value) {
    var text = value.toString();
    if (RegExp(r'^[=+@\-\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  final rows = <List<Object>>[
    ['Type', 'Name', 'Category', 'Amount', 'Currency', 'Date', 'Notes'],
  ];
  for (final e in data.expenses) {
    rows.add([
      'Expense',
      e.title,
      data.expenseCategories[e.category].name,
      e.amount.toStringAsFixed(2),
      data.currency,
      e.date.toIso8601String().substring(0, 10),
      '',
    ]);
  }
  for (final e in data.incomes) {
    rows.add([
      'Income',
      e.name,
      data.incomeCategories[e.category].name,
      e.amount.toStringAsFixed(2),
      data.currency,
      e.date.toIso8601String().substring(0, 10),
      e.notes,
    ]);
  }
  for (final b in data.bills.bills) {
    rows.add([
      'Bill',
      b.name,
      b.category == null ? 'Bills' : data.billCategories[b.category!].name,
      b.amount.toStringAsFixed(2),
      data.currency,
      b.due.toIso8601String().substring(0, 10),
      '${b.paid ? 'Paid' : 'Unpaid'}; ${b.repeat}; ${b.reminder}; ${b.notes}${b.paymentPlanAt == null ? '' : '; Pay on ${b.paymentPlanAt!.toIso8601String()}; ${b.followUpRepeat}; ${b.paymentReason}'}',
    ]);
  }
  return '\uFEFF${rows.map((row) => row.map(cell).join(',')).join('\r\n')}';
}

String _report(BuildContext context, AppData data) => [
  'SpendTracker Report',
  'Generated ${formatDate(DateTime.now())} | Currency: ${data.currency}',
  '',
  'EXPENSES',
  ...data.expenses.map(
    (e) =>
        '${formatDate(e.date)} | ${e.title} | ${data.expenseCategories[e.category].name} | ${formatMoney(context, e.amount)}',
  ),
  '',
  'INCOME',
  ...data.incomes.map(
    (e) =>
        '${formatDate(e.date)} | ${e.name} | ${data.incomeCategories[e.category].name} | ${formatMoney(context, e.amount)}${e.notes.isEmpty ? '' : ' | ${e.notes}'}',
  ),
  '',
  'BILLS',
  ...data.bills.bills.map(
    (b) =>
        '${formatDate(b.due)} | ${b.name} | ${b.category == null ? 'Bills' : data.billCategories[b.category!].name} | ${formatMoney(context, b.amount)} | ${b.paid ? 'Paid' : 'Unpaid'}${b.notes.isEmpty ? '' : ' | ${b.notes}'}${b.paymentPlanAt == null ? '' : ' | Pay on ${b.paymentPlanAt!.toIso8601String()} | ${b.followUpRepeat} | ${b.paymentReason}'}',
  ),
].join('\n');

// Preview backgrounds, cards, and buttons before choosing a theme.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.selected});
  final String selected;
  @override
  Widget build(BuildContext context) => Dialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose theme',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose colors for your dashboard and forms.',
              style: TextStyle(
                color: AppPalette.of(context).muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final palette in appPalettes)
                    SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: Semantics(
                        selected: selected == palette.name,
                        button: true,
                        child: Material(
                          color: palette.background,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(context, palette.name),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selected == palette.name
                                      ? palette.accent
                                      : palette.border,
                                  width: selected == palette.name ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    height: 24,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          palette.heroStart,
                                          palette.heroEnd,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: palette.surface,
                                      border: Border.all(color: palette.border),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      width: 30,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: palette.accent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          palette.name,
                                          style: TextStyle(
                                            color: palette.ink,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (selected == palette.name)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: palette.accent,
                                          size: 16,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'Custom'),
              icon: const Icon(Icons.color_lens_outlined),
              label: const Text('Color wheel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}
