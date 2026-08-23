import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_tracking/l10n/generated/app_localizations.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.trackOrders),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: loc.search,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ordersAsync.when(
          data: (orders) {
            final filteredOrders = orders.where((order) {
              return order.orderNumber.contains(_searchQuery) ||
                  order.imeiOrSerial.contains(_searchQuery) ||
                  (order.serviceCenterOrderNumber != null && order.serviceCenterOrderNumber!.contains(_searchQuery)) ||
                  order.productName.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection(
                  title: loc.pendingServiceCenterDelivery,
                  icon: Icons.local_shipping,
                  color: Colors.blue,
                  status: 'pending_service_center',
                  orders: filteredOrders,
                  loc: loc,
                  initiallyExpanded: true, // Only this section is open by default
                ),
                _buildSection(
                  title: loc.underMaintenanceTab,
                  icon: Icons.build_circle,
                  color: Colors.orange,
                  status: 'delivered_service_center',
                  orders: filteredOrders,
                  loc: loc,
                ),
                _buildSection(
                  title: loc.waitingCustomerApprovalTab,
                  icon: Icons.phone_in_talk,
                  color: Colors.purple,
                  status: 'waiting_customer_approval',
                  orders: filteredOrders,
                  loc: loc,
                ),
                _buildSection(
                  title: loc.outOfWarrantyTab,
                  icon: Icons.money_off,
                  color: Colors.deepOrange,
                  status: 'out_of_warranty',
                  orders: filteredOrders,
                  loc: loc,
                ),
                _buildSection(
                  title: loc.rejectedPendingDeliveryTab,
                  icon: Icons.cancel,
                  color: Colors.red,
                  status: 'rejected_pending_delivery',
                  orders: filteredOrders,
                  loc: loc,
                ),
                _buildSection(
                  title: loc.completed,
                  icon: Icons.check_circle,
                  color: Colors.green,
                  status: 'completed',
                  orders: filteredOrders,
                  loc: loc,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required String status,
    required List<OrderModel> orders,
    required AppLocalizations loc,
    bool initiallyExpanded = false,
  }) {
    final statusOrders = orders.where((o) {
      if (status == 'waiting_customer_approval') {
        return o.status == status || o.status == 'received_service_center';
      }
      if (status == 'completed') {
        return o.status == status || o.status == 'delivered_branch';
      }
      return o.status == status;
    }).toList();

    // Hide empty sections when user is searching to make results cleaner
    if (statusOrders.isEmpty && _searchQuery.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded || _searchQuery.isNotEmpty,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${statusOrders.length}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          children: [
            if (statusOrders.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text('لا توجد طلبات في هذا القسم', style: TextStyle(color: Colors.grey.shade500)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: statusOrders.length,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemBuilder: (context, index) {
                  final order = statusOrders[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push('/order_details', extra: order),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.smartphone, color: Theme.of(context).primaryColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.productName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'رقم الطلب: ${order.orderNumber}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 10, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('yyyy-MM-dd').format(order.receivedFromCustomerDate),
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildMaintenanceDaysBadge(order.maintenanceDays),
                                const SizedBox(height: 8),
                                Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceDaysBadge(int days) {
    Color color;
    if (days < 7) {
      color = Colors.green;
    } else if (days <= 11) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$days يوم',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}
