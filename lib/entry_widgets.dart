import 'package:flutter/material.dart';

import 'app_theme.dart';

import 'app_data.dart';

const appPink = Color(0xFFFF5C83);

// Shared form layout: scrollable fields and a save button above the safe area.
class EntryPage extends StatelessWidget {
  const EntryPage({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    required this.saveLabel,
  });
  final String title, saveLabel;
  final List<Widget> children;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: BoxDecoration(color: AppPalette.of(context).background),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, size: 21),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 21,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onSave,
                      child: Text(saveLabel),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class EntryField extends StatelessWidget {
  const EntryField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 7),
        child,
      ],
    ),
  );
}

InputDecoration entryDecoration(BuildContext context, String hint) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppPalette.of(context).muted, fontSize: 13),
      filled: true,
      fillColor: AppPalette.of(context).surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: AppPalette.of(context).border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: AppPalette.of(context).border),
      ),
    );

String formatMoney(BuildContext context, double amount) {
  final parts = amount.toStringAsFixed(2).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '${AppDataScope.of(context).symbol} $whole.${parts.last}';
}

String? validateAmount(String? text) {
  final amount = double.tryParse(text?.trim() ?? '');
  return amount == null ||
          !amount.isFinite ||
          amount < 0.01 ||
          amount > 999999999
      ? 'Enter an amount between 0.01 and 999,999,999'
      : null;
}

String formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
