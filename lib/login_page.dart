import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_data.dart';
import 'app_theme.dart';
import 'cloud_api.dart';
import 'entry_widgets.dart';
import 'welcome_screen.dart';

// One root route switches between sign-in and Home. Logging out also closes
// any screens opened above Home, so Back cannot reopen a signed-out session.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.destination});
  final Widget destination;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  CloudApi? _cloud;
  bool _wasSignedIn = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cloud = AppDataScope.of(context).cloud;
    if (identical(cloud, _cloud)) return;
    _cloud?.removeListener(_changed);
    _cloud = cloud;
    _wasSignedIn = cloud.signedIn;
    cloud.addListener(_changed);
  }

  void _changed() {
    final signedIn = _cloud!.signedIn;
    if (_wasSignedIn && !signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    _wasSignedIn = signedIn;
    setState(() {});
  }

  @override
  void dispose() {
    _cloud?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = AppDataScope.of(context).sync;
    return _cloud!.signedIn && (!sync.enabled || sync.ready)
        ? widget.destination
        : const LoginPage();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController(),
      _server = TextEditingController();
  bool _register = false, _obscure = true, _busy = false, _initialized = false;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _server.text = AppDataScope.of(context).cloud.suggestedUrl;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final cloud = AppDataScope.of(context).cloud;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await cloud.authenticate(
        _server.text,
        _email.text,
        _password.text,
        register: _register,
        name: _register ? _name.text : null,
      );
      // AuthGate opens Home when the API confirms the account session.
      TextInput.finishAutofillContext();
    } on CloudApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final visibleError = _error ?? AppDataScope.of(context).sync.error;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: SpendTrackerLogo()),
                      const SizedBox(height: 24),
                      Text(
                        _register ? 'Create your account' : 'Welcome back',
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _register
                            ? 'Start tracking your money with SpendTracker.'
                            : 'Sign in to continue to SpendTracker.',
                        style: TextStyle(color: palette.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      if (_register)
                        EntryField(
                          label: 'Full name',
                          child: TextFormField(
                            key: const Key('login-name'),
                            controller: _name,
                            enabled: !_busy,
                            maxLength: 80,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration:
                                entryDecoration(
                                  context,
                                  'e.g. Pamela Reyes',
                                ).copyWith(
                                  prefixIcon: const Icon(
                                    Icons.person_outline_rounded,
                                    size: 20,
                                  ),
                                ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter your name'
                                : value.trim().length > 80
                                ? 'Use up to 80 characters'
                                : null,
                          ),
                        ),
                      EntryField(
                        label: 'Email address',
                        child: TextFormField(
                          key: const Key('login-email'),
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration:
                              entryDecoration(
                                context,
                                'you@example.com',
                              ).copyWith(
                                prefixIcon: const Icon(
                                  Icons.mail_outline_rounded,
                                  size: 20,
                                ),
                              ),
                          validator: (value) =>
                              value == null ||
                                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(value.trim())
                              ? 'Enter a valid email address'
                              : null,
                        ),
                      ),
                      EntryField(
                        label: 'Password',
                        child: TextFormField(
                          key: const Key('login-password'),
                          controller: _password,
                          enabled: !_busy,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: [
                            _register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          textInputAction: _register
                              ? TextInputAction.next
                              : TextInputAction.done,
                          decoration:
                              entryDecoration(
                                context,
                                'At least 8 characters',
                              ).copyWith(
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                          () => _obscure = !_obscure,
                                        ),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                ),
                              ),
                          validator: (value) =>
                              value == null ||
                                  value.length < 8 ||
                                  value.length > 128
                              ? 'Use a password of 8–128 characters'
                              : null,
                          onFieldSubmitted: (_) {
                            if (!_register) _submit();
                          },
                        ),
                      ),
                      if (_register)
                        EntryField(
                          label: 'Confirm password',
                          child: TextFormField(
                            key: const Key('login-confirm-password'),
                            controller: _confirm,
                            enabled: !_busy,
                            obscureText: _obscure,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.done,
                            decoration:
                                entryDecoration(
                                  context,
                                  'Enter your password again',
                                ).copyWith(
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                  ),
                                ),
                            validator: (value) =>
                                value != _password.text ||
                                    value == null ||
                                    value.isEmpty
                                ? 'Passwords do not match'
                                : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        ),
                      if (visibleError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              visibleError,
                              key: const Key('login-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          key: const Key('login-submit'),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_register ? 'Create account' : 'Sign in'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        key: const Key('login-switch-mode'),
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() {
                                  _register = !_register;
                                  _error = null;
                                  final email = _email.text;
                                  final name = _name.text;
                                  final server = _server.text;
                                  _password.clear();
                                  _confirm.clear();
                                  _form.currentState?.reset();
                                  _email.text = email;
                                  _name.text = name;
                                  _server.text = server;
                                });
                              },
                        child: Text(
                          _register
                              ? 'Already have an account? Sign in'
                              : 'New to SpendTracker? Create an account',
                        ),
                      ),
                      if (!kReleaseMode)
                        ExpansionTile(
                          key: const Key('login-connection'),
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            'Connection settings',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.muted,
                            ),
                          ),
                          children: [
                            EntryField(
                              label: 'Server URL',
                              child: TextFormField(
                                key: const Key('login-server'),
                                controller: _server,
                                enabled: !_busy,
                                keyboardType: TextInputType.url,
                                decoration: entryDecoration(
                                  context,
                                  'http://10.0.2.2:3000',
                                ),
                              ),
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
      ),
    );
  }
}
