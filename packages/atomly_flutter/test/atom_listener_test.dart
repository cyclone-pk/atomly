import 'package:atomly_flutter/atomly_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AtomListener', () {
    testWidgets('does not fire on initial mount', (tester) async {
      final counter = Atom(0);
      var calls = 0;
      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: AtomListener<int>(
              atom: counter,
              onChange: (_, prev, next) => calls++,
              child: const SizedBox(),
            ),
          ),
        ),
      );
      expect(calls, 0);
    });

    testWidgets('fires on every change with previous and next', (tester) async {
      final counter = Atom(0);
      final calls = <(int?, int)>[];
      late BuildContext rootContext;

      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                rootContext = context;
                return AtomListener<int>(
                  atom: counter,
                  onChange: (_, prev, next) => calls.add((prev, next)),
                  child: const SizedBox(),
                );
              },
            ),
          ),
        ),
      );

      counter.set(rootContext, 1);
      await tester.pump();
      counter.set(rootContext, 2);
      await tester.pump();

      expect(calls, [(0, 1), (1, 2)]);
    });

    testWidgets('does not rebuild the child', (tester) async {
      final counter = Atom(0);
      var childBuilds = 0;
      late BuildContext rootContext;

      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                rootContext = context;
                return AtomListener<int>(
                  atom: counter,
                  onChange: (_, __, ___) {},
                  child: Builder(
                    builder: (_) {
                      childBuilds++;
                      return const SizedBox();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(childBuilds, 1);
      counter.set(rootContext, 5);
      await tester.pump();
      expect(childBuilds, 1); // listener rebuild does not propagate
    });
  });

  group('AtomConsumer', () {
    testWidgets('watches multiple atoms', (tester) async {
      final a = Atom(1);
      final b = Atom(2);
      late BuildContext rootContext;

      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                rootContext = context;
                return AtomConsumer(
                  builder: (_, watch) =>
                      Text('a:${watch(a)} b:${watch(b)}'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('a:1 b:2'), findsOneWidget);
      a.set(rootContext, 10);
      await tester.pump();
      expect(find.text('a:10 b:2'), findsOneWidget);
      b.update(rootContext, (v) => v + 100);
      await tester.pump();
      expect(find.text('a:10 b:102'), findsOneWidget);
    });
  });

  group('BuildContext extensions', () {
    testWidgets('refresh re-runs a future atom', (tester) async {
      var calls = 0;
      final probe = Atom.future<int>((_) async {
        calls++;
        return calls;
      });
      late BuildContext rootContext;

      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                rootContext = context;
                return AtomAsyncBuilder<int>(
                  atom: probe,
                  loading: (_) => const Text('loading'),
                  data: (_, v) => Text('v:$v'),
                  error: (_, e, st) => Text('e:$e'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 5));
      expect(find.text('v:1'), findsOneWidget);

      probe.refresh(rootContext);
      await tester.pump(const Duration(milliseconds: 5));
      expect(find.text('v:2'), findsOneWidget);
    });

    testWidgets('read does not subscribe', (tester) async {
      final counter = Atom(0);
      var builds = 0;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        AtomScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                builds++;
                capturedContext = context;
                // read instead of watch — does not register as a dependent
                final v = counter.read(context);
                return Text('v:$v');
              },
            ),
          ),
        ),
      );

      expect(builds, 1);
      counter.set(capturedContext, 99);
      await tester.pump();
      // Builder did not rebuild — `read` does not subscribe.
      expect(builds, 1);
    });
  });
}
