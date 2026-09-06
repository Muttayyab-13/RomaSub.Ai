import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_assets.dart';
import '../core/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        AppRoutes.replace(context, AppRoutes.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Image.asset(
          AppAssets.logoAlt,
          width: 140,
          height: 140,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.video_library,
            size: 100,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}
