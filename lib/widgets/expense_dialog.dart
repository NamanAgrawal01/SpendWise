import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../providers/app_provider.dart';
import 'package:flutter/services.dart';

class ExpenseDialog extends StatefulWidget {
  final Expense? expense;

  const ExpenseDialog({super.key, this.expense});

  @override
  State<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late String _selectedCategory;
  late DateTime _selectedDate;
  late bool _isRecurring;
  late String _frequency;
  late String _type;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense?.title ?? '');
    _amountController = TextEditingController(text: widget.expense?.amount.toStringAsFixed(0) == '0' ? '' : widget.expense?.amount.toStringAsFixed(0) ?? '');
    _notesController = TextEditingController(text: widget.expense?.notes ?? '');
    final provider = Provider.of<AppProvider>(
      context,
      listen: false,
    );

    final categoryNames =
    provider.categories.map((c) => c.name).toList();

    _selectedCategory =
    categoryNames.contains(widget.expense?.category)
        ? widget.expense!.category
        : categoryNames.first;
    _selectedDate = widget.expense?.date ?? DateTime.now();
    _isRecurring = widget.expense?.isRecurring ?? false;
    _frequency = widget.expense?.frequency ?? 'None';
    _type = widget.expense?.type ?? 'expense';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.expense == null ? 'Add Transaction' : 'Edit Transaction',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Expense'),
                      selected: _type == 'expense',
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _type = 'expense';
                          });
                        }
                      },
                      selectedColor: Colors.purple.shade100,
                      labelStyle: TextStyle(
                        color: _type == 'expense' ? Colors.purple : null,
                        fontWeight: _type == 'expense' ? FontWeight.bold : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('Income'),
                      selected: _type == 'income',
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _type = 'income';
                          });
                        }
                      },
                      selectedColor: Colors.green.shade100,
                      labelStyle: TextStyle(
                        color: _type == 'income' ? Colors.green : null,
                        fontWeight: _type == 'income' ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    prefixIcon: const Icon(Icons.edit_note_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (value) => value!.isEmpty ? 'Enter a title' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) => double.tryParse(value!) == null ? 'Enter a valid amount' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: provider.categories.map((c) {
                    return DropdownMenuItem(
                      value: c.name,
                      child: Row(
                        children: [
                          Icon(c.icon, size: 18, color: c.color),
                          const SizedBox(width: 8),
                          Text(c.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: Colors.grey),
                        const SizedBox(width: 12),
                        Text(
                          'Date: ${DateFormat('d MMM yyyy').format(_selectedDate)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Recurring'),
                  value: _isRecurring,
                  activeTrackColor: Colors.purple.withValues(alpha: 0.5),
                  activeColor: Colors.purple,
                  onChanged: (val) => setState(() {
                    _isRecurring = val;
                    if (!_isRecurring) {
                      _frequency = 'None';
                    } else if (_frequency == 'None') {
                      _frequency = 'Weekly';
                    }
                  }),
                ),
                if (_isRecurring)
                  DropdownButtonFormField<String>(
                    initialValue: _frequency,
                    items: ['Weekly', 'Monthly'].map((f) {
                      return DropdownMenuItem(value: f, child: Text(f));
                    }).toList(),
                    onChanged: (val) => setState(() => _frequency = val!),
                    decoration: InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    prefixIcon: const Icon(Icons.notes),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (widget.expense != null)
                      IconButton(
                        onPressed: () {
                          provider.deleteExpenseByRef(widget.expense!);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final amount = double.tryParse(_amountController.text);
                          if (amount == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid amount')),
                            );
                            return;
                          }

                          final newExpense = Expense(
                            title: _titleController.text,
                            amount: amount,
                            category: _selectedCategory,
                            date: _selectedDate,
                            notes: _notesController.text,
                            isRecurring: _isRecurring,
                            frequency: _frequency,
                            type: _type,
                          );

                          if (widget.expense == null) {
                            provider.addExpense(newExpense);
                          } else {
                            provider.updateExpenseByRef(widget.expense!, newExpense);
                          }
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
