import 'package:flutter/material.dart';

import '../core/simulation_states.dart';

class SimulationStateChip extends StatelessWidget {
  final String state;

  const SimulationStateChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final color = simulationStateColors[state] ?? Colors.blueGrey;
    return Chip(
      label: Text(simulationStateLabels[state] ?? state),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      side: BorderSide.none,
    );
  }
}
