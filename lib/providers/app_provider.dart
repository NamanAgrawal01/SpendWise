import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/expense.dart';
import '../models/category_config.dart';
import '../services/firestore_service.dart';
import '../services/sms_parser.dart';
import '../services/sms_service.dart';
import '../services/notification_service.dart';

class AppProvider with ChangeNotifier {
  static const String _expenseBoxName = 'expenses';
  static const String _settingsBoxName = 'settings';

  late Box _expenseBox;
  late Box _settingsBox;
  final FirestoreService _firestoreService = FirestoreService();
  final SmsService _smsService = SmsService();

  List<Expense> _expenses = [];
  List<CategoryConfig> _categories = kDefaultCategories;
  ThemeMode _themeMode = ThemeMode.system;
  double _monthlyBudget = 0.0;
  bool _isBiometricLockEnabled = false;
  bool _isImporting = false;
  bool _isSmsSyncEnabled = false;

  // Bank Balance Persistence
  double _bankBalance = 0.0;
  DateTime? _bankBalanceUpdatedAt;

  String _searchQuery = '';
  String _filterCategory = 'All';
  String? _userId;

  List<Expense> get expenses {
    List<Expense> filtered = _expenses;
    if (_searchQuery.isNotEmpty || _filterCategory != 'All') {
      filtered = _expenses.where((e) {
        final matchesSearch = e.title.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesCategory = _filterCategory == 'All' || e.category == _filterCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    }
    return filtered..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Expense> get allExpenses => _expenses;
  List<CategoryConfig> get categories => _categories;
  ThemeMode get themeMode => _themeMode;
  double get monthlyBudget => _monthlyBudget;
  bool get isBiometricLockEnabled => _isBiometricLockEnabled;
  bool get isImporting => _isImporting;
  bool get isSmsSyncEnabled => _isSmsSyncEnabled;
  String get searchQuery => _searchQuery;
  String get filterCategory => _filterCategory;
  
  // Bank Balance Getters
  double get bankBalance => _bankBalance;
  DateTime? get bankBalanceUpdatedAt => _bankBalanceUpdatedAt;
  bool get hasBankBalance => _bankBalanceUpdatedAt != null;

  // SMART FALLBACK BALANCE
  double get displayBalance {
    if (hasBankBalance) return _bankBalance;
    return netBalance;
  }

  void setImporting(bool value) {
    _isImporting = value;
    notifyListeners();
  }

  Future<void> init() async {
    try {
      await Hive.initFlutter();

      _expenseBox = await Hive.openBox(_expenseBoxName);
      _settingsBox = await Hive.openBox(_settingsBoxName);

      // Initialize or load User ID
      _userId = _settingsBox.get('userId');
      if (_userId == null) {
        _userId = const Uuid().v4();
        await _settingsBox.put('userId', _userId);
      }

      // Load expenses
      _expenses = _expenseBox.values
          .map((e) => Expense.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      final themeIndex = _settingsBox.get('themeMode', defaultValue: 0);
      _themeMode = themeIndex < ThemeMode.values.length
          ? ThemeMode.values[themeIndex]
          : ThemeMode.system;
      
      _monthlyBudget = _settingsBox.get('monthlyBudget', defaultValue: 0.0);
      _isBiometricLockEnabled = _settingsBox.get('biometricLock', defaultValue: false);
      _isSmsSyncEnabled = _settingsBox.get('isSmsSyncEnabled', defaultValue: false);
      
      _bankBalance = _settingsBox.get('bankBalance', defaultValue: 0.0);
      final updatedAtString = _settingsBox.get('bankBalanceUpdatedAt');
      if (updatedAtString != null) {
        _bankBalanceUpdatedAt = DateTime.tryParse(updatedAtString);
      }

      final savedCategories = _settingsBox.get('categories');
      if (savedCategories != null) {
        _categories = (savedCategories as List)
            .map((c) => CategoryConfig.fromMap(Map<String, dynamic>.from(c)))
            .toList();
      }

      await _processRecurringExpenses();
      
      // FULL CLOUD RECONCILIATION ON START
      if (_userId != null) {
        await syncWithCloud();
      }
      
      // AUTO-SYNC SMS ONLY IF ENABLED
      if (_isSmsSyncEnabled) {
        syncWithSms();
      }
      
      await detectRecurringPatterns();

    } catch (e) {
      debugPrint('Error initializing AppProvider: $e');
    }
    notifyListeners();
  }

  Future<void> toggleSmsSync(bool enabled) async {
    if (enabled) {
      final status = await Permission.sms.request();
      if (!status.isGranted) return;
    }
    
    _isSmsSyncEnabled = enabled;
    await _settingsBox.put('isSmsSyncEnabled', enabled);
    _syncSettings();
    
    if (enabled) {
      syncWithSms();
    }
    notifyListeners();
  }

  Future<void> syncWithCloud() async {
    if (_userId == null) return;
    
    try {
      final cloudExpenses = await _firestoreService.fetchExpenses(_userId!);
      
      bool updated = false;

      // 1. Cloud -> Local (Restore missing transactions)
      for (var cloudExp in cloudExpenses) {
        bool exists = _expenses.any((local) => local.id == cloudExp.id);
        if (!exists) {
          await _expenseBox.put(cloudExp.id, cloudExp.toMap());
          _expenses.add(cloudExp);
          updated = true;
        }
      }

      // 2. Local -> Cloud (Back up offline transactions)
      for (var localExp in _expenses) {
        bool inCloud = cloudExpenses.any((cloud) => cloud.id == localExp.id);
        if (!inCloud) {
          await _firestoreService.addExpense(_userId!, localExp);
        }
      }

      await _syncSettingsFromCloud();
      if (updated) notifyListeners();
    } catch (e) {
      debugPrint("Cloud Sync Error: $e");
    }
  }

  Future<void> _syncSettingsFromCloud() async {
    if (_userId == null) return;
    try {
      final settings = await _firestoreService.fetchSettings(_userId!);
      if (settings != null) {
        bool changed = false;
        if (settings['themeMode'] != null) {
          _themeMode = ThemeMode.values[settings['themeMode']];
          await _settingsBox.put('themeMode', _themeMode.index);
          changed = true;
        }
        if (settings['monthlyBudget'] != null) {
          _monthlyBudget = (settings['monthlyBudget'] as num).toDouble();
          await _settingsBox.put('monthlyBudget', _monthlyBudget);
          changed = true;
        }
        if (settings['biometricLock'] != null) {
          _isBiometricLockEnabled = settings['biometricLock'];
          await _settingsBox.put('biometricLock', _isBiometricLockEnabled);
          changed = true;
        }
        if (settings['isSmsSyncEnabled'] != null) {
          _isSmsSyncEnabled = settings['isSmsSyncEnabled'];
          await _settingsBox.put('isSmsSyncEnabled', _isSmsSyncEnabled);
          changed = true;
        }
        if (settings['categories'] != null) {
          _categories = (settings['categories'] as List)
              .map((c) => CategoryConfig.fromMap(Map<String, dynamic>.from(c)))
              .toList();
          await _settingsBox.put('categories', settings['categories']);
          changed = true;
        }
        if (changed) notifyListeners();
      }
    } catch (e) {
      debugPrint("Settings Cloud Sync Error: $e");
    }
  }

  Future<int> syncWithSms() async {
    if (_isImporting || !_isSmsSyncEnabled) return 0;
    _isImporting = true;
    notifyListeners();

    final count = await _performSync();
    await detectRecurringPatterns();

    _isImporting = false;
    notifyListeners();
    return count;
  }

  Future<int> _performSync() async {
    try {
      final messages = await _smsService.getMessages();
      if (messages.isEmpty) return 0;

      int count = 0;
      
      final sortedMessages = List<SmsMessage>.from(messages)
        ..sort((a, b) => (a.dateSent ?? DateTime(0)).compareTo(b.dateSent ?? DateTime(0)));

      for (final sms in sortedMessages) {
        final body = sms.body;
        if (body == null) continue;
        final parsed = SmsParser.parse(body);
        if (parsed == null) continue;

        final transactionDate = sms.dateSent ?? DateTime.now();
        final normalizedBody = body.trim();

        if (parsed.bankBalance != null) {
          await updateBankBalanceIfNewer(parsed.bankBalance!, transactionDate);
        }

        if (parsed.isTransaction && !isDuplicateSms(normalizedBody, transactionDate, parsed.reference, parsed.amount)) {
          final newExp = Expense(
            title: parsed.title,
            amount: parsed.amount,
            category: parsed.category,
            date: transactionDate,
            notes: body,
            type: parsed.type,
            bankName: parsed.bankName,
            reference: parsed.reference,
          );
          
          await _expenseBox.put(newExp.id, newExp.toMap());
          _expenses.add(newExp);
          if (_userId != null) {
            await _firestoreService.addExpense(_userId!, newExp);
          }
          count++;
        }
      }
      return count;
    } catch (e) {
      debugPrint("Sync Error: $e");
      return 0;
    }
  }

  static Future<void> syncSmsSilently() async {
    try {
      await Hive.initFlutter();
      final settingsBox = await Hive.openBox(_settingsBoxName);
      
      final isEnabled = settingsBox.get('isSmsSyncEnabled', defaultValue: false);
      if (!isEnabled) return;

      final expenseBox = await Hive.openBox(_expenseBoxName);
      final smsService = SmsService();
      final messages = await smsService.getMessages();
      if (messages.isEmpty) return;

      final existingExpenses = expenseBox.values
          .map((e) => Expense.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      bool isDup(String body, DateTime date, String ref, double amt, List<Expense> list) {
        return list.any((e) => 
          (ref.isNotEmpty && e.reference == ref) || 
          e.notes.trim() == body.trim() ||
          ( (e.amount - amt).abs() < 0.01 && date.difference(e.date).inMinutes.abs() <= 3 )
        );
      }

      final sortedMessages = List<SmsMessage>.from(messages)
        ..sort((a, b) => (a.dateSent ?? DateTime(0)).compareTo(b.dateSent ?? DateTime(0)));

      final firestoreService = FirestoreService();
      final userId = settingsBox.get('userId');

      for (final sms in sortedMessages) {
        final body = sms.body;
        if (body == null) continue;
        final parsed = SmsParser.parse(body);
        if (parsed == null) continue;
        final date = sms.dateSent ?? DateTime.now();

        if (parsed.bankBalance != null) {
          final currentTs = DateTime.tryParse(settingsBox.get('bankBalanceUpdatedAt') ?? '');
          if (currentTs == null || date.isAfter(currentTs)) {
             await settingsBox.put('bankBalance', parsed.bankBalance);
             await settingsBox.put('bankBalanceUpdatedAt', date.toIso8601String());
             if (userId != null) {
               await firestoreService.updateSettings(userId, {
                 'bankBalance': parsed.bankBalance,
                 'bankBalanceUpdatedAt': date.toIso8601String(),
               });
             }
          }
        }

        if (parsed.isTransaction && !isDup(body, date, parsed.reference, parsed.amount, existingExpenses)) {
          final newExp = Expense(
            title: parsed.title,
            amount: parsed.amount,
            category: parsed.category,
            date: date,
            notes: body,
            type: parsed.type,
            bankName: parsed.bankName,
            reference: parsed.reference,
          );
          await expenseBox.put(newExp.id, newExp.toMap());
          existingExpenses.add(newExp);
          if (userId != null) {
            await firestoreService.addExpense(userId, newExp);
          }
          await NotificationService.showTransactionAlert(newExp.title, newExp.amount, newExp.type);
        }
      }
    } catch (e) {
      debugPrint("Background Sync Error: $e");
    }
  }

  Future<void> _processRecurringExpenses() async {
    final now = DateTime.now();
    List<Expense> newRecurringOnes = [];

    for (var e in _expenses) {
      if (!e.isRecurring || e.frequency == 'None') continue;

      DateTime nextDate = e.date;
      int safety = 0;
      while (safety < 1000) {
        safety++;
        DateTime previousDate = nextDate;

        if (e.frequency == 'Weekly') {
          nextDate = nextDate.add(const Duration(days: 7));
        } else if (e.frequency == 'Monthly') {
          nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
        } else {
          break;
        }

        if (nextDate.isBefore(previousDate) || nextDate.isAtSameMomentAs(previousDate)) break;
        if (nextDate.isAfter(now)) break;

        bool alreadyAdded = _expenses.any((ex) =>
            ex.title == e.title &&
            ex.amount == e.amount &&
            ex.date.year == nextDate.year &&
            ex.date.month == nextDate.month &&
            ex.date.day == nextDate.day);

        if (!alreadyAdded) {
          final newExp = Expense(
            title: e.title,
            amount: e.amount,
            category: e.category,
            date: nextDate,
            notes: e.notes,
            isRecurring: true,
            frequency: e.frequency,
            type: e.type,
            bankName: e.bankName,
            reference: e.reference,
          );
          newRecurringOnes.add(newExp);
        }
      }
    }

    if (newRecurringOnes.isNotEmpty) {
      for (var exp in newRecurringOnes) {
        await _expenseBox.put(exp.id, exp.toMap());
        _expenses.add(exp);
        if (_userId != null) {
          await _firestoreService.addExpense(_userId!, exp);
        }
      }
    }
  }

  Future<void> updateBankBalanceIfNewer(double balance, DateTime smsTime) async {
    if (_bankBalanceUpdatedAt == null || smsTime.isAfter(_bankBalanceUpdatedAt!)) {
      _bankBalance = balance;
      _bankBalanceUpdatedAt = smsTime;
      await _settingsBox.put('bankBalance', _bankBalance);
      await _settingsBox.put('bankBalanceUpdatedAt', _bankBalanceUpdatedAt?.toIso8601String());
      _syncSettings();
      notifyListeners();
    }
  }

  Future<void> addExpense(Expense expense) async {
    await _expenseBox.put(expense.id, expense.toMap());
    _expenses.add(expense);
    if (_userId != null) {
      await _firestoreService.addExpense(_userId!, expense);
    }
    notifyListeners();
  }

  Future<void> updateExpenseByRef(Expense oldExp, Expense newExp) async {
    await _expenseBox.put(newExp.id, newExp.toMap());
    final index = _expenses.indexWhere((e) => e.id == oldExp.id);
    if (index != -1) {
      _expenses[index] = newExp;
    } else {
      _expenses.add(newExp);
    }
    if (_userId != null) {
      await _firestoreService.updateExpense(_userId!, newExp);
    }
    notifyListeners();
  }

  Future<void> deleteExpenseByRef(Expense expense) async {
    await _expenseBox.delete(expense.id);
    _expenses.removeWhere((e) => e.id == expense.id);
    if (_userId != null) {
      await _firestoreService.deleteExpense(_userId!, expense.id);
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _settingsBox.put('themeMode', _themeMode.index);
    _syncSettings();
    notifyListeners();
  }

  Future<void> setMonthlyBudget(double budget) async {
    _monthlyBudget = budget;
    await _settingsBox.put('monthlyBudget', budget);
    _syncSettings();
    notifyListeners();
  }

  Future<void> toggleBiometricLock(bool enabled) async {
    _isBiometricLockEnabled = enabled;
    await _settingsBox.put('biometricLock', enabled);
    _syncSettings();
    notifyListeners();
  }

  Future<void> addCategory(CategoryConfig category) async {
    _categories.add(category);
    await _settingsBox.put('categories', _categories.map((c) => c.toMap()).toList());
    _syncSettings();
    notifyListeners();
  }

  Future<void> updateCategory(int index, CategoryConfig category) async {
    _categories[index] = category;
    await _settingsBox.put('categories', _categories.map((c) => c.toMap()).toList());
    _syncSettings();
    notifyListeners();
  }

  void _syncSettings() {
    if (_userId != null) {
      _firestoreService.updateSettings(_userId!, {
        'themeMode': _themeMode.index,
        'monthlyBudget': _monthlyBudget,
        'biometricLock': _isBiometricLockEnabled,
        'isSmsSyncEnabled': _isSmsSyncEnabled,
        'categories': _categories.map((c) => c.toMap()).toList(),
        'bankBalance': _bankBalance,
        'bankBalanceUpdatedAt': _bankBalanceUpdatedAt?.toIso8601String(),
      });
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterCategory(String category) {
    _filterCategory = category;
    notifyListeners();
  }

  Future<void> clearAllData() async {
    await _expenseBox.clear();
    _expenses.clear();
    await _settingsBox.clear();
    _categories = List.from(kDefaultCategories);
    _monthlyBudget = 0.0;
    _themeMode = ThemeMode.system;
    _bankBalance = 0.0;
    _bankBalanceUpdatedAt = null;
    _isSmsSyncEnabled = false;
    if (_userId != null) {
      await _firestoreService.clearAllData(_userId!);
    }
    notifyListeners();
  }

  bool isDuplicateSms(String smsBody, DateTime smsDate, String reference, double amount) {
    final normalized = smsBody.trim();
    return _expenses.any((e) {
      if (reference.isNotEmpty && e.reference.isNotEmpty) {
        if (e.reference == reference) return true;
      }
      if (e.notes.trim() == normalized) return true;
      final isSameAmount = (e.amount - amount).abs() < 0.01;
      final timeDiff = e.date.difference(smsDate).inMinutes.abs();
      if (isSameAmount && timeDiff <= 3) return true;
      return false;
    });
  }

  // Statistics Getters
  double get totalSpending => _expenses.where((e) => e.type == 'expense').fold(0.0, (sum, e) => sum + e.amount);
  double get totalIncome => _expenses.where((e) => e.type == 'income').fold(0.0, (sum, e) => sum + e.amount);
  double get netBalance => totalIncome - totalSpending;
  double get currentMonthSpending {
    final now = DateTime.now();
    return _expenses.where((e) => e.type == 'expense' && e.date.year == now.year && e.date.month == now.month).fold(0.0, (sum, e) => sum + e.amount);
  }
  double get currentMonthIncome {
    final now = DateTime.now();
    return _expenses.where((e) => e.type == 'income' && e.date.year == now.year && e.date.month == now.month).fold(0.0, (sum, e) => sum + e.amount);
  }
  double get monthlyCashFlow => currentMonthIncome - currentMonthSpending;

  Map<String, double> get categorySpending {
    final map = <String, double>{};
    for (var e in _expenses) {
      if (e.type == 'expense') {
        map[e.category] = (map[e.category] ?? 0) + e.amount;
      }
    }
    return map;
  }

  Future<void> detectRecurringPatterns() async {
    if (_expenses.length < 5) return;
    final Map<String, List<Expense>> merchantGroups = {};
    for (var e in _expenses) {
      if (e.type == 'expense' && e.title != 'Bank Debit') {
        merchantGroups.putIfAbsent(e.title, () => []).add(e);
      }
    }
    for (var merchant in merchantGroups.keys) {
      final history = merchantGroups[merchant]!..sort((a, b) => a.date.compareTo(b.date));
      if (history.length < 2) continue;
      bool isMonthly = true;
      for (int i = 1; i < history.length; i++) {
        final diff = history[i].date.difference(history[i-1].date).inDays;
        if (diff < 25 || diff > 35) {
          isMonthly = false;
          break;
        }
      }
      if (isMonthly) {
        for (var e in history) {
          if (!e.isRecurring) {
             final updated = Expense(id: e.id, title: e.title, amount: e.amount, category: 'Subscription', date: e.date, notes: e.notes, isRecurring: true, frequency: 'Monthly', type: e.type, bankName: e.bankName, reference: e.reference);
             await updateExpenseByRef(e, updated);
          }
        }
      }
    }
  }
}
