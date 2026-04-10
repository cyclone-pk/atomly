import 'package:atomly_flutter/atomly_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final counter = Atom(0);
final doubled = Atom.computed((read) => read(counter) * 2);

class _CounterText extends StatelessWidget {
  const _CounterText();

  @override
  Widget build(BuildContext context) {
    return Text('count:${counter.watch(context)}');
  }
}

class _StaticText extends StatelessWidget {
  const _StaticText({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Text('static:$label');
}

void main() {
  group('AtomScope', () {
    testWidgets('throws when no scope ancestor exists', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _CounterText()));
      // The error is thrown during build; pumpWidget surfaces it.
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('provides a store and reads atoms', (tester) async {
      await tester.pumpWidget(
        const AtomScope(child: MaterialApp(home: _CounterText())),
      );
      expect(find.text('count:0'), findsOneWidget);
    });

    testWidgets('rebuilds the watching widget on update', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const _CounterText();
              },
            ),
          ),
        ),
      );
      expect(find.text('count:0'), findsOneWidget);
      counter.set(capturedContext, 5);
      await tester.pump();
      expect(find.text('count:5'), findsOneWidget);
    });

    testWidgets('only watching widgets rebuild', (tester) async {
      var counterBuilds = 0;
      var staticBuilds = 0;
      late BuildContext root;

      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                root = context;
                return Column(
                  children: [
                    // This Builder watches counter directly.
                    Builder(builder: (ctx) {
                      counterBuilds++;
                      final v = counter.watch(ctx);
                      return Text('count:$v');
                    }),
                    // This Builder reads nothing — should never rebuild.
                    Builder(builder: (_) {
                      staticBuilds++;
                      return const _StaticText(label: 'x');
                    }),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(counterBuilds, 1);
      expect(staticBuilds, 1);

      counter.update(root, (v) => v + 1);
      await tester.pump();

      expect(counterBuilds, 2); // watched counter -> rebuilds
      expect(staticBuilds, 1); // never watched -> stays
    });

    testWidgets('per-aspect rebuild filtering', (tester) async {
      // Two widgets watch different atoms; updating one only rebuilds
      // its own widget, not the other.
      var counterBuilds = 0;
      var doubledBuilds = 0;
      late BuildContext root;

      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                root = context;
                return Column(
                  children: [
                    Builder(builder: (ctx) {
                      counterBuilds++;
                      // Watch counter only
                      counter.watch(ctx);
                      return const SizedBox();
                    }),
                    Builder(builder: (ctx) {
                      doubledBuilds++;
                      // Watch doubled, which depends on counter — but
                      // only doubled is registered as the InheritedModel
                      // aspect for this widget. When counter changes,
                      // the store invalidates doubled, which IS the
                      // aspect, so this rebuilds too. We assert that
                      // both rebuild because doubled depends on counter.
                      doubled.watch(ctx);
                      return const SizedBox();
                    }),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(counterBuilds, 1);
      expect(doubledBuilds, 1);

      counter.update(root, (v) => v + 1);
      await tester.pump();

      // Both should rebuild — counter directly, doubled because its
      // computed value changed.
      expect(counterBuilds, 2);
      expect(doubledBuilds, 2);
    });

    testWidgets('overrides substitute atom values', (tester) async {
      await tester.pumpWidget(
        AtomScope(
          overrides: [counter.overrideWithValue(99)],
          child: const MaterialApp(home: _CounterText()),
        ),
      );
      expect(find.text('count:99'), findsOneWidget);
    });

    testWidgets('AtomScope.maybeOf returns null without scope',
        (tester) async {
      AtomStore? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = AtomScope.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(captured, isNull);
    });
  });
}
