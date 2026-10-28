import 'package:flutter/material.dart';

import 'app_data.dart';
import 'app_theme.dart';
import 'cloud_api.dart';

class AccountSyncBanner extends StatelessWidget {
  const AccountSyncBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final sync = AppDataScope.of(context).sync,
        palette = AppPalette.of(context);
    if (!sync.enabled || !sync.ready || !sync.dirty && sync.error == null) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const Key('account-sync-status'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: palette.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sync.error == null
                ? 'Saving to your account...'
                : 'Server save not confirmed. ${sync.error}${AppDataScope.of(context).storageAvailable ? '' : ' Device storage is unavailable; keep the app open until the save succeeds.'}',
            style: TextStyle(fontSize: 12, color: palette.ink),
          ),
          if (sync.error != null)
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: sync.saving ? null : sync.retry,
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: sync.saving
                      ? null
                      : () async {
                          final approved = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Reload account data?'),
                              content: const Text(
                                'This replaces unsaved changes on this device with the current server records. Export a local JSON backup first if you want to keep them.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Reload'),
                                ),
                              ],
                            ),
                          );
                          if (approved != true) return;
                          try {
                            await sync.reload();
                          } on CloudApiException catch (failure) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(failure.message)),
                              );
                            }
                          }
                        },
                  child: const Text('Reload server data'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
