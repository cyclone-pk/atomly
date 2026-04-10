import 'dart:async';

import 'package:meta/meta.dart';

import 'atom_lifecycle.dart';
import 'atom_reader.dart';
import 'atom_value.dart';

/// The single primitive at the heart of atomly.
///
/// Every piece of state in an atomly app is an `Atom<T>`. There are no
/// providers, no notifiers, no events, no states, no blocs — just
/// atoms. They are usually defined as top-level constants:
///
/// ```dart
/// // 1. plain value
/// final counter = Atom(0);
///
/// // 2. derived / computed
/// final doubled = Atom.computed((read) => read(counter) * 2);
///
/// // 3. async (Future)
/// final user = Atom.future((read) async {
///   final id = read(userIdAtom);
///   return await api.fetchUser(id);
/// });
///
/// // 4. async (Stream)
/// final clock = Atom.stream((read) =>
///   Stream.periodic(const Duration(seconds: 1), (i) => i));
///
/// // 5. parameterized (family)
/// final post = Atom.family<int, AtomValue<Post>>(
///   (id) => Atom.future((read) => api.fetchPost(id)),
/// );
/// ```
///
/// Atoms are *keys*: they identify a slot in the runtime store. The
/// runtime caches their values, tracks their dependencies on other
/// atoms, and disposes them automatically when nothing watches them
/// anymore. Two references to the same atom constant are the same
/// state; constructing a "second" `Atom(0)` makes a different one.
///
/// Reading and writing atoms is done through the Flutter integration
/// in `package:atomly_flutter` (`atom.watch(context)`, `atom.update(...)`),
/// or through an `AtomStore` instance directly for headless tests.
@immutable
abstract class Atom<T> {
  /// Internal — concrete subclasses call this. User code uses one of
  /// the named constructors below.
  const Atom._internal();

  /// A plain mutable cell holding [initialValue].
  ///
  /// ```dart
  /// final counter = Atom(0);
  /// ```
  ///
  /// Update via `counter.update(context, (v) => v + 1)` or
  /// `counter.set(context, 42)` from a widget, or
  /// `store.update(counter, (v) => v + 1)` from a headless test.
  factory Atom(T initialValue) = _ValueAtom<T>;

  /// A derived atom whose value is computed from other atoms.
  ///
  /// The framework tracks every atom you read inside [compute]. When
  /// any of those dependencies change, the computed atom is invalidated
  /// and re-runs.
  ///
  /// ```dart
  /// final doubled = Atom.computed((read) => read(counter) * 2);
  /// ```
  static Atom<R> computed<R>(R Function(AtomReader read) compute) =>
      _ComputedAtom<R>(compute);

  /// An asynchronous atom backed by a `Future`.
  ///
  /// The first read returns `AtomLoading()`. When the future completes,
  /// the value flips to `AtomData(result)` (or `AtomError(...)`) and
  /// every watcher rebuilds.
  ///
  /// You can declare dependencies on other atoms via [read]; the future
  /// is re-run whenever those dependencies change. While the new value
  /// is loading, the previous data is carried forward in
  /// `AtomLoading.previousData` so widgets can render stale data.
  ///
  /// ```dart
  /// final user = Atom.future((read) async {
  ///   final id = read(userIdAtom);
  ///   read.onDispose(() => api.cancelInFlight());
  ///   return api.fetchUser(id);
  /// });
  /// ```
  static Atom<AtomValue<R>> future<R>(
    FutureOr<R> Function(AtomReader read) load,
  ) =>
      _FutureAtom<R>(load);

  /// An asynchronous atom backed by a `Stream`.
  ///
  /// Each emitted value becomes the next `AtomData`. Errors become
  /// `AtomError`. The first read returns `AtomLoading` until the stream
  /// emits its first event.
  ///
  /// The stream subscription is auto-cancelled when the atom is
  /// disposed.
  ///
  /// ```dart
  /// final clock = Atom.stream((read) =>
  ///   Stream.periodic(const Duration(seconds: 1), (i) => i));
  /// ```
  static Atom<AtomValue<R>> stream<R>(
    Stream<R> Function(AtomReader read) build,
  ) =>
      _StreamAtom<R>(build);

  /// A factory that produces a distinct atom for every argument value.
  ///
  /// Use this when state is keyed by something — a route id, a list
  /// index, a tab name. Each call with a new argument creates (and
  /// caches) a fresh atom; the same argument returns the same atom.
  ///
  /// ```dart
  /// final post = Atom.family<int, AtomValue<Post>>(
  ///   (id) => Atom.future((read) => api.fetchPost(id)),
  /// );
  ///
  /// // In a widget:
  /// post(42).watch(context); // returns AtomValue<Post> for id=42
  /// ```
  static AtomFamily<Arg, R> family<Arg, R>(
    Atom<R> Function(Arg arg) factory,
  ) =>
      AtomFamily<Arg, R>._(factory);

  /// Wraps a constant value as an atom that never changes. Useful in
  /// tests for overriding async atoms with a fixed result.
  ///
  /// ```dart
  /// AtomScope(
  ///   overrides: {user: Atom.constant(AtomValue.data(testUser))},
  ///   child: ...
  /// )
  /// ```
  static Atom<R> constant<R>(R value) => _ValueAtom<R>(value);

  /// Internal — the runtime calls this once per atom instance to
  /// produce its initial value.
  ///
  /// The signature uses `Object?` instead of `T` deliberately: the
  /// store stores values type-erased so it can iterate dependents and
  /// dependencies without colliding with Dart's invariant generic
  /// class parameters. The user-facing API casts back to `T` at the
  /// boundary.
  @internal
  Object? initializeState(AtomLifecycle<Object?> lc);

  /// Whether the runtime should keep this atom's state alive after the
  /// last watcher unsubscribes. Defaults to `false` (auto-dispose).
  /// Override via [keepAlive].
  bool get isKeptAlive => false;

  /// Returns a wrapper that prevents auto-dispose. Use sparingly — the
  /// default of "dispose when nobody watches" is what makes async
  /// atoms cheap.
  ///
  /// ```dart
  /// final session = Atom('guest').keepAlive();
  /// ```
  Atom<T> keepAlive() => _KeepAliveAtom<T>(this);
}

// ─────────────────────────────────────────────────────────────────────
// Concrete subclasses (private to the package)
// ─────────────────────────────────────────────────────────────────────

/// A plain value atom.
class _ValueAtom<T> extends Atom<T> {
  final T _initial;

  const _ValueAtom(this._initial) : super._internal();

  @override
  Object? initializeState(AtomLifecycle<Object?> lc) => _initial;

  @override
  String toString() => 'Atom<$T>($_initial)';
}

/// A derived atom whose value is computed from other atoms.
class _ComputedAtom<T> extends Atom<T> {
  final T Function(AtomReader read) _compute;

  const _ComputedAtom(this._compute) : super._internal();

  @override
  Object? initializeState(AtomLifecycle<Object?> lc) => _compute(lc.reader);

  @override
  String toString() => 'Atom.computed<$T>';
}

/// A future-backed async atom.
class _FutureAtom<T> extends Atom<AtomValue<T>> {
  final FutureOr<T> Function(AtomReader read) _load;

  const _FutureAtom(this._load) : super._internal();

  @override
  Object? initializeState(AtomLifecycle<Object?> lc) {
    var cancelled = false;
    lc.reader.onDispose(() => cancelled = true);

    final FutureOr<T> result;
    try {
      result = _load(lc.reader);
    } catch (e, st) {
      return AtomValue.error<T>(e, stackTrace: st);
    }

    if (result is Future<T>) {
      result.then(
        (value) {
          if (cancelled) return;
          lc.setValue(AtomValue.data(value));
        },
        onError: (Object e, StackTrace st) {
          if (cancelled) return;
          lc.setValue(AtomValue.error<T>(e, stackTrace: st));
        },
      );
      return AtomValue.loading<T>();
    }
    return AtomValue.data<T>(result);
  }

  @override
  String toString() => 'Atom.future<$T>';
}

/// A stream-backed async atom.
class _StreamAtom<T> extends Atom<AtomValue<T>> {
  final Stream<T> Function(AtomReader read) _build;

  const _StreamAtom(this._build) : super._internal();

  @override
  Object? initializeState(AtomLifecycle<Object?> lc) {
    final Stream<T> stream;
    try {
      stream = _build(lc.reader);
    } catch (e, st) {
      return AtomValue.error<T>(e, stackTrace: st);
    }
    final sub = stream.listen(
      (value) => lc.setValue(AtomValue.data(value)),
      onError: (Object e, StackTrace st) =>
          lc.setValue(AtomValue.error<T>(e, stackTrace: st)),
    );
    lc.reader.onDispose(sub.cancel);
    return AtomValue.loading<T>();
  }

  @override
  String toString() => 'Atom.stream<$T>';
}

/// Wrapper that disables auto-dispose for the inner atom.
class _KeepAliveAtom<T> extends Atom<T> {
  final Atom<T> _inner;

  const _KeepAliveAtom(this._inner) : super._internal();

  @override
  Object? initializeState(AtomLifecycle<Object?> lc) =>
      _inner.initializeState(lc);

  @override
  bool get isKeptAlive => true;

  @override
  String toString() => '$_inner.keepAlive()';
}

// ─────────────────────────────────────────────────────────────────────
// Family
// ─────────────────────────────────────────────────────────────────────

/// A factory that produces a distinct [Atom] for every argument value.
///
/// Created via [Atom.family]. Calling the family with an argument
/// returns the cached atom for that argument (creating it on the first
/// call):
///
/// ```dart
/// final post = Atom.family<int, AtomValue<Post>>(
///   (id) => Atom.future((read) => api.fetchPost(id)),
/// );
///
/// post(1) == post(1); // true — same Atom instance
/// post(1) == post(2); // false — different argument
/// ```
///
/// Family-produced atoms participate in auto-dispose like any other
/// atom. When the last watcher unsubscribes from `post(42)`, that
/// specific cached entry is released.
class AtomFamily<Arg, R> {
  final Atom<R> Function(Arg arg) _factory;
  final Map<Arg, Atom<R>> _cache = <Arg, Atom<R>>{};

  /// Internal — created by [Atom.family].
  AtomFamily._(this._factory);

  /// Returns the atom for [arg], creating and caching it on the first
  /// call.
  Atom<R> call(Arg arg) {
    return _cache.putIfAbsent(arg, () => _factory(arg));
  }

  /// Drops the cached atom for [arg]. The next call recreates it.
  void release(Arg arg) {
    _cache.remove(arg);
  }

  /// Drops every cached atom in this family.
  void clear() => _cache.clear();
}
