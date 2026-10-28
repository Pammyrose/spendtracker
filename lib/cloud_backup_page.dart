import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_data.dart';
import 'app_theme.dart';
import 'cloud_api.dart';
import 'entry_widgets.dart';

class CloudBackupPage extends StatefulWidget {
  const CloudBackupPage({super.key});
  @override
  State<CloudBackupPage> createState() => _CloudBackupPageState();
}

class _CloudBackupPageState extends State<CloudBackupPage> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController(),
      _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController();
  bool _register = false,
      _busy = false,
      _initialized = false,
      _confirming = false;
  String? _message;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _url.text = AppDataScope.of(context).cloud.suggestedUrl;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await work();
    } on CloudApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on FormatException {
      if (mounted) {
        setState(
          () => _message = 'This backup is not compatible with the app. Your current records were kept.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    setState(() => _confirming = true);
    try {
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  String _counts(Map<String, dynamic> value) =>
      '${(value['expenses'] as List).length} expenses, ${(value['incomes'] as List).length} income entries, ${(value['bills'] as List).length} bills';
  Future<void> _save() => _run(() async {
    final data = AppDataScope.of(context), cloud = data.cloud;
    final current = cloud.latest ?? await cloud.refresh();
    if (!mounted) return;
    final document = data.backupJson();
    final confirmed = await _confirm(
      'Save to server?',
      'Save ${_counts(jsonDecode(document))} for ${cloud.email}? ${current.data == null ? 'This creates your first server backup.' : 'This replaces server backup revision ${current.revision} (${_counts(current.data!)}).'}',
    );
    if (!confirmed || !mounted) return;
    if (data.sync.enabled) {
      await data.sync.saveReviewed();
    } else {
      await cloud.upload(document);
    }
    if (mounted) setState(() => _message = 'Saved to your MySQL account.');
  });
  Future<void> _restore() => _run(() async {
    final data = AppDataScope.of(context);
    final remote = await data.cloud.refresh();
    if (remote.data == null) {
      throw const CloudApiException(
        'There is no server backup yet. Save your current records first.',
      );
    }
    final document = jsonEncode(remote.data);
    data.validateBackup(document);
    if (!mounted) return;
    if (!await _confirm(
      'Replace local records?',
      'Restore revision ${remote.revision} with ${_counts(remote.data!)}? This replaces all local records, categories, activity, and settings. Create a local JSON backup first if you want to keep your current data.',
    )) {
      return;
    }
    if (!mounted) return;
    if (data.sync.enabled) {
      await data.sync.reload();
    } else {
      data.restore(document);
    }
    await data.flush();
    if (mounted) {
      setState(
        () => _message = data.storageAvailable
            ? 'Server backup restored and saved on this device.'
            : 'Restored for this session, but device storage is unavailable.',
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final cloud = AppDataScope.of(context).cloud;
    return AnimatedBuilder(
      animation: cloud,
      builder: (context, _) {
        final palette = AppPalette.of(context);
        return PopScope(
          canPop: !_busy,
          child: Scaffold(
            appBar: AppBar(title: const Text('Cloud backup')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Icon(Icons.cloud_outlined, size: 40),
                    const SizedBox(height: 14),
                    Text(
                      cloud.signedIn
                          ? cloud.email!
                          : 'Your SpendTracker account',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppDataScope.of(context).sync.enabled
                          ? 'Your records save automatically to your account. Use these controls to review or reload the server copy.'
                          : 'Save a copy of your app data to your account, or restore a saved copy. Changes stay on this device until you choose Save to server.',
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    if (!cloud.signedIn)
                      Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_register)
                              EntryField(
                                label: 'Full name',
                                child: TextFormField(
                                  key: const Key('cloud-name'),
                                  controller: _name,
                                  enabled: !_busy,
                                  maxLength: 80,
                                  textCapitalization: TextCapitalization.words,
                                  autofillHints: const [AutofillHints.name],
                                  decoration: entryDecoration(
                                    context,
                                    'Your name',
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Enter your name'
                                      : null,
                                ),
                              ),
                            EntryField(
                              label: 'Server URL',
                              child: TextFormField(
                                key: const Key('cloud-url'),
                                controller: _url,
                                enabled: !_busy,
                                keyboardType: TextInputType.url,
                                decoration: entryDecoration(
                                  context,
                                  'http://10.0.2.2:3000',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Enter the server URL'
                                    : null,
                              ),
                            ),
                            EntryField(
                              label: 'Email',
                              child: TextFormField(
                                key: const Key('cloud-email'),
                                controller: _email,
                                enabled: !_busy,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                decoration: entryDecoration(
                                  context,
                                  'you@example.com',
                                ),
                                validator: (value) =>
                                    value == null ||
                                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                            .hasMatch(value.trim())
                                    ? 'Enter a valid email'
                                    : null,
                              ),
                            ),
                            EntryField(
                              label: 'Password',
                              child: TextFormField(
                                key: const Key('cloud-password'),
                                controller: _password,
                                enabled: !_busy,
                                obscureText: true,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: entryDecoration(
                                  context,
                                  'At least 8 characters',
                                ),
                                validator: (value) =>
                                    value == null ||
                                        value.length < 8 ||
                                        value.length > 128
                                    ? 'Use 8–128 characters'
                                    : null,
                              ),
                            ),
                            FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      if (!_form.currentState!.validate()) {
                                        return;
                                      }
                                      _run(() async {
                                        await cloud.authenticate(
                                          _url.text,
                                          _email.text,
                                          _password.text,
                                          register: _register,
                                          name: _register ? _name.text : null,
                                        );
                                        _password.clear();
                                      });
                                    },
                              child: Text(
                                _register ? 'Create account' : 'Sign in',
                              ),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () =>
                                        setState(() => _register = !_register),
                              child: Text(
                                _register
                                    ? 'Already have an account? Sign in'
                                    : 'Create an account',
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      if (cloud.latest != null)
                        Text(
                          cloud.latest!.data == null
                              ? 'No server backup yet.'
                              : 'Server revision ${cloud.latest!.revision}: ${_counts(cloud.latest!.data!)}',
                          key: const Key('cloud-status'),
                        ),
                      if (cloud.latest?.updatedAt != null)
                        Text(
                          'Saved ${formatDate(cloud.latest!.updatedAt!.toLocal())} at ${TimeOfDay.fromDateTime(cloud.latest!.updatedAt!.toLocal()).format(context)}',
                          style: TextStyle(color: palette.muted, fontSize: 12),
                        ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Save to server'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _restore,
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('Restore from server'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await cloud.refresh();
                              }),
                        child: const Text('Refresh server status'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _run(cloud.signOut),
                        child: const Text('Sign out'),
                      ),
                    ],
                    if (_busy && !_confirming)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _message!,
                          key: const Key('cloud-message'),
                          style: TextStyle(color: palette.ink),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      'Sign-in lasts until you close the app. Signing in or out does not change your local records.',
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
