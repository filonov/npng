import 'dart:io' show Platform;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/repository.dart';
import 'data/sqlite/sqlite_repository.dart';
import 'generated/l10n.dart';
import 'logic/cubit/current_tab_cubit.dart';
import 'logic/cubit/default_program_cubit.dart';
import 'logic/cubit/workout_cubit.dart';
import 'presentation/routes/route_map.dart';

// final bool isApple = !kIsWeb && (Platform.isMacOS || Platform.isIOS);
// bool get isMobileDevice => !kIsWeb && (Platform.isIOS || Platform.isAndroid);
// bool get isMobileDeviceOrWeb => kIsWeb || isMobileDevice;
// bool get isDesktopDeviceOrWeb => kIsWeb || isDesktopDevice;

final bool isDesktopDevice =
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = SqliteRepository();
  await repository.init();
  late int defaultProgram;

  // Get default program.
  defaultProgram = await repository.getCurrentProgramId();



  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<CurrentTabCubit>(
          create: (context) => CurrentTabCubit(),
        ),
        BlocProvider<DefaultProgramCubit>(
          create: (context) =>
              DefaultProgramCubit(defaultProgram: defaultProgram),
        ),
        BlocProvider<WorkoutCubit>(create: (context) => WorkoutCubit()),
      ],
      child: RepositoryProvider<Repository>(
        lazy: false,
        create: (_) => repository,
        child: const Application(),
      ),
    ),
  );
}

class Application extends StatelessWidget {
  const Application({super.key});
  static final _defaultLightColorScheme = ColorScheme.fromSwatch();
  static final _defaultDarkColorScheme =
      ColorScheme.fromSwatch(brightness: Brightness.dark);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        //locale: const Locale('ru', 'RU'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        onGenerateTitle: (BuildContext context) => S.of(context).title,
        theme: ThemeData(
          colorScheme: lightColorScheme ?? _defaultLightColorScheme,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: darkColorScheme ?? _defaultDarkColorScheme,
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        initialRoute: kInitialRoute,
        routes: appRoutes,
      );
    });
  }
}
