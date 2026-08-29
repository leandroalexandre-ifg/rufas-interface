/// Os 5 campos da fazenda que a API usa pra montar a entrada do RuFaS
/// (ver backend/app.py FarmInputRequest e CLAUDE.md, "Nova frente").
class FarmInput {
  final int cowNum;
  final int calfNum;
  final double annualMilkYield;
  final double fieldSize1;
  final double fieldSize2;
  final int fipsCountyCode;

  FarmInput({
    required this.cowNum,
    required this.calfNum,
    required this.annualMilkYield,
    required this.fieldSize1,
    required this.fieldSize2,
    required this.fipsCountyCode,
  });

  factory FarmInput.fromJson(Map<String, dynamic> json) => FarmInput(
        cowNum: json['cow_num'] as int,
        calfNum: json['calf_num'] as int,
        annualMilkYield: (json['annual_milk_yield'] as num).toDouble(),
        fieldSize1: (json['field_size_1'] as num).toDouble(),
        fieldSize2: (json['field_size_2'] as num).toDouble(),
        fipsCountyCode: json['fips_county_code'] as int,
      );

  Map<String, dynamic> toJson() => {
        'cow_num': cowNum,
        'calf_num': calfNum,
        'annual_milk_yield': annualMilkYield,
        'field_size_1': fieldSize1,
        'field_size_2': fieldSize2,
        'fips_county_code': fipsCountyCode,
      };
}
