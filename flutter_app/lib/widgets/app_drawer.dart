import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/simulation_states.dart';
import '../models/simulation_summary.dart';

/// Navegação lateral do app (menu hambúrguer nativo do `Scaffold.drawer`) —
/// adaptação para celular da barra lateral fixa do design "Cadastro Fazenda
/// Wizard" (que usava uma coluna de 360px, inviável numa tela de celular;
/// ver docs/REQUIREMENTS.md RNF-01). Mostra a "fazenda ativa" (conceito só
/// de UI, não existe no backend) e permite trocá-la; não há campo "nome" de
/// fazenda no backend, então o resumo usa vacas/bezerras como identificador,
/// igual à lista da Tela 1.
class AppDrawer extends StatefulWidget {
  final List<SimulationSummary> simulations;
  final String? activeId;
  final ValueChanged<String> onSelectActive;

  /// Quando true, renderiza como painel fixo (web/navegador) em vez de
  /// gaveta deslizante (mobile) — ver farm_list_screen.dart, que decide
  /// qual modo usar por `kIsWeb`. Mesmo conteúdo nos dois casos.
  final bool asSidebar;

  const AppDrawer({
    super.key,
    required this.simulations,
    required this.activeId,
    required this.onSelectActive,
    this.asSidebar = false,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _switcherOpen = false;

  SimulationSummary? get _active {
    final id = widget.activeId;
    if (id == null) return null;
    for (final sim in widget.simulations) {
      if (sim.simulationId == id) return sim;
    }
    return null;
  }

  String _resumo(SimulationSummary sim) => '${sim.farm.cowNum} vacas · ${sim.farm.calfNum} bezerras';

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final textTheme = Theme.of(context).textTheme;

    final content = SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.lightGreen,
                    foregroundColor: AppColors.primaryGreen,
                    child: Text('RF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RuFaS', style: textTheme.titleLarge),
                        Text('Simulador de Fazenda', style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _sectionLabel(context, 'Fazenda ativa'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: widget.simulations.isEmpty ? null : () => setState(() => _switcherOpen = !_switcherOpen),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.home_work, color: AppColors.primaryGreen),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    active != null ? _resumo(active) : 'Nenhuma fazenda selecionada',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    active != null ? (simulationStateLabels[active.state] ?? active.state) : 'Toque para escolher',
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (widget.simulations.isNotEmpty)
                              Icon(_switcherOpen ? Icons.expand_less : Icons.expand_more),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_switcherOpen)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        children: widget.simulations.map((sim) {
                          final isActive = sim.simulationId == widget.activeId;
                          return Material(
                            color: isActive ? AppColors.lightGreen.withValues(alpha: 0.4) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                widget.onSelectActive(sim.simulationId);
                                setState(() => _switcherOpen = false);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(isActive ? Icons.check : Icons.home_work_outlined, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(_resumo(sim))),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _sectionLabel(context, 'Navegação'),
                  ListTile(
                    leading: const Icon(Icons.agriculture, color: AppColors.primaryGreen),
                    title: const Text('Minhas Fazendas', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: widget.simulations.isEmpty
                        ? null
                        : CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.primaryGreen,
                            child: Text(
                              '${widget.simulations.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                    selected: true,
                    selectedTileColor: AppColors.lightGreen.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onTap: widget.asSidebar ? () {} : () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.support_agent, color: AppColors.primaryGreen, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Precisa de ajuda? Fale com o técnico da sua região.',
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

    if (widget.asSidebar) {
      // Material próprio (não só Container com cor) para o ListTile
      // selecionado pintar corretamente — sem isso o framework avisa que
      // o DecoratedBox com cor de fundo esconde o ink/seleção do ListTile.
      return Container(
        width: 300,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: content,
        ),
      );
    }
    return Drawer(child: content);
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
