import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return settingsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
      data: (settings) => Scaffold(
        appBar: AppBar(
          title: const Text('Einstellungen'),
        ),
        body: ListView(
          children: [
            const _SettingsHeader('Darstellung'),
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Dunkles Erscheinungsbild aktivieren'),
              value: settings.isDarkMode,
              onChanged: (_) => ref
                  .read(settingsNotifierProvider.notifier)
                  .toggleDarkMode(),
            ),
            const Divider(),
            
            const _SettingsHeader('Spieleinstellungen'),
            SwitchListTile(
              title: const Text('Cent statt Euro'),
              subtitle: const Text('Beträge in Cent anzeigen'),
              value: settings.showCentsInstead,
              onChanged: (_) => ref
                  .read(settingsNotifierProvider.notifier)
                  .toggleShowCents(),
            ),
            ListTile(
              title: const Text('Standard Grundwert'),
              subtitle: Text('${settings.defaultBaseValue} Cent'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: settings.defaultBaseValue <= 5
                        ? null
                        : () => ref
                            .read(settingsNotifierProvider.notifier)
                            .updateBaseValue(settings.defaultBaseValue - 5),
                  ),
                  Text(settings.defaultBaseValue.toString()),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: settings.defaultBaseValue >= 50
                        ? null
                        : () => ref
                            .read(settingsNotifierProvider.notifier)
                            .updateBaseValue(settings.defaultBaseValue + 5),
                  ),
                ],
              ),
            ),
            const Divider(),

            const _SettingsHeader('Über'),
            const ListTile(
              title: Text('Version'),
              subtitle: Text('1.0.0'),
            ),
            ListTile(
              title: const Text('Entwickler'),
              subtitle: const Text('Your Name'),
              onTap: () {
                // Could open a dialog with more info or link to website
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final String title;

  const _SettingsHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
} 