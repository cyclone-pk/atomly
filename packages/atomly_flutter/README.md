# atomly_flutter

> Flutter integration for the [atomly](https://pub.dev/packages/atomly) atomic state manager.

This package adds Flutter widgets and `BuildContext` extensions on top of the pure-Dart `atomly` core. The combined surface is what you typically import in a Flutter app:

```dart
import 'package:atomly_flutter/atomly_flutter.dart';
// re-exports everything from package:atomly/atomly.dart as well
```

## Install

```yaml
dependencies:
  atomly: ^0.1.0
  atomly_flutter: ^0.1.0
```

## What's in the box

| Symbol | Purpose |
|---|---|
| `AtomScope` | The runtime root — wraps your app, owns an `AtomStore`, exposes it via `InheritedModel<Atom>` for per-aspect rebuilds. Optionally takes `overrides` and `observers`. |
| `BuildContext` extensions on `Atom<T>` | `watch`, `read`, `select`, `set`, `update`, `refresh`, `invalidate`. Plus `when` for `Atom<AtomValue<T>>`. |
| `AtomBuilder<T>` | Single-atom builder widget for places where you can't easily call `atom.watch(context)`. Supports a static `child:`. |
| `AtomAsyncBuilder<T>` | Same shape as `AtomBuilder`, but pattern-matches `data` / `loading` / `error` for `Atom<AtomValue<T>>`. |
| `AtomConsumer` | Multi-atom builder. The `builder` callback receives a `watch` function. |
| `AtomListener<T>` | Side-effect-only widget. Runs `onChange(context, previous, next)` on every change *without* rebuilding the child. |

## Quick start

```dart
import 'package:atomly_flutter/atomly_flutter.dart';
import 'package:flutter/material.dart';

final counter = Atom(0);

void main() {
  runApp(const AtomScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: CounterText()),
        floatingActionButton: FloatingActionButton(
          onPressed: () => counter.update(context, (v) => v + 1),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class CounterText extends StatelessWidget {
  const CounterText({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${counter.watch(context)}',
      style: const TextStyle(fontSize: 64),
    );
  }
}
```

That's a complete Flutter counter app. No `MultiBlocProvider`, no `ProviderScope` types, no event/state classes. One `AtomScope` at the root, one `Atom(0)` at the top of the file, one `counter.watch(context)` in the widget. Done.

## BuildContext extensions

Inside any widget below an `AtomScope`:

```dart
// Read + subscribe (use in build)
final value = counter.watch(context);

// Read once (use in callbacks — no rebuild)
final current = counter.read(context);

// Write
counter.set(context, 42);
counter.update(context, (v) => v + 1);

// Re-run (for Atom.future / Atom.stream)
user.refresh(context);
user.invalidate(context); // drop cache and recreate

// Async pattern matching
user.when(
  context,
  data: (u) => Text(u.name),
  loading: () => const CircularProgressIndicator(),
  error: (e, st) => Text('$e'),
  refreshing: (previous) => Text('${previous.name} (refreshing…)'), // optional
);
```

## Side effects with `AtomListener`

`AtomListener<T>` is the right tool for snackbars, navigation, dialogs, analytics, haptics — anything you do **not** want firing twice because a parent widget rebuilt:

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

The child does not rebuild when the atom changes. The listener does not fire on initial mount — only on actual changes. Mount it once near the top of the screen and forget about it.

## `AtomBuilder` and `AtomAsyncBuilder`

When you cannot easily call `atom.watch(context)` from a widget's `build` (e.g., deep inside a third-party widget that takes a `WidgetBuilder`), use the builder widgets:

```dart
AtomBuilder<int>(
  atom: counter,
  builder: (context, value, child) => Text('$value'),
)

AtomAsyncBuilder<User>(
  atom: user,
  loading: (context) => const CircularProgressIndicator(),
  data: (context, u) => Text(u.name),
  error: (context, e, st) => Text('$e'),
  refreshing: (context, prev) => Text('${prev.name}…'), // optional
)
```

Both accept an optional `child:` argument that is **not** rebuilt when the atom changes — useful for performance when part of the subtree is static.

## `AtomConsumer` — multi-atom builder

Watch many atoms in one place without nesting builders:

```dart
AtomConsumer(
  builder: (context, watch) {
    final count = watch(counter);
    final doubled = watch(doubledAtom);
    final user = watch(currentUser);
    return Text('$count → $doubled (${user.id})');
  },
)
```

## Test overrides

`AtomScope` accepts an `overrides:` list. Build entries with `atom.overrideWith(...)` (substitute the atom) or `atom.overrideWithValue(...)` (pin to a fixed value):

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

For headless unit tests (no widgets), use `AtomStore` directly — see the [`atomly` package README](../atomly/README.md).

## Observers

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

## Per-aspect rebuilds

`AtomScope` is built on `InheritedModel<Atom>`. Every `atom.watch(context)` call registers that atom as the rebuild *aspect* — so widgets that watched only `counter` do **not** rebuild when `userId` changes, even though both atoms live in the same store. The filter is built in, not opt-in. There is no `BlocSelector` analogue to remember to use.

## Example app

A complete demo app exercising every feature lives at [`example/lib/main.dart`](example/lib/main.dart). Five tabs:

1. **Counter** — sync atoms, computed atoms, child rebuild isolation
2. **Async** — `Atom.future` + `AtomAsyncBuilder` + `refresh`
3. **Family** — parameterized atoms keyed by id
4. **Listener** — `AtomListener` showing snackbars without rebuilds
5. **Override** — nested `AtomScope` with a scoped override

Run it:

```sh
cd packages/atomly_flutter/example
flutter pub get
flutter run
```

## Tests

This package ships with **18 widget tests** covering `AtomScope` setup, scope lookup errors, override application, per-aspect rebuild filtering, `AtomBuilder` / `AtomAsyncBuilder`, `AtomConsumer`, `AtomListener` (no-rebuild guarantee), and the `BuildContext` extensions.

```sh
cd packages/atomly_flutter
flutter test
```

## Public API reference

`package:atomly_flutter/atomly_flutter.dart` exports:

- Everything from `package:atomly/atomly.dart` (`Atom`, `AtomValue`, `AtomStore`, `AtomReader`, `AtomOverride`, `AtomObserver`, etc.)
- `AtomScope`, `AtomBuilder`, `AtomAsyncBuilder`, `AtomConsumer`, `AtomListener`
- `BuildContext` extensions: `watch`, `read`, `select`, `set`, `update`, `refresh`, `invalidate`, `when`

So you only need a single import in your Flutter app.

## License

MIT.
