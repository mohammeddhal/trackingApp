import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_tracking/l10n/generated/app_localizations.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../providers/services_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/branch_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/phone_inspection_widget.dart';
import '../../models/order_history.dart';
import 'package:go_router/go_router.dart';
import '../../services/notification_service.dart';
import 'package:intl/intl.dart' hide TextDirection;

class OrderDetailsScreen extends ConsumerWidget {
  final OrderModel order;
  
  const OrderDetailsScreen({super.key, required this.order});

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String newStatus, String actionName, {Map<String, dynamic>? additionalData}) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final user = ref.read(currentUserModelProvider).value;
      final userName = user?.name ?? 'مستخدم';

      final historyId = FirebaseFirestore.instance.collection('order_history').doc().id;
      final history = OrderHistory(
        id: historyId,
        orderId: order.id,
        actionName: actionName,
        timestamp: DateTime.now(),
        userName: userName,
      );

      await firestoreService.updateOrderStatus(order.id, newStatus, history, additionalData: additionalData);
      
      // Manage notifications
      if (newStatus == 'completed' || newStatus == 'delivered_branch') {
        await NotificationService().cancelMaintenanceDelays(order.id);
        await NotificationService().cancelBranchDelays(order.id);
        await NotificationService().cancelDailyDeliveryReminder(order.id);
      } else if (newStatus == 'delivered_service_center') {
        await NotificationService().cancelBranchDelays(order.id);
        await NotificationService().cancelMaintenanceDelays(order.id);
        await NotificationService().cancelDailyDeliveryReminder(order.id);
        await NotificationService().scheduleMaintenanceDelays(order.id, order.orderNumber, DateTime.now());
      } else if (newStatus == 'received_from_maintenance') {
        await NotificationService().cancelMaintenanceDelays(order.id);
        await NotificationService().scheduleDailyDeliveryReminder(order.id, order.orderNumber);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الحالة بنجاح')));
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _deleteOrder(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الطلب'),
        content: const Text('هل أنت متأكد من حذف هذا الطلب نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      )
    );

    if (confirm == true && context.mounted) {
      try {
        FirebaseFirestore.instance.collection('orders').doc(order.id).delete();
        final historyDocs = await FirebaseFirestore.instance.collection('order_history').where('orderId', isEqualTo: order.id).get();
        for (var doc in historyDocs.docs) {
          await doc.reference.delete();
        }
        
        await NotificationService().cancelMaintenanceDelays(order.id);
        await NotificationService().cancelBranchDelays(order.id);
        await NotificationService().cancelDailyDeliveryReminder(order.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح')));
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
        }
      }
    }
  }

  Future<void> _showOutOfWarrantyDialog(BuildContext context, WidgetRef ref, String branchName) async {
    final reasonController = TextEditingController(text: order.outOfWarrantyReason ?? '');
    final costController = TextEditingController(text: order.repairCost ?? '');
    File? selectedPdfFile;
    String? existingPdfUrl = order.maintenancePdfUrl;
    bool isUploading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          // Format WhatsApp message in English as requested:
          // Service Memo: [رقم الطلب للفرع]
          // Store: [رمز/اسم الفرع]
          // Device Name: [اسم الجهاز]
          // Out of Warranty Reason: [السبب]
          // Repair Cost: [التكلفة]
          String generateEnglishMessage() {
            final memo = order.orderNumber;
            return 'Service Memo: $memo\n'
                'Store: $branchName\n'
                'Device Name: ${order.productName}\n'
                'Out of Warranty Reason: ${reasonController.text.trim()}\n'
                'Repair Cost: ${costController.text.trim()} SAR';
          }

          Future<void> openWhatsAppOnly() async {
            final message = generateEnglishMessage();
            final encoded = Uri.encodeComponent(message);
            final waUrl = Uri.parse('whatsapp://send?text=$encoded');
            final webWaUrl = Uri.parse('https://wa.me/?text=$encoded');
            try {
              if (await canLaunchUrl(waUrl)) {
                await launchUrl(waUrl);
              } else if (await canLaunchUrl(webWaUrl)) {
                await launchUrl(webWaUrl, mode: LaunchMode.externalApplication);
              } else {
                await SharePlus.instance.share(ShareParams(text: message));
              }
            } catch (_) {
              await SharePlus.instance.share(ShareParams(text: message));
            }
          }

          Future<void> shareWithWhatsAppOrPdf() async {
            final message = generateEnglishMessage();
            if (selectedPdfFile != null) {
              await SharePlus.instance.share(ShareParams(
                files: [XFile(selectedPdfFile!.path)],
                text: message,
              ));
            } else {
              await openWhatsAppOnly();
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Expanded(child: Text('جهاز خارج الضمان (Out of Warranty)')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'سبب خروج الجهاز من الضمان (Reason)',
                      hintText: 'مثال: سوء استخدام / كسر شاشة / دخول سوائل',
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: costController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'تكلفة الإصلاح (Repair Cost)',
                      hintText: 'مثال: 250',
                      suffixText: 'SAR',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedPdfFile != null
                                    ? 'الملف المحدد: ${selectedPdfFile!.path.split(Platform.isWindows ? '\\' : '/').last}'
                                    : (existingPdfUrl != null ? 'يوجد تقرير PDF مرفق مسبقاً' : 'لم يتم إرفاق ملف PDF بعد'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('إرفاق تقرير الصيانة اليدوي (PDF)', style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            final result = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf'],
                            );
                            if (result.isNotEmpty && result.first.path != null) {
                              setState(() {
                                selectedPdfFile = File(result.first.path!);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'معاينة رسالة الواتساب باللغة الإنجليزية للفرع:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      generateEnglishMessage(),
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.green.shade900),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    label: const Text('إرسال ومشاركة عبر الواتساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () => shareWithWhatsAppOrPdf(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        setState(() => isUploading = true);
                        String? uploadedPdfUrl = existingPdfUrl;
                        if (selectedPdfFile != null) {
                          try {
                            final fileName = 'report_${order.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
                            final refStorage = FirebaseStorage.instance.ref().child('orders/${order.id}/$fileName');
                            await refStorage.putFile(selectedPdfFile!);
                            uploadedPdfUrl = await refStorage.getDownloadURL();
                          } catch (e) {
                            uploadedPdfUrl = selectedPdfFile!.path;
                          }
                        }

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          await _updateStatus(
                            context,
                            ref,
                            'out_of_warranty',
                            'تم تعيين الجهاز كخارج الضمان وإرسال التقرير',
                            additionalData: {
                              'outOfWarrantyReason': reasonController.text.trim(),
                              'repairCost': costController.text.trim(),
                              if (uploadedPdfUrl != null) 'maintenancePdfUrl': uploadedPdfUrl,
                            },
                          );
                        }
                      },
                child: isUploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('حفظ واعتماد خارج الضمان'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showReceivedFromMaintenanceDialog(BuildContext context, WidgetRef ref) async {
    final resultController = TextEditingController(text: order.maintenanceResult ?? '');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.inventory_2, color: Colors.teal),
            SizedBox(width: 8),
            Text('استلام الجهاز من الصيانة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيتم تحويل حالة الجهاز إلى "الأجهزة المستلمة من الصيانة" وتفعيل تذكير يومي لحين تسليمه للفرع.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resultController,
              decoration: const InputDecoration(
                labelText: 'نتيجة أو تفاصيل الصيانة (اختياري)',
                hintText: 'مثال: تم تغيير الشاشة بنجاح وفحص الجهاز',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الاستلام والتذكير', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await _updateStatus(
        context,
        ref,
        'received_from_maintenance',
        'تم استلام الجهاز من مركز الصيانة وجاهز للتسليم للفرع',
        additionalData: {
          'receivedFromMaintenanceDate': DateTime.now(),
          if (resultController.text.trim().isNotEmpty) 'maintenanceResult': resultController.text.trim(),
        },
      );
    }
  }

  Future<void> _showDeliverToBranchDialog(BuildContext context, WidgetRef ref, AppLocalizations loc) async {
    final receiverController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('تأكيد تسليم الجهاز للفرع'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('عند التأكيد سيتم إغلاق التذكير اليومي وتغيير حالة الطلب إلى مكتمل.'),
            const SizedBox(height: 12),
            TextField(
              controller: receiverController,
              decoration: InputDecoration(
                labelText: loc.receiverName,
                hintText: 'اسم الموظف المستلم بالفرع',
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات التسليم (اختياري)',
                prefixIcon: Icon(Icons.note),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              if (receiverController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.requiredField)));
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('تأكيد التسليم وإكمال الطلب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true && receiverController.text.trim().isNotEmpty && context.mounted) {
      await _updateStatus(
        context,
        ref,
        'completed',
        'تم تأكيد تسليم الجهاز للفرع واكتمال الطلب',
        additionalData: {
          'receiverName': receiverController.text.trim(),
          if (notesController.text.trim().isNotEmpty) 'handoverNotes': notesController.text.trim(),
        },
      );
    }
  }

  Future<void> _showMaintenanceResultDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نتيجة الصيانة'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'اكتب تفاصيل الصيانة هنا...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _updateStatus(context, ref, 'waiting_customer_approval', 'تم استلام الجهاز من مركز الصيانة وبانتظار موافقة العميل', additionalData: {
        'maintenanceResult': controller.text.trim(),
      });
    }
  }

  Future<void> _showDeliverToServiceCenterDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final serviceCenterOrderController = TextEditingController();
    final serviceCenterNameController = TextEditingController();
    bool withAccessories = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تسليم لمركز الصيانة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('تسليم الجهاز مع الملحقات؟'),
                value: withAccessories,
                onChanged: (val) {
                  setState(() {
                    withAccessories = val ?? false;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: serviceCenterNameController,
                decoration: const InputDecoration(hintText: 'اسم مركز الصيانة'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: serviceCenterOrderController,
                decoration: const InputDecoration(hintText: 'رقم الطلب في مركز الصيانة (اختياري)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'ملاحظات إضافية (اختياري)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (serviceCenterNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال اسم مركز الصيانة')));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ وتسليم'),
            ),
          ],
        ),
      ),
    );

    if (result == true && context.mounted) {
      await _updateStatus(context, ref, 'delivered_service_center', 'تم تسليم الجهاز لمركز الصيانة', additionalData: {
        'handedOverWithAccessories': withAccessories,
        'handoverNotes': controller.text.trim(),
        'serviceCenterOrderNumber': serviceCenterOrderController.text.trim().isNotEmpty ? serviceCenterOrderController.text.trim() : null,
        'serviceCenterName': serviceCenterNameController.text.trim().isNotEmpty ? serviceCenterNameController.text.trim() : null,
      });
    }
  }

  Future<void> _showDeliverToStoreDialog(BuildContext context, WidgetRef ref, AppLocalizations loc) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.receiverNameDialogTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: loc.receiverName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ وإغلاق')),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty && context.mounted) {
      await _updateStatus(context, ref, 'completed', 'تم تسليم الجهاز للمتجر وإغلاق الطلب', additionalData: {
        'receiverName': controller.text.trim(),
      });
    } else if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.requiredField)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final historyAsync = ref.watch(orderHistoryProvider(order.id));
    final branchesAsync = ref.watch(branchesProvider);
    final branchName = branchesAsync.when(
      data: (branches) {
        try {
          return branches.firstWhere((b) => b.id == order.branchId).name;
        } catch (_) {
          return order.branchId;
        }
      },
      loading: () => 'جاري التحميل...',
      error: (_, __) => order.branchId,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${loc.orderNumber}: ${order.orderNumber}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'تعديل',
            onPressed: () => context.push('/intake', extra: order),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            tooltip: 'حذف',
            onPressed: () => _deleteOrder(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Theme.of(context).primaryColor,
              padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.productName,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'الحالة: ${_getStatusText(order.status, loc)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildMaintenanceDaysBadge(order.maintenanceDays),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(Icons.business, loc.manufacturer, order.manufacturer),
                          const Divider(),
                          _buildDetailRow(Icons.storefront, 'الفرع', branchName),
                          const Divider(),
                          _buildDetailRow(Icons.tag, loc.imeiOrSerial, order.imeiOrSerial),
                          const Divider(),
                          _buildDetailRow(Icons.calendar_today, 'تاريخ استلام الفرع من العميل', DateFormat('yyyy-MM-dd').format(order.receivedFromCustomerDate)),
                          const Divider(),
                          _buildDetailRow(Icons.event_available, 'تاريخ استلامي من الفرع (الإنشاء)', DateFormat('yyyy-MM-dd').format(order.createdAt)),
                          const Divider(),
                          Builder(
                            builder: (context) {
                              final dateBranchReceived = DateTime(order.receivedFromCustomerDate.year, order.receivedFromCustomerDate.month, order.receivedFromCustomerDate.day);
                              final dateIReceived = DateTime(order.createdAt.year, order.createdAt.month, order.createdAt.day);
                              
                              int diff = 0;
                              DateTime current = dateBranchReceived;
                              while (current.isBefore(dateIReceived)) {
                                if (current.weekday != DateTime.friday && current.weekday != DateTime.saturday) {
                                  diff++;
                                }
                                current = current.add(const Duration(days: 1));
                              }
                              
                              return _buildDetailRow(
                                Icons.timelapse, 
                                'مدة بقاء الجهاز في الفرع', 
                                diff <= 0 ? 'نفس اليوم' : '$diff يوم',
                                isError: diff > 2,
                              );
                            }
                          ),
                          const Divider(),
                          _buildDetailRow(Icons.warning_amber_rounded, loc.deviceProblem, order.problem, isError: true),
                          const Divider(),
                          _buildDetailRow(Icons.info_outline, loc.deviceCondition, order.deviceCondition),
                          if (order.visualInspectionData != null && order.visualInspectionData!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.smartphone, size: 18, color: Colors.indigo),
                                label: const Text('عرض مخطط فحص الجوال والخدوش 📱', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => PhoneInspectionDialog(
                                      initialData: order.visualInspectionData,
                                      initialConditionText: order.deviceCondition,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          const Divider(),
                          _buildDetailRow(Icons.person, loc.delivererName, order.delivererName),
                          if (order.outOfWarrantyReason != null && order.outOfWarrantyReason!.isNotEmpty) ...[
                            const Divider(),
                            _buildDetailRow(Icons.warning_amber_rounded, 'سبب خروج الجهاز من الضمان', order.outOfWarrantyReason!, isError: true),
                          ],
                          if (order.repairCost != null && order.repairCost!.isNotEmpty) ...[
                            const Divider(),
                            _buildDetailRow(Icons.payments_outlined, 'تكلفة الإصلاح المقدرة', '${order.repairCost} SAR', isError: true),
                          ],
                          if (order.maintenancePdfUrl != null && order.maintenancePdfUrl!.isNotEmpty) ...[
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('تقرير الصيانة المرفق (PDF)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        SizedBox(height: 2),
                                        Text('ملف التقرير متوفر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.open_in_new, size: 16),
                                    label: const Text('فتح / مشاركة'),
                                    onPressed: () async {
                                      final url = order.maintenancePdfUrl!;
                                      if (url.startsWith('http')) {
                                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                      } else {
                                        await SharePlus.instance.share(ShareParams(files: [XFile(url)]));
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (order.accessories != null && order.accessories!.isNotEmpty) ...[
                            const Divider(),
                            _buildDetailRow(Icons.devices_other, 'الملحقات المستلمة', order.accessories!.join('، ')),
                          ],
                          if (order.intakeNotes != null && order.intakeNotes!.isNotEmpty) ...[
                            const Divider(),
                            _buildDetailRow(Icons.notes, 'ملاحظات الاستلام', order.intakeNotes!),
                          ],
                          if (order.handedOverWithAccessories != null) ...[
                            const Divider(),
                            _buildDetailRow(Icons.inventory, 'التسليم للصيانة', order.handedOverWithAccessories! ? 'تم التسليم مع الملحقات' : 'تم تسليم الجهاز فقط'),
                          ],
                          if (order.handoverNotes != null && order.handoverNotes!.isNotEmpty) ...[
                            const Divider(),
                            _buildDetailRow(Icons.note_alt, 'ملاحظات الصيانة', order.handoverNotes!),
                          ],
                          if (order.serviceCenterName != null && order.serviceCenterName!.isNotEmpty) ...[
                            const Divider(),
                            _buildDetailRow(Icons.build_circle_outlined, 'اسم مركز الصيانة', order.serviceCenterName!),
                          ],
                          if (order.serviceCenterOrderNumber != null && order.serviceCenterOrderNumber!.isNotEmpty) ...[
                            const Divider(),
                            _buildDetailRow(Icons.confirmation_number, 'رقم الطلب في مركز الصيانة', order.serviceCenterOrderNumber!),
                          ],
                          if (order.receiverName != null) ...[
                            const Divider(),
                            _buildDetailRow(Icons.person_outline, loc.receiverName, order.receiverName!),
                          ],
                          if (order.maintenanceResult != null && order.maintenanceResult!.isNotEmpty) ...[
                            const Divider(),
                            _buildDetailRow(Icons.check_circle_outline, 'نتيجة الصيانة', order.maintenanceResult!, isSuccess: true),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  _buildActionButtons(context, ref, loc, branchName),
                    
                  const SizedBox(height: 32),
                  Text('سجل تتبع الطلب (Timeline)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  historyAsync.when(
                    data: (history) {
                      if (history.isEmpty) return const Text('لا يوجد سجل لهذا الطلب بعد.');
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final item = history[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            color: Theme.of(context).scaffoldBackgroundColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                            child: ListTile(
                              leading: Icon(Icons.history, color: Theme.of(context).primaryColor),
                              title: Text(item.actionName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(item.timestamp)),
                              trailing: Text(item.userName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('خطأ: $e'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isError = false, bool isSuccess = false}) {
    Color? color;
    if (isError) color = Colors.red;
    if (isSuccess) color = Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, AppLocalizations loc, String branchName) {
    List<Widget> buttons = [];

    if (order.status == 'pending_service_center') {
      buttons.add(ElevatedButton.icon(
        onPressed: () => _showDeliverToServiceCenterDialog(context, ref),
        icon: const Icon(Icons.local_shipping),
        label: Text(loc.deliverToServiceCenterBtn),
      ));
    }

    if (order.status == 'delivered_service_center') {
      // 1. Button: Received from Maintenance (with daily reminder)
      buttons.add(ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
        onPressed: () => _showReceivedFromMaintenanceDialog(context, ref),
        icon: const Icon(Icons.inventory_2, color: Colors.white),
        label: const Text('تم استلام الجهاز من الصيانة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ));
      buttons.add(const SizedBox(height: 12));
      // 2. Button: Out of Warranty
      buttons.add(OutlinedButton.icon(
        onPressed: () => _showOutOfWarrantyDialog(context, ref, branchName),
        icon: const Icon(Icons.money_off),
        label: const Text('تحويل حالة الجهاز إلى خارج الضمان (إرسال واتساب للفرع)'),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
      ));
      buttons.add(const SizedBox(height: 12));
      buttons.add(OutlinedButton.icon(
        onPressed: () => _showMaintenanceResultDialog(context, ref),
        icon: const Icon(Icons.phone_in_talk),
        label: const Text('طلب موافقة العميل على الصيانة'),
      ));
    }

    if (order.status == 'received_from_maintenance') {
      // Status Banner
      buttons.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade300),
          ),
          child: const Row(
            children: [
              Icon(Icons.alarm, color: Colors.teal, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الأجهزة المستلمة من الصيانة 📦', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    SizedBox(height: 2),
                    Text('الجهاز بانتظار تسليمه للفرع. يوجد تذكير يومي نشط لحين التسليم.', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      // Button: Confirm delivery to branch -> sets status to completed
      buttons.add(ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () => _showDeliverToBranchDialog(context, ref, loc),
        icon: const Icon(Icons.verified, color: Colors.white),
        label: const Text('تأكيد تسليم الجهاز للفرع (اكتمال الطلب)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ));
    }

    if (order.status == 'out_of_warranty' || order.status == 'waiting_customer_approval') {
      // Button: Re-send WhatsApp message to branch
      buttons.add(ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
        onPressed: () => _showOutOfWarrantyDialog(context, ref, branchName),
        icon: const Icon(Icons.chat, color: Colors.white),
        label: const Text('إعادة إرسال رسالة الواتساب للفرع (English)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ));
      buttons.add(const SizedBox(height: 12));
      buttons.add(ElevatedButton.icon(
        onPressed: () => _updateStatus(context, ref, 'delivered_service_center', 'موافقة العميل - إرجاع لمركز الصيانة'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        icon: const Icon(Icons.thumb_up),
        label: const Text('العميل وافق على الإصلاح'),
      ));
      buttons.add(const SizedBox(height: 12));
      buttons.add(ElevatedButton.icon(
        onPressed: () => _updateStatus(context, ref, 'rejected_pending_delivery', 'العميل رفض الإصلاح'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        icon: const Icon(Icons.thumb_down),
        label: const Text('العميل رفض الإصلاح'),
      ));
    }

    if (order.status == 'rejected_pending_delivery') {
      buttons.add(ElevatedButton.icon(
        onPressed: () => _updateStatus(context, ref, 'received_from_maintenance', 'تم استلام الجهاز المرفوض من الصيانة وبانتظار تسليمه للفرع'),
        icon: const Icon(Icons.store_mall_directory),
        label: const Text('تم استلام الجهاز وجاهز للتسليم للفرع'),
      ));
    }

    if (order.status == 'delivered_branch') {
      buttons.add(ElevatedButton.icon(
        onPressed: () => _showDeliverToStoreDialog(context, ref, loc),
        icon: const Icon(Icons.done_all),
        label: const Text('تسليم للعميل وإغلاق الطلب'),
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: buttons,
    );
  }

  String _getStatusText(String status, AppLocalizations loc) {
    switch (status) {
      case 'pending_service_center': return loc.pendingServiceCenterDelivery;
      case 'delivered_service_center': return loc.underMaintenanceTab;
      case 'received_service_center': return loc.waitingCustomerApprovalTab;
      case 'waiting_customer_approval': return loc.waitingCustomerApprovalTab;
      case 'out_of_warranty': return loc.outOfWarrantyTab;
      case 'rejected_pending_delivery': return loc.rejectedPendingDeliveryTab;
      case 'received_from_maintenance': return 'الأجهزة المستلمة من الصيانة (بانتظار تسليمها للفرع)';
      case 'delivered_branch': return loc.completed;
      case 'completed': return loc.completed;
      default: return status;
    }
  }

  Widget _buildMaintenanceDaysBadge(int days) {
    Color color;
    if (days < 7) {
      color = Colors.white;
    } else if (days <= 11) {
      color = Colors.orange;
    } else {
      color = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(days < 7 ? 0.2 : 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '$days',
            style: TextStyle(color: days < 7 ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 24),
          ),
          Text(
            'يوم عمل',
            style: TextStyle(color: days < 7 ? Colors.white : color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
