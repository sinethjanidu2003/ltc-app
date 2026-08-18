/// NeoClinic often stores a composite clinical string in `address`, e.g.
/// `Dec 01 2020, Miramichi Lodge, Stroke (437)`:
/// - date of admission
/// - LTC facility name (not shown in UI)
/// - condition
class ClinicalAddressParts {
  const ClinicalAddressParts.parsed({
    required this.dateOfAdmission,
    required this.condition,
  })  : isParsed = true,
        rawAddress = null;

  const ClinicalAddressParts.asAddress(this.rawAddress)
      : isParsed = false,
        dateOfAdmission = null,
        condition = null;

  final bool isParsed;
  final String? dateOfAdmission;
  final String? condition;
  final String? rawAddress;
}

final _admissionDatePattern = RegExp(
  r'^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\s+\d{4}$',
  caseSensitive: false,
);

/// Parses the composite address string. Falls back to raw Address when format
/// does not match.
ClinicalAddressParts parseClinicalAddress(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) {
    return const ClinicalAddressParts.asAddress(null);
  }

  final parts = text
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty || !_admissionDatePattern.hasMatch(parts.first)) {
    return ClinicalAddressParts.asAddress(text);
  }

  final dateOfAdmission = parts.first;

  // Prefer: date, LTC name, condition…
  if (parts.length >= 3) {
    final condition = parts.sublist(2).join(', ').trim();
    if (condition.isEmpty) return ClinicalAddressParts.asAddress(text);
    return ClinicalAddressParts.parsed(
      dateOfAdmission: dateOfAdmission,
      condition: condition,
    );
  }

  // date + condition (no LTC segment)
  if (parts.length == 2) {
    return ClinicalAddressParts.parsed(
      dateOfAdmission: dateOfAdmission,
      condition: parts[1],
    );
  }

  return ClinicalAddressParts.asAddress(text);
}
