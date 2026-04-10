import 'atom.dart';

/// A hook for observing every atom event in a store.
///
/// Implement this and register it with `AtomStore.addObserver` (or via
/// `AtomScope(observers: [...])` in Flutter) to log atom traffic, ship
/// it to a remote service, integrate with DevTools, or assert on it in
/// tests.
///
/// Every callback is wrapped in a try/catch by the runtime — a faulty
/// observer cannot crash the store or the app.
abstract class AtomObserver {
  /// Default no-op constructor.
  const AtomObserver();

  /// Called the first time an atom is read after creation.
  void didCreate(Atom<Object?> atom, Object? value) {}

  /// Called whenever the value of an atom changes (sync set, computed
  /// re-evaluation, async future/stream emission).
  void didUpdate(Atom<Object?> atom, Object? previous, Object? next) {}

  /// Called when an atom is auto-disposed or invalidated.
  void didDispose(Atom<Object?> atom, Object? value) {}
}

/// A simple observer that delegates to user-supplied callbacks.
class CallbackAtomObserver extends AtomObserver {
  /// Optional `didCreate` callback.
  final void Function(Atom<Object?> atom, Object? value)? onCreate;

  /// Optional `didUpdate` callback.
  final void Function(Atom<Object?> atom, Object? previous, Object? next)?
      onUpdate;

  /// Optional `didDispose` callback.
  final void Function(Atom<Object?> atom, Object? value)? onDispose;

  /// Creates a callback observer with any subset of the three hooks.
  const CallbackAtomObserver({this.onCreate, this.onUpdate, this.onDispose});

  @override
  void didCreate(Atom<Object?> atom, Object? value) =>
      onCreate?.call(atom, value);

  @override
  void didUpdate(Atom<Object?> atom, Object? previous, Object? next) =>
      onUpdate?.call(atom, previous, next);

  @override
  void didDispose(Atom<Object?> atom, Object? value) =>
      onDispose?.call(atom, value);
}
