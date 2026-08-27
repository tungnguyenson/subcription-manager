import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/ui/screens/add/cost_field.dart';

void main() {
  // A global, published by `SubdockTheme` in the running app. Put back after
  // every test so a stray list cannot reach the next one.
  tearDown(() => Fx.publishDeclared([Fx.defaultBase]));

  group('the currency chips on the amount field', () {
    test('offer what the user said they are billed in, and stop there', () {
      Fx.publishDeclared(['VND', 'EUR']);
      // No dollar chip. They named the two they are billed in, and the app
      // takes them at their word rather than adding a third for its own
      // convenience.
      expect(CostField.offered('VND'), ['VND', 'EUR']);
    });

    // Before the declared list existed everyone got dong and dollars here.
    // Dropping them for a user who declared one currency would take a chip
    // away from a form they use daily, to reward them for answering a
    // question in onboarding.
    test('still offer the other half of the bundled rate', () {
      Fx.publishDeclared(['VND']);
      expect(CostField.offered('VND'), ['VND', 'USD']);

      Fx.publishDeclared(['USD']);
      expect(CostField.offered('USD'), ['USD', 'VND']);
    });

    test('never repeat the base, wherever it sits in the list', () {
      Fx.publishDeclared(['VND', 'USD']);
      expect(CostField.offered('USD'), ['USD', 'VND']);
    });

    // Three at most, ever. A row of chips is a row of things to rule out
    // before typing, and a fourth earns its place on nobody's form.
    test('never run past three', () {
      Fx.publishDeclared(['EUR', 'GBP']);
      expect(CostField.offered('EUR'), ['EUR', 'GBP']);

      // The one case that reaches three: a single declared currency the app
      // holds no rate for, plus both halves of the rate it does hold.
      Fx.publishDeclared(['EUR']);
      expect(CostField.offered('EUR'), ['EUR', 'USD', 'VND']);
    });
  });
}
