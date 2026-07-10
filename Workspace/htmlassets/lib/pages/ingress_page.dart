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
  final _controller = TextEditingController(text: 'drone');
  bool _advanced = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openCompiler() {
    final prompt = _controller.text.trim();
    context.push(AppRoutes.compiler, extra: prompt);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: AppSpacing.paddingXl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _HeroHeader(advancedHint: _advanced),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: AppSpacing.paddingLg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Semantic object', style: context.textStyles.titleMedium?.semiBold),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.go,
                            onSubmitted: (_) => _openCompiler(),
                            decoration: InputDecoration(
                              hintText: 'e.g. drone, bonsai, racing helmet, protein fold…',
                              filled: true,
                              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: _advanced
                                      ? Text('Advanced knobs live in the next screen.', key: const ValueKey('advOn'), style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant))
                                      : Text('Start simple—add constraints later.', key: const ValueKey('advOff'), style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilterChip(
                                label: const Text('Advanced'),
                                selected: _advanced,
                                onSelected: (v) => setState(() => _advanced = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: 220,
                            child: FilledButton.icon(
                              onPressed: _openCompiler,
                              icon: Icon(Icons.play_arrow_rounded, color: cs.onPrimary),
                              label: Text('Compile', style: TextStyle(color: cs.onPrimary)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text('Prompt → Firebase proxy → compile → preview', style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.advancedHint});

  final bool advancedHint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.85),
            cs.surfaceContainerHighest.withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: cs.primary,
            ),
            child: Icon(Icons.auto_fix_high_rounded, color: cs.onPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Asset Compiler', style: context.textStyles.headlineSmall?.semiBold?.withColor(cs.onPrimaryContainer)),
                const SizedBox(height: 6),
                Text(
                  'Prompt → compile → preview → export HTML. This build fakes the compiler but keeps the UX real.',
                  style: context.textStyles.bodyMedium?.withColor(cs.onPrimaryContainer.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniTag(icon: Icons.bolt_rounded, text: 'Deterministic seed'),
                    _MiniTag(icon: Icons.web_rounded, text: 'Single-file artifact'),
                    _MiniTag(icon: advancedHint ? Icons.tune_rounded : Icons.tune_outlined, text: advancedHint ? 'Knobs ready' : 'Knobs optional'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.surface.withValues(alpha: 0.50),
        border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(text, style: context.textStyles.labelMedium?.withColor(cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
