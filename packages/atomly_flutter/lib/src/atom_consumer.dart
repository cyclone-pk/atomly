import 'package:atomly/atomly.dart';
import 'package:flutter/widgets.dart';

import 'context_extensions.dart';

/// Function type passed to [AtomConsumer.builder] for reading multiple
/// atoms inside a single rebuild.
typedef AtomWatch = T Function<T>(Atom<T> atom);

/// A builder widget that can watch any number of atoms inside a single
/// `build` call.
///
/// `AtomConsumer` exists for the (rare) case where you want to read
/// several atoms from the same place but do not want to nest multiple
/// [AtomBuilder]s. The `watch` callback passed to [builder] is a
/// shortcut for `someAtom.watch(context)` — register a dependency on
/// every atom you call it with, and the consumer rebuilds whenever any
/// of them changes.
///
/// ```dart
/// AtomConsumer(
///   builder: (context, watch) {
///     final count = watch(counter);
///     final doubled = watch(doubledAtom);
///     return Text('$count → $doubled');
///   },
/// )
/// ```
class AtomConsumer extends StatelessWidget {
  /// Builds the UI given a watch function.
  final Widget Function(BuildContext context, AtomWatch watch) builder;

  /// Creates an [AtomConsumer].
  const AtomConsumer({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    T watch<T>(Atom<T> atom) => atom.watch(context);
    return builder(context, watch);
  }
}
