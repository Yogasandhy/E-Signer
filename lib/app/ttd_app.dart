import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/app_theme.dart';
import 'app_dependencies.dart';
import 'app_root.dart';

class TtdApp extends StatelessWidget {
  const TtdApp({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: dependencies.providers,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeData,
        home: AppRoot(initialSession: dependencies.initialSession),
      ),
    );
  }
}

