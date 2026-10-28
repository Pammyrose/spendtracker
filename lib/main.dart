import 'package:flutter/material.dart';

import 'app_theme.dart';

import 'expenses_page.dart';
import 'bills_page.dart';
import 'welcome_screen.dart';
import 'income_page.dart';
import 'app_data.dart';
import 'entry_widgets.dart';
import 'more_pages.dart';
import 'notifications_inbox_page.dart';
import 'login_page.dart';
import 'cloud_api.dart';
import 'account_greeting.dart';
import 'account_sync_banner.dart';

void main() => runApp(const SpendTrackerApp());

class SpendTrackerApp extends StatefulWidget {
  const SpendTrackerApp({super.key, this.cloud, this.data});
  final CloudApi? cloud;
  final AppData? data;
  @override
  State<SpendTrackerApp> createState() => _SpendTrackerAppState();
}

class _SpendTrackerAppState extends State<SpendTrackerApp> {
  late final AppData _data;
  @override
  void initState() {
    super.initState();
    _data =
        widget.data ??
        AppData(seed: false, liveAccount: true, cloud: widget.cloud);
    _data.load();
  }

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDataScope(
    data: _data,
    child: Builder(
      builder: (context) {
        final data = AppDataScope.of(context);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SpendTracker',
          theme: ThemeData(
            brightness: data.palette.brightness,
            colorScheme: ColorScheme.fromSeed(
              brightness: data.palette.brightness,
              seedColor: data.accent,
              primary: data.accent,
              onPrimary: data.palette.onAccent,
              surface: data.palette.surface,
              onSurface: data.palette.ink,
              primaryContainer: data.palette.soft,
              onPrimaryContainer: data.palette.ink,
              outlineVariant: data.palette.border,
            ),
            extensions: [data.palette],
            scaffoldBackgroundColor: data.palette.background,
            canvasColor: data.palette.surface,
            dividerColor: data.palette.border,
            appBarTheme: AppBarTheme(
              backgroundColor: data.palette.background,
              surfaceTintColor: Colors.transparent,
              foregroundColor: data.palette.ink,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: data.palette.surface,
              surfaceTintColor: Colors.transparent,
            ),
            bottomSheetTheme: BottomSheetThemeData(
              backgroundColor: data.palette.surface,
              modalBackgroundColor: data.palette.surface,
              surfaceTintColor: Colors.transparent,
            ),
            popupMenuTheme: PopupMenuThemeData(
              color: data.palette.surface,
              surfaceTintColor: Colors.transparent,
            ),
            textTheme: ThemeData.light().textTheme.apply(
              bodyColor: data.palette.ink,
              displayColor: data.palette.ink,
            ),
          ),
          home: const WelcomeScreen(
            destination: AuthGate(destination: HomeScreen()),
          ),
        );
      },
    ),
  );
}

// Changing the selected tab or balance visibility rebuilds this screen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _tabs = ['Home', 'Expenses', 'Bills', 'Income', 'More'];
  int _selectedIndex = 0;
  bool _balanceVisible = true;
  BillsController get _bills => AppDataScope.of(context).bills;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AccountSyncBanner(),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                // Keep cards readable on wider displays too.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  // Keep expense entries and the selected month when changing tabs.
                  child: IndexedStack(
                    index: _selectedIndex == 1
                        ? 0
                        : _selectedIndex == 2
                        ? 1
                        : _selectedIndex == 3
                        ? 2
                        : _selectedIndex == 4
                        ? 3
                        : 4,
                    children: [
                      const ExpensesPage(),
                      BillsPage(controller: _bills),
                      const IncomePage(),
                      const MorePage(),
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: const AccountGreeting()),
                                IconButton(
                                  tooltip: 'Notifications',
                                  icon: const Icon(
                                    Icons.notifications_none_rounded,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const NotificationsInboxPage(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            // Scrolling prevents overflow on smaller phones.
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                              child: _selectedIndex == 0
                                  ? _buildDashboard()
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 32),
                                      child: Text(
                                        '${_tabs[_selectedIndex]} will appear here.',
                                        style: TextStyle(
                                          color: AppPalette.of(context).muted,
                                        ),
                                      ),
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
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppPalette.of(context).border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          // setState asks Flutter to rebuild with the new selected tab.
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppPalette.of(context).surface,
          elevation: 0,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: AppPalette.of(context).muted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description_rounded),
              label: 'Expenses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Bills',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_rounded),
              label: 'Income',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final data = AppDataScope.of(context);
    final now = DateTime.now();
    bool inMonth(DateTime date) =>
        date.year == now.year && date.month == now.month;
    final income = data.incomes
        .where((e) => inMonth(e.date))
        .fold(0.0, (sum, e) => sum + e.amount);
    final spent = data.expenses
        .where((e) => inMonth(e.date))
        .fold(0.0, (sum, e) => sum + e.amount);
    final previousMonth = DateTime(now.year, now.month - 1);
    bool inPreviousMonth(DateTime date) =>
        date.year == previousMonth.year && date.month == previousMonth.month;
    final previousIncome = data.incomes
        .where((e) => inPreviousMonth(e.date))
        .fold(0.0, (sum, e) => sum + e.amount);
    final previousSpent = data.expenses
        .where((e) => inPreviousMonth(e.date))
        .fold(0.0, (sum, e) => sum + e.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The gradient and rounded corners style the current balance card.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppPalette.of(context).heroStart,
                AppPalette.of(context).heroEnd,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Current Balance',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    tooltip: _balanceVisible ? 'Hide balance' : 'Show balance',
                    onPressed: () =>
                        setState(() => _balanceVisible = !_balanceVisible),
                    icon: Icon(
                      _balanceVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ],
              ),
              // Scale the amount down if the available width is very small.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _balanceVisible
                      ? formatMoney(context, income - spent)
                      : '${data.symbol} ••••••',
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Both Expanded widgets get an equal share of the row's width.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Total Income',
                amount: formatMoney(context, income),
                percentage: previousIncome == 0
                    ? '0%'
                    : '${((income - previousIncome).abs() / previousIncome * 100).round()}%',
                income: true,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _SummaryCard(
                title: 'Total Spent',
                amount: formatMoney(context, spent),
                percentage: previousSpent == 0
                    ? '0%'
                    : '${((spent - previousSpent).abs() / previousSpent * 100).round()}%',
                income: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BillsPreview(
          controller: _bills,
          onSeeAll: () => setState(() => _selectedIndex = 2),
        ),
      ],
    );
  }
}

// One reusable widget keeps both summary cards consistent.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.percentage,
    required this.income,
  });

  final String title;
  final String amount;
  final String percentage;
  final bool income;

  @override
  Widget build(BuildContext context) {
    final color = income
        ? const Color(0xFF20BF96)
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.of(context).surface,
        border: Border.all(color: AppPalette.of(context).border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: income
                    ? const Color(0xFFD9F8EF)
                    : AppPalette.of(context).soft,
                child: Icon(
                  income
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: color,
                  size: 23,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                percentage,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
