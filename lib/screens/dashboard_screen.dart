import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/app_provider.dart';
import '../models/category_config.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _generatePdfReport(BuildContext context, AppProvider provider) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SpendWise Monthly Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(monthName),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Actual Balance: ₹ ${provider.hasBankBalance ? provider.bankBalance.toStringAsFixed(2) : provider.bankBalance.toStringAsFixed(2)}',
                    ),
                    pw.Text(
                      'Total Budget: ₹ ${provider.monthlyBudget.toStringAsFixed(2)}',
                    ),
                    pw.Text(
                      'Total Spent: ₹ ${provider.currentMonthSpending.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Expense Breakdown by Category', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            provider.categorySpending.isEmpty
                ? pw.Text('No expenses recorded for this period.')
                : pw.TableHelper.fromTextArray(
                    headers: ['Category', 'Amount (₹)'],
                    data: provider.categorySpending.entries
                        .map((e) => [e.key, e.value.toStringAsFixed(2)])
                        .toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    cellAlignment: pw.Alignment.centerLeft,
                  ),
            pw.SizedBox(height: 20),
            pw.Text('Recent Transactions', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Title', 'Bank', 'Category', 'Amount (₹)'],
              data: provider.allExpenses.reversed.take(50).map((e) {
                return [
                  DateFormat('yyyy-MM-dd').format(e.date),
                  e.title,
                  e.bankName,
                  e.category,
                  e.amount.toStringAsFixed(2),
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final categorySpending = provider.categorySpending;
    final total = provider.totalSpending;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _generatePdfReport(context, provider),
            tooltip: 'Generate PDF Report',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(context, total, provider),
            const SizedBox(height: 32),
            Text(
              'Spending Distribution (Bar)',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 220,
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(theme),
              child: const _SpendingBarChart(),
            ),
            const SizedBox(height: 32),
            Text(
              'Spending Distribution (Pie)',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(theme),
              child: const _SpendingPieChart(),
            ),
            const SizedBox(height: 32),
            Text(
              'Category Budgets',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...provider.categories.where((c) => c.budget != null).map((cat) {
              final spent = categorySpending[cat.name] ?? 0.0;
              final progress = (spent / cat.budget!).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(theme),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(cat.icon, size: 20, color: cat.color),
                            const SizedBox(width: 12),
                            Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text('₹${spent.toStringAsFixed(0)} / ₹${cat.budget!.toStringAsFixed(0)}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          spent > cat.budget! ? Colors.redAccent : cat.color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),
            Text(
              'Statistics',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatList(provider),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, double total, AppProvider provider) {
    // Show real bank balance if available, otherwise net calculation
    final displayBalance = provider.hasBankBalance ? provider.bankBalance : provider.netBalance;
    final balanceLabel = provider.hasBankBalance ? 'Bank Balance' : 'Net Balance';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade700, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(balanceLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            '₹ ${displayBalance.toStringAsFixed(2)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Monthly Income',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('₹ ${provider.currentMonthIncome.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Monthly Expense',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('₹ ${provider.currentMonthSpending.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatList(AppProvider provider) {
    if (provider.expenses.isEmpty) return const Center(child: Text('No data recorded yet.'));

    final dailyAvg = provider.currentMonthSpending / (DateTime.now().day);

    final dayMap = <int, double>{};
    for (var e in provider.expenses) {
      if (e.date.month == DateTime.now().month) {
        dayMap[e.date.day] = (dayMap[e.date.day] ?? 0) + e.amount;
      }
    }
    int topDay = 0;
    double maxSpent = 0;
    dayMap.forEach((day, amt) {
      if (amt > maxSpent) {
        maxSpent = amt;
        topDay = day;
      }
    });

    return Column(
      children: [
        _buildStatTile(Icons.trending_up, 'Daily Avg (This Month)', '₹ ${dailyAvg.toStringAsFixed(2)}', Colors.green),
        const SizedBox(height: 12),
        _buildStatTile(Icons.calendar_month, 'Peak Day (This Month)', topDay == 0 ? 'N/A' : 'Day $topDay (₹ ${maxSpent.toStringAsFixed(0)})', Colors.orange),
      ],
    );
  }

  Widget _buildStatTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _SpendingBarChart extends StatelessWidget {
  const _SpendingBarChart();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final spending = provider.categorySpending;
    final categories = spending.keys.toList();

    if (categories.isEmpty) return const Center(child: Text('Add data to view chart'));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueGrey.withValues(alpha: 0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${categories[group.x]}\n₹${rod.toY.toStringAsFixed(0)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        maxY: spending.values.fold(0.0, (m, v) => v > m ? v : m) * 1.3,
        barGroups: List.generate(categories.length, (i) {
          final catName = categories[i];
          final color = provider.categories.firstWhere((c) => c.name == catName, orElse: () => kDefaultCategories.last).color;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: spending[catName]!,
                color: color,
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= categories.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    categories[index].substring(0, 3),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _SpendingPieChart extends StatelessWidget {
  const _SpendingPieChart();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final spending = provider.categorySpending;
    final categories = spending.keys.toList();

    if (categories.isEmpty) return const Center(child: Text('Add data to view chart'));

    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 0,
        sections: List.generate(categories.length, (i) {
          final catName = categories[i];
          final color = provider.categories.firstWhere((c) => c.name == catName, orElse: () => kDefaultCategories.last).color;
          final value = spending[catName]!;
          final percentage = (value / provider.totalSpending * 100).toStringAsFixed(1);

          return PieChartSectionData(
            color: color,
            value: value,
            title: '$percentage%',
            radius: 110,
            titleStyle: const TextStyle(
              fontSize: 12 ,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
            ),
          );
        }),
      ),
    );
  }
}
