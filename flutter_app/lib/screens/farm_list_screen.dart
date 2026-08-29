import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/simulation_summary.dart';
import '../widgets/app_drawer.dart';
import '../widgets/simulation_state_chip.dart';
import 'new_farm_wizard_screen.dart';
import 'results_screen.dart';
import 'simulation_status_screen.dart';

/// Tela 1 (ver CLAUDE.md): histórico de simulações, GET /simulations, mais
/// a navegação lateral do app (AppDrawer) e o conceito de "fazenda ativa" —
/// adaptação do design "Cadastro Fazenda Wizard" (ver docs/diagrams). Tocar
/// no card de uma simulação concluída abre a Tela 4 (resultados); em
/// qualquer outro estado, abre a Tela 3 (status). "Nova fazenda" agora abre
/// o wizard (new_farm_wizard_screen.dart) em vez do formulário único.
class FarmListScreen extends StatefulWidget {
  const FarmListScreen({super.key});

  @override
  State<FarmListScreen> createState() => _FarmListScreenState();
}

class _FarmListScreenState extends State<FarmListScreen> {
  final _apiClient = ApiClient();

  bool _loading = true;
  Object? _error;
  List<SimulationSummary> _simulations = [];

  /// Fazenda em destaque no drawer/lista — estado só de UI, não existe no
  /// backend (não há endpoint nem conceito de "simulação ativa" em
  /// backend/app.py). Não persiste entre reinícios do app.
  String? _activeId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Carrega e guarda o resultado diretamente no state (em vez de um
  /// FutureBuilder) porque o AppDrawer e a lista do corpo precisam
  /// enxergar a mesma lista/`_activeId` sempre em sincronia — com
  /// FutureBuilder, o Drawer (construído fora do builder) ficaria sempre
  /// um ciclo de carregamento atrás.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _apiClient.getJson('/simulations') as List<dynamic>;
      final sims = data.map((item) => SimulationSummary.fromJson(item as Map<String, dynamic>)).toList();
      if (!mounted) return;
      setState(() {
        _simulations = sims;
        if (_activeId == null || !sims.any((s) => s.simulationId == _activeId)) {
          _activeId = sims.isNotEmpty ? sims.first.simulationId : null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() => _load();

  void _setActive(String simulationId) {
    setState(() => _activeId = simulationId);
  }

  void _openSimulation(SimulationSummary sim) {
    if (sim.state == 'done') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultsScreen(simulationId: sim.simulationId)),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SimulationStatusScreen(simulationId: sim.simulationId)),
    );
  }

  Future<void> _openNewFarmForm() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewFarmWizardScreen()),
    );
    if (created == true && mounted) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fazenda cadastrada — simulação iniciada.')),
        );
      }
    }
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _formatDate(DateTime dt) {
    return '${_twoDigits(dt.day)}/${_twoDigits(dt.month)} ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fazendas')),
      drawer: AppDrawer(
        simulations: _simulations,
        activeId: _activeId,
        onSelectActive: _setActive,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _simulations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Erro ao carregar simulações:\n$_error',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
      children: [
        Text('Minhas fazendas', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Escolha sobre qual fazenda você quer trabalhar hoje.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _openNewFarmForm,
          icon: const Icon(Icons.add),
          label: const Text('Cadastrar nova fazenda'),
        ),
        const SizedBox(height: 24),
        if (_simulations.isEmpty) _buildEmptyState(context) else ..._buildFarmCards(_simulations),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.agriculture_outlined,
              size: 48,
              color: AppColors.primaryGreen.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma fazenda por aqui ainda',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cadastre sua primeira fazenda em três passos rápidos: rebanho, produção e propriedade.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFarmCards(List<SimulationSummary> simulations) {
    return [
      for (final sim in simulations) ...[
        _FarmCard(
          sim: sim,
          isActive: sim.simulationId == _activeId,
          onTap: () => _openSimulation(sim),
          onSelect: () => _setActive(sim.simulationId),
          onViewResults: sim.state == 'done' ? () => _openSimulation(sim) : null,
          dateLabel: _formatDate(sim.createdAt),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}

class _FarmCard extends StatelessWidget {
  final SimulationSummary sim;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onSelect;
  final VoidCallback? onViewResults;
  final String dateLabel;

  const _FarmCard({
    required this.sim,
    required this.isActive,
    required this.onTap,
    required this.onSelect,
    required this.onViewResults,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: isActive
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.primaryGreen, width: 2),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.lightGreen,
                    foregroundColor: AppColors.primaryGreen,
                    child: Icon(Icons.agriculture),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${sim.farm.cowNum} vacas · ${sim.farm.calfNum} bezerras',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text('${sim.simulationId} · $dateLabel', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SimulationStateChip(state: sim.state),
                      if (isActive) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Selecionada',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: isActive ? null : onSelect,
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: Text(isActive ? 'Selecionada' : 'Selecionar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onViewResults,
                    icon: const Icon(Icons.insights, size: 20),
                    label: const Text('Ver resultados'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
