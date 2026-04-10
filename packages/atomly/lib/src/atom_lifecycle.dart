import 'package:meta/meta.dart';

import 'atom_reader.dart';

/// Internal lifecycle handle the runtime passes to an atom's
/// `initializeState` method.
///
/// Wraps the user-facing [AtomReader] with the framework-only ability
/// to push new values for an atom whose state evolves over time
/// (`Atom.future`, `Atom.stream`).
///
/// User code never instantiates this — it is created by `AtomStore` and
/// passed to atom subclasses internally.
@internal
final class AtomLifecycle<T> {
  /// User-facing reader.
  final AtomReader reader;

  /// Framework-only setter used by async atoms (`Atom.future`,
  /// `Atom.stream`) to publish a new value after their initial
  /// initialization returned a loading placeholder.
  final void Function(T value) setValue;

  /// Internal constructor.
  AtomLifecycle({required this.reader, required this.setValue});
}
