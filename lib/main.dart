import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/database.dart';
import 'home_screen.dart';

void main() {
  runApp(ManoApp(database: AppDatabase()));
}

class ManoApp extends StatelessWidget {
  const ManoApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mano',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B7F5A)),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: _Startup(database: database),
    );
  }
}

/// Ouvre la base (et fait ses mises à jour) avant d'afficher l'app.
/// En cas de problème, affiche un message au lieu d'un chargement sans fin.
class _Startup extends StatefulWidget {
  const _Startup({required this.database});

  final AppDatabase database;

  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  late final Future<void> _open = widget.database.ensureOpen().timeout(
    const Duration(seconds: 60),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _open,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupError(error: snapshot.error!);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Ouverture de vos données...'),
                ],
              ),
            ),
          );
        }
        return HomeScreen(database: widget.database);
      },
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade800),
            const SizedBox(height: 16),
            Text(
              'Mano n\'arrive pas à ouvrir vos données',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Vos données ne sont pas effacées. Fermez Mano et rouvrez-la. '
              'Si le message revient, faites une capture de cet écran et '
              'envoyez-la pour obtenir de l\'aide. Ne supprimez pas Mano.',
            ),
            const SizedBox(height: 16),
            SelectableText(
              '$error',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
