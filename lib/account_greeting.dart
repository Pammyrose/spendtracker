import 'dart:async';

import 'package:flutter/material.dart';

import 'app_data.dart';

// Device-local hours: morning starts at 5 AM, afternoon at noon, evening at 6 PM.
String greetingFor(DateTime localTime) =>
    localTime.hour >= 5 && localTime.hour < 12
    ? 'Good Morning'
    : localTime.hour >= 12 && localTime.hour < 18
    ? 'Good Afternoon'
    : 'Good Evening';

class AccountGreeting extends StatefulWidget {
  const AccountGreeting({super.key, this.now});
  final DateTime Function()? now;
  @override
  State<AccountGreeting> createState() => _AccountGreetingState();
}

class _AccountGreetingState extends State<AccountGreeting>
    with WidgetsBindingObserver {
  Timer? _timer;
  late DateTime _now;
  DateTime _readTime() => widget.now?.call() ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _now = _readTime();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final untilNextMinute =
        const Duration(minutes: 1) -
        Duration(
          seconds: _now.second,
          milliseconds: _now.millisecond,
          microseconds: _now.microsecond,
        );
    _timer = Timer(untilNextMinute, _refresh);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _now = _readTime());
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = AppDataScope.of(context).cloud;
    return AnimatedBuilder(
      animation: cloud,
      builder: (context, _) => Text(
        '${greetingFor(_now)},\n${cloud.displayName}!',
        key: const Key('home-greeting'),
        style: const TextStyle(
          fontSize: 24,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
        ),
      ),
    );
  }
}
