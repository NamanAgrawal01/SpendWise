class ParsedSms {
  final String title;
  final double amount;
  final String category;
  final String type;
  final String reference;
  final double? bankBalance;
  final bool isTransaction;
  final String bankName;

  ParsedSms({
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    this.reference = '',
    this.bankBalance,
    this.isTransaction = true,
    this.bankName = 'Unknown Bank',
  });
}

class SmsParser {
  static const Map<String, String> _merchantToCategory = {
    'swiggy': 'Food',
    'zomato': 'Food',
    'uber': 'Travel',
    'ola': 'Travel',
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'airtel': 'Bills',
    'jio': 'Bills',
    'vi ': 'Bills',
    'petrol': 'Petrol',
    'shell': 'Petrol',
    'hpcl': 'Petrol',
    'bpcl': 'Petrol',
    'apollo': 'Medical',
    'pharmacy': 'Medical',
    'hospital': 'Medical',
    'reliance digital': 'Shopping',
    'tata play': 'Bills',
    'electricity': 'Bills',
    'water': 'Bills',
    'insurance': 'Bills',
    'lic': 'Bills',
  };

  static ParsedSms? parse(String body) {
    final text = body.toLowerCase();

    // 1. Filter out promotional/spam
    final blockedWords = [
      'offer', 'sponsored', 'loan', 'credit card', 'pre-approved', 
      'recharge', 'validity', 'data pack', 'sale', 'discount', 
      'reward', 'coupon', 'promo', 'advertisement', 'otp', 
      'verification code', 'amazon pay later', 'personal loan',
      'cashback', 'win', 'chance', 'congratulations', 'limited time',
      'gift', 'voucher', 'invite', 'referral', 'earn', 'points',
    ];

    for (final word in blockedWords) {
      if (text.contains(word)) {
        return null;
      }
    }
    
    // Detect Bank
    String bankName = 'Unknown Bank';
    if (text.contains('sbi')) {
      bankName = 'SBI';
    } else if (text.contains('hdfc')) {
      bankName = 'HDFC';
    } else if (text.contains('icici')) {
      bankName = 'ICICI';
    } else if (text.contains('axis')) {
      bankName = 'AXIS';
    } else if (text.contains('kotak')) {
      bankName = 'KOTAK';
    } else if (text.contains('paytm')) {
      bankName = 'Paytm';
    } else if (text.contains('airtel pb')) {
      bankName = 'Airtel Bank';
    }

    // Extract Reference Number (UPI Ref, Txn ID, etc.)
    final refMatch = RegExp(
      r'(?:upi ref no|ref no|txn id|id|reference|ref|txn)[:#]?\s*([a-zA-Z0-9]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final reference = refMatch?.group(1) ?? '';

    // Check for balance
    final double? extractedBalance = extractAvailableBalance(body);

    final isDebit = text.contains('debited') || text.contains('withdrawn') || text.contains('paid') || text.contains('spent');
    final isCredit = text.contains('credited') || text.contains('received') || text.contains('deposited');
    
    if (!isDebit && !isCredit) {
      if (extractedBalance != null) {
        return ParsedSms(
          title: 'Balance Update',
          amount: 0.0,
          category: 'Other',
          type: 'expense',
          bankBalance: extractedBalance,
          isTransaction: false,
          bankName: bankName,
          reference: reference,
        );
      }
      return null;
    }

    final match = RegExp(
      r'(?:debited|credited|withdrawn|received|paid|spent|inr|rs\.?|₹)\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    ).firstMatch(text);
    
    if (match == null && extractedBalance == null) {
      return null;
    }

    double amount = 0.0;
    if (match != null) {
      amount = double.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0.0;
    }

    bool isExpense = isDebit;
    if (text.contains('debited') && text.contains('credited')) {
      isExpense = true; 
    }

    // Extract Merchant
    String merchant = isExpense ? 'Bank Debit' : 'Bank Credit';
    if (text.contains('at ')) {
      final atMatch = RegExp(r'at\s+([a-zA-Z0-9\s*]+?)(?:\s+on|\s+using|\s+ref|$)').firstMatch(text);
      if (atMatch != null) {
        merchant = atMatch.group(1)!.trim().toUpperCase();
      }
    } else if (text.contains('to vpa') || text.contains('transfer to') || text.contains('paid to')) {
      final vpaMatch = RegExp(r'(?:to vpa|transfer to|paid to)\s+([a-zA-Z0-9.\-_@\s*]+?)(?:\s+on|\s+ref|$)').firstMatch(text);
      if (vpaMatch != null) {
        merchant = vpaMatch.group(1)!.trim().toUpperCase();
      }
    }

    // Auto-Categorization Engine
    String category = isExpense ? 'Other' : 'Income';
    if (isExpense) {
      final lowerMerchant = merchant.toLowerCase();
      for (var entry in _merchantToCategory.entries) {
        if (lowerMerchant.contains(entry.key)) {
          category = entry.value;
          break;
        }
      }
    }

    return ParsedSms(
      title: merchant,
      amount: amount,
      category: category,
      type: isExpense ? 'expense' : 'income',
      bankBalance: extractedBalance,
      isTransaction: amount > 0,
      bankName: bankName,
      reference: reference,
    );
  }

  static double? extractAvailableBalance(String body) {
    // Robust balance extraction handling colons, dashes, and currency variations
    final regex = RegExp(
      r'(?:Aval?\.?\s*Bal\.?|Available\s*Balance|Avl\.?\s*Bal\.?|A\/c\s*Bal|Bal|Balance|Total\s*Bal)[:\s\-]* (?:INR|Rs\.?|₹)?\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(body);
    if (match != null) {
      final raw = match.group(1)!.replaceAll(',', '');
      return double.tryParse(raw);
    }
    return null;
  }
}
