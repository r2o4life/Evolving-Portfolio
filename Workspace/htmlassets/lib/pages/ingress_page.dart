import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:html_artifact_pipeline/nav.dart';
import 'package:html_artifact_pipeline/theme.dart';

class IngressPage extends StatefulWidget {
  const IngressPage({super.key});

  @override
  State<IngressPage> createState() => _IngressPageState();
}

class _IngressPageState extends State<IngressPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openCompiler(String prompt) {
    if (prompt.trim().isEmpty) return;
    context.push(AppRoutes.compiler, extra: prompt.trim());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1024),
            child: ListView(
              padding: AppSpacing.paddingXl,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Web Paradigm Engine',
                  style: context.textStyles.headlineLarge?.semiBold?.withColor(cs.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a macro blueprint to instantiate or command a custom payload.',
                  style: context.textStyles.titleMedium?.withColor(cs.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                
                // BENTO GRID
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    if (isWide) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _BentoCard(
                                title: 'Stripe-Style Mega Flyout',
                                subtitle: 'Contextual navigation with fluid spatial continuity.',
                                icon: Icons.explore_rounded,
                                color: Colors.indigo.shade400,
                                onTap: () => _openCompiler('Stripe-style mega flyout navigation menu with nested feature lists'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _BentoCard(
                                      title: 'Apple-Style Bento Grid',
                                      subtitle: 'High-impact macro grouping.',
                                      icon: Icons.grid_view_rounded,
                                      color: Colors.grey.shade800,
                                      onTap: () => _openCompiler('Apple-style bento grid layout with large feature cards'),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: _BentoCard(
                                      title: 'Linear Command-K',
                                      subtitle: 'Ultra-high-density operational matrix.',
                                      icon: Icons.keyboard_command_key_rounded,
                                      color: Colors.teal.shade600,
                                      onTap: () => _openCompiler('Linear command-k matrix palette with search and shortcuts'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: _BentoCard(
                                title: 'Vercel Telemetry',
                                subtitle: 'Real-time delta metrics.',
                                icon: Icons.timeline_rounded,
                                color: Colors.blueGrey.shade700,
                                onTap: () => _openCompiler('Vercel-style deployment telemetry dashboard with graphs'),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return Column(
                        children: [
                          _BentoCard(
                            title: 'Stripe-Style Mega Flyout',
                            subtitle: 'Contextual navigation with fluid spatial continuity.',
                            icon: Icons.explore_rounded,
                            color: Colors.indigo.shade400,
                            onTap: () => _openCompiler('Stripe-style mega flyout navigation menu with nested feature lists'),
                          ),
                          const SizedBox(height: 16),
                          _BentoCard(
                            title: 'Apple-Style Bento Grid',
                            subtitle: 'High-impact macro grouping.',
                            icon: Icons.grid_view_rounded,
                            color: Colors.grey.shade800,
                            onTap: () => _openCompiler('Apple-style bento grid layout with large feature cards'),
                          ),
                          const SizedBox(height: 16),
                          _BentoCard(
                            title: 'Linear Command-K',
                            subtitle: 'Ultra-high-density operational matrix.',
                            icon: Icons.keyboard_command_key_rounded,
                            color: Colors.teal.shade600,
                            onTap: () => _openCompiler('Linear command-k matrix palette with search and shortcuts'),
                          ),
                          const SizedBox(height: 16),
                          _BentoCard(
                            title: 'Vercel Telemetry',
                            subtitle: 'Real-time delta metrics.',
                            icon: Icons.timeline_rounded,
                            color: Colors.blueGrey.shade700,
                            onTap: () => _openCompiler('Vercel-style deployment telemetry dashboard with graphs'),
                          ),
                        ],
                      );
                    }
                  },
                ),
                
                const SizedBox(height: 32),
                
                // CUSTOM PAYLOAD
                Card(
                  elevation: 0,
                  color: cs.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.terminal_rounded, size: 20, color: cs.primary),
                            const SizedBox(width: 12),
                            Text('Custom Payload Initialization', style: context.textStyles.titleMedium?.semiBold),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (v) => _openCompiler(v),
                          decoration: InputDecoration(
                            hintText: 'e.g. minimalist blog index, generative art gallery...',
                            filled: true,
                            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilledButton.icon(
                                onPressed: () => _openCompiler(_controller.text),
                                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                label: const Text('Execute'),
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white24,
        highlightColor: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const Spacer(),
              const SizedBox(height: 24),
              Text(
                title,
                style: context.textStyles.titleLarge?.semiBold?.copyWith(color: Colors.white, height: 1.1),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: context.textStyles.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
