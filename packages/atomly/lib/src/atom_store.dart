import 'package:meta/meta.dart';

import 'atom.dart';
import 'atom_lifecycle.dart';
import 'atom_override.dart';
import 'atom_reader.dart';
import 'observer.dart';

/// The runtime that holds atom state.
///
/// `AtomStore` is the engine behind every atomly application. It owns
/// the cached value of each [Atom], tracks which atoms depend on which
/// other atoms, dispatches change notifications to listeners, and
/// disposes state when nothing is watching it anymore.
///
/// Most apps interact with the store through `AtomScope` and the
/// `BuildContext` extensions in `package:atomly_flutter`. You only
/// touch `AtomStore` directly when:
///
/// * writing headless unit tests (no widgets needed),
/// * embedding atomly in non-Flutter Dart code,
/// * implementing a custom integration.
///
/// ```dart
/// test('counter increments', () {
///   final store = AtomStore();
///   expect(store.read(counter), 0);
///   store.update(counter, (v) => v + 1);
///   expect(store.read(counter), 1);
/// });
/// ```
///
/// The store is *not* a singleton. You can create as many as you want;
/// they do not share state. The Flutter integration uses one store per
/// `AtomScope`.
class AtomStore {
  /// Creates a fresh store. Optionally seed it with [overrides] that
  /// replace specific atoms with alternate ones — typically used in
  /// tests to substitute fakes for async or family atoms.
  ///
  /// ```dart
  /// final store = AtomStore(overrides: [
  ///   counter.overrideWithValue(42),
  ///   user.overrideWith(Atom.constant(AtomValue.data(testUser))),
  /// ]);
  /// ```
  AtomStore({List<AtomOverride>? overrides})
      : _overrides = _buildOverrideMap(overrides);

  static Map<Atom<Object?>, Atom<Object?>> _buildOverrideMap(
    List<AtomOverride>? overrides,
  ) {
    if (overrides == null || overrides.isEmpty) {
      return const <Atom<Object?>, Atom<Object?>>{};
    }
    final out = <Atom<Object?>, Atom<Object?>>{};
    for (final o in overrides) {
      out[o.original] = o.replacement;
    }
    return Map.unmodifiable(out);
  }

  final Map<Atom<Object?>, Atom<Object?>> _overrides;
  final Map<Atom<Object?>, _AtomState> _states = <Atom<Object?>, _AtomState>{};
  final Set<AtomObserver> _observers = <AtomObserver>{};

  bool _disposed = false;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  /// Read the current value of [atom], creating its state on first
  /// access. Does **not** subscribe the caller — for that use
  /// [subscribe] (or, in widgets, `atom.watch(context)`).
  T read<T>(Atom<T> atom) {
    _assertAlive();
    return _ensureState(atom).value as T;
  }

  /// Replace the value of [atom] with [value]. Notifies every
  /// subscriber and invalidates every dependent computed atom.
  void set<T>(Atom<T> atom, T value) {
    _assertAlive();
    final state = _ensureState(atom);
    if (identical(state.value, value)) return;
    final previous = state.value;
    state.value = value;
    _notifyChange(state, previous);
  }

  /// Update [atom] by applying [updater] to its current value.
  void update<T>(Atom<T> atom, T Function(T current) updater) {
    _assertAlive();
    final state = _ensureState(atom);
    final next = updater(state.value as T);
    if (identical(state.value, next)) return;
    final previous = state.value;
    state.value = next;
    _notifyChange(state, previous);
  }

  /// Re-runs the initializer for [atom], replacing its value. Useful
  /// for `Atom.future` / `Atom.stream` to trigger a refetch.
  ///
  /// While the new value is being produced, watchers continue to see
  /// the previous value (and `AtomLoading.previousData` carries it
  /// forward for async atoms).
  void refresh<T>(Atom<T> atom) {
    _assertAlive();
    final state = _states[_effectiveAtom(atom)];
    if (state == null) {
      _ensureState(atom);
      return;
    }
    _reinitialize(state);
  }

  /// Drops the cached value for [atom]. The next read recreates it
  /// from scratch. Used to force a "cold" reload.
  void invalidate<T>(Atom<T> atom) {
    _assertAlive();
    final effective = _effectiveAtom(atom);
    final state = _states.remove(effective);
    if (state == null) return;
    state.runDisposers();
    state.clearDependencies();
    for (final dependent in state.dependents.toList()) {
      _reinitialize(dependent);
    }
    for (final listener in state.listeners.toList()) {
      listener();
    }
    _notifyObservers((o) => o.didDispose(atom, state.value));
  }

  /// Subscribe [listener] to changes in [atom]. Returns an unsubscribe
  /// function — call it to detach.
  ///
  /// The first call to `subscribe` for an atom creates its state if
  /// necessary; the last unsubscribe disposes the state (unless the
  /// atom was created with [Atom.keepAlive]).
  void Function() subscribe<T>(Atom<T> atom, void Function() listener) {
    _assertAlive();
    final state = _ensureState(atom);
    state.listeners.add(listener);
    return () {
      state.listeners.remove(listener);
      _maybeAutoDispose(state);
    };
  }

  /// Registers an observer that is notified for every read, write, and
  /// dispose. Returns a disposer.
  void Function() addObserver(AtomObserver observer) {
    _observers.add(observer);
    return () => _observers.remove(observer);
  }

  /// Disposes every cached atom and releases the store. After this
  /// call, the store is unusable.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final snapshot = _states.values.toList(growable: false);
    _states.clear();
    for (final state in snapshot) {
      state.runDisposers();
    }
    _observers.clear();
  }

  // ───────────────────────────────────────────────────────────────────
  // Internals
  // ───────────────────────────────────────────────────────────────────

  void _assertAlive() {
    if (_disposed) {
      throw StateError('AtomStore has been disposed.');
    }
  }

  /// Resolves an atom through the override map (used for tests).
  @pragma('vm:prefer-inline')
  Atom<Object?> _effectiveAtom(Atom<Object?> atom) {
    return _overrides[atom] ?? atom;
  }

  _AtomState _ensureState(Atom<Object?> atom) {
    final effective = _effectiveAtom(atom);
    final cached = _states[effective];
    if (cached != null) return cached;
    return _create(atom, effective);
  }

  _AtomState _create(Atom<Object?> publicAtom, Atom<Object?> effective) {
    final state = _AtomState(publicAtom, effective);
    _states[effective] = state;
    _initialize(state);
    _notifyObservers((o) => o.didCreate(publicAtom, state.value));
    return state;
  }

  void _initialize(_AtomState state) {
    final reader = _StoreReader(this, state);
    final lifecycle = AtomLifecycle<Object?>(
      reader: reader,
      setValue: (value) => _setFromInside(state, value),
    );
    // initializeState is declared with an Object? signature so the
    // store can call it on any concrete subclass without hitting
    // Dart's invariant generic class parameters.
    state.value = state.effective.initializeState(lifecycle);
  }

  void _reinitialize(_AtomState state) {
    state.runDisposers();
    state.clearDependencies();
    final previous = state.value;
    _initialize(state);
    final next = state.value;
    if (!identical(previous, next)) {
      _notifyChange(state, previous);
    }
  }

  void _setFromInside(_AtomState state, Object? value) {
    if (_disposed) return;
    final cached = _states[state.effective];
    if (cached == null || !identical(cached, state)) {
      // The state was invalidated/disposed before the async work
      // resolved; ignore the late delivery.
      return;
    }
    if (identical(state.value, value)) return;
    final previous = state.value;
    state.value = value;
    _notifyChange(state, previous);
  }

  void _notifyChange(_AtomState state, Object? previous) {
    _notifyObservers((o) => o.didUpdate(state.publicAtom, previous, state.value));
    for (final dependent in state.dependents.toList()) {
      _reinitialize(dependent);
    }
    for (final listener in state.listeners.toList()) {
      listener();
    }
  }

  void _maybeAutoDispose(_AtomState state) {
    if (state.effective.isKeptAlive) return;
    if (state.listeners.isNotEmpty) return;
    if (state.dependents.isNotEmpty) return;
    _states.remove(state.effective);
    state.runDisposers();
    final orphans = state.dependencies.toList();
    state.clearDependencies();
    for (final depState in orphans) {
      _maybeAutoDispose(depState);
    }
    _notifyObservers((o) => o.didDispose(state.publicAtom, state.value));
  }

  void _notifyObservers(void Function(AtomObserver) action) {
    if (_observers.isEmpty) return;
    for (final o in _observers.toList()) {
      try {
        action(o);
      } catch (_) {
        // Observer failures must never break the store.
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Internal state object
// ─────────────────────────────────────────────────────────────────────

/// Type-erased state slot owned by the store. Generics live at the
/// public API boundary; internally everything is `Object?` so the
/// runtime can iterate dependents/dependencies without colliding with
/// invariant generic class parameters.
class _AtomState {
  _AtomState(this.publicAtom, this.effective);

  /// The atom the user defined (before override resolution).
  final Atom<Object?> publicAtom;

  /// The atom actually used by the store (may be an override).
  final Atom<Object?> effective;

  /// Set by `AtomStore._initialize` immediately after construction;
  /// the store guarantees no read happens before that.
  late Object? value;

  final List<void Function()> listeners = <void Function()>[];
  final Set<_AtomState> dependencies = <_AtomState>{};
  final Set<_AtomState> dependents = <_AtomState>{};
  final List<void Function()> disposers = <void Function()>[];

  void runDisposers() {
    for (final d in disposers.toList()) {
      try {
        d();
      } catch (_) {
        // Disposer failures must not break the store.
      }
    }
    disposers.clear();
  }

  void clearDependencies() {
    for (final dep in dependencies) {
      dep.dependents.remove(this);
    }
    dependencies.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Internal AtomReader implementation
// ─────────────────────────────────────────────────────────────────────

class _StoreReader extends AtomReader {
  _StoreReader(this._store, this._owner) : super();

  final AtomStore _store;
  final _AtomState _owner;

  @override
  U call<U>(Atom<U> dep) => get<U>(dep);

  @override
  U get<U>(Atom<U> dep) {
    final depState = _store._ensureState(dep);
    _owner.dependencies.add(depState);
    depState.dependents.add(_owner);
    return depState.value as U;
  }

  @override
  U peek<U>(Atom<U> dep) => _store._ensureState(dep).value as U;

  @override
  void onDispose(void Function() callback) {
    _owner.disposers.add(callback);
  }
}

/// Internal helper used by the Flutter integration to read raw state.
@internal
extension AtomStoreInternals on AtomStore {
  /// Returns `true` if [atom] currently has a cached state in this
  /// store.
  bool containsAtom(Atom<Object?> atom) =>
      _states.containsKey(_effectiveAtom(atom));

  /// Number of atoms currently held by the store.
  int get cachedAtomCount => _states.length;
}
