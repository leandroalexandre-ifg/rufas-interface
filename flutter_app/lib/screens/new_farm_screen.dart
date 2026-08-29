import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/form_validators.dart';
import '../models/farm_input.dart';

/// Tela 2 da Fase 3 (ver CLAUDE.md): formulario dos 5 campos que a PoC
/// validou (cow_num, calf_num, annual_milk_yield, field_size ×2,
/// fips_county_code), disparando POST /simulations. Ao enviar com
/// sucesso, volta pra tela anterior (lista) com `true`, pra ela recarregar
/// e mostrar a simulacao recem-criada — Tela 3 (status) ainda nao existe.
class NewFarmScreen extends StatefulWidget {
  const NewFarmScreen({super.key});

  @override
  State<NewFarmScreen> createState() => _NewFarmScreenState();
}

class _NewFarmScreenState extends State<NewFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiClient = ApiClient();

  final _cowNumController = TextEditingController();
  final _calfNumController = TextEditingController();
  final _annualMilkYieldController = TextEditingController();
  final _fieldSize1Controller = TextEditingController();
  final _fieldSize2Controller = TextEditingController();
  final _fipsCountyCodeController = TextEditingController();

  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _cowNumController.dispose();
    _calfNumController.dispose();
    _annualMilkYieldController.dispose();
    _fieldSize1Controller.dispose();
    _fieldSize2Controller.dispose();
    _fipsCountyCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final farm = FarmInput(
      cowNum: int.parse(_cowNumController.text.trim()),
      calfNum: int.parse(_calfNumController.text.trim()),
      annualMilkYield: double.parse(_annualMilkYieldController.text.trim().replaceAll(',', '.')),
      fieldSize1: double.parse(_fieldSize1Controller.text.trim().replaceAll(',', '.')),
      fieldSize2: double.parse(_fieldSize2Controller.text.trim().replaceAll(',', '.')),
      fipsCountyCode: int.parse(_fipsCountyCodeController.text.trim()),
    );

    try {
      await _apiClient.postJson('/simulations', farm.toJson());
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _submitError = 'Não foi possível cadastrar a fazenda agora. '
            'Confira se a API está rodando e tente de novo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova fazenda')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _cowNumController,
              decoration: const InputDecoration(
                labelText: 'Vacas em lactação',
              ),
              keyboardType: TextInputType.number,
              validator: (value) => validateRequiredInt(
                value,
                allowZero: false,
                requiredMessage: 'Informe o número de vacas em lactação.',
                typeMessage: 'Digite um número inteiro de vacas.',
                rangeMessage: 'O número de vacas deve ser maior que zero.',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _calfNumController,
              decoration: const InputDecoration(
                labelText: 'Bezerras',
              ),
              keyboardType: TextInputType.number,
              validator: (value) => validateRequiredInt(
                value,
                allowZero: true,
                requiredMessage: 'Informe o número de bezerras.',
                typeMessage: 'Digite um número inteiro de bezerras.',
                rangeMessage: 'O número de bezerras não pode ser negativo.',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _annualMilkYieldController,
              decoration: const InputDecoration(
                labelText: 'Meta de produção de leite (kg/ano)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => validateRequiredDouble(
                value,
                requiredMessage: 'Informe a meta de produção de leite anual.',
                typeMessage: 'Digite um número válido para a produção de leite.',
                rangeMessage: 'A meta de produção de leite deve ser maior que zero.',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fieldSize1Controller,
              decoration: const InputDecoration(
                labelText: 'Tamanho do campo 1 (acres)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => validateRequiredDouble(
                value,
                requiredMessage: 'Informe o tamanho do campo 1.',
                typeMessage: 'Digite um número válido para o tamanho do campo 1.',
                rangeMessage: 'O tamanho do campo 1 deve ser maior que zero.',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fieldSize2Controller,
              decoration: const InputDecoration(
                labelText: 'Tamanho do campo 2 (acres)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => validateRequiredDouble(
                value,
                requiredMessage: 'Informe o tamanho do campo 2.',
                typeMessage: 'Digite um número válido para o tamanho do campo 2.',
                rangeMessage: 'O tamanho do campo 2 deve ser maior que zero.',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fipsCountyCodeController,
              decoration: const InputDecoration(
                labelText: 'Código do condado (FIPS)',
                helperText: 'Define a região e o clima usados na simulação.',
              ),
              keyboardType: TextInputType.number,
              validator: (value) => validateRequiredInt(
                value,
                allowZero: false,
                requiredMessage: 'Informe o código do condado.',
                typeMessage: 'Digite um número inteiro para o código do condado.',
                rangeMessage: 'O código do condado deve ser maior que zero.',
              ),
            ),
            const SizedBox(height: 24),
            if (_submitError != null) ...[
              Text(
                _submitError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Enviando...' : 'Cadastrar fazenda'),
            ),
          ],
        ),
      ),
    );
  }
}
