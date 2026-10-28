import 'dart:convert';

import 'package:flutter/services.dart';

import 'cloud_api.dart';

// Account data uses the API's revisioned MySQL document. Each device keeps its
// own account-scoped pending copy, so a failed request never becomes a fake save.
class AccountSync {
  AccountSync({
    required this.enabled,
    required this.cloud,
    required this.document,
    required this.apply,
    required this.emptyDocument,
    required this.onChanged,
    required this.onStorageUnavailable,
  }) {
    if (enabled) cloud.addListener(_sessionChanged);
  }
  final bool enabled;
  final CloudApi cloud;
  final String Function() document;
  final void Function(String) apply;
  final String emptyDocument;
  final VoidCallback onChanged, onStorageUnavailable;
  bool ready = false, dirty = false, saving = false, applying = false;
  String? error;
  String? _key, _server, _email;
  int _generation = 0, _serial = 0, _revision = 0;
  bool _loading = false, _disposed = false;
  Future<void>? _initialized;
  Future<void> _queue = Future.value(), _localQueue = Future.value();
  static const _storage = MethodChannel('spendtracker/storage');
  void _emit() {
    if (!_disposed) onChanged();
  }

  Future<dynamic> _native(String method, [dynamic arguments]) async {
    try {
      return await _storage.invokeMethod<dynamic>(method, arguments);
    } on MissingPluginException {
      onStorageUnavailable();
    } on PlatformException {
      onStorageUnavailable();
    }
    return null;
  }

  Future<void> initializeDevice() => _initialized ??= () async {
    await _native('archiveLocalData');
    await _native('setActiveAccount');
  }();
  Map<String, dynamic> get _identity => {'server': _server, 'email': _email};
  bool _current(int generation) =>
      !_disposed && generation == _generation && cloud.signedIn;
  void _apply(String source) {
    applying = true;
    try {
      apply(source);
    } finally {
      applying = false;
    }
  }

  void _sessionChanged() {
    if (!cloud.signedIn) {
      if (_key != null) {
        _generation++;
        _key = null;
        ready = false;
        dirty = false;
        saving = false;
        _loading = false;
        error = null;
        _apply(emptyDocument);
        _native('setActiveAccount');
        _emit();
      }
      return;
    }
    final key = '${cloud.baseUrl}\n${cloud.email}';
    if (_key != key) {
      _generation++;
      _key = key;
      _server = cloud.baseUrl;
      _email = cloud.email;
      ready = false;
      dirty = false;
      saving = false;
      _loading = false;
      error = null;
      _apply(emptyDocument);
      _emit();
    }
    if (!ready && !_loading && cloud.latest != null) {
      _loading = true;
      _hydrate(_generation);
    }
  }

  Future<void> _hydrate(int generation) async {
    final remote = cloud.latest!;
    try {
      await initializeDevice();
      if (!_current(generation)) return;
      await _native('setActiveAccount', _identity);
      final cached = await _native('loadAccountData', _identity);
      if (!_current(generation)) return;
      Map<String, dynamic>? pending;
      if (cached is String) {
        try {
          final value = jsonDecode(cached);
          if (value is Map<String, dynamic> &&
              value['dirty'] == true &&
              value['revision'] is int &&
              value['data'] is String) {
            pending = value;
          }
        } on FormatException {
          pending = null;
        }
      }
      _revision = pending?['revision'] ?? remote.revision;
      dirty = pending != null;
      final remoteDocument = remote.data == null
          ? emptyDocument
          : jsonEncode(remote.data);
      try {
        _apply(pending?['data'] ?? remoteDocument);
      } on FormatException {
        if (pending == null) rethrow;
        _apply(remoteDocument);
        dirty = false;
        _revision = remote.revision;
      }
      ready = true;
      _loading = false;
      if (dirty && _revision != remote.revision) error = 'The server has newer data. Your unsaved changes are kept on this device. Review Cloud backup before replacing either copy.';
      _persist();
      _emit();
      if (dirty && error == null) _enqueue();
    } on FormatException {
      if (!_current(generation)) return;
      _loading = false;
      error = 'This account data could not be read. Your saved copy has not been changed.';
      _emit();
    }
  }

  Future<void> _persist() {
    final identity = Map<String, dynamic>.from(_identity);
    final payload = {
      ...identity,
      'data': document(),
      'revision': _revision,
      'dirty': dirty,
    };
    _localQueue = _localQueue.then((_) async {
      await _native('saveAccountData', payload);
    });
    return _localQueue;
  }

  void changed() {
    if (!enabled || applying || !ready || !cloud.signedIn) return;
    dirty = true;
    _serial++;
    _persist();
    _enqueue();
  }

  void _enqueue() {
    final generation = _generation, serial = _serial, snapshot = document();
    _queue = _queue.then((_) async {
      if (!_current(generation) || !ready || error != null) return;
      saving = true;
      _emit();
      try {
        await cloud.upload(snapshot, revision: _revision);
        if (!_current(generation)) return;
        _revision = cloud.latest!.revision;
        if (_serial == serial) dirty = false;
        await _persist();
      } on CloudApiException catch (failure) {
        if (!_current(generation)) return;
        error = failure.message;
        dirty = true;
        await _persist();
      } finally {
        if (_current(generation)) {
          saving = false;
          _emit();
        }
      }
    });
  }

  Future<void> retry() async {
    if (!ready || !cloud.signedIn) return;
    error = null;
    dirty = true;
    _serial++;
    _enqueue();
    await _queue;
  }

  Future<void> saveReviewed() async {
    final generation = _generation;
    await _queue;
    if (!_current(generation)) return;
    _revision = cloud.latest!.revision;
    await retry();
    if (error != null) throw CloudApiException(error!);
  }

  Future<void> reload() async {
    final generation = _generation;
    await _queue;
    if (!_current(generation)) return;
    final remote = await cloud.refresh();
    if (!_current(generation)) return;
    _apply(remote.data == null ? emptyDocument : jsonEncode(remote.data));
    _revision = remote.revision;
    dirty = false;
    error = null;
    _serial++;
    await _persist();
    _emit();
  }

  Future<void> flushLocal() => _localQueue;
  Future<void> flushServer() => _queue;
  void dispose() {
    _disposed = true;
    _generation++;
    if (enabled) cloud.removeListener(_sessionChanged);
  }
}
