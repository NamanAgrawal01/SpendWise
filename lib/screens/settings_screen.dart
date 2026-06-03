import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _exportToCSV(BuildContext context, AppProvider provider) async {
    String csv = 'Title,Amount,Category,Date,Notes,Type,Reference\n';
    for (var e in provider.allExpenses) {
      csv += '${e.title},${e.amount},${e.category},${DateFormat('yyyy-MM-dd').format(e.date)},"${e.notes}",${e.type},${e.reference}\n';
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/spendwise_expenses.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'SpendWise Export',
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Budgeting'),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Set Monthly Budget'),
            subtitle: Text('Current: ₹ ${provider.monthlyBudget.toStringAsFixed(0)}'),
            onTap: () => _showBudgetDialog(context, provider),
          ),
          const Divider(),
          _buildSectionHeader('Preference'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            value: provider.themeMode == ThemeMode.dark,
            onChanged: (val) => provider.toggleTheme(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint_outlined),
            title: const Text('Biometric Lock'),
            subtitle: const Text('Secure your data with Fingerprint/Face ID'),
            value: provider.isBiometricLockEnabled,
            onChanged: (val) => provider.toggleBiometricLock(val),
          ),
          const Divider(),
          _buildSectionHeader('Data Management'),
          SwitchListTile(
            secondary: const Icon(Icons.sms_outlined),
            title: const Text('Auto-Detect Bank SMS'),
            subtitle: const Text('Automatically sync spends and bank balance'),
            value: provider.isSmsSyncEnabled,
            onChanged: (val) => provider.toggleSmsSync(val),
          ),
          ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: const Text('Sync with Cloud (Firestore)'),
            subtitle: const Text('Manual cloud reconciliation'),
            onTap: () async {
               await provider.syncWithCloud();
               if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud sync complete')));
               }
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Export Data (CSV)'),
            onTap: () => _exportToCSV(context, provider),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Clear Data', style: TextStyle(color: Colors.red)),
            onTap: () => _showClearDialog(context, provider),
          ),
          const Divider(),
          _buildSectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About SpendWise'),
            subtitle: const Text('v 1.0.0'),
            onTap: () => _showAboutDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => _showPrivacyPolicy(context),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('License'),
            subtitle: const Text('MIT License'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'SpendWise',
              applicationVersion: '1.0.0',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importSms(BuildContext context, AppProvider provider) async {
    try {
      final count = await provider.syncWithSms();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0
                ? 'Imported $count new transactions'
                : 'No new transactions found in SMS'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing SMS: $e')),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('SpendWise'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Developed by Naman Agrawal', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('Track your expenses easily and manage your finances efficiently.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'SpendWise stores all expense data locally on your device. '
            'No personal data is collected, shared, or transmitted. '
            'Your financial privacy is our priority.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.purple,
        ),
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, AppProvider provider) {
    final controller = TextEditingController(text: provider.monthlyBudget.toStringAsFixed(0) == '0' ? '' : provider.monthlyBudget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Enter budget amount',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              provider.setMonthlyBudget(double.tryParse(controller.text) ?? 0.0);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text('This will delete all your expenses. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await provider.clearAllData();
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
