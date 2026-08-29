import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/api_client.dart';

const _maxSelectable = 3;
const _maxListed = 200;

String _shortLabel(String column) => column.split('.').last.trim();

/// Tela 4 da Fase 3 (ver CLAUDE.md), Parte B — grafico. Recebe as colunas ja
/// filtradas pela Parte A (sem as colunas de tempo), deixa o usuario
/// escolher ate 3 pra plotar, busca cada uma via GET /chart-data (uma
/// chamada por variavel — garante series sem buracos, ver nota no backend
/// sobre reporters com contagens de linha diferentes) e usa a
/// classificacao (plottable/categorical/excluded_*/no_data) devolvida pra
/// decidir se desenha o grafico ou mostra uma mensagem clara.
class ChartScreen extends StatefulWidget {
  final String simulationId;
  final List<String> candidateColumns;

  const ChartScreen({
    super.key,
    required this.simulationId,
    required this.candidateColumns,
  });

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final _apiClient = ApiClient();
  final _searchController = TextEditingController();
  String _search = '';

  final List<String> _selected = [];

  bool _loadingCharts = false;
  String? _chartsError;
  final Map<String, Map<String, dynamic>> _chartResults = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredCandidates {
    if (_search.isEmpty) return widget.candidateColumns;
    final query = _search.toLowerCase();
    return widget.candidateColumns.where((c) => c.toLowerCase().contains(query)).toList();
  }

  void _toggle(String column) {
    setState(() {
      if (_selected.contains(column)) {
        _selected.remove(column);
      } else if (_selected.length < _maxSelectable) {
        _selected.add(column);
      }
    });
  }

  Future<void> _generateCharts() async {
    setState(() {
      _loadingCharts = true;
      _chartsError = null;
      _chartResults.clear();
    });
    try {
      final futures = _selected.map(
        (column) => _apiClient.getJson(
          '/simulations/${widget.simulationId}/chart-data'
          '?columns=${Uri.encodeComponent(column)}&max_points=200',
        ),
      );
      final results = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _selected.length; i++) {
          _chartResults[_selected[i]] = results[i] as Map<String, dynamic>;
        }
        _loadingCharts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCharts = false;
        _chartsError = 'Não foi possível carregar os dados do gráfico agora.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _filteredCandidates;
    final listed = candidates.take(_maxListed).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Gráfico')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Escolha até $_maxSelectable variáveis para plotar '
            '(${_selected.length}/$_maxSelectable selecionadas).',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar variável...',
              isDense: true,
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          if (candidates.length > _maxListed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Mostrando $_maxListed de ${candidates.length}. Digite algo para refinar a busca.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          ...listed.map((column) {
            final isSelected = _selected.contains(column);
            final disabled = !isSelected && _selected.length >= _maxSelectable;
            return CheckboxListTile(
              value: isSelected,
              onChanged: disabled ? null : (_) => _toggle(column),
              title: Text(_shortLabel(column)),
              subtitle: Text(
                column,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _selected.isNotEmpty && !_loadingCharts ? _generateCharts : null,
            child: Text(_loadingCharts ? 'Gerando gráfico...' : 'Gerar gráfico'),
          ),
          if (_chartsError != null) ...[
            const SizedBox(height: 12),
            Text(
              _chartsError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_chartResults.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            ..._selected
                .where((column) => _chartResults.containsKey(column))
                .map((column) => _ChartCard(column: column, data: _chartResults[column]!)),
          ],
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String column;
  final Map<String, dynamic> data;

  const _ChartCard({required this.column, required this.data});

  @override
  Widget build(BuildContext context) {
    final label = _shortLabel(column);
    final seriesMap = data['series'] as Map<String, dynamic>?;
    final series = seriesMap?[column] as Map<String, dynamic>?;

    if (series == null) {
      return _messageCard(context, label, 'Não foi possível carregar essa variável.');
    }

    final classification = series['classification'] as String? ?? 'unknown';
    if (classification != 'plottable' && classification != 'categorical') {
      return _messageCard(context, label, _classificationMessage(classification));
    }

    final timeValues = (data['time'] as List?) ?? const [];
    final values = (series['values'] as List?) ?? const [];
    final timeLabel = (data['time_column_label'] as String?) ?? (data['time_column'] as String?) ?? 'Tempo';

    final spots = <FlSpot>[];
    for (var i = 0; i < timeValues.length && i < values.length; i++) {
      final t = timeValues[i];
      final v = values[i];
      if (t == null || v == null) continue;
      spots.add(FlSpot((t as num).toDouble(), (v as num).toDouble()));
    }

    if (spots.isEmpty) {
      return _messageCard(context, label, 'Essa variável não tem nenhum valor registrado nesta simulação.');
    }

    // fl_chart trava calculando os eixos quando minY == maxY (serie
    // constante — comum em variaveis "categorical", ex.: teor de gordura
    // do leite sempre 4.0). Forcar uma faixa minima evita esse caso.
    final yValues = spots.map((s) => s.y);
    final rawMinY = yValues.reduce((a, b) => a < b ? a : b);
    final rawMaxY = yValues.reduce((a, b) => a > b ? a : b);
    final yRange = rawMaxY - rawMinY;
    // Epsilon, nao "> 0": series "constantes" de verdade ainda trazem ruido
    // de ponto flutuante (ex.: 4.0 vs 4.000000000000001), o que da um range
    // positivo mas infinitesimal — o fl_chart trava calculando os eixos
    // com um intervalo desse tamanho. Descoberto travando de verdade no
    // Android com a coluna herd_milk_fat_percent.
    const epsilon = 1e-9;
    final yPadding = yRange > epsilon ? yRange * 0.1 : (rawMinY.abs() * 0.1).clamp(1.0, double.infinity);

    final xValues = spots.map((s) => s.x);
    final rawMinX = xValues.reduce((a, b) => a < b ? a : b);
    final rawMaxX = xValues.reduce((a, b) => a > b ? a : b);
    final xRange = rawMaxX - rawMinX;
    final xPadding = xRange > epsilon ? 0.0 : 1.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            if (classification == 'categorical')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Valores com poucas variações — pode ser uma categoria, não uma medição contínua.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Nome completo: $column',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: rawMinX - xPadding,
                  maxX: rawMaxX + xPadding,
                  minY: rawMinY - yPadding,
                  maxY: rawMaxY + yPadding,
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text(timeLabel, style: Theme.of(context).textTheme.bodySmall),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) => Text(_formatY(value), style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageCard(BuildContext context, String label, String message) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _classificationMessage(String classification) {
    switch (classification) {
      case 'excluded_name':
      case 'excluded_type':
        return 'Essa variável não é uma medição contínua (é um identificador ou categoria) '
            'e não pode virar gráfico de linha.';
      case 'no_data':
        return 'Essa variável não tem nenhum valor registrado nesta simulação.';
      case 'time':
        return 'Essa é a própria coluna de tempo — não faz sentido como gráfico separado.';
      default:
        return 'Essa variável não pôde ser exibida em gráfico.';
    }
  }

  String _formatY(double value) {
    if (value.abs() >= 1000) return value.toStringAsFixed(0);
    if (value.abs() >= 10) return value.toStringAsFixed(1);
    return value.toStringAsFixed(2);
  }
}
