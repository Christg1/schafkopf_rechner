import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
            ),
          ),
          // Decorative cards in top-right with rotations
          Positioned(
            top: screenSize.height * 0.12,
            right: screenSize.width * 0.05,
            child: Transform.rotate(
              angle: 0.2,
              child: Image.asset(
                'assets/images/herz.png',
                width: screenSize.width * 0.07,
              ),
            ),
          ),
          Positioned(
            top: screenSize.height * 0.14,
            right: screenSize.width * 0.15,
            child: Transform.rotate(
              angle: -0.1,
              child: Image.asset(
                'assets/images/eichel.png',
                width: screenSize.width * 0.07,
              ),
            ),
          ),
          // Karten.png on the left side
          Positioned(
            top: screenSize.height * 0.13,
            left: screenSize.width * 0.05,
            child: Transform.rotate(
              angle: -0.15,
              child: Image.asset(
                'assets/images/karten.png',
                width: screenSize.width * 0.20,
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // Logo/Title Area
                  Image.asset(
                    'assets/images/schafkopf.png',
                    width: screenSize.width * 0.18,
                  ),
                  const SizedBox(height: 16),
                  Stack(
                    children: [
                      // Shadow layer
                      Text(
                        'Schafkopf\nRechner',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cinzel(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black.withOpacity(0.3),
                          height: 1.2,
                        ),
                      ).translate(offset: const Offset(2, 2)),
                      // Main text with gradient
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.onPrimary,
                            Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds),
                        child: Text(
                          'Schafkopf\nRechner',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cinzel(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Menu Options
                  _MenuButton(
                    icon: Icons.play_circle,
                    label: 'Neue Session',
                    onTap: () => Navigator.pushNamed(context, '/lobby'),
                  ),
                  const SizedBox(height: 16),
                  _MenuButton(
                    icon: Icons.bar_chart,
                    label: 'Statistiken',
                    onTap: () => Navigator.pushNamed(context, '/statistics'),
                  ),
                  const SizedBox(height: 16),
                  _MenuButton(
                    icon: Icons.settings,
                    label: 'Einstellungen',
                    onTap: () => Navigator.pushNamed(context, '/settings'),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(
            children: [
              Icon(icon, size: 32),
              const SizedBox(width: 16),
              Text(
                label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }
}

// Extension for easy text translation
extension on Widget {
  Widget translate({required Offset offset}) {
    return Transform.translate(
      offset: offset,
      child: this,
    );
  } }