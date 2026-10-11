import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ExtractedInvoiceData {
  final String? serviceTicket;
  final String? branchName;
  final String? customerName;
  final String? customerPhone;
  final String? deviceName;
  final String? category;
  final String? serialOrImei;
  final String? issue;
  final String? condition;
  final String? accessories;
  final String? manufacturer;
  final String rawText;

  ExtractedInvoiceData({
    this.serviceTicket,
    this.branchName,
    this.customerName,
    this.customerPhone,
    this.deviceName,
    this.category,
    this.serialOrImei,
    this.issue,
    this.condition,
    this.accessories,
    this.manufacturer,
    required this.rawText,
  });
}

class InvoiceOcrService {
  static final InvoiceOcrService _instance = InvoiceOcrService._internal();
  factory InvoiceOcrService() => _instance;
  InvoiceOcrService._internal();

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ExtractedInvoiceData> extractFromImageFile(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return parseRecognizedText(recognizedText.text);
  }

  ExtractedInvoiceData parseRecognizedText(String rawText) {
    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String? serviceTicket;
    String? branchName;
    String? customerName;
    String? customerPhone;
    String? deviceName;
    String? category;
    String? serialOrImei;
    String? issue;
    String? condition;
    String? accessories;
    String? manufacturer;

    // Helper to find value after a label in current line or following line
    String? findValue(List<String> labelPatterns, {bool allowNextLine = true}) {
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        for (final pattern in labelPatterns) {
          final regex = RegExp('^$pattern[:\\-]?\\s*(.*)\$', caseSensitive: false);
          final match = regex.firstMatch(line);
          if (match != null) {
            final val = match.group(1)?.trim();
            if (val != null && val.isNotEmpty) {
              return val;
            } else if (allowNextLine && i + 1 < lines.length) {
              final next = lines[i + 1].trim();
              if (next.isNotEmpty && !next.contains(':')) {
                return next;
              }
            }
          }
        }
      }
      return null;
    }

    // 1. Service Ticket
    serviceTicket = findValue(['Service Ticket', 'ServiceTicket', 'Ticket', 'رقم التذكرة', 'رقم الطلب']);
    if (serviceTicket == null) {
      // Look for regex pattern like SRV-2026-8433
      final ticketRegex = RegExp(r'\b(SRV[-\w\d]+)\b', caseSensitive: false);
      final match = ticketRegex.firstMatch(rawText);
      if (match != null) {
        serviceTicket = match.group(1);
      }
    }

    // 2. Branch
    branchName = findValue(['Branch', 'الفرع', 'المتجر', 'Store']);

    // 3. Customer name & phone
    customerName = findValue(['Customer name', 'Customer', 'العميل', 'اسم العميل']);
    customerPhone = findValue(['Customer Mob Number', 'Customer Mob', 'Mob Number', 'Phone', 'رقم الجوال', 'الجوال']);

    // 4. Device Details / Device
    deviceName = findValue(['Device Details', 'Device', 'اسم الجهاز', 'الجهاز', 'Item Description']);

    // 5. Category / نوع الجهاز
    final rawCategory = findValue(['Category', 'التصنيف', 'نوع الجهاز']);
    if (rawCategory != null) {
      final lower = rawCategory.toLowerCase();
      if (lower.contains('laptop') || lower.contains('كمبيوتر') || lower.contains('لابتوب')) {
        category = 'laptop';
      } else if (lower.contains('mobile') || lower.contains('phone') || lower.contains('جوال') || lower.contains('هاتف')) {
        category = 'mobile';
      } else if (lower.contains('tablet') || lower.contains('تابلت') || lower.contains('ايباد') || lower.contains('ipad')) {
        category = 'tablet';
      } else if (lower.contains('access') || lower.contains('ملحق')) {
        category = 'accessories';
      } else {
        category = 'other';
      }
    }

    // 6. Serial # or IMEI
    serialOrImei = findValue(['Serial #', 'Serial', 'Serial No', 'S/N', 'IMEI', 'السيريال', 'الرقم التسلسلي']);

    // 7. Issue / Problem / Additional Notes
    final rawIssue = findValue(['Issue', 'المشكلة', 'العطل']);
    final rawNotes = findValue(['Additional Notes', 'ملاحظات إضافية', 'Notes']);
    if (rawNotes != null && rawNotes.isNotEmpty) {
      issue = rawNotes;
    } else if (rawIssue != null && rawIssue.isNotEmpty) {
      issue = rawIssue;
    }

    // 8. Condition
    condition = findValue(['Condition', 'حالة الجهاز']);

    // 9. Accessories
    accessories = findValue(['Accessories', 'الملحقات', 'المرفقات']);

    // 10. Auto-detect Manufacturer from Device Name or Raw Text
    final searchSource = '${deviceName ?? ''} $rawText';
    final knownBrands = [
      'Apple',
      'Acer',
      'Samsung',
      'Infinix',
      'Tecno',
      'Itel',
      'Realme',
      'Honor',
      'Vivo',
      'Oppo',
      'Lenovo',
      'Dell',
      'HP',
      'Asus',
      'Xiaomi',
      'Huawei',
      'Sony',
      'Nokia',
      'Google',
      'OnePlus',
      'Motorola',
    ];

    for (final brand in knownBrands) {
      if (searchSource.toLowerCase().contains(brand.toLowerCase())) {
        manufacturer = brand;
        break;
      }
    }

    // If category was not explicitly found in Category label, guess from deviceName
    if (category == null && deviceName != null) {
      final dLower = deviceName.toLowerCase();
      if (dLower.contains('n.book') || dLower.contains('laptop') || dLower.contains('notebook') || dLower.contains('pc')) {
        category = 'laptop';
      } else if (dLower.contains('phone') || dLower.contains('iphone') || dLower.contains('galaxy') || dLower.contains('redmi')) {
        category = 'mobile';
      } else if (dLower.contains('tab') || dLower.contains('pad')) {
        category = 'tablet';
      }
    }

    return ExtractedInvoiceData(
      serviceTicket: serviceTicket,
      branchName: branchName,
      customerName: customerName,
      customerPhone: customerPhone,
      deviceName: deviceName,
      category: category,
      serialOrImei: serialOrImei,
      issue: issue,
      condition: condition,
      accessories: accessories,
      manufacturer: manufacturer,
      rawText: rawText,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }
}
