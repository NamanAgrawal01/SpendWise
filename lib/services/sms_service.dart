import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  final SmsQuery _query = SmsQuery();

  Future<List<SmsMessage>> getMessages() async {
    var permission = await Permission.sms.status;
    if (permission.isDenied) {
      permission = await Permission.sms.request();
    }

    if (permission.isGranted) {
      return await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 20,
      );
    }
    return [];
  }
}

class ParsedSms {
  final String title;
  final double amount;
  final String category;
  final String type;

  ParsedSms({
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
  });
}

