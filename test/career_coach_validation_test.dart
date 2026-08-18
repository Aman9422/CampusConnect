import 'package:campusconnect/models/career_coach_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CareerCoachAnalysis.fromJson — valid input', () {
    test('parses a complete analysis', () {
      final json = <String, dynamic>{
        'careerReadiness': {
          'level': 'strong',
          'summary': 'Great profile',
        },
        'careerFocus': 'Mobile development',
        'recommendations': [
          {
            'type': 'portfolio',
            'priority': 'high',
            'title': 'Strengthen Portfolio',
            'reason': 'Your projects need more depth',
            'action': 'Build a production app',
            'whyItMatters': 'Shows real-world capability',
            'estimatedEffort': '2-3 weeks',
          },
          {
            'type': 'resume',
            'priority': 'medium',
            'title': 'Improve Resume',
            'reason': 'ATS score could be better',
            'action': 'Add more technical keywords',
          },
        ],
        'analysisVersion': 1,
      };

      final analysis = CareerCoachAnalysis.fromJson(json);

      expect(analysis.careerReadiness.level, CareerReadinessLevel.strong);
      expect(analysis.careerReadiness.summary, 'Great profile');
      expect(analysis.careerFocus, 'Mobile development');
      expect(analysis.recommendations.length, 2);
      expect(analysis.recommendations.first.type, CareerCoachRecType.portfolio);
      expect(
        analysis.recommendations.first.priority,
        CareerCoachPriority.high,
      );
      expect(analysis.recommendations.first.estimatedEffort, '2-3 weeks');
      expect(analysis.analysisVersion, 1);
      expect(analysis.hasContent, true);
    });

    test('parses from summary doc with top-level metadata', () {
      final doc = <String, dynamic>{
        'analysis': {
          'careerReadiness': {'level': 'solid', 'summary': 'Good'},
          'careerFocus': 'Web development',
          'recommendations': [
            {
              'type': 'skill',
              'priority': 'low',
              'title': 'Deepen React',
              'reason': 'Could strengthen state management',
              'action': 'Learn Redux Toolkit',
            },
          ],
          'analysisVersion': 2,
        },
        'analysisVersion': 2,
        'generatedAt': '2026-08-18T10:00:00.000Z',
        'providerUsed': 'groq',
      };

      final analysis = CareerCoachAnalysis.fromSummaryDoc(doc);

      expect(analysis.careerReadiness.level, CareerReadinessLevel.solid);
      expect(analysis.careerFocus, 'Web development');
      expect(analysis.recommendations.length, 1);
      expect(analysis.generatedAt, isNotNull);
      expect(analysis.providerUsed, 'groq');
      expect(analysis.analysisVersion, 2);
    });
  });

  group('CareerCoachAnalysis.fromJson — tolerant/fallback', () {
    test('null json returns empty analysis', () {
      final analysis = CareerCoachAnalysis.fromJson(null);
      expect(analysis.hasContent, false);
      expect(analysis.recommendations, isEmpty);
      expect(analysis.careerReadiness.level, CareerReadinessLevel.developing);
    });

    test('fromSummaryDoc with null returns empty', () {
      final analysis = CareerCoachAnalysis.fromSummaryDoc(null);
      expect(analysis.hasContent, false);
    });

    test('fromSummaryDoc with null nested analysis returns empty', () {
      final analysis = CareerCoachAnalysis.fromSummaryDoc({'analysis': null});
      expect(analysis.hasContent, false);
    });

    test('unknown readiness level falls back to developing', () {
      final json = <String, dynamic>{
        'careerReadiness': {'level': 'unknown_value', 'summary': 'Test'},
      };
      final analysis = CareerCoachAnalysis.fromJson(json);
      expect(analysis.careerReadiness.level, CareerReadinessLevel.developing);
    });

    test('unknown recommendation type is excluded (FIX-4)', () {
      final json = <String, dynamic>{
        'recommendations': [
          {
            'type': 'made_up_type',
            'priority': 'high',
            'title': 'Something',
            'reason': 'Because',
            'action': 'Do it',
          },
        ],
      };
      final analysis = CareerCoachAnalysis.fromJson(json);
      // FIX-4: unknown types produce an invalid rec (empty title) that is
      // filtered out by the isValid check — never silently mapped to profile.
      expect(analysis.recommendations, isEmpty);
    });

    test('unknown priority falls back to medium', () {
      final json = <String, dynamic>{
        'recommendations': [
          {
            'type': 'resume',
            'priority': 'ultra_critical',
            'title': 'Test',
            'reason': 'R',
            'action': 'A',
          },
        ],
      };
      final analysis = CareerCoachAnalysis.fromJson(json);
      expect(
        analysis.recommendations.first.priority,
        CareerCoachPriority.medium,
      );
    });

    test('recommendation with missing required fields is excluded', () {
      final json = <String, dynamic>{
        'recommendations': [
          {
            'type': 'portfolio',
            'priority': 'high',
            // missing title, reason, action
          },
          {
            'type': 'resume',
            'priority': 'medium',
            'title': 'Valid',
            'reason': 'Valid reason',
            'action': 'Valid action',
          },
        ],
      };
      final analysis = CareerCoachAnalysis.fromJson(json);
      // First rec is invalid (empty title), second is valid
      expect(analysis.recommendations.length, 1);
      expect(analysis.recommendations.first.title, 'Valid');
    });

    test('non-list recommendations field is ignored gracefully', () {
      final json = <String, dynamic>{
        'recommendations': 'not a list',
      };
      final analysis = CareerCoachAnalysis.fromJson(json);
      expect(analysis.recommendations, isEmpty);
    });

    test('non-map items in recommendations list are skipped', () {
      final json = <String, dynamic>{
        'recommendations': [
          'a string',
          42,
          null,
          {
            'type': 'resume',
            'priority': 'low',
            'title': 'Real',
            'reason': 'R',
            'action': 'A',
          },
        ],
      };
      final analysis = CareerCoachAnalysis.fromJson(json);
      expect(analysis.recommendations.length, 1);
      expect(analysis.recommendations.first.title, 'Real');
    });

    test('duplicates by type are excluded', () {
      final json = <String, dynamic>{
        'recommendations': [
          {
            'type': 'portfolio',
            'priority': 'high',
            'title': 'First',
            'reason': 'R1',
            'action': 'A1',
          },
          {
            'type': 'portfolio',
            'priority': 'low',
            'title': 'Duplicate',
            'reason': 'R2',
            'action': 'A2',
          },
        ],
      };
      final analysis = CareerCoachAnalysis.fromJson(json);
      expect(analysis.recommendations.length, 1);
      expect(analysis.recommendations.first.title, 'First');
    });

    test('max 5 recommendations enforced', () {
      final recs = List.generate(8, (i) {
        final types = [
          'portfolio', 'resume', 'project', 'experience',
          'certification', 'achievement', 'profile', 'skill',
        ];
        return {
          'type': types[i],
          'priority': 'medium',
          'title': 'Rec $i',
          'reason': 'R',
          'action': 'A',
        };
      });
      final json = <String, dynamic>{'recommendations': recs};
      final analysis = CareerCoachAnalysis.fromJson(json);
      expect(analysis.recommendations.length, 5);
    });
  });

  group('CareerCoachUsage', () {
    test('defaults', () {
      const usage = CareerCoachUsage();
      expect(usage.monthlyCount, 0);
      expect(usage.monthlyLimit, 3);
      expect(usage.analysesRemaining, 3);
      expect(usage.hasReachedLimit, false);
    });

    test('at limit', () {
      const usage = CareerCoachUsage(monthlyCount: 3, monthlyLimit: 3);
      expect(usage.analysesRemaining, 0);
      expect(usage.hasReachedLimit, true);
    });

    test('over limit clamps to zero remaining', () {
      const usage = CareerCoachUsage(monthlyCount: 5, monthlyLimit: 3);
      expect(usage.analysesRemaining, 0);
      expect(usage.hasReachedLimit, true);
    });

    test('fromJson parses correctly', () {
      final usage = CareerCoachUsage.fromJson({
        'monthlyCount': 2,
        'monthlyLimit': 5,
        'lastResetMonth': '2026-08',
      });
      expect(usage.monthlyCount, 2);
      expect(usage.monthlyLimit, 5);
      expect(usage.analysesRemaining, 3);
      expect(usage.lastResetMonth, '2026-08');
    });

    test('fromJson with null returns defaults', () {
      final usage = CareerCoachUsage.fromJson(null);
      expect(usage.monthlyCount, 0);
      expect(usage.monthlyLimit, 3);
    });
  });

  group('CareerCoachRecommendation — all types parse', () {
    for (final typeName in [
      'skill', 'portfolio', 'resume', 'project', 'experience',
      'certification', 'achievement', 'profile', 'interview', 'jobSearch',
    ]) {
      test('type "$typeName" parses correctly', () {
        final json = <String, dynamic>{
          'type': typeName,
          'priority': 'high',
          'title': 'Test',
          'reason': 'Because',
          'action': 'Do this',
        };
        final rec = CareerCoachRecommendation.fromJson(json);
        expect(rec.isValid, true);
        expect(rec.title, 'Test');
      });
    }
  });

  group('CareerCoachRecommendation — all priorities parse', () {
    for (final p in ['high', 'medium', 'low']) {
      test('priority "$p" parses correctly', () {
        final json = <String, dynamic>{
          'type': 'portfolio',
          'priority': p,
          'title': 'Test',
          'reason': 'R',
          'action': 'A',
        };
        final rec = CareerCoachRecommendation.fromJson(json);
        expect(rec.priority.name, p);
      });
    }
  });

  group('CareerReadiness — all levels parse', () {
    for (final level in ['strong', 'solid', 'developing', 'sparse']) {
      test('level "$level" parses correctly', () {
        final readiness = CareerReadiness.fromJson({
          'level': level,
          'summary': 'test',
        });
        expect(readiness.level.name, level);
        expect(readiness.hasContent, true);
      });
    }
  });

  group('Timestamp parsing', () {
    test('ISO string parses to DateTime', () {
      final json = <String, dynamic>{
        'generatedAt': '2026-08-18T10:30:00.000Z',
      };
      final analysis = CareerCoachAnalysis.fromJson(json);
      expect(analysis.generatedAt, isNotNull);
      expect(analysis.generatedAt!.year, 2026);
    });

    test('null generatedAt returns null', () {
      final analysis = CareerCoachAnalysis.fromJson(<String, dynamic>{});
      expect(analysis.generatedAt, isNull);
    });
  });

  group('toJson roundtrip', () {
    test('roundtrip preserves data', () {
      final original = CareerCoachAnalysis(
        careerReadiness: const CareerReadiness(
          level: CareerReadinessLevel.solid,
          summary: 'Good student',
        ),
        careerFocus: 'Data science',
        recommendations: [
          const CareerCoachRecommendation(
            type: CareerCoachRecType.project,
            priority: CareerCoachPriority.high,
            title: 'Build ML Pipeline',
            reason: 'Strengthens practical skills',
            action: 'Create an end-to-end project',
            whyItMatters: 'Shows production capability',
            estimatedEffort: '3 weeks',
          ),
        ],
        analysisVersion: 1,
      );

      final json = original.toJson();
      final restored = CareerCoachAnalysis.fromJson(json);

      expect(restored.careerReadiness.level, CareerReadinessLevel.solid);
      expect(restored.careerReadiness.summary, 'Good student');
      expect(restored.careerFocus, 'Data science');
      expect(restored.recommendations.length, 1);
      expect(
        restored.recommendations.first.type,
        CareerCoachRecType.project,
      );
      expect(restored.recommendations.first.title, 'Build ML Pipeline');
      expect(
        restored.recommendations.first.estimatedEffort,
        '3 weeks',
      );
    });
  });

  group('No-skill-row contract (v9.0)', () {
    test('skill type is supported but not auto-generated from role lists', () {
      // The model supports 'skill' as a valid type (the AI CAN recommend
      // a genuinely important missing skill). But the contract from Task.md
      // §1.1 says the system must NOT auto-recommend technologies from
      // generic role requirement lists.
      //
      // This is enforced by the backend prompt (career_coach.js 14 rules),
      // not the client model. The model test simply confirms 'skill' type
      // is supported and parseable.
      final json = <String, dynamic>{
        'recommendations': [
          {
            'type': 'skill',
            'priority': 'medium',
            'title': 'Learn Docker for deployment',
            'reason':
                'Your project lacks deployment pipeline — Docker is '
                'directly relevant to your current stack needs',
            'action': 'Containerize your existing Flutter backend',
          },
        ],
      };
      final analysis = CareerCoachAnalysis.fromJson(json);
      expect(analysis.recommendations.length, 1);
      expect(analysis.recommendations.first.type, CareerCoachRecType.skill);
      // The AI provides context-specific titles, not generic "Learn Kotlin"
      expect(
        analysis.recommendations.first.title,
        contains('Docker'),
      );
    });
  });

  group('Navigation type mapping', () {
    test('all recommendation types have a valid enum value', () {
      expect(CareerCoachRecType.values.length, 10);
      expect(CareerCoachPriority.values.length, 3);
      expect(CareerReadinessLevel.values.length, 4);
    });
  });
}
