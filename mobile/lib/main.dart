import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/prefs/prefs_providers.dart';
import 'core/prefs/saved_papers.dart';
import 'core/prefs/user_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Interests gate the router redirect and the reading list primes the
  // library, so both must be on disk before routing starts.
  await UserPreferences.instance.load();
  await SavedPapers.prime();
  runApp(const ProviderScope(child: AthenaApp()));
}

class AthenaApp extends ConsumerWidget {
  const AthenaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeModeProvider);

    return MaterialApp.router(
      title: 'Athena',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: buildAppRouter(),
    );
  }
}
