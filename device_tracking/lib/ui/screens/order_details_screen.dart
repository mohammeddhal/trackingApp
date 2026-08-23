import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_tracking/l10n/generated/app_localizations.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../providers/services_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/branch_provider.dart';
import '../../models/branch.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      } else if (newStatus == 'delivered_service_center') {
        await NotificationService().cancelBranchDelays(order.id);
        await NotificationService().cancelMaintenanceDelays(order.id);
        await NotificationService().scheduleMaintenanceDelays(order.id, order.orderNumber, DateTime.now());
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
                          const Divider(),
                          _buildDetailRow(Icons.person, loc.delivererName, order.delivererName),
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
                  _buildActionButtons(context, ref, loc),
                    
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

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, AppLocalizations loc) {
    List<Widget> buttons = [];

    if (order.status == 'pending_service_center') {
      buttons.add(ElevatedButton.icon(
        onPressed: () => _showDeliverToServiceCenterDialog(context, ref),
        icon: const Icon(Icons.local_shipping),
        label: Text(loc.deliverToServiceCenterBtn),
      ));
    }

    if (order.status == 'delivered_service_center') {
      buttons.add(ElevatedButton.icon(
        onPressed: () => _updateStatus(context, ref, 'delivered_branch', 'تم استلام الجهاز وجاهز للتسليم في الفرع'),
        icon: const Icon(Icons.store),
        label: const Text('تأكيد استلامه وتسليمه للفرع'),
      ));
      buttons.add(const SizedBox(height: 12));
      buttons.add(OutlinedButton.icon(
        onPressed: () => _updateStatus(context, ref, 'out_of_warranty', 'تعيين الجهاز كخارج الضمان'),
        icon: const Icon(Icons.money_off),
        label: const Text('تحويل حالة الجهاز إلى خارج الضمان'),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
      ));
    }

    if (order.status == 'out_of_warranty' || order.status == 'waiting_customer_approval') {
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
        onPressed: () => _updateStatus(context, ref, 'delivered_branch', 'تم تسليم الجهاز للمتجر'),
        icon: const Icon(Icons.store_mall_directory),
        label: const Text('تسليم الجهاز للمتجر'),
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
