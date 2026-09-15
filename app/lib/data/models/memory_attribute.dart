/// "추억 조건" 하나 — 학교/동네/자주 간 장소 중 하나와, 그 시기(연도 범위).
class MemoryAttribute {
  const MemoryAttribute({
    required this.id,
    required this.type,
    required this.label,
    this.placeId,
    this.startYear,
    this.endYear,
  });

  final int id;
  final String type; // 'region' | 'school' | 'place'
  final String label;
  final String? placeId;
  final int? startYear;
  final int? endYear;

  String get periodLabel {
    if (startYear != null && endYear != null) return '$startYear~$endYear';
    if (startYear != null) return '$startYear~';
    if (endYear != null) return '~$endYear';
    return '';
  }

  factory MemoryAttribute.fromJson(Map<String, dynamic> json) {
    return MemoryAttribute(
      id: json['id'] as int,
      type: json['type'] as String,
      label: json['label'] as String,
      placeId: json['place_id'] as String?,
      startYear: json['start_year'] as int?,
      endYear: json['end_year'] as int?,
    );
  }
}
