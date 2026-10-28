import 'package:flutter/material.dart';

import 'app_data.dart';
import 'cloud_api.dart';
import 'entry_widgets.dart';

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key});
  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _initialized = false, _saving = false;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _name.text = AppDataScope.of(context).cloud.name ?? '';
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final cloud = AppDataScope.of(context).cloud;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await cloud.updateProfileName(_name.text);
      if (mounted) Navigator.pop(context, true);
    } on CloudApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Edit profile'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EntryField(
                label: 'Full name',
                child: TextFormField(
                  key: const Key('edit-profile-name'),
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: entryDecoration(context, 'Your name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name'
                      : value.trim().length > 80
                      ? 'Use up to 80 characters'
                      : null,
                ),
              ),
              const Text(
                'Email',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                AppDataScope.of(context).cloud.email ?? '',
                style: const TextStyle(fontSize: 13),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    key: const Key('edit-profile-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save-profile'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    ),
  );
}
