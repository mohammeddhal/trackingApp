import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/language_selection_screen.dart';
import '../ui/screens/intake_screen.dart';
import '../ui/screens/orders_screen.dart';
import '../ui/screens/branches_screen.dart';
import '../ui/screens/order_details_screen.dart';
import '../models/order_model.dart';
import '../main.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final initialHasLanguage = prefs.getString('selected_locale') != null;

  return GoRouter(
    initialLocation: initialHasLanguage ? (authState.value != null ? '/' : '/login') : '/language',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final hasLanguage = prefs.getString('selected_locale') != null;
      final isAuth = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isLanguageSelect = state.matchedLocation == '/language';

      if (!hasLanguage && !isLanguageSelect) return '/language';
      if (hasLanguage && !isAuth && !isLoggingIn && !isLanguageSelect) return '/login';
      if (isAuth && isLoggingIn) return '/';
      if (hasLanguage && isLanguageSelect) return isAuth ? '/' : '/login';

      return null;
    },
    routes: [
      GoRoute(
        path: '/language',
        builder: (context, state) => const LanguageSelectionScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/intake',
        builder: (context, state) {
          final existingOrder = state.extra as OrderModel?;
          return IntakeScreen(existingOrder: existingOrder);
        },
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/branches',
        builder: (context, state) => const BranchesScreen(),
      ),
      GoRoute(
        path: '/order_details',
        builder: (context, state) {
          final order = state.extra as OrderModel;
          return OrderDetailsScreen(order: order);
        },
      ),
    ],
  );
});
