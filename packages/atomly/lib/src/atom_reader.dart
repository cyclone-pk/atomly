import 'package:meta/meta.dart';

import 'atom.dart';

/// Function type used by atom builders to read other atoms.
///
/// You will rarely use this type directly — it is what the framework
/// passes to your `Atom.computed` / `Atom.future` / `Atom.stream`
/// callbacks. The same callable also exposes [AtomReader.onDispose] for
/// registering cleanup, so it is more than just a getter.
abstract class AtomReader {
  /// Internal — the framework constructs these, not user code.
  @internal
  AtomReader();

  /// Reads another atom *and* declares it as a dependency of the atom
  /// being built. When the dependency changes, the atom that called
  /// `read(dep)` is invalidated and recomputed.
  ///
  /// Equivalent to [get] — `read(other)` and `read.get(other)` do the
  /// same thing.
  T call<T>(Atom<T> dep);

  /// Reads another atom and tracks it as a dependency. Same as calling
  /// the reader directly: `read(other)`.
  T get<T>(Atom<T> dep);

  /// Reads another atom *without* tracking it as a dependency. The
  /// current atom will not re-run when [dep] changes.
  ///
  /// Use sparingly — most reads should be tracked so derived state
  /// stays consistent.
  T peek<T>(Atom<T> dep);

  /// Registers a cleanup callback to run when the current atom is
  /// disposed (because it lost all watchers, or because the store was
  /// reset).
  ///
  /// Use this to cancel HTTP requests, close stream subscriptions, or
  /// release any other resource the atom owns:
  ///
  /// ```dart
  /// final messages = Atom.stream<String>((read) {
  ///   final controller = StreamController<String>();
  ///   read.onDispose(controller.close);
  ///   return controller.stream;
  /// });
  /// ```
  void onDispose(void Function() callback);
}
