import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart';
import '../../providers/services_provider.dart';
import '../../providers/branch_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/user_model.dart';
import '../../models/branch.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  String _searchQuery = '';
  String? _selectedRegionFilter;

  final List<String> _regions = [
    'الرياض / الوسطى',
    'جدة / مكة / الغربية',
    'الدمام / الخبر / الشرقية',
    'القصيم / الشمال',
    'أبها / جازان / الجنوبية',
    'كافة المناطق (عام)',
  ];

  Future<void> _showAddStaffDialog(BuildContext context, List<Branch> branches) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRegion = _regions.first;
    String selectedRole = 'staff';
    final List<String> selectedBranches = [];
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.indigo),
              SizedBox(width: 8),
              Text('إضافة موظف جديد'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الموظف',
                    hintText: 'مثال: أحمد العتيبي',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني / اسم الدخول',
                    hintText: 'ahmed@company.com',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور',
                    hintText: '6 أحرف أو أرقام على الأقل',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الجوال (اختياري)',
                    hintText: '05xxxxxxxx',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'المنطقة المسندة للموظف',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  value: selectedRegion,
                  items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRegion = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'نوع الحساب / الصلاحية',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'staff', child: Text('موظف ميداني / فني (Staff)')),
                    DropdownMenuItem(value: 'admin', child: Text('مشرف / مدير (Admin)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                if (branches.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('الفروع المخصصة للموظف (اختياري):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    height: 130,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: branches.length,
                      itemBuilder: (context, idx) {
                        final b = branches[idx];
                        final isChecked = selectedBranches.contains(b.id);
                        return CheckboxListTile(
                          dense: true,
                          title: Text(b.name, style: const TextStyle(fontSize: 13)),
                          value: isChecked,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedBranches.add(b.id);
                              } else {
                                selectedBranches.remove(b.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
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
                      final name = nameController.text.trim();
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();
                      final phone = phoneController.text.trim();

                      if (name.isEmpty || email.isEmpty || password.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('الرجاء تعبئة الاسم والإيميل وكلمة المرور')),
                        );
                        return;
                      }

                      if (password.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('كلمة المرور يجب أن لا تقل عن 6 أحرف')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      // Create user using a temporary secondary FirebaseApp instance
                      // so the current Admin does not get logged out!
                      FirebaseApp? tempApp;
                      try {
                        tempApp = await Firebase.initializeApp(
                          name: 'StaffRegister_${DateTime.now().millisecondsSinceEpoch}',
                          options: Firebase.app().options,
                        );

                        final userCred = await FirebaseAuth.instanceFor(app: tempApp).createUserWithEmailAndPassword(
                          email: email,
                          password: password,
                        );

                        final newUid = userCred.user!.uid;

                        final newUser = UserModel(
                          id: newUid,
                          name: name,
                          email: email,
                          role: selectedRole,
                          region: selectedRegion,
                          assignedBranchIds: selectedBranches.isNotEmpty ? selectedBranches : null,
                          phone: phone.isNotEmpty ? phone : null,
                          isActive: true,
                          createdAt: DateTime.now(),
                        );

                        await ref.read(firestoreServiceProvider).createUserDocument(newUser);

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Colors.green,
                              content: Text('تم إنشاء حساب الموظف بنجاح! 🎉'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ أثناء إنشاء الحساب: $e')),
                          );
                        }
                      } finally {
                        if (tempApp != null) {
                          await tempApp.delete();
                        }
                        if (context.mounted) {
                          setDialogState(() => isSaving = false);
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ وإنشاء الموظف'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditStaffDialog(BuildContext context, UserModel user, List<Branch> branches) async {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone ?? '');
    String selectedRegion = user.region != null && _regions.contains(user.region) ? user.region! : _regions.first;
    String selectedRole = user.role;
    final List<String> selectedBranches = List.from(user.assignedBranchIds ?? []);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('تعديل بيانات: ${user.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم الموظف', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'رقم الجوال', prefixIcon: Icon(Icons.phone)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'المنطقة', prefixIcon: Icon(Icons.location_on)),
                  value: selectedRegion,
                  items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRegion = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'الرتبة', prefixIcon: Icon(Icons.badge)),
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'staff', child: Text('موظف (Staff)')),
                    DropdownMenuItem(value: 'admin', child: Text('مدير (Admin)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final updatedUser = UserModel(
                  id: user.id,
                  name: nameController.text.trim(),
                  email: user.email,
                  role: selectedRole,
                  region: selectedRegion,
                  assignedBranchIds: selectedBranches.isNotEmpty ? selectedBranches : null,
                  phone: phoneController.text.trim(),
                  isActive: user.isActive,
                  createdAt: user.createdAt,
                );

                await ref.read(firestoreServiceProvider).updateUser(updatedUser);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث بيانات الموظف بنجاح')));
                }
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final branchesAsync = ref.watch(branchesProvider);
    final ordersAsync = ref.watch(ordersProvider);
    final branches = branchesAsync.value ?? [];
    final allOrders = ordersAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة ومتابعة الموظفين'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        onPressed: () => _showAddStaffDialog(context, branches),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة موظف جديد', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Theme.of(context).primaryColor,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'بحث باسم الموظف أو البريد أو المنطقة...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('جميع المناطق'),
                        selected: _selectedRegionFilter == null,
                        onSelected: (_) => setState(() => _selectedRegionFilter = null),
                      ),
                      const SizedBox(width: 6),
                      ..._regions.map((reg) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(reg),
                            selected: _selectedRegionFilter == reg,
                            onSelected: (selected) {
                              setState(() => _selectedRegionFilter = selected ? reg : null);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Staff List
          Expanded(
            child: usersAsync.when(
              data: (users) {
                final filtered = users.where((u) {
                  final matchesSearch = u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      u.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      (u.region != null && u.region!.toLowerCase().contains(_searchQuery.toLowerCase()));
                  final matchesRegion = _selectedRegionFilter == null || u.region == _selectedRegionFilter;
                  return matchesSearch && matchesRegion;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('لا يوجد موظفون مطابقون للبحث', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    // Count how many orders were handled by this user
                    final userOrdersCount = allOrders.where((o) => o.delivererName.contains(user.name)).length;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: user.isAdmin ? Colors.deepPurple : Colors.indigo,
                                  foregroundColor: Colors.white,
                                  radius: 22,
                                  child: Text(
                                    user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              user.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: user.isAdmin ? Colors.deepPurple.shade50 : Colors.indigo.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              user.isAdmin ? 'مدير' : 'موظف',
                                              style: TextStyle(
                                                color: user.isAdmin ? Colors.deepPurple : Colors.indigo,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user.email.isNotEmpty ? user.email : 'بدون بريد',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: user.isActive,
                                  activeColor: Colors.green,
                                  onChanged: (val) async {
                                    await ref.read(firestoreServiceProvider).toggleUserStatus(user.id, val);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(val ? 'تم تفعيل الحساب' : 'تم تعطيل الحساب')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                if (user.region != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                                      const SizedBox(width: 4),
                                      Text('المنطقة: ${user.region}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                if (user.phone != null && user.phone!.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.phone, size: 16, color: Colors.teal),
                                      const SizedBox(width: 4),
                                      Text(user.phone!, style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.assignment, size: 16, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text('الطلبات المرتبطة: $userOrdersCount', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('تعديل البيانات', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _showEditStaffDialog(context, user, branches),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  label: const Text('حذف', style: TextStyle(fontSize: 12, color: Colors.red)),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('حذف حساب الموظف'),
                                        content: Text('هل أنت متأكد من حذف حساب "${user.name}"؟'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                            onPressed: () => Navigator.pop(c, true),
                                            child: const Text('تأكيد الحذف'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ref.read(firestoreServiceProvider).deleteUser(user.id);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
