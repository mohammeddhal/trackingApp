import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/branch.dart';

class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _searchQuery = '';
  bool _isAdding = false;

  Future<void> _addBranch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isAdding = true);
    try {
      await FirebaseFirestore.instance.collection('branches').add({
        'name': _nameController.text.trim(),
        'code': _codeController.text.trim(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _nameController.clear();
      _codeController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('تمت إضافة الفرع بنجاح! 🎉'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء إضافة الفرع: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _showEditBranchDialog(Branch branch) async {
    final editNameController = TextEditingController(text: branch.name);
    final editCodeController = TextEditingController(text: branch.code);
    final editFormKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: Colors.blue),
              SizedBox(width: 8),
              Text('تعديل بيانات الفرع'),
            ],
          ),
          content: Form(
            key: editFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: editNameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الفرع',
                    hintText: 'مثال: فرع طويق أو الظهران',
                    prefixIcon: Icon(Icons.store),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال اسم الفرع' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: editCodeController,
                  decoration: const InputDecoration(
                    labelText: 'كود الفرع',
                    hintText: 'مثال: 9551 أو TWQ',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال كود الفرع' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!editFormKey.currentState!.validate()) return;

                      setDialogState(() => isSaving = true);
                      try {
                        await FirebaseFirestore.instance.collection('branches').doc(branch.id).update({
                          'name': editNameController.text.trim(),
                          'code': editCodeController.text.trim(),
                        });

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Colors.green,
                              content: Text('تم تحديث بيانات الفرع بنجاح'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ أثناء التحديث: $e')),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => isSaving = false);
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteBranchDialog(Branch branch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('حذف الفرع'),
          ],
        ),
        content: Text('هل أنت متأكد من حذف فرع "${branch.name}" (${branch.code}) نهائياً من النظام؟\n\nلن يتمكن المسؤولون من اختيار هذا الفرع بعد حذفه.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('branches').doc(branch.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text('تم حذف فرع "${branch.name}" بنجاح'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ أثناء الحذف: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفروع (Branches)'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Add Branch Form
          Card(
            margin: const EdgeInsets.all(16.0),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.add_business, color: Colors.indigo),
                        SizedBox(width: 8),
                        Text(
                          'إضافة فرع جديد',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم الفرع',
                              hintText: 'مثال: طويق أو الظهران',
                              prefixIcon: Icon(Icons.store),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _codeController,
                            decoration: const InputDecoration(
                              labelText: 'كود الفرع',
                              hintText: 'مثال: 9551',
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isAdding ? null : _addBranch,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isAdding
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add),
                      label: Text(_isAdding ? 'جاري الإضافة...' : 'إضافة الفرع للنظام'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث باسم الفرع أو الكود...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          const SizedBox(height: 8),

          // Branches List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('branches').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('لا يوجد فروع مضافة بعد', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  );
                }

                final branches = docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return Branch.fromMap(data, d.id);
                }).where((b) {
                  if (_searchQuery.isEmpty) return true;
                  return b.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      b.code.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();

                if (branches.isEmpty) {
                  return const Center(
                    child: Text('لا توجد فروع مطابقة للبحث', style: TextStyle(color: Colors.grey, fontSize: 15)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: branches.length,
                  itemBuilder: (context, index) {
                    final branch = branches[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: branch.isActive ? Colors.grey.shade200 : Colors.red.shade100),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: branch.isActive ? Colors.indigo.shade50 : Colors.grey.shade200,
                          child: Icon(
                            Icons.store,
                            color: branch.isActive ? Colors.indigo : Colors.grey,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                branch.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: branch.isActive ? null : TextDecoration.lineThrough,
                                  color: branch.isActive ? null : Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                branch.code,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          branch.isActive ? 'مفعل لاستلام الأجهزة' : 'معطل مؤقتاً',
                          style: TextStyle(
                            fontSize: 12,
                            color: branch.isActive ? Colors.green.shade700 : Colors.red.shade400,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 22),
                              tooltip: 'تعديل اسم وكود الفرع',
                              onPressed: () => _showEditBranchDialog(branch),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                              tooltip: 'حذف الفرع نهائياً',
                              onPressed: () => _showDeleteBranchDialog(branch),
                            ),
                            Switch(
                              value: branch.isActive,
                              onChanged: (val) {
                                FirebaseFirestore.instance
                                    .collection('branches')
                                    .doc(branch.id)
                                    .update({'isActive': val});
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
