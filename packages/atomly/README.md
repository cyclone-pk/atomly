# atomly

> The pure-Dart core of [atomly](https://github.com/cyclone-pk/atomly) — atomic state management with one primitive.

This package contains the runtime that powers atomly. It runs on the
Dart VM, the web, and Flutter. For Flutter widgets and `BuildContext`
extensions, also depend on
[`atomly_flutter`](https://pub.dev/packages/atomly_flutter).

## Install

```yaml
dependencies:
  atomly: ^0.1.0
```

```dart
import 'package:atomly/atomly.dart';
```

## What's in the box

| Symbol | Purpose |
|---|---|
| `Atom<T>` | The single state primitive. Five constructors: `Atom(value)`, `Atom.computed`, `Atom.future`, `Atom.stream`, `Atom.family`. |
| `AtomValue<T>` | Sealed `AtomData` / `AtomLoading` / `AtomError` for async state, with `previousData` for stale-while-revalidate. |
| `AtomStore` | The runtime. Caches values, tracks dependencies, dispatches changes, auto-disposes. |
| `AtomReader` | What you receive inside `Atom.computed` / `Atom.future` / `Atom.stream` callbacks. Has `call`/`get`/`peek`/`onDispose`. |
| `AtomOverride` | Test substitution helper. Build with `atom.overrideWith(...)` / `atom.overrideWithValue(...)`. |
| `AtomObserver` | Hook for logging every read, write, and dispose — perfect for DevTools or external sinks. |

## Quick taste — pure Dart, no Flutter

```dart
import 'package:atomly/atomly.dart';

final counter = Atom(0);
final doubled = Atom.computed((read) => read(counter) * 2);

void main() {
  final store = AtomStore();

  print(store.read(counter)); // 0
  print(store.read(doubled)); // 0

  store.update(counter, (v) => v + 5);

  print(store.read(counter)); // 5
  print(store.read(doubled)); // 10 — invalidated automatically
}
```

## Async state

```dart
final user = Atom.future<User>((read) async {
  final id = read(userIdAtom);
  return await api.fetchUser(id);
});

void main() async {
  final store = AtomStore();

  final initial = store.read(user);
  print(initial); // AtomLoading()

  await Future.delayed(const Duration(seconds: 1));

  final settled = store.read(user);
  print(settled); // AtomData(User(name: 'Alice'))

  // Re-fetch
  store.refresh(user);
}
```

`AtomValue<T>` is a sealed class — pattern-match it exhaustively:

```dart
final value = store.read(user);
switch (value) {
  case AtomData(:final value):     print('user: ${value.name}');
  case AtomLoading(:final previousData): print('loading (was: $previousData)');
  case AtomError(:final error):    print('failed: $error');
}

// Or use the helper:
value.when(
  data: (u) => print(u.name),
  loading: (prev) => print('loading'),
  error: (e, st, prev) => print('$e'),
);
```

## Family — parameterized atoms

```dart
final post = Atom.family<int, AtomValue<Post>>(
  (id) => Atom.future((read) => api.fetchPost(id)),
);

store.read(post(1)); // AtomLoading() then AtomData(Post(1))
store.read(post(2)); // independent — separate cached state
identical(post(1), post(1)); // true
```

## Auto-dispose and `keepAlive`

When the last subscriber unsubscribes, the atom's state is released and any registered cleanup callbacks fire:

```dart
final probe = Atom.computed((read) {
  read.onDispose(() => print('cleaning up'));
  return read(counter) * 2;
});

final dispose = store.subscribe(probe, () {});
store.read(probe); // 0
dispose();          // -> prints 'cleaning up'
```

Opt out:

```dart
final session = Atom('guest').keepAlive();
```

## Overrides — test substitution

```dart
final counter = Atom(0);
final user = Atom.future<User>((_) async => api.fetchUser());

final store = AtomStore(overrides: [
  counter.overrideWithValue(42),
  user.overrideWith(Atom.constant(AtomValue.data(testUser))),
]);

store.read(counter); // 42
store.read(user);    // AtomData(testUser) — instantly, no API call
```

## Observers

```dart
final store = AtomStore()
  ..addObserver(CallbackAtomObserver(
    onCreate: (atom, value) => print('+ $atom = $value'),
    onUpdate: (atom, prev, next) => print('~ $atom: $prev → $next'),
    onDispose: (atom, value) => print('- $atom'),
  ));
```

Implement `AtomObserver` for richer integrations (DevTools, structured logger, time-travel debugger).

## Public API reference

`package:atomly/atomly.dart` exports:

- **Primitive**: `Atom<T>`, `AtomFamily<Arg, R>`
- **Async state**: `AtomValue<T>`, `AtomData<T>`, `AtomLoading<T>`, `AtomError<T>`
- **Reading inside builders**: `AtomReader`
- **Runtime**: `AtomStore`
- **Overrides**: `AtomOverride`, plus extension methods `Atom.overrideWith` / `Atom.overrideWithValue`
- **Observers**: `AtomObserver`, `CallbackAtomObserver`

## Tests

This package ships with **34 unit tests** covering value atoms, computed atoms, async (Future) atoms, async (Stream) atoms, families, dependency invalidation, auto-dispose cascade, `keepAlive`, overrides, observers, refresh, and invalidate.

```sh
cd packages/atomly
dart test
```

## License

MIT.
