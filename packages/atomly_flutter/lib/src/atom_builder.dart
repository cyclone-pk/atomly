import 'package:atomly/atomly.dart';
import 'package:flutter/widgets.dart';

import 'context_extensions.dart';

/// Rebuilds [builder] whenever [atom] changes.
///
/// `AtomBuilder` is the simplest way to react to a single atom from a
/// place where you cannot easily call `atom.watch(context)` — for
/// example, deep inside a widget that does not have its own build
/// override.
///
/// ```dart
/// AtomBuilder<int>(
///   atom: counter,
///   builder: (context, value, child) => Text('$value'),
/// )
/// ```
///
/// You can pass an optional [child] subtree that does *not* depend on
/// the atom; it will be passed to [builder] verbatim and Flutter will
/// not rebuild it when the atom changes.
class AtomBuilder<T> extends StatelessWidget {
  /// The atom to watch.
  final Atom<T> atom;

  /// Builds the UI for the current atom value.
  final Widget Function(BuildContext context, T value, Widget? child) builder;

  /// Optional child that is passed to [builder] but not rebuilt when
  /// [atom] changes.
  final Widget? child;

  /// Creates an [AtomBuilder].
  const AtomBuilder({
    super.key,
    required this.atom,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final value = atom.watch(context);
    return builder(context, value, child);
  }
}

/// `AtomBuilder` for asynchronous atoms (`Atom.future` / `Atom.stream`)
/// that exposes the data/loading/error states as named callbacks.
///
/// ```dart
/// AtomAsyncBuilder<User>(
///   atom: user,
///   data: (context, u) => Text(u.name),
///   loading: (context) => const CircularProgressIndicator(),
///   error: (context, error, stackTrace) => Text('$error'),
/// )
/// ```
class AtomAsyncBuilder<T> extends StatelessWidget {
  /// The async atom to watch.
  final Atom<AtomValue<T>> atom;

  /// Builds the UI for the data state.
  final Widget Function(BuildContext context, T value) data;

  /// Builds the UI for the loading state.
  final Widget Function(BuildContext context) loading;

  /// Builds the UI for the error state.
  final Widget Function(
      BuildContext context, Object error, StackTrace? stackTrace) error;

  /// Builds the UI for a refresh that has previous data available.
  /// Falls back to [data] when not provided.
  final Widget Function(BuildContext context, T previousData)? refreshing;

  /// Creates an [AtomAsyncBuilder].
  const AtomAsyncBuilder({
    super.key,
    required this.atom,
    required this.data,
    required this.loading,
    required this.error,
    this.refreshing,
  });

  @override
  Widget build(BuildContext context) {
    return atom.when(
      context,
      data: (value) => data(context, value),
      loading: () => loading(context),
      error: (e, st) => error(context, e, st),
      refreshing: refreshing == null ? null : (prev) => refreshing!(context, prev),
    );
  }
}
