import 'package:flutter/material.dart';

import 'expenses_page.dart';
import 'bills_page.dart';
import 'welcome_screen.dart';

void main() => runApp(const SpendTrackerApp());

const _pink = Color(0xFFFF5C83);
const _ink = Color(0xFF151826);
const _muted = Color(0xFF788396);

class SpendTrackerApp extends StatelessWidget {
  const SpendTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SpendTracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _pink),
        scaffoldBackgroundColor: const Color(0xFFFCF8FA),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: _ink,
          displayColor: _ink,
        ),
      ),
      home: const WelcomeScreen(destination: HomeScreen()),
    );
  }
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
  final _bills = BillsController();

  @override
  void dispose() {
    _bills.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
                  : 2,
              children: [
                const ExpensesPage(),
                BillsPage(controller: _bills),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedIndex == 0
                                  ? 'Good Morning,\nPamela!'
                                  : _tabs[_selectedIndex],
                              style: const TextStyle(
                                fontSize: 24,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Notifications',
                            icon: const Icon(Icons.notifications_none_rounded),
                            onPressed: () {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('No notifications yet.'),
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
                                  style: const TextStyle(color: _muted),
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
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF0F0F4))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          // setState asks Flutter to rebuild with the new selected tab.
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: _pink,
          unselectedItemColor: const Color(0xFFA8B3C2),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The gradient and rounded corners style the current balance card.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFDCE5), Color(0xFFFFCFDB)],
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
                  _balanceVisible ? '\u20b1 12,500.00' : '\u20b1 ••••••',
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
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Total Income',
                amount: '\u20b1 30,000.00',
                percentage: '12%',
                income: true,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _SummaryCard(
                title: 'Total Spent',
                amount: '\u20b1 17,500.00',
                percentage: '8%',
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
    final color = income ? const Color(0xFF20BF96) : _pink;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
                    : const Color(0xFFFFDFE7),
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
