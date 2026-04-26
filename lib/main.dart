import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/module_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final moduleService = ModuleService();
  unawaited(moduleService.initialize());
  runApp(RitaApp(moduleService: moduleService));
}

class RitaApp extends StatelessWidget {
  final ModuleService moduleService;
  const RitaApp({super.key, required this.moduleService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ModuleService>.value(
      value: moduleService,
      child: MaterialApp(
        title: 'Rita',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const HomeScreen(),
      ),
    );
  }
}
