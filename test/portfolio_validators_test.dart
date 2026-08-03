import 'package:campusconnect/utilities/portfolio_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PortfolioValidators.required', () {
    test('null and empty values are rejected', () {
      expect(PortfolioValidators.required(null, 'Title'), isNotNull);
      expect(PortfolioValidators.required('', 'Title'), isNotNull);
      expect(PortfolioValidators.required('   ', 'Title'), isNotNull);
    });

    test('non-empty values pass', () {
      expect(PortfolioValidators.required('Hello', 'Title'), isNull);
    });
  });

  group('PortfolioValidators.optionalUrl', () {
    test('empty optional values pass', () {
      expect(PortfolioValidators.optionalUrl(null), isNull);
      expect(PortfolioValidators.optionalUrl(''), isNull);
      expect(PortfolioValidators.optionalUrl('   '), isNull);
    });

    test('https URLs pass', () {
      expect(
        PortfolioValidators.optionalUrl('https://github.com/aman'),
        isNull,
      );
    });

    test('http URLs pass when allowHttp (default)', () {
      expect(
        PortfolioValidators.optionalUrl('http://example.com'),
        isNull,
      );
    });

    test('http URLs rejected when allowHttp: false (H3)', () {
      expect(
        PortfolioValidators.optionalUrl('http://example.com', allowHttp: false),
        isNotNull,
      );
    });

    test('https URLs still pass when allowHttp: false (H3)', () {
      expect(
        PortfolioValidators.optionalUrl('https://example.com', allowHttp: false),
        isNull,
      );
    });

    test('scheme-less and malformed strings rejected', () {
      expect(PortfolioValidators.optionalUrl('github.com/aman'), isNotNull);
      expect(PortfolioValidators.optionalUrl('not a url'), isNotNull);
      expect(PortfolioValidators.optionalUrl('https://'), isNotNull);
    });
  });
}
