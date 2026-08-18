import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;
// UGFUGYUFFYGU
import 'core/config/supabase_config.dart';
import 'core/routing/app_router.dart';
import 'core/theme/theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/services/auth_scope.dart';
import 'features/auth/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load configuration and initialize shared Supabase client
  final initialized = await SupabaseConfig.initialize();

  late final AuthService authService;

  if (initialized) {
    // Internal connectivity diagnostic pre-check
    unawaited(SupabaseConfig.checkConnectivity());

    final repository = AuthRepository(
      client: supabase_flutter.Supabase.instance.client,
    );

    authService = AuthService(repository);
  } else {
    // Local / test mode when environment variables are not configured
    authService = AuthService(null);
  }

  authService.initialize();

  runApp(
    AuthScope(
      service: authService,
      child: const SalonQueueApp(),
    ),
  );
}

class SalonQueueApp extends StatelessWidget {
  const SalonQueueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salon Queue',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.generateRoute,
      onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
    );
  }
}