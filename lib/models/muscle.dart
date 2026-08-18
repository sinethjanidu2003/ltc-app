class Muscle {
  const Muscle({
    required this.id,
    required this.name,
    required this.isCustom,
    this.facilityId,
  });

  final String id;
  final String name;
  final bool isCustom;
  final String? facilityId;

  factory Muscle.fromJson(Map<String, dynamic> json) {
    return Muscle(
      id: '${json['id']}',
      name: (json['name'] as String?)?.trim() ?? 'Muscle',
      isCustom: json['is_custom'] == true,
      facilityId: json['ltc_facility_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_custom': isCustom,
        'ltc_facility_id': facilityId,
      };
}
