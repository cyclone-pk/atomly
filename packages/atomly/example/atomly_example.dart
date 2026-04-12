// ignore_for_file: avoid_print

import 'package:atomly/atomly.dart';

// A plain value atom — the canonical counter.
final counter = Atom(0);

// A computed atom derived from [counter].
final doubled = Atom.computed((read) => read(counter) * 2);

// An async atom backed by a Future.
final greeting = Atom.future<String>((read) async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return 'Hello, atom #${read(counter)}';
});

Future<void> main() async {
  final store = AtomStore();

  // Read initial values.
  print('counter = ${store.read(counter)}'); // 0
  print('doubled = ${store.read(doubled)}'); // 0

  // Subscribe to counter changes; the computed atom stays in sync.
  final unsubscribe = store.subscribe(counter, () {
    print('counter -> ${store.read(counter)} '
        '(doubled = ${store.read(doubled)})');
  });

  // Mutate.
  store.update<int>(counter, (v) => v + 1); // 0 -> 1
  store.set<int>(counter, 10); // 1 -> 10

  // Resolve the async atom by polling its AtomValue<String> until data.
  while (store.read(greeting) is AtomLoading) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  final value = store.read(greeting);
  value.when(
    data: (v) => print('greeting = $v'),
    loading: (_) => print('still loading'),
    error: (e, _, __) => print('error: $e'),
  );

  unsubscribe();
  store.dispose();
}
