import 'farm_input.dart';

/// Um item da lista de GET /simulations (ver backend/app.py list_simulations).
class SimulationSummary {
  final String simulationId;
  final String state;
  final DateTime createdAt;
  final FarmInput farm;

  SimulationSummary({
    required this.simulationId,
    required this.state,
    required this.createdAt,
    required this.farm,
  });

  factory SimulationSummary.fromJson(Map<String, dynamic> json) => SimulationSummary(
        simulationId: json['simulation_id'] as String,
        state: json['state'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          ((json['created_at'] as num) * 1000).round(),
        ),
        farm: FarmInput.fromJson(json['farm'] as Map<String, dynamic>),
      );
}
