import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:device_tracking/l10n/generated/app_localizations.dart';
import '../../providers/branch_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/notification_service.dart';
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
  String? _selectedDeviceType;
  String? _selectedManufacturerDropdown;
  bool _isLoading = false;
  DateTime _receivedDate = DateTime.now();

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
      _selectedDeviceType = o.deviceType;
      _receivedDate = o.receivedFromCustomerDate;

      if (_manufacturers.contains(o.manufacturer)) {
        _selectedManufacturerDropdown = o.manufacturer;
      } else {
        _selectedManufacturerDropdown = 'Other';
        _manufacturerController.text = o.manufacturer;
      }
    }
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
      final selectedAccessories = _accessories.entries.where((e) => e.value).map((e) => e.key).toList();
      
      final data = {
        'branchId': _selectedBranch,
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
        'updatedAt': FieldValue.serverTimestamp(),
        'receivedFromCustomerDate': _receivedDate,
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
                          return DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: loc.branch),
                            value: _selectedBranch,
                            items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                            onChanged: (val) => setState(() => _selectedBranch = val),
                            validator: (val) => val == null ? loc.requiredField : null,
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
                          decoration: InputDecoration(
                            labelText: 'تاريخ استلام الجهاز من العميل',
                            suffixIcon: const Icon(Icons.calendar_today),
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
