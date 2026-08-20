import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/spasticity_assessment.dart';
import '../models/spasticity_pattern_catalog.dart';
import '../theme/app_theme.dart';
import 'section_card.dart';

/// Read-only full snapshot of an earlier assessment (history).
class PreviousVisitSummary extends StatelessWidget {
  const PreviousVisitSummary({
    super.key,
    required this.assessment,
    this.catalog = const SpasticityPatternCatalog(regions: {}),
    this.title = 'Previous visit',
    this.initiallyExpanded = true,
  });

  final SpasticityAssessment assessment;
  final SpasticityPatternCatalog catalog;
  final String title;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      subtitle:
          '${assessment.assessmentType.label} · ${formatDate(assessment.assessmentDate)}',
      icon: Icons.history,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text(
            'Full overview from earlier assessment',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          children: [
            _blockTitle('Assessment overview'),
            _kv('Type', assessment.assessmentType.label),
            _kv('Body parts', formatBodyParts(assessment.bodyParts)),
            _kv('Side', assessment.side.label),
            if (assessment.outcome != null)
              _kv('Outcome', assessment.outcome!.label),
            const SizedBox(height: 12),
            _blockTitle('Spasticity pattern'),
            if (!assessment.patterns.hasAny)
              const Text(
                'No patterns recorded',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else
              ..._patternRows(),
            const SizedBox(height: 12),
            _blockTitle('Treatment goals'),
            if (assessment.goals.activeGoals.isEmpty)
              const Text(
                'No goals selected',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: assessment.goals.activeGoals
                    .map(
                      (goal) => Chip(
                        label: Text(goal),
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            AppColors.accent.withValues(alpha: 0.08),
                        side: BorderSide(
                          color: AppColors.accent.withValues(alpha: 0.2),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 12),
            _blockTitle('Botox injection record'),
            if (assessment.botoxInjections.isEmpty)
              const Text(
                'No injections recorded',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else
              ...assessment.botoxInjections
                  .where((injection) => injection.totalUnits > 0)
                  .map(
                    (injection) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              injection.muscle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            [
                              if (injection.rightUnits != null)
                                'R ${injection.rightUnits}',
                              if (injection.leftUnits != null)
                                'L ${injection.leftUnits}',
                            ].join(' · '),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            if (assessment.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _blockTitle('Clinical notes'),
              Text(
                assessment.notes,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _patternRows() {
    final rows = <Widget>[];
    final regions = catalog.isEmpty
        ? assessment.patterns.byRegion.entries
        : [
            ...catalog.orderedRegions.map(
              (entry) => MapEntry(
                entry.key,
                assessment.patterns.keysFor(entry.key),
              ),
            ),
            ...assessment.patterns.byRegion.entries.where(
              (entry) => !catalog.regions.containsKey(entry.key),
            ),
          ];

    for (final entry in regions) {
      if (entry.value.isEmpty) continue;
      final label = catalog.regionLabel(entry.key);
      final values = entry.value
          .map((key) => catalog.optionLabel(entry.key, key))
          .join(', ');
      rows.add(_kv(label, values));
    }
    return rows;
  }

  Widget _blockTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
