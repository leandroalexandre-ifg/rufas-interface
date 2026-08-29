import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/form_validators.dart';
import '../models/farm_input.dart';
import 'simulation_status_screen.dart';

const _stepNames = ['Rebanho', 'Produção', 'Propriedade'];

/// Tela 2, adaptada do design "Cadastro Fazenda Wizard": um wizard de 3
/// passos + revisão + confirmação, em vez do formulário único anterior
/// (substituído — ver docs/ARCHITECTURE.md). Usa só os 6 campos que
/// `backend/app.py` (`FarmInputRequest`) realmente aceita; os campos do
/// design sem equivalente no backend (nome da fazenda, vacas secas, raça,
/// busca de município por nome) não entram — decisão tomada com o usuário.
class NewFarmWizardScreen extends StatefulWidget {
  const NewFarmWizardScreen({super.key});

  @override
  State<NewFarmWizardScreen> createState() => _NewFarmWizardScreenState();
}

class _NewFarmWizardScreenState extends State<NewFarmWizardScreen> {
  final _apiClient = ApiClient();

  final _cowNumController = TextEditingController();
  final _calfNumController = TextEditingController();
  final _annualMilkYieldController = TextEditingController();
  final _fieldSize1Controller = TextEditingController();
  final _fieldSize2Controller = TextEditingController();
  final _fipsCountyCodeController = TextEditingController();

  /// 1-3: etapas do wizard. 4: revisão. 5: confirmação.
  int _step = 1;
  final Set<int> _triedSteps = {};
  bool _submitting = false;
  String? _submitError;
  String? _createdSimulationId;

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

  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  void _stepInt(TextEditingController c, int delta) {
    final next = (_int(c) + delta).clamp(0, 1000000);
    setState(() => c.text = next.toString());
  }

  Map<String, String?> _errorsForStep(int step) {
    switch (step) {
      case 1:
        return {
          'cowNum': validateRequiredInt(
            _cowNumController.text,
            allowZero: false,
            requiredMessage: 'Informe o número de vacas em lactação.',
            typeMessage: 'Digite um número inteiro de vacas.',
            rangeMessage: 'O número de vacas deve ser maior que zero.',
          ),
          'calfNum': validateRequiredInt(
            _calfNumController.text,
            allowZero: true,
            requiredMessage: 'Informe o número de bezerras.',
            typeMessage: 'Digite um número inteiro de bezerras.',
            rangeMessage: 'O número de bezerras não pode ser negativo.',
          ),
        };
      case 2:
        return {
          'annualMilkYield': validateRequiredDouble(
            _annualMilkYieldController.text,
            requiredMessage: 'Informe a meta de produção de leite anual.',
            typeMessage: 'Digite um número válido para a produção de leite.',
            rangeMessage: 'A meta de produção de leite deve ser maior que zero.',
          ),
        };
      case 3:
        return {
          'fieldSize1': validateRequiredDouble(
            _fieldSize1Controller.text,
            requiredMessage: 'Informe o tamanho do campo 1.',
            typeMessage: 'Digite um número válido para o tamanho do campo 1.',
            rangeMessage: 'O tamanho do campo 1 deve ser maior que zero.',
          ),
          'fieldSize2': validateRequiredDouble(
            _fieldSize2Controller.text,
            requiredMessage: 'Informe o tamanho do campo 2.',
            typeMessage: 'Digite um número válido para o tamanho do campo 2.',
            rangeMessage: 'O tamanho do campo 2 deve ser maior que zero.',
          ),
          'fipsCountyCode': validateRequiredInt(
            _fipsCountyCodeController.text,
            allowZero: false,
            requiredMessage: 'Informe o código do condado.',
            typeMessage: 'Digite um número inteiro para o código do condado.',
            rangeMessage: 'O código do condado deve ser maior que zero.',
          ),
        };
      default:
        return {};
    }
  }

  Future<void> _advance() async {
    if (_step <= 3) {
      final errors = _errorsForStep(_step);
      if (errors.values.any((e) => e != null)) {
        setState(() => _triedSteps.add(_step));
        return;
      }
      setState(() => _step += 1);
      return;
    }
    if (_step == 4) {
      await _submit();
    }
  }

  void _back() {
    if (_step > 1 && _step <= 4) {
      setState(() => _step -= 1);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final farm = FarmInput(
      cowNum: _int(_cowNumController),
      calfNum: _int(_calfNumController),
      annualMilkYield: double.parse(_annualMilkYieldController.text.trim().replaceAll(',', '.')),
      fieldSize1: double.parse(_fieldSize1Controller.text.trim().replaceAll(',', '.')),
      fieldSize2: double.parse(_fieldSize2Controller.text.trim().replaceAll(',', '.')),
      fipsCountyCode: _int(_fipsCountyCodeController),
    );
    try {
      final result = await _apiClient.postJson('/simulations', farm.toJson()) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _createdSimulationId = result['simulation_id'] as String;
        _step = 5;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = 'Não foi possível cadastrar a fazenda agora. '
            'Confira se a API está rodando e tente de novo.';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _goToStatus() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SimulationStatusScreen(simulationId: _createdSimulationId!)),
      result: true,
    );
  }

  void _goToList() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova fazenda')),
      body: SafeArea(
        child: Column(
          children: [
            if (_step <= 5) _buildProgressHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [_buildStepContent(context)],
              ),
            ),
            if (_step <= 4) _buildNavFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader(BuildContext context) {
    final label = _step <= 3
        ? 'Etapa $_step de 3'
        : (_step == 4 ? 'Quase lá' : 'Concluído');
    final name = _step <= 3 ? _stepNames[_step - 1] : (_step == 4 ? 'Revisão' : 'Pronto');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryGreen),
              ),
              Text(name, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (i) {
              final segment = i + 1;
              final filled = _step > segment || _step >= 4;
              final current = _step == segment;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: filled
                        ? AppColors.lightGreen
                        : (current ? AppColors.primaryGreen : Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (_step) {
      case 1:
        return _buildRebanhoStep(context);
      case 2:
        return _buildProducaoStep(context);
      case 3:
        return _buildPropriedadeStep(context);
      case 4:
        return _buildRevisaoStep(context);
      default:
        return _buildConfirmacaoStep(context);
    }
  }

  Widget _card(List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }

  Widget _buildRebanhoStep(BuildContext context) {
    final errors = _triedSteps.contains(1) ? _errorsForStep(1) : {};
    return _card([
      Text('Seu rebanho', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(
        'A qualquer momento, correções podem ser realizadas nos campos abaixo.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 28),
      _stepperField(
        label: 'Quantas vacas estão dando leite?',
        helper: 'As vacas em lactação, que você ordenha hoje.',
        controller: _cowNumController,
        onDecrement: () => _stepInt(_cowNumController, -1),
        onIncrement: () => _stepInt(_cowNumController, 1),
        errorText: errors['cowNum'],
      ),
      const SizedBox(height: 24),
      _stepperField(
        label: 'Quantas bezerras você tem?',
        helper: 'As fêmeas novas, que ainda não tiveram cria.',
        controller: _calfNumController,
        onDecrement: () => _stepInt(_calfNumController, -1),
        onIncrement: () => _stepInt(_calfNumController, 1),
        errorText: errors['calfNum'],
      ),
    ]);
  }

  Widget _buildProducaoStep(BuildContext context) {
    final errors = _triedSteps.contains(2) ? _errorsForStep(2) : {};
    return _card([
      Text('Sua produção', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text('Uma pergunta só, sobre o leite do dia a dia.', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 28),
      Text('Meta de produção de leite anual', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        'É um alvo de calibração da simulação, não uma garantia de resultado.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _annualMilkYieldController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: '0',
          suffixText: 'kg/ano',
          errorText: errors['annualMilkYield'],
        ),
      ),
    ]);
  }

  Widget _buildPropriedadeStep(BuildContext context) {
    final errors = _triedSteps.contains(3) ? _errorsForStep(3) : {};
    return _card([
      Text('Sua propriedade', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text('Onde fica e qual o tamanho da terra.', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 28),
      Text('Tamanho do campo 1', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      TextFormField(
        controller: _fieldSize1Controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(hintText: '0', suffixText: 'acres', errorText: errors['fieldSize1']),
      ),
      const SizedBox(height: 24),
      Text('Tamanho do campo 2', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      TextFormField(
        controller: _fieldSize2Controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(hintText: '0', suffixText: 'acres', errorText: errors['fieldSize2']),
      ),
      const SizedBox(height: 24),
      Text('Código do condado (FIPS)', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text('Define a região e o clima usados na simulação.', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 10),
      TextFormField(
        controller: _fipsCountyCodeController,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(hintText: '0', errorText: errors['fipsCountyCode']),
      ),
    ]);
  }

  Widget _buildRevisaoStep(BuildContext context) {
    return _card([
      Text('Confira antes de enviar', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text('Está tudo certo? Se algo mudou, é só voltar e ajustar.', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 20),
      _reviewGroup(context, 'Rebanho', 1, [
        ('Vacas em lactação', '${_int(_cowNumController)} vacas'),
        ('Bezerras', '${_int(_calfNumController)}'),
      ]),
      const SizedBox(height: 16),
      _reviewGroup(context, 'Produção', 2, [
        ('Meta de produção anual', '${_annualMilkYieldController.text} kg/ano'),
      ]),
      const SizedBox(height: 16),
      _reviewGroup(context, 'Propriedade', 3, [
        ('Tamanho do campo 1', '${_fieldSize1Controller.text} acres'),
        ('Tamanho do campo 2', '${_fieldSize2Controller.text} acres'),
        ('Código do condado (FIPS)', _fipsCountyCodeController.text),
      ]),
      if (_submitError != null) ...[
        const SizedBox(height: 16),
        Text(_submitError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    ]);
  }

  Widget _reviewGroup(BuildContext context, String titulo, int step, List<(String, String)> itens) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(titulo, style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                onPressed: () => setState(() => _step = step),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Alterar'),
              ),
            ],
          ),
          for (final (rotulo, valor) in itens)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(rotulo, style: Theme.of(context).textTheme.bodyMedium),
                  Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmacaoStep(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.amber,
              child: Icon(Icons.check_circle, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text('Cadastro enviado', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'Recebemos as informações da sua fazenda. A simulação já começou — '
              'pode levar cerca de 10 minutos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _goToStatus,
              icon: const Icon(Icons.rss_feed),
              label: const Text('Acompanhar simulação'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _goToList,
              child: const Text('Voltar para minhas fazendas'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (_step > 1)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _back,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar'),
              ),
            ),
          if (_step > 1) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _advance,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_forward),
              label: Text(
                _submitting
                    ? 'Enviando...'
                    : (_step == 3 ? 'Revisar respostas' : (_step == 4 ? 'Enviar cadastro' : 'Próximo')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperField({
    required String label,
    required String helper,
    required TextEditingController controller,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(helper, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton.filled(
              onPressed: onDecrement,
              icon: const Icon(Icons.remove),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.lightGreen,
                foregroundColor: AppColors.primaryGreen,
                minimumSize: const Size(52, 52),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: '0'),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: onIncrement,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.lightGreen,
                foregroundColor: AppColors.primaryGreen,
                minimumSize: const Size(52, 52),
              ),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          _hintBanner(errorText),
        ],
      ],
    );
  }

  Widget _hintBanner(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
