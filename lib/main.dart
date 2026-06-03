import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'providers/app_provider.dart';
import 'widgets/expense_dialog.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'models/category_config.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await NotificationService.init();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppProvider _appProvider = AppProvider();
  late Future<void> _initFuture;
  bool _isAuthenticated = false;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _initFuture = _appProvider.init().then((_) {
      if (!_appProvider.isBiometricLockEnabled) {
        setState(() => _isAuthenticated = true);
      } else {
        _authenticate();
      }
    });
  }

  Future<void> _authenticate() async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to access SpendWise',
      );
      setState(() {
        _isAuthenticated = didAuthenticate;
      });
    } catch (e) {
      debugPrint('Biometric error: $e');
      setState(() => _isAuthenticated = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appProvider,
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: 'SpendWise',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.purple,
                primary: Colors.purple,
                brightness: Brightness.light,
              ),
              appBarTheme: const AppBarTheme(
                centerTitle: false,
                titleTextStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.purple,
                brightness: Brightness.dark,
              ),
            ),
            themeMode: provider.themeMode,
            home: FutureBuilder(
              future: _initFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (_isAuthenticated) {
                    return const HomeScreen();
                  } else {
                    return Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_outline, size: 64, color: Colors.purple),
                            const SizedBox(height: 16),
                            const Text(
                              'SpendWise is Locked',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _authenticate,
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Unlock with Biometrics'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                }
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet, size: 64, color: Colors.purple),
                        SizedBox(height: 16),
                        Text(
                          'SpendWise',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple),
                        ),
                        SizedBox(height: 16),
                        CircularProgressIndicator(),
                      ],
                    ),
                  ),
                );
              },
            ),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search...', border: InputBorder.none),
                onChanged: (val) => provider.setSearchQuery(val),
              )
            : const Text('SpendWise'),
        bottom: provider.isImporting 
          ? const PreferredSize(
              preferredSize: Size.fromHeight(4),
              child: LinearProgressIndicator(minHeight: 2),
            )
          : null,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (!_isSearching) {
                _searchController.clear();
                provider.setSearchQuery('');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // SMS Sync Invitation (if disabled)
          if (!provider.isSmsSyncEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.blue),
                title: const Text('Enable Auto-Tracking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Auto-detect spends from bank SMS messages.', style: TextStyle(fontSize: 11)),
                trailing: TextButton(
                  onPressed: () => provider.toggleSmsSync(true),
                  child: const Text('ENABLE'),
                ),
              ),
            ),
          ),

          // Balance Cards
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _BalanceCard(
                    label: 'Bank Balance',
                    sublabel: provider.hasBankBalance ? 'from bank SMS' : 'no SMS data yet',
                    amount: provider.bankBalance,
                    icon: Icons.account_balance,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BalanceCard(
                    label: 'This Month',
                    sublabel: 'Income - Expense',
                    amount: provider.monthlyCashFlow,
                    icon: Icons.trending_up,
                    color: provider.monthlyCashFlow >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          // Monthly Stats Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _StatChip(label: 'Income', amount: provider.currentMonthIncome, color: Colors.green),
                const SizedBox(width: 8),
                _StatChip(label: 'Expense', amount: provider.currentMonthSpending, color: Colors.red),
              ],
            ),
          ),

          // Budget Progress (if set)
          if (provider.monthlyBudget > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Monthly Budget', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(
                          '₹${provider.currentMonthSpending.toInt()} / ₹${provider.monthlyBudget.toInt()}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (provider.currentMonthSpending / provider.monthlyBudget).clamp(0.0, 1.0),
                        minHeight: 6,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          provider.currentMonthSpending > provider.monthlyBudget ? Colors.red : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Category Chips
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('All', provider),
                ...provider.categories.map((c) => _buildFilterChip(c.name, provider)),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Text(
                  'Recent Transactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Recent Transactions List
          Expanded(
            child: provider.expenses.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '💰 No transactions yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap + to add your first transaction',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.expenses.length,
                    itemBuilder: (context, index) {
                      final expense = provider.expenses[index];
                      final category = provider.categories.firstWhere(
                        (c) => c.name == expense.category,
                        orElse: () => kDefaultCategories.last,
                      );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: category.color.withValues(alpha: 0.1),
                            child: Icon(category.icon, color: category.color, size: 20),
                          ),
                          title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text("${DateFormat('d MMM yyyy').format(expense.date)} • ${expense.bankName}"),
                          trailing: Text(
                            '₹${expense.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: expense.type == 'income' ? Colors.green : null,
                            ),
                          ),
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => ExpenseDialog(expense: expense),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (_) => const ExpenseDialog()),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Stats'),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
          }
        },
      ),
    );
  }

  Widget _buildFilterChip(String name, AppProvider provider) {
    final isSelected = provider.filterCategory == name;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(name),
        selected: isSelected,
        onSelected: (val) => provider.setFilterCategory(name),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final double amount;
  final IconData icon;
  final Color color;

  const _BalanceCard({
    required this.label,
    required this.sublabel,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text(sublabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              '₹ ${amount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _StatChip({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(label == 'Income' ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
