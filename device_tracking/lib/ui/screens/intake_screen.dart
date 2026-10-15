import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:device_tracking/l10n/generated/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/branch_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/branch.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/notification_service.dart';
import '../../services/invoice_ocr_service.dart';
import '../widgets/phone_inspection_widget.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../models/order_model.dart';

class IntakeScreen extends ConsumerStatefulWidget {
  final OrderModel? existingOrder;
  
  const IntakeScreen({super.key, this.existingOrder});

  @override
  ConsumerState<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends ConsumerState<IntakeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderNumberController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _productNameController = TextEditingController();
  final _colorController = TextEditingController();
  final _imeiController = TextEditingController();
  final _problemController = TextEditingController();
  final _conditionController = TextEditingController();
  final _delivererController = TextEditingController();
  final _intakeNotesController = TextEditingController();

  final Map<String, bool> _accessories = {
    'شاحن': false,
    'كيبل': false,
    'كرتون': false,
    'دبوس الشريحة': false,
    'كتالوج': false,
  };

  String? _selectedBranch;
  String? _branchAlertMessage;
  bool _isManualBranch = false;
  final _manualBranchController = TextEditingController();
  String? _selectedDeviceType;
  String? _selectedManufacturerDropdown;
  bool _isLoading = false;
  bool _isScanningInvoice = false;
  String? _visualInspectionData;
  DateTime _receivedDate = DateTime.now();

  String _normArabic(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u0600-\u06FF]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  final List<String> _deviceTypes = [
    'mobile',
    'laptop',
    'tablet',
    'accessories',
    'other'
  ];

  final List<String> _manufacturers = [
    'Apple',
    'Samsung',
    'Infinix',
    'Tecno',
    'Itel',
    'Realme',
    'Honor',
    'Vivo',
    'Oppo',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingOrder != null) {
      final o = widget.existingOrder!;
      _orderNumberController.text = o.orderNumber;
      _productNameController.text = o.productName;
      _colorController.text = o.color ?? '';
      _imeiController.text = o.imeiOrSerial;
      _problemController.text = o.problem;
      _conditionController.text = o.deviceCondition;
      _delivererController.text = o.delivererName;
      _intakeNotesController.text = o.intakeNotes ?? '';
      if (o.accessories != null) {
        for (var acc in o.accessories!) {
          if (_accessories.containsKey(acc)) {
            _accessories[acc] = true;
          }
        }
      }
      _selectedBranch = o.branchId;
      if (o.branchName != null && o.branchName!.isNotEmpty) {
        _manualBranchController.text = o.branchName!;
      } else {
        _manualBranchController.text = o.branchId;
      }
      _selectedDeviceType = o.deviceType;
      _receivedDate = o.receivedFromCustomerDate;
      _visualInspectionData = o.visualInspectionData;

      if (_manufacturers.contains(o.manufacturer)) {
        _selectedManufacturerDropdown = o.manufacturer;
      } else {
        _selectedManufacturerDropdown = 'Other';
        _manufacturerController.text = o.manufacturer;
      }
    }
  }

  @override
  void dispose() {
    _orderNumberController.dispose();
    _manufacturerController.dispose();
    _productNameController.dispose();
    _colorController.dispose();
    _imeiController.dispose();
    _problemController.dispose();
    _conditionController.dispose();
    _delivererController.dispose();
    _intakeNotesController.dispose();
    _manualBranchController.dispose();
    super.dispose();
  }

  Future<void> _pickReceivedDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _receivedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      setState(() {
        _receivedDate = date;
      });
    }
  }

  Future<void> _showInvoicePickerOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'التعرف التلقائي على الفاتورة (OCR)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'اختر طريقة تصوير أو جلب الفاتورة لاستخراج البيانات آلياً:',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt, color: Colors.indigo),
                ),
                title: const Text('التقاط صورة بالفاتورة عبر الكاميرا', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('تصوير فاتورة/إيصال الاستلام مباشرة'),
                onTap: () {
                  Navigator.pop(ctx);
                  _scanInvoice(ImageSource.camera);
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library, color: Colors.teal),
                ),
                title: const Text('اختيار صورة الفاتورة من الاستوديو', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('جلب صورة الفاتورة المحفوظة في الجهاز'),
                onTap: () {
                  Navigator.pop(ctx);
                  _scanInvoice(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanInvoice(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() => _isScanningInvoice = true);

      final extracted = await InvoiceOcrService().extractFromImageFile(File(pickedFile.path));

      int fieldsCount = 0;

      // 11. Smart Branch Matching across entire invoice text
      final allBranches = ref.read(branchesProvider).value ?? [];
      final currentUser = ref.read(currentUserModelProvider).value;

      final allowedBranches = (currentUser != null && !currentUser.isAdmin)
          ? allBranches.where((b) => (currentUser.assignedBranchIds ?? []).contains(b.id)).toList()
          : allBranches;

      final fullRaw = '${extracted.branchName ?? ''} ${extracted.branchCode ?? ''} ${extracted.rawText}';
      final normFull = _normArabic(fullRaw);

      Branch? matchedBranch;
      Branch? matchedInAll;

      bool isBranchMatch(Branch b) {
        // Priority 1: Match 4-digit branch code (e.g. 9551)
        final code = b.code.trim();
        if (code.isNotEmpty) {
          if (extracted.branchCode == code) return true;
          final codeRegex = RegExp(r'\b' + RegExp.escape(code) + r'\b');
          if (codeRegex.hasMatch(extracted.rawText) || normFull.contains(_normArabic(code))) {
            return true;
          }
        }

        // Check if b.name contains 4 digits (e.g. "فرع 9551" or "طويق 9551")
        final fourDigitsInName = RegExp(r'\b(\d{4})\b').firstMatch(b.name)?.group(1);
        if (fourDigitsInName != null && RegExp(r'\b' + fourDigitsInName + r'\b').hasMatch(extracted.rawText)) {
          return true;
        }

        // Priority 2: Match branch name (e.g. طويق, الريم بلازا, etc.)
        final normName = _normArabic(b.name);
        if (normName.isNotEmpty) {
          if (normFull.contains(normName)) return true;

          final cleanWords = normName
              .split(' ')
              .where((w) => w.length >= 3 && !['فرع', 'محل', 'متجر', 'شركة', 'branch', 'store', 'hypermarket', 'supermarket', 'nesto', 'هايبر', 'بنده', 'لولو'].contains(w))
              .toList();

          if (cleanWords.isNotEmpty && cleanWords.every((w) => normFull.contains(w))) {
            return true;
          }
        }
        return false;
      }

      // Check allowed branches first
      for (final b in allowedBranches) {
        if (isBranchMatch(b)) {
          matchedBranch = b;
          break;
        }
      }

      // If not in allowed branches, check all branches
      if (matchedBranch == null) {
        for (final b in allBranches) {
          if (isBranchMatch(b)) {
            matchedInAll = b;
            break;
          }
        }
      }

      String? matchedBranchId;
      String? matchedBranchName;

      final detectedBranch = (extracted.branchName != null && extracted.branchName!.isNotEmpty)
          ? extracted.branchName!
          : (extracted.branchCode != null && extracted.branchCode!.isNotEmpty ? extracted.branchCode! : '');

      if (matchedBranch != null) {
        matchedBranchId = matchedBranch.id;
        matchedBranchName = matchedBranch.name;
        _isManualBranch = false;
        _manualBranchController.text = matchedBranch.name;
        _branchAlertMessage = 'تم التعرف على الفرع وتحديده تلقائياً: ${matchedBranch.name} (${matchedBranch.code})';
      } else if (matchedInAll != null) {
        matchedBranchId = null;
        matchedBranchName = null;
        _manualBranchController.text = matchedInAll.name;
        _branchAlertMessage = 'الفرع المكتشف بالفاتورة (${matchedInAll.name}) غير مسند لحسابك في القائمة. تم إدراجه في خانة الكتابة اليدوية.';
      } else {
        matchedBranchId = null;
        matchedBranchName = null;

        if (detectedBranch.isNotEmpty) {
          _manualBranchController.text = detectedBranch;
          _branchAlertMessage = 'تم قراءة اسم الفرع من الفاتورة: "$detectedBranch". يمكنك اعتماده ككتابة يدوية أو اختيار الفرع المطابق من القائمة.';
        } else {
          _branchAlertMessage = 'لم يتم التعرف على الفرع تلقائياً من الفاتورة. يمكنك اختياره من القائمة أو كتابة اسمه يدوياً.';
        }
      }

      setState(() {
        // 1. Service Ticket
        if (extracted.serviceTicket != null && extracted.serviceTicket!.isNotEmpty) {
          _orderNumberController.text = extracted.serviceTicket!;
          fieldsCount++;
        }

        // 2. Device Details / Product Name
        if (extracted.deviceName != null && extracted.deviceName!.isNotEmpty) {
          _productNameController.text = extracted.deviceName!;
          fieldsCount++;
        }

        // 3. Category / Device Type
        if (extracted.category != null && _deviceTypes.contains(extracted.category)) {
          _selectedDeviceType = extracted.category;
          fieldsCount++;
        }

        // 4. Serial # / IMEI
        if (extracted.serialOrImei != null && extracted.serialOrImei!.isNotEmpty) {
          _imeiController.text = extracted.serialOrImei!;
          fieldsCount++;
        }

        // 5. Issue / Problem / Notes
        if (extracted.issue != null && extracted.issue!.isNotEmpty) {
          _problemController.text = extracted.issue!;
          fieldsCount++;
        }

        // 6. Condition
        if (extracted.condition != null && extracted.condition!.isNotEmpty) {
          _conditionController.text = extracted.condition!;
          fieldsCount++;
        }

        // 7. Deliverer / Customer Name
        if (extracted.customerName != null && extracted.customerName!.isNotEmpty) {
          _delivererController.text = extracted.customerName!;
          fieldsCount++;
        }

        // 8. Manufacturer
        if (extracted.manufacturer != null) {
          if (_manufacturers.contains(extracted.manufacturer)) {
            _selectedManufacturerDropdown = extracted.manufacturer;
          } else {
            _selectedManufacturerDropdown = 'Other';
            _manufacturerController.text = extracted.manufacturer!;
          }
          fieldsCount++;
        }

        // 9. Accessories
        if (extracted.accessories != null && extracted.accessories!.isNotEmpty) {
          final accLower = extracted.accessories!.toLowerCase();
          if (accLower.contains('charger') || accLower.contains('شاحن')) _accessories['شاحن'] = true;
          if (accLower.contains('cable') || accLower.contains('كيبل')) _accessories['كيبل'] = true;
          if (accLower.contains('box') || accLower.contains('كرتون')) _accessories['كرتون'] = true;

          final notePrefix = 'المرفقات بالفاتورة: ${extracted.accessories!}';
          if (_intakeNotesController.text.isEmpty) {
            _intakeNotesController.text = notePrefix;
          } else if (!_intakeNotesController.text.contains(extracted.accessories!)) {
            _intakeNotesController.text += '\n$notePrefix';
          }
          fieldsCount++;
        }

        // 10. Customer Phone
        if (extracted.customerPhone != null && extracted.customerPhone!.isNotEmpty) {
          final phoneNote = 'هاتف العميل: ${extracted.customerPhone!}';
          if (!_intakeNotesController.text.contains(extracted.customerPhone!)) {
            _intakeNotesController.text += (_intakeNotesController.text.isEmpty ? '' : '\n') + phoneNote;
          }
        }

        // 11. Branch
        if (matchedBranchId != null) {
          _selectedBranch = matchedBranchId;
          _isManualBranch = false;
          fieldsCount++;
        } else {
          _selectedBranch = null;
        }
      });

      if (mounted) {
        if (matchedBranchName != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.green.shade700,
              content: Text('تم استخراج $fieldsCount حقل من الفاتورة (تم تحديد فرع $matchedBranchName تلقائياً) 🎉'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.indigo.shade700,
              content: Text('تم استخراج $fieldsCount حقل من الفاتورة بنجاح. يمكنك اختيار الفرع من القائمة أو كتابته يدوياً.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء قراءة الفاتورة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanningInvoice = false);
    }
  }

  Future<void> _scanBarcode() async {
    bool isScanned = false; // Flag to prevent multiple pops
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('مسح الباركود')),
          body: MobileScanner(
            onDetect: (capture) {
              if (isScanned) return; // Ignore subsequent scans
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final val = barcodes.first.rawValue;
                if (val != null && val.isNotEmpty) {
                  isScanned = true;
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context, val);
                  }
                }
              }
            },
          ),
        ),
      ),
    );

    if (code != null && mounted) {
      setState(() {
        _imeiController.text = code;
      });
    }
  }

  Future<void> _saveOrder(AppLocalizations loc) async {
    if (!_formKey.currentState!.validate()) return;

    final finalManufacturer = _selectedManufacturerDropdown == 'Other' 
        ? _manufacturerController.text.trim() 
        : _selectedManufacturerDropdown ?? '';

    if (finalManufacturer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.requiredField)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final allBranches = ref.read(branchesProvider).value ?? [];
      final currentUser = ref.read(currentUserModelProvider).value;

      String finalBranchId;
      String finalBranchName;

      if (_isManualBranch) {
        final manualName = _manualBranchController.text.trim();
        if (manualName.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء كتابة اسم الفرع أو الاختيار من القائمة')),
          );
          setState(() => _isLoading = false);
          return;
        }
        finalBranchId = manualName;
        finalBranchName = manualName;
      } else {
        if (_selectedBranch == null || _selectedBranch!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء اختيار الفرع أو كتابته يدوياً')),
          );
          setState(() => _isLoading = false);
          return;
        }
        final b = allBranches.firstWhere(
          (item) => item.id == _selectedBranch,
          orElse: () => Branch(id: _selectedBranch!, name: _selectedBranch!, code: '', isActive: true),
        );
        finalBranchId = b.id;
        finalBranchName = b.name;
      }

      final selectedAccessories = _accessories.entries.where((e) => e.value).map((e) => e.key).toList();
      
      final data = <String, dynamic>{
        'branchId': finalBranchId,
        'branchName': finalBranchName,
        'isManualBranch': _isManualBranch,
        'orderNumber': _orderNumberController.text.trim(),
        'deviceType': _selectedDeviceType,
        'manufacturer': finalManufacturer,
        'productName': _productNameController.text.trim(),
        'color': _colorController.text.trim(),
        'imeiOrSerial': _imeiController.text.trim(),
        'problem': _problemController.text.trim(),
        'deviceCondition': _conditionController.text.trim(),
        'delivererName': _delivererController.text.trim(),
        'intakeNotes': _intakeNotesController.text.trim(),
        'accessories': selectedAccessories,
        'visualInspectionData': _visualInspectionData,
        'updatedAt': FieldValue.serverTimestamp(),
        'receivedFromCustomerDate': _receivedDate,
        if (currentUser != null) 'createdBy': currentUser.id,
        if (currentUser != null) 'createdByName': currentUser.name,
      };

      String orderId;
      if (widget.existingOrder == null) {
        data['status'] = 'pending_service_center';
        data['createdAt'] = FieldValue.serverTimestamp();
        final docRef = FirebaseFirestore.instance.collection('orders').doc();
        orderId = docRef.id;
        docRef.set(data); // Don't await to support immediate offline UI updates
      } else {
        orderId = widget.existingOrder!.id;
        FirebaseFirestore.instance.collection('orders').doc(orderId).update(data); // Don't await
      }

      // Manage notifications
      final status = widget.existingOrder?.status ?? 'pending_service_center';
      if (status == 'pending_service_center') {
        await NotificationService().cancelBranchDelays(orderId);
        await NotificationService().scheduleBranchDelays(orderId, _orderNumberController.text.trim(), _receivedDate);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الطلب بنجاح')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserModelProvider).value;
    final branchesAsync = ref.watch(branchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingOrder == null ? loc.receiveDevice : 'تعديل الطلب'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Smart OCR Invoice Scanning Banner
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor, Colors.indigo.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.indigo.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.document_scanner, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'التعرف الذكي على الفاتورة (OCR)',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'قراءة رقم التذكرة، اسم الجهاز، السيريال، والعطل تلقائياً',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isScanningInvoice ? null : _showInvoicePickerOptions,
                        icon: _isScanningInvoice
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome),
                        label: Text(
                          _isScanningInvoice ? 'جاري استخراج البيانات...' : 'مسح الفاتورة تلقائياً (كاميرا / صورة)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('البيانات الأساسية', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                      const SizedBox(height: 16),
                      branchesAsync.when(
                        data: (branches) {
                          final isStaff = currentUser != null && !currentUser.isAdmin;
                          final assignedIds = currentUser?.assignedBranchIds ?? [];
                          final allowedBranches = isStaff
                              ? branches.where((b) => assignedIds.contains(b.id)).toList()
                              : branches;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Mode Switcher (List vs Manual)
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() {
                                        _isManualBranch = false;
                                        _branchAlertMessage = null;
                                      }),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 9),
                                        decoration: BoxDecoration(
                                          color: !_isManualBranch ? Theme.of(context).primaryColor : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: !_isManualBranch ? Theme.of(context).primaryColor : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.list_alt,
                                              size: 18,
                                              color: !_isManualBranch ? Colors.white : Colors.grey.shade700,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'اختيار من القائمة',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: !_isManualBranch ? Colors.white : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() {
                                        _isManualBranch = true;
                                        _branchAlertMessage = null;
                                      }),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 9),
                                        decoration: BoxDecoration(
                                          color: _isManualBranch ? Theme.of(context).primaryColor : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: _isManualBranch ? Theme.of(context).primaryColor : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.edit_note,
                                              size: 18,
                                              color: _isManualBranch ? Colors.white : Colors.grey.shade700,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'كتابة اسم الفرع يدوياً',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _isManualBranch ? Colors.white : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (!_isManualBranch) ...[
                                if (isStaff && allowedBranches.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.amber.shade300),
                                    ),
                                    child: Text(
                                      'تنبيه: لا توجد فروع مسندة لحسابك في القائمة حالياً. يمكنك استخدام "كتابة اسم الفرع يدوياً" أعلاه.',
                                      style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: loc.branch,
                                    helperText: isStaff
                                        ? 'الفروع المعتمدة لحسابك (${allowedBranches.length} فرع)'
                                        : 'اختر الفرع من قائمة الفروع المسجلة',
                                  ),
                                  value: allowedBranches.any((b) => b.id == _selectedBranch) ? _selectedBranch : null,
                                  items: allowedBranches.map((b) => DropdownMenuItem(
                                    value: b.id, 
                                    child: Text('${b.name} (${b.code})'),
                                  )).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedBranch = val;
                                      _branchAlertMessage = null;
                                    });
                                  },
                                  validator: (val) => !_isManualBranch && val == null ? loc.requiredField : null,
                                ),
                              ] else ...[
                                TextFormField(
                                  controller: _manualBranchController,
                                  decoration: InputDecoration(
                                    labelText: 'اسم الفرع (كتابة يدوية)',
                                    hintText: 'مثال: فرع طويق أو الظهران أو 9551',
                                    prefixIcon: const Icon(Icons.store),
                                    helperText: 'اكتب اسم الفرع مباشرة إذا كان مختلفاً أو غير مضاف بالقائمة',
                                    suffixIcon: _manualBranchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () => setState(() => _manualBranchController.clear()),
                                          )
                                        : null,
                                  ),
                                  validator: (val) => _isManualBranch && (val == null || val.trim().isEmpty) ? loc.requiredField : null,
                                ),
                              ],
                              if (_branchAlertMessage != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.indigo.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.indigo.shade800, size: 22),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _branchAlertMessage!,
                                          style: TextStyle(
                                            color: Colors.indigo.shade900,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Text('خطأ في تحميل الفروع: $err'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _orderNumberController,
                        decoration: InputDecoration(labelText: loc.orderNumber),
                        validator: (val) => val!.isEmpty ? loc.requiredField : null,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _pickReceivedDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تاريخ استلام الجهاز من العميل',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(DateFormat('yyyy-MM-dd').format(_receivedDate), style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: loc.deviceType),
                        value: _selectedDeviceType,
                        items: _deviceTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getDeviceTypeName(type, loc)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedDeviceType = val),
                        validator: (val) => val == null ? loc.requiredField : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تفاصيل الجهاز', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: loc.manufacturer),
                        value: _selectedManufacturerDropdown,
                        items: _manufacturers.map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text(m == 'Other' ? 'أخرى (Other)' : m),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedManufacturerDropdown = val),
                        validator: (val) => val == null ? loc.requiredField : null,
                      ),
                      if (_selectedManufacturerDropdown == 'Other') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _manufacturerController,
                          decoration: const InputDecoration(labelText: 'اكتب اسم الشركة يدوياً'),
                          validator: (val) => val!.isEmpty ? loc.requiredField : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _productNameController,
                        decoration: InputDecoration(labelText: loc.productName),
                        validator: (val) => val!.isEmpty ? loc.requiredField : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _colorController,
                        decoration: InputDecoration(labelText: loc.color),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _imeiController,
                              decoration: InputDecoration(labelText: loc.imeiOrSerial),
                              validator: (val) => val!.isEmpty ? loc.requiredField : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                              onPressed: _scanBarcode,
                              tooltip: loc.scanBarcode,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('حالة الجهاز والمشكلة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _problemController,
                        decoration: InputDecoration(labelText: loc.deviceProblem),
                        maxLines: 3,
                        validator: (val) => val!.isEmpty ? loc.requiredField : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _conditionController,
                        decoration: InputDecoration(labelText: loc.deviceCondition),
                        maxLines: 3,
                        validator: (val) => val!.isEmpty ? loc.requiredField : null,
                      ),
                      const SizedBox(height: 10),
                      // Visual phone inspection button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.indigo,
                          side: BorderSide(color: Colors.indigo.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        ),
                        onPressed: () async {
                          final result = await showDialog<Map<String, dynamic>>(
                            context: context,
                            builder: (ctx) => PhoneInspectionDialog(
                              initialData: _visualInspectionData,
                              initialConditionText: _conditionController.text,
                            ),
                          );
                          if (result != null && mounted) {
                            setState(() {
                              _conditionController.text = result['summary'] ?? _conditionController.text;
                              _visualInspectionData = result['data'];
                            });
                          }
                        },
                        icon: const Icon(Icons.draw, size: 20),
                        label: Text(
                          _visualInspectionData != null && _visualInspectionData!.isNotEmpty
                              ? 'تعديل الفحص البصري للجوال (تم الحفظ ✔️)'
                              : 'فحص وتحديد الخدوش على رسم الجوال 📱',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _delivererController,
                        decoration: InputDecoration(labelText: loc.delivererName),
                        validator: (val) => val!.isEmpty ? loc.requiredField : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الملحقات والملاحظات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                      const SizedBox(height: 16),
                      Text('الملحقات المستلمة مع الجهاز:', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _accessories.keys.map((String key) {
                          return FilterChip(
                            label: Text(key),
                            selected: _accessories[key]!,
                            onSelected: (bool selected) {
                              setState(() {
                                _accessories[key] = selected;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _intakeNotesController,
                        decoration: const InputDecoration(labelText: 'ملاحظات إضافية عند الاستلام (اختياري)'),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () => _saveOrder(loc),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      child: Text(widget.existingOrder == null ? loc.createOrder : 'حفظ التعديلات'),
                    ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _getDeviceTypeName(String type, AppLocalizations loc) {
    switch (type) {
      case 'mobile': return loc.mobile;
      case 'laptop': return loc.laptop;
      case 'tablet': return loc.tablet;
      case 'accessories': return loc.accessories;
      default: return loc.other;
    }
  }
}
