import 'package:flutter/material.dart';

/// Version de l'app, fixée au moment de la fabrication (tool/build_web.sh).
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

/// Affiché à la place d'un chargement sans fin quand une lecture échoue.
class DataError extends StatelessWidget {
  const DataError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade800),
          const SizedBox(height: 8),
          const Text(
            'Impossible d\'afficher ces informations. Fermez et rouvrez Mano ; '
            'si le message revient, envoyez une capture de cet écran.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SelectableText(
            'Version $appVersion\n$error',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
