import 'package:atomly_flutter/atomly_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AtomBuilder', () {
    testWidgets('builds with the current value', (tester) async {
      final counter = Atom(7);
      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: AtomBuilder<int>(
              atom: counter,
              builder: (context, value, _) => Text('v:$value'),
            ),
          ),
        ),
      );
      expect(find.text('v:7'), findsOneWidget);
    });

    testWidgets('rebuilds on change', (tester) async {
      final counter = Atom(0);
      late BuildContext rootContext;

      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                rootContext = context;
                return AtomBuilder<int>(
                  atom: counter,
                  builder: (_, v, __) => Text('v:$v'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('v:0'), findsOneWidget);
      counter.set(rootContext, 42);
      await tester.pump();
      expect(find.text('v:42'), findsOneWidget);
    });

    testWidgets('passes through static child', (tester) async {
      final counter = Atom(0);
      var staticBuilds = 0;
      final staticChild = Builder(
        builder: (_) {
          staticBuilds++;
          return const Text('static');
        },
      );

      late BuildContext rootContext;

      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                rootContext = context;
                return AtomBuilder<int>(
                  atom: counter,
                  builder: (_, v, child) => Column(children: [Text('v:$v'), child!]),
                  child: staticChild,
                );
              },
            ),
          ),
        ),
      );

      expect(staticBuilds, 1);
      counter.update(rootContext, (v) => v + 1);
      await tester.pump();
      expect(staticBuilds, 1); // static child preserved
    });
  });

  group('AtomAsyncBuilder', () {
    testWidgets('renders loading then data', (tester) async {
      final user = Atom.future<String>((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'alice';
      });

      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: AtomAsyncBuilder<String>(
              atom: user,
              loading: (_) => const Text('loading'),
              data: (_, name) => Text('data:$name'),
              error: (_, e, st) => Text('error:$e'),
            ),
          ),
        ),
      );

      expect(find.text('loading'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('data:alice'), findsOneWidget);
    });

    testWidgets('renders error state', (tester) async {
      final bad = Atom.future<String>((_) => throw StateError('boom'));
      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: AtomAsyncBuilder<String>(
              atom: bad,
              loading: (_) => const Text('loading'),
              data: (_, v) => Text(v),
              error: (_, e, st) => Text('error:$e'),
            ),
          ),
        ),
      );
      expect(find.textContaining('error:'), findsOneWidget);
    });
  });
}
