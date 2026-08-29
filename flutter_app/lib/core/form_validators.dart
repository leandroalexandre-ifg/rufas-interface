/// Validadores de campo numérico com mensagens gentis, não técnicas —
/// evita expor "int.tryParse" ou termos de programação para o produtor.
String? validateRequiredInt(
  String? value, {
  required bool allowZero,
  required String requiredMessage,
  required String typeMessage,
  required String rangeMessage,
}) {
  if (value == null || value.trim().isEmpty) return requiredMessage;
  final parsed = int.tryParse(value.trim());
  if (parsed == null) return typeMessage;
  if (allowZero ? parsed < 0 : parsed <= 0) return rangeMessage;
  return null;
}

String? validateRequiredDouble(
  String? value, {
  required String requiredMessage,
  required String typeMessage,
  required String rangeMessage,
}) {
  if (value == null || value.trim().isEmpty) return requiredMessage;
  // Aceita virgula como separador decimal (uso comum no Brasil), alem do ponto.
  final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
  if (parsed == null) return typeMessage;
  if (parsed <= 0) return rangeMessage;
  return null;
}
