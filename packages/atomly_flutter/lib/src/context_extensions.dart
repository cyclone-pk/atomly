import 'package:atomly/atomly.dart';
import 'package:flutter/widgets.dart';

import 'atom_scope.dart';

/// `BuildContext`-aware operations on every [Atom].
///
/// These extensions are the ergonomic core of the Flutter integration.
/// Inside any widget that lives below an [AtomScope] you can call
/// `someAtom.watch(context)`, `someAtom.update(context, …)`, etc., and
/// the framework wires up the right rebuilds, dependency tracking, and
/// disposal automatically.
extension AtomContextExt<T> on Atom<T> {
  /// Reads this atom *and* registers the calling element to rebuild
  /// when its value changes.
  ///
  /// Use this in `build` methods. Other call sites should use [read]
  /// (one-shot, no rebuild).
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   final value = counter.watch(context);
  ///   return Text('$value');
  /// }
  /// ```
  T watch(BuildContext context) {
    final store = AtomScope.of(context, aspect: this);
    return store.read(this);
  }

  /// Reads this atom *without* registering for rebuilds. Use inside
  /// callbacks (`onPressed`, `onChanged`, …) where you need the
  /// current value but the widget itself does not need to rebuild
  /// when it changes.
  ///
  /// ```dart
  /// onPressed: () {
  ///   final current = counter.read(context);
  ///   showDialog(context: context, builder: (_) => Text('$current'));
  /// }
  /// ```
  T read(BuildContext context) {
    return AtomScope.of(context).read(this);
  }

  /// Replaces the value of this atom.
  ///
  /// ```dart
  /// onPressed: () => counter.set(context, 0),
  /// ```
  void set(BuildContext context, T value) {
    AtomScope.of(context).set(this, value);
  }

  /// Updates this atom by applying [updater] to the current value.
  ///
  /// ```dart
  /// onPressed: () => counter.update(context, (v) => v + 1),
  /// ```
  void update(BuildContext context, T Function(T current) updater) {
    AtomScope.of(context).update(this, updater);
  }

  /// Re-runs this atom's initializer. For `Atom.future` / `Atom.stream`
  /// this triggers a refetch; the previous value remains visible
  /// (`AtomLoading.previousData`) until the new value arrives.
  void refresh(BuildContext context) {
    AtomScope.of(context).refresh(this);
  }

  /// Drops the cached value of this atom. The next read recreates it
  /// from scratch — useful for forcing a "cold" reload.
  void invalidate(BuildContext context) {
    AtomScope.of(context).invalidate(this);
  }

  /// Reads this atom and applies [selector] to the result. Subscribes
  /// the calling element to changes in this atom.
  ///
  /// **Note for v0.1**: this is currently equivalent to
  /// `selector(watch(context))` — every atom change triggers a
  /// rebuild, even if the selected slice did not change. For true
  /// selector-based filtering, derive a computed atom:
  ///
  /// ```dart
  /// final userName = Atom.computed((read) => read(user).name);
  /// // … then in your widget:
  /// final name = userName.watch(context);
  /// ```
  R select<R>(BuildContext context, R Function(T value) selector) {
    return selector(watch(context));
  }
}

/// Convenience extensions on the `AtomValue<T>` returned from
/// `Atom.future` / `Atom.stream` so that callers can write
/// `user.when(context, data:, loading:, error:)` directly.
extension AtomValueContextExt<T> on Atom<AtomValue<T>> {
  /// Watches this async atom and pattern-matches on its current state.
  ///
  /// ```dart
  /// final user = Atom.future((read) => api.fetchUser());
  ///
  /// Widget build(BuildContext context) {
  ///   return user.when(
  ///     context,
  ///     data: (u) => Text(u.name),
  ///     loading: () => const CircularProgressIndicator(),
  ///     error: (e, st) => Text('$e'),
  ///   );
  /// }
  /// ```
  R when<R>(
    BuildContext context, {
    required R Function(T value) data,
    required R Function() loading,
    required R Function(Object error, StackTrace? stackTrace) error,
    R Function(T previousData)? refreshing,
  }) {
    final value = watch(context);
    return value.when(
      data: data,
      loading: (previous) {
        if (refreshing != null && previous != null) {
          return refreshing(previous);
        }
        return loading();
      },
      error: (e, st, _) => error(e, st),
    );
  }
}
