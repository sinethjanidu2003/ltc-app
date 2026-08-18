/// One checkbox option for a spasticity pattern region.
class SpasticityPatternOption {
  const SpasticityPatternOption({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;

  factory SpasticityPatternOption.fromJson(Map<String, dynamic> json) {
    final key = '${json['key'] ?? ''}'.trim();
    final label = (json['label'] as String?)?.trim();
    return SpasticityPatternOption(
      key: key,
      label: (label != null && label.isNotEmpty)
          ? label
          : _labelFromKey(key),
    );
  }
}

/// Catalog from `GET /api/spasticity-patterns`.
class SpasticityPatternCatalog {
  const SpasticityPatternCatalog({required this.regions});

  /// Region key → options (order preserved for UI).
  final Map<String, List<SpasticityPatternOption>> regions;

  /// Preferred display order matching the paper form.
  static const preferredOrder = [
    'shoulder',
    'elbow',
    'wrist',
    'thumb',
    'fingers',
    'hip',
    'knee',
    'ankle',
  ];

  List<MapEntry<String, List<SpasticityPatternOption>>> get orderedRegions {
    final entries = <MapEntry<String, List<SpasticityPatternOption>>>[];
    final seen = <String>{};

    for (final key in preferredOrder) {
      final options = regions[key];
      if (options == null || options.isEmpty) continue;
      entries.add(MapEntry(key, options));
      seen.add(key);
    }

    for (final entry in regions.entries) {
      if (seen.contains(entry.key) || entry.value.isEmpty) continue;
      entries.add(entry);
    }
    return entries;
  }

  String regionLabel(String regionKey) {
    if (regionKey.isEmpty) return regionKey;
    return regionKey[0].toUpperCase() + regionKey.substring(1);
  }

  String optionLabel(String regionKey, String optionKey) {
    final options = regions[regionKey];
    if (options != null) {
      for (final option in options) {
        if (option.key == optionKey) return option.label;
      }
    }
    return _labelFromKey(optionKey);
  }

  factory SpasticityPatternCatalog.fromJson(Map<String, dynamic> json) {
    final regionsJson = json['regions'];
    final regions = <String, List<SpasticityPatternOption>>{};

    if (regionsJson is Map) {
      for (final entry in regionsJson.entries) {
        final regionKey = '${entry.key}'.trim();
        final raw = entry.value;
        if (regionKey.isEmpty || raw is! List) continue;
        regions[regionKey] = raw
            .whereType<Map>()
            .map(
              (item) => SpasticityPatternOption.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .where((option) => option.key.isNotEmpty)
            .toList();
      }
    }

    return SpasticityPatternCatalog(regions: regions);
  }

  Map<String, dynamic> toJson() => {
        'regions': {
          for (final entry in regions.entries)
            entry.key: entry.value
                .map((o) => {'key': o.key, 'label': o.label})
                .toList(),
        },
      };

  bool get isEmpty => regions.isEmpty;
}

String _labelFromKey(String key) {
  return key.replaceAll('_', ' ').trim();
}
