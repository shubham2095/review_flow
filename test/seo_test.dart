import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/seo_models.dart';
import 'package:review_flow/screens/seo_sheets.dart';
import 'package:review_flow/services/nav_access.dart';
import 'package:review_flow/services/session.dart';
import 'package:review_flow/theme/brand.dart';

void main() {
  group('models', () {
    test('SeoOverview reads counts, places and context', () {
      final o = SeoOverview.fromJson({
        'keywords': 4,
        'competitors': 2,
        'checks_this_month': 7,
        'ai_configured': false,
        'locations': [
          {'id': 'l1', 'name': 'Main shop'},
        ],
        'context': {
          'business': 'Main shop',
          'city': 'Pune',
          'industry': 'Bakery',
          'location_id': 'l1',
        },
      });
      expect(o.keywords, 4);
      expect(o.checksThisMonth, 7);
      expect(o.aiConfigured, isFalse);
      expect(o.locations.single.name, 'Main shop');
      expect(o.context!.city, 'Pune');
    });

    test('SeoOverview without context or flag uses safe defaults', () {
      final o = SeoOverview.fromJson({'keywords': 0});
      expect(o.context, isNull);
      expect(o.aiConfigured, isTrue);
      expect(o.locations, isEmpty);
    });

    test('SeoKeyword reads a null rank as not checked', () {
      final k = SeoKeyword.fromJson({
        'id': 'k1',
        'keyword': 'bakery in pune',
        'city': 'Pune',
        'location': {'id': 'l1', 'name': 'Main shop'},
        'latest_rank': null,
        'checks': 0,
        'last_checked_at': null,
      });
      expect(k.latestRank, '');
      expect(k.locationName, 'Main shop');
      expect(k.lastCheckedAt, isNull);
    });

    test('rank result and analysis know whether AI answered', () {
      expect(
        SeoRankResult.fromJson({
          'source': 'ai',
          'rank': 'Top 3',
          'summary': 'Good.',
          'tips': ['Post weekly'],
        }).isAi,
        isTrue,
      );
      expect(SeoRankResult.fromJson({'source': 'fallback'}).isAi, isFalse);
      final a = SeoAnalysis.fromJson({
        'source': 'ai',
        'summary': 'You lead on reviews.',
        'strengths': ['4.6/5'],
        'gaps': ['Fewer posts'],
        'actions': ['Post weekly'],
        'my_stats': {'avg': 4.6, 'total': 120, 'name': 'Main shop'},
      });
      expect(a.myAverage, 4.6);
      expect(a.myReviews, 120);
      expect(a.gaps, ['Fewer posts']);
    });

    test('idea groups and snapshots', () {
      final g = SeoIdeaGroup.fromJson({
        'theme': 'Core',
        'keywords': ['a', 'b'],
      });
      expect(g.keywords, ['a', 'b']);
      final s = SeoSnapshot.fromJson({
        'rank': '4-10',
        'source': 'ai',
        'checked_at': '2026-11-01T10:00:00Z',
      });
      expect(s.checkedAt, isNotNull);
    });
  });

  group('seoRankInfo', () {
    test('top 3 is good, 4-10 is a warning, not in top 10 is bad', () {
      expect(seoRankInfo('Top 3').$2, good);
      expect(seoRankInfo('4-10').$2, warn);
      expect(seoRankInfo('Not in top 10').$2, bad);
    });

    test('empty and unknown values are neutral', () {
      expect(seoRankInfo('').$1, 'Not checked yet');
      expect(seoRankInfo('').$2, muted);
      expect(seoRankInfo('Unknown').$2, muted);
    });
  });

  group('form rules', () {
    test('keyword', () {
      expect(seoKeywordProblem('  '), isNotNull);
      expect(seoKeywordProblem('a' * 121), isNotNull);
      expect(seoKeywordProblem('dentist near me'), isNull);
    });

    test('competitor', () {
      expect(seoCompetitorProblem(' '), isNotNull);
      expect(seoCompetitorProblem('Rival Bakery'), isNull);
    });
  });

  group('SEO menu rule', () {
    AppUser user(List<String>? features) =>
        AppUser(id: '1', name: 'A', email: 'a@b.c', planFeatures: features);

    test('needs the seo plan feature when the plan has a feature list', () {
      expect(navAllowed(user(['reports']), NavRules.seo), isFalse);
      expect(navAllowed(user(['seo']), NavRules.seo), isTrue);
      expect(navAllowed(user(null), NavRules.seo), isTrue);
    });
  });
}
