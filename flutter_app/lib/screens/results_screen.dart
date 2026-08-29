import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import 'chart_screen.dart';

/// Tela 4 da Fase 3 (ver CLAUDE.md). Parte A — filtro: consome
/// GET /simulations/{id}/columns (modulos + palavras-chave disponiveis) e
/// POST /simulations/{id}/filters/preview (contagem dinamica de colunas
/// selecionadas, como a legenda do dashboard). Caminho principal e
/// modulo + palavra-chave — o padrao de busca (regex) fica escondido atras
/// de um "Avancado", nunca exposto como primeira opcao pro produtor.
/// Parte B — "Ver gráfico" leva pra ChartScreen com as colunas ja
/// filtradas aqui (sem as de tempo), pra escolher o que plotar.
class ResultsScreen extends StatefulWidget {
  final String simulationId;

  const ResultsScreen({super.key, required this.simulationId});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _apiClient = ApiClient();
  final _patternController = TextEditingController();
  Timer? _patternDebounce;

  bool _loadingColumns = true;
  String? _loadError;

  List<String> _modules = [];
  List<String> _keywordsAvailable = [];

  final Set<String> _selectedModules = {};
  final Set<String> _selectedKeywords = {};
  bool _customPatternActive = false;

  bool _previewLoading = false;
  String? _previewError;
  int _selectedCount = 0;
  List<String> _selectedColumns = [];

  @override
  void initState() {
    super.initState();
    _loadColumns();
  }

  @override
  void dispose() {
    _patternDebounce?.cancel();
    _patternController.dispose();
    super.dispose();
  }

  Future<void> _loadColumns() async {
    try {
      final data = await _apiClient.getJson('/simulations/${widget.simulationId}/columns') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _modules = List<String>.from(data['modules'] as List);
        _keywordsAvailable = List<String>.from(data['keywords_available'] as List);
        _loadingColumns = false;
      });
      _updatePreview();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingColumns = false;
        _loadError = 'Não foi possível carregar as variáveis desta simulação.';
      });
    }
  }

  Future<void> _updatePreview() async {
    setState(() {
      _previewLoading = true;
      _previewError = null;
    });
    try {
      final body = <String, dynamic>{
        'modules': _selectedModules.toList(),
        'keywords': _selectedKeywords.toList(),
      };
      if (_customPatternActive) {
        body['pattern'] = _patternController.text;
      }
      final data = await _apiClient.postJson(
        '/simulations/${widget.simulationId}/filters/preview',
        body,
      ) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _selectedCount = data['count'] as int;
        _selectedColumns = List<String>.from(data['selected_columns'] as List);
        _previewLoading = false;
        if (!_customPatternActive) {
          _patternController.text = data['pattern'] as String;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _previewError = 'Não foi possível atualizar a contagem agora.';
      });
    }
  }

  void _toggleModule(String module) {
    setState(() {
      if (_selectedModules.contains(module)) {
        _selectedModules.remove(module);
      } else {
        _selectedModules.add(module);
      }
    });
    _updatePreview();
  }

  void _toggleKeyword(String keyword) {
    setState(() {
      if (_selectedKeywords.contains(keyword)) {
        _selectedKeywords.remove(keyword);
      } else {
        _selectedKeywords.add(keyword);
      }
    });
    _updatePreview();
  }

  void _onPatternEdited(String _) {
    _customPatternActive = true;
    _patternDebounce?.cancel();
    _patternDebounce = Timer(const Duration(milliseconds: 400), _updatePreview);
  }

  void _resetToSimpleFilter() {
    setState(() {
      _customPatternActive = false;
    });
    _updatePreview();
  }

  void _openChart() {
    final candidateColumns = _selectedColumns.where((c) => !c.startsWith('RufasTime.')).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChartScreen(simulationId: widget.simulationId, candidateColumns: candidateColumns),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultados')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loadingColumns) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_loadError!, textAlign: TextAlign.center),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Módulo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _modules
                      .map((module) => FilterChip(
                            label: Text(module),
                            selected: _selectedModules.contains(module),
                            onSelected: _customPatternActive ? null : (_) => _toggleModule(module),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                Text('Palavra-chave', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _keywordsAvailable
                      .map((keyword) => FilterChip(
                            label: Text(keyword),
                            selected: _selectedKeywords.contains(keyword),
                            onSelected: _customPatternActive ? null : (_) => _toggleKeyword(keyword),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                ExpansionTile(
                  title: const Text('Avançado (padrão de busca)'),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    Text(
                      'Mesmo mecanismo usado pelos filtros nativos do RuFaS. '
                      'Editar aqui substitui o filtro por módulo e palavra-chave acima.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _patternController,
                      onChanged: _onPatternEdited,
                    ),
                    if (_customPatternActive) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _resetToSimpleFilter,
                          child: const Text('Voltar para módulo e palavra-chave'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Material(
            elevation: 4,
            color: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_previewLoading) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          _previewError ??
                              '$_selectedCount colunas selecionadas (colunas de tempo sempre incluídas).',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _selectedCount > 0 ? _openChart : null,
                    child: const Text('Ver gráfico'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
