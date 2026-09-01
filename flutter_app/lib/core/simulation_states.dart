import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Estados de uma simulação (ver backend/app.py) traduzidos pra linguagem
/// de fazenda — nunca mostrar os nomes técnicos (queued, running_herd_init
/// etc.) direto pro produtor. Fonte unica usada pelo chip da lista (Tela 1)
/// e pela tela de status (Tela 3), pra nao duplicar os textos.
const Map<String, String> simulationStateLabels = {
  'queued': 'na fila',
  'running_herd_init': 'gerando rebanho',
  'running_simulation': 'simulando',
  'done': 'concluída',
  'failed': 'falhou',
};

const Map<String, String> simulationStateDescriptions = {
  'queued': 'Sua fazenda está na fila. A simulação começa assim que a anterior terminar.',
  'running_herd_init': 'Gerando o rebanho da fazenda a partir dos dados informados.',
  'running_simulation': 'Rodando a simulação completa da fazenda.',
};

/// Cores alinhadas à paleta de fazenda (ver AppColors em core/app_theme.dart):
/// verde primário para "concluída", âmbar de acento para os estados "em
/// andamento", cinza neutro para "na fila" e vermelho de erro (fora da
/// paleta de marca, mas necessário para o alerta semântico de falha).
const Map<String, Color> simulationStateColors = {
  'queued': Color(0xFF6B7A72),
  'running_herd_init': AppColors.amber,
  'running_simulation': AppColors.amber,
  'done': AppColors.primaryGreen,
  'failed': Color(0xFFB3261E),
};

bool isSimulationFinished(String state) => state == 'done' || state == 'failed';
