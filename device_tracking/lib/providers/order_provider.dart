import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_model.dart';
import '../models/order_history.dart';
import 'services_provider.dart';

final ordersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getOrders();
});

final orderHistoryProvider = StreamProvider.family<List<OrderHistory>, String>((ref, orderId) {
  return ref.watch(firestoreServiceProvider).getOrderHistory(orderId);
});
