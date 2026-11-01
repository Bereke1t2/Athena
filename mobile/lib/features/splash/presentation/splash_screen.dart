import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/prefs/user_preferences.dart';
import '../../../core/widgets/athena_launch_splash.dart';

/// Full-screen Splash View for Athena.
///
/// Features the decelerating spinning aperture logo, dynamic iris expansion,
/// and smooth transition into the application shell.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AthenaLaunchSplash(
        duration: const Duration(milliseconds: 2200),
        onCompleted: () {
          if (context.mounted) {
            final destination =
                UserPreferences.instance.onboarded ? '/' : '/onboarding';
            context.go(destination);
          }
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}
