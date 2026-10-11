import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:device_tracking/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/services_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final userAsync = ref.watch(currentUserModelProvider);
    final user = userAsync.value;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.appTitle),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: 'تغيير اللغة',
            onPressed: () => context.push('/language'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تسجيل خروج'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authServiceProvider).signOut();
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لوحة التحكم',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (user != null)
                        Text(
                          'المستخدم: ${user.name} (${user.isAdmin ? 'مدير' : 'موظف'})${user.region != null ? ' - ${user.region}' : ''}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  children: [
                    _buildDashboardCard(
                      context,
                      title: loc.receiveDevice,
                      icon: Icons.add_to_photos_rounded,
                      color: const Color(0xFF14803B),
                      onTap: () => context.push('/intake'),
                    ),
                    _buildDashboardCard(
                      context,
                      title: loc.trackOrders,
                      icon: Icons.list_alt_rounded,
                      color: const Color(0xFF0D47A1),
                      onTap: () => context.push('/orders'),
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'إدارة الفروع',
                      icon: Icons.storefront_rounded,
                      color: const Color(0xFFE65100),
                      onTap: () => context.push('/branches'),
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'إدارة ومتابعة الموظفين',
                      icon: Icons.people_alt_rounded,
                      color: Colors.indigo,
                      onTap: () => context.push('/staff'),
                    ),
                    _buildDashboardCard(
                      context,
                      title: 'التقارير',
                      icon: Icons.bar_chart_rounded,
                      color: const Color(0xFF6A1B9A),
                      onTap: () => context.push('/reports'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
