import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_tracking/l10n/generated/app_localizations.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/order_provider.dart';
import '../../providers/branch_provider.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isExporting = false;

  Future<void> _exportToExcel(WidgetRef ref, BuildContext context, AppLocalizations loc) async {
    setState(() => _isExporting = true);
    try {
      final orders = ref.read(ordersProvider).value ?? [];
      
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Orders'];
      excel.setDefaultSheet('Orders');
      
      // Header
      List<String> headers = [
        loc.orderNumber,
        loc.branch,
        loc.deviceType,
        loc.manufacturer,
        loc.productName,
        loc.imeiOrSerial,
        loc.status,
        loc.date,
        loc.receiverName,
      ];
      sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

      // Data
      for (var order in orders) {
        List<String> row = [
          order.orderNumber,
          order.branchId, // Ideally map to branch name
          order.deviceType,
          order.manufacturer,
          order.productName,
          order.imeiOrSerial,
          order.status,
          DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt),
          order.receiverName ?? '',
        ];
        sheetObject.appendRow(row.map((e) => TextCellValue(e)).toList());
      }

      var fileBytes = excel.save();
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/orders_report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File saved successfully: ${file.path}')),
          );
          
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'Device Tracking Report',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final ordersAsync = ref.watch(ordersProvider);
    final branchesAsync = ref.watch(branchesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.reports),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _exportToExcel(ref, context, loc),
              tooltip: loc.exportExcel,
            ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) {
          final completedOrders = orders.where((o) => o.status == 'completed').length;
          final pendingOrders = orders.where((o) => o.status != 'completed').length;
          
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Total Orders'),
                  trailing: Text(orders.length.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              Card(
                child: ListTile(
                  title: Text('Completed Orders'),
                  trailing: Text(completedOrders.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              ),
              Card(
                child: ListTile(
                  title: Text('Pending/In Process'),
                  trailing: Text(pendingOrders.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
