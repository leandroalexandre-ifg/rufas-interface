import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/simulation_states.dart';
import 'results_screen.dart';

/// Tela 3 da Fase 3 (ver CLAUDE.md): acompanha uma simulação em andamento
/// via polling de GET /simulations/{id}. O polling para sozinho quando o
/// estado vira "done"/"failed", e sempre que a tela é destruída (dispose) —
/// nunca fica consultando a API pra sempre nem sobrevive à saída do usuário.
class SimulationStatusScreen extends StatefulWidget {
  final String simulationId;

  const SimulationStatusScreen({super.key, required this.simulationId});

  @override
  State<SimulationStatusScreen> createState() => _SimulationStatusScreenState();
}

class _SimulationStatusScreenState extends State<SimulationStatusScreen> {
  static const _pollInterval = Duration(seconds: 5);

  final _apiClient = ApiClient();
  Timer? _pollTimer;

  bool _loading = true;
  String? _state;
  String? _error;
  bool _lastPollFailed = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _fetchStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final data = await _apiClient.getJson('/simulations/${widget.simulationId}') as Map<String, dynamic>;
      if (!mounted) return;
      final newState = data['state'] as String;
      setState(() {
        _state = newState;
        _error = data['error'] as String?;
        _loading = false;
        _lastPollFailed = false;
      });
      if (isSimulationFinished(newState)) {
        _pollTimer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      // Erro passageiro de rede: mantem o ultimo estado conhecido na tela
      // (se houver) e deixa o polling tentar de novo sozinho — nao trava
      // nem cancela o timer por causa disso.
      setState(() {
        _loading = false;
        _lastPollFailed = true;
      });
    }
  }

  void _openResults() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultsScreen(simulationId: widget.simulationId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Status da simulação')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const CircularProgressIndicator();
    }
    final state = _state;
    if (state == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Não foi possível consultar o status agora.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchStatus,
            child: const Text('Tentar de novo'),
          ),
        ],
      );
    }
    if (state == 'failed') return _buildFailed(context);
    if (state == 'done') return _buildDone(context);
    return _buildInProgress(context, state);
  }

  Widget _buildInProgress(BuildContext context, String state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          simulationStateLabels[state] ?? state,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          simulationStateDescriptions[state] ?? '',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          'Isso pode levar cerca de 10 minutos. Você pode sair desta tela — '
          'a simulação continua rodando e vai aparecer pronta na lista de fazendas.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_lastPollFailed) ...[
          const SizedBox(height: 16),
          Text(
            'Não foi possível atualizar agora — tentando de novo em alguns segundos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 64),
        const SizedBox(height: 24),
        Text('Simulação concluída!', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text('Os resultados da sua fazenda estão prontos.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _openResults,
          child: const Text('Ver resultados'),
        ),
      ],
    );
  }

  Widget _buildFailed(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 64),
        const SizedBox(height: 24),
        Text(
          'Não foi possível concluir a simulação',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Algo deu errado durante o processamento dessa fazenda. '
          'Tente cadastrar novamente ou fale com o suporte técnico.',
          textAlign: TextAlign.center,
        ),
        if (_error != null) ...[
          const SizedBox(height: 24),
          ExpansionTile(
            title: const Text('Detalhes técnicos'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _error!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
