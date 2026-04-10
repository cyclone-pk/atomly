# atomly

> Atomic state management for Flutter and Dart. One primitive — `Atom<T>` — handles **everything**: sync state, async state with built-in loading/error handling, computed values, parameterized families, and side effects. Zero boilerplate. Zero code generation. Zero `BuildContext` lifecycle dance.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/Dart-%5E3.5.0-blue.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.22.0-blue.svg)](https://flutter.dev)

```dart
import 'package:atomly_flutter/atomly_flutter.dart';

// 1. Define atoms as top-level constants. No classes, no providers.
final counter = Atom(0);
final doubled = Atom.computed((read) => read(counter) * 2);
final user = Atom.future((read) async => api.fetchUser(read(userIdAtom)));

// 2. Read from any widget.
class CounterText extends StatelessWidget {
  Widget build(BuildContext context) => Text('${counter.watch(context)}');
}

// 3. Update from anywhere.
counter.update(context, (v) => v + 1);

// 4. Async state has loading/data/error built into the type.
user.when(
  context,
  data: (u) => Text(u.name),
  loading: () => const CircularProgressIndicator(),
  error: (e, st) => Text('Error: $e'),
);
```

That's the entire mental model. Five concepts: `Atom`, `read`, `watch`, `update`, `listen`.

---

## Why atomly

Flutter state management has matured around three big pain points. atomly was built specifically to fix them at the same time.

| Pain | Existing fix | atomly's answer |
|---|---|---|
| **Provider** is tied to `BuildContext` and `InheritedWidget` — placement matters, lookups can fail, lifecycle is awkward | Riverpod's global providers | Atoms are top-level constants. There is no `InheritedWidget` per atom and no "wrong context" — `atom.watch(context)` works from any descendant of the single root `AtomScope`. |
| **BLoC** has too many classes per screen: events + states + bloc + provider + listener + repository | `BlocSelector`, `BlocBuilder.buildWhen`, `MultiBlocProvider`, `Equatable` | One `Atom<T>` covers all of those roles. No events, no separate state classes, no per-screen wiring. |
| **Async state** ceremony: loading, refresh, caching, retry, stale-while-revalidate, error handling | Riverpod's `AsyncValue` + `FutureProvider` + `ref.refresh` | `Atom.future((read) async => ...)` returns an `AtomValue<T>` with `data`/`loading`/`error` already in the type. `previousData` is carried forward automatically for stale-while-revalidate. `atom.refresh(context)` re-runs the loader. |
| **Unnecessary rebuilds** when state is wired badly | `BlocSelector`, `context.select`, `buildWhen` | `AtomScope` is an `InheritedModel<Atom>` — each watching widget registers its atom as the *aspect*, so widgets only rebuild when *their* atom changes. The filter is built in, not opt-in. |
| **Side effects** (snackbar / nav / dialog) mixed into UI logic | `BlocListener`, manual `ref.listen` | `AtomListener<T>` is a dedicated widget that runs callbacks on changes **without rebuilding**. You can never accidentally fire a snackbar twice. |
| **Auto-dispose / lifecycle** | `.autoDispose` modifier in Riverpod | Auto-dispose is the default. Opt out with `.keepAlive()`. |
| **Testing** | Override providers + ProviderScope | `AtomScope(overrides: [counter.overrideWithValue(42)])` for widget tests, or `AtomStore()` for headless unit tests — no widgets needed. |
| **Code generation** | Manual or `riverpod_generator` | None. Pure Dart, no `build_runner`. |

---

## This is a monorepo

This repository contains two packages, managed with [melos](https://melos.invertase.dev):

| Package | Path | Description |
|---|---|---|
| [`atomly`](packages/atomly) | [`packages/atomly`](packages/atomly) | Pure-Dart core. `Atom<T>`, `AtomStore`, `AtomValue`, `AtomReader`, observers, overrides. Runs on the VM, web, and Flutter. |
| [`atomly_flutter`](packages/atomly_flutter) | [`packages/atomly_flutter`](packages/atomly_flutter) | Flutter integration. `AtomScope`, `AtomBuilder`, `AtomConsumer`, `AtomListener`, and the `BuildContext` extensions. |

A complete demo Flutter app using both packages lives at [`packages/atomly_flutter/example`](packages/atomly_flutter/example) — five tabs, every feature.

### Workspace setup

```sh
# One-time
dart pub global activate melos
git clone https://github.com/cyclone-pk/atomly.git
cd atomly
dart pub get          # bootstraps melos itself
melos bootstrap       # links the local packages

# Common tasks
melos run analyze         # dart analyze every Dart-only package
melos run analyze:flutter # flutter analyze every Flutter package
melos run test            # dart test every Dart-only package
melos run test:flutter    # flutter test every Flutter package
melos run format          # dart format the workspace
melos run publish:dry     # publish dry-run on every Dart package
```

---

## The five concepts

That's all you have to learn:

| Concept | What it is |
|---|---|
| `Atom<T>` | A piece of state. Sync, computed, async, stream, or family — same primitive. |
| `read` | Reads an atom (and tracks it as a dependency when used inside a builder). |
| `watch` | Reads an atom from a widget *and* subscribes to rebuilds when it changes. |
| `update` / `set` | Writes a new value (and propagates to dependents). |
| `listen` | Side-effect callback that fires on change without rebuilding. |

Everything else (`AtomScope`, `AtomBuilder`, `AtomListener`, `AtomConsumer`) supports those five.

---

## Install

```yaml
dependencies:
  atomly: ^0.1.0
  atomly_flutter: ^0.1.0
```

For pure-Dart use (CLI tools, server, headless tests) you only need `atomly`. The Flutter integration adds `atomly_flutter` on top.

---

## API tour

### 1. Sync state

```dart
final counter = Atom(0);

class CounterText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('${counter.watch(context)}');
  }
}

// Anywhere with a context:
counter.set(context, 42);
counter.update(context, (v) => v + 1);
```

### 2. Computed state — automatic dependency tracking

```dart
final counter = Atom(0);
final doubled = Atom.computed((read) => read(counter) * 2);
final isEven = Atom.computed((read) => read(counter) % 2 == 0);
```

When `counter` changes, **only** the computed atoms that called `read(counter)` are invalidated. Multi-level chains work transparently:

```dart
final a = Atom(1);
final b = Atom.computed((read) => read(a) + 1);
final c = Atom.computed((read) => read(b) * 10);
// c == 20. Set a = 4 → b == 5 → c == 50.
```

### 3. Async state — loading / data / error baked into the type

```dart
final user = Atom.future<User>((read) async {
  final id = read(userIdAtom);     // dependency tracked
  read.onDispose(() => api.cancel()); // cleanup
  return await api.fetchUser(id);
});

// In a widget:
user.when(
  context,
  data: (u) => Text(u.name),
  loading: () => const CircularProgressIndicator(),
  error: (e, st) => Text('$e'),
);
```

The first read returns `AtomLoading()`. When the future resolves it flips to `AtomData(user)`. If it throws, you get `AtomError(error, stackTrace)`. When `userIdAtom` changes, the future re-runs automatically and `AtomLoading.previousData` carries the previous user forward so you can render stale data while refreshing.

Force a refetch with `user.refresh(context)`. Drop the cached value and recreate from scratch with `user.invalidate(context)`.

### 4. Stream-backed atoms

```dart
final clock = Atom.stream((read) =>
  Stream.periodic(const Duration(seconds: 1), (i) => i));
```

Same `AtomValue<T>` pattern. The stream subscription is auto-cancelled on dispose.

### 5. Family — parameterized atoms

```dart
final post = Atom.family<int, AtomValue<Post>>(
  (id) => Atom.future((read) => api.fetchPost(id)),
);

// Each call with a new arg creates and caches a fresh atom.
post(42).watch(context); // AtomValue<Post> for id 42
post(43).watch(context); // independent state, separate cache entry
identical(post(42), post(42)); // true
```

### 6. Selectors and child-rebuild isolation

`AtomScope` is built on `InheritedModel<Atom>`. Each `atom.watch(context)` registers that atom as the rebuild *aspect*, so widgets that watched only `counter` do **not** rebuild when `userId` changes — even though both atoms live in the same store. This is the same per-aspect filtering that `Provider` achieves with one `InheritedWidget` per provider, but with one scope and zero per-atom widget boilerplate.

For finer-grained control, derive a computed atom:

```dart
final userName = Atom.computed((read) =>
  read(user).when(data: (u) => u.name, loading: (_) => '...', error: (_, __, ___) => '?'));

// Now widgets only rebuild when the *name* changes, not the whole user.
final name = userName.watch(context);
```

### 7. Side effects without rebuilds

```dart
AtomListener<AtomValue<User>>(
  atom: user,
  onChange: (context, previous, next) {
    if (next case AtomError(:final error)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  },
  child: const HomeBody(),
);
```

The child does not rebuild when the atom changes — only the listener fires. Perfect for snackbars, navigation, dialogs, analytics, haptics, audio cues, anything you do **not** want coupled to the build cycle.

### 8. Auto-dispose by default

When the last widget unsubscribes from an atom, its state (and any dependencies it owns) is released automatically. `Atom.future` cleans up its in-flight request via the `read.onDispose` callback. `Atom.stream` cancels its subscription. No manual lifecycle management.

Opt out for atoms that need to outlive their watchers:

```dart
final session = Atom('guest').keepAlive();
```

### 9. Testing

#### Headless (no widgets)

```dart
test('counter increments', () {
  final store = AtomStore();
  expect(store.read(counter), 0);
  store.update(counter, (v) => v + 1);
  expect(store.read(counter), 1);
});
```

#### Widget tests with overrides

```dart
testWidgets('shows test user', (tester) async {
  await tester.pumpWidget(
    AtomScope(
      overrides: [
        user.overrideWith(Atom.constant(AtomValue.data(testUser))),
        counter.overrideWithValue(42),
      ],
      child: const UserGreeting(),
    ),
  );
  expect(find.text('Test User'), findsOneWidget);
});
```

`overrideWith` swaps the atom; `overrideWithValue` pins it to a fixed value. Both are type-safe extension methods on `Atom<T>`.

### 10. Observers

```dart
AtomScope(
  observers: [
    CallbackAtomObserver(
      onUpdate: (atom, prev, next) => debugPrint('$atom: $prev → $next'),
    ),
  ],
  child: const MyApp(),
);
```

Implement `AtomObserver` to log every read, write, and dispose — perfect for DevTools integration, time-travel debugging, or shipping atom traffic to a structured logger.

---

## Comparison

```
┌──────────────────────┬──────────┬──────────┬──────────┬──────────┐
│                      │ Provider │   BLoC   │ Riverpod │  atomly  │
├──────────────────────┼──────────┼──────────┼──────────┼──────────┤
│ Boilerplate          │   low    │   high   │  medium  │   none   │
│ Async state built in │    no    │    no    │   yes    │   yes    │
│ Code generation      │    no    │    no    │ optional │    no    │
│ Per-aspect rebuilds  │ multiple │  manual  │   yes    │ built-in │
│ Auto-dispose default │    no    │    no    │ optional │   yes    │
│ Side effects API     │   none   │ Listener │ ref.listen │ Listener │
│ BuildContext-free    │    no    │   yes    │   yes    │   yes    │
│ Number of concepts   │ 4-5      │ 6-8      │ 6-10     │    5     │
└──────────────────────┴──────────┴──────────┴──────────┴──────────┘
```

atomly is closer to Riverpod than to BLoC — same async-state-as-data philosophy — but ships with a deliberately smaller API. There is one constructor for each kind of atom (`Atom(...)`, `Atom.computed`, `Atom.future`, `Atom.stream`, `Atom.family`) and one way to read each one. No `Notifier`, `AsyncNotifier`, `StateProvider`, `StateNotifierProvider`, `FutureProvider`, `StreamProvider`, or `Provider` to choose between.

---

## Status

Both packages are at **0.1.0**. The API surface is intentionally tiny and is expected to be stable, but minor pre-1.0 adjustments are possible based on early adopter feedback.

Run the example app to see everything in action:

```sh
cd packages/atomly_flutter/example
flutter pub get
flutter run
```

## License

MIT.
