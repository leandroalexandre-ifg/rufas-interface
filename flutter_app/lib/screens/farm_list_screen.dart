import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/simulation_summary.dart';
import '../widgets/simulation_state_chip.dart';
import 'new_farm_screen.dart';
import 'results_screen.dart';
import 'simulation_status_screen.dart';

/// Tela 1 da Fase 3 (ver CLAUDE.md): histórico de simulações, GET
/// /simulations. Tocar numa simulação ainda em andamento (ou que falhou)
/// abre a tela de status (tela 3); numa concluida, abre a tela de
/// resultados (tela 4). "Nova fazenda" (tela 2) ja esta ligada: ao voltar
/// com sucesso, a lista recarrega.
class FarmListScreen extends StatefulWidget {
  const FarmListScreen({super.key});

  @override
  State<FarmListScreen> createState() => _FarmListScreenState();
}

class _FarmListScreenState extends State<FarmListScreen> {
  final _apiClient = ApiClient();
  late Future<List<SimulationSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadSimulations();
  }

  Future<List<SimulationSummary>> _loadSimulations() async {
    final data = await _apiClient.getJson('/simulations') as List<dynamic>;
    return data.map((item) => SimulationSummary.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> _refresh() async {
    final future = _loadSimulations();
    setState(() {
      _future = future;
    });
    await future;
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
      MaterialPageRoute(builder: (_) => const NewFarmScreen()),
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<SimulationSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
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
                          'Erro ao carregar simulações:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            final simulations = snapshot.data ?? [];
            if (simulations.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.agriculture_outlined,
                          size: 48,
                          color: AppColors.primaryGreen.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhuma simulação ainda.\nToque em "+" para cadastrar uma fazenda.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: simulations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final sim = simulations[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.lightGreen,
                      foregroundColor: AppColors.primaryGreen,
                      child: Icon(Icons.agriculture),
                    ),
                    title: Text('${sim.farm.cowNum} vacas · ${sim.farm.calfNum} bezerras'),
                    subtitle: Text('${sim.simulationId} · ${_formatDate(sim.createdAt)}'),
                    trailing: SimulationStateChip(state: sim.state),
                    onTap: () => _openSimulation(sim),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewFarmForm,
        tooltip: 'Nova fazenda',
        child: const Icon(Icons.add),
      ),
    );
  }
}
