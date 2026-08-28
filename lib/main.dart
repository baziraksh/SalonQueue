import 'dart:async';

import 'package:flutter/material.dart';
import 'core/routing/app_router.dart';
import 'core/theme/theme.dart';
import 'features/auth/services/auth_scope.dart';
import 'features/auth/services/auth_service.dart';
import 'features/salon/data/salon_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload disk cached salons for instant frame-1 display
  unawaited(SalonRepository.initDiskCache());

  // Instantiate the shared AuthService with asynchronous background Supabase startup
  final authService = AuthService(null);
  unawaited(authService.initializeAsync());

  // Render the Flutter splash screen immediately on frame 1 without startup block
  runApp(AuthScope(service: authService, child: const SalonQueueApp()));
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
