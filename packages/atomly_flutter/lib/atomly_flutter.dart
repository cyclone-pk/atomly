/// Flutter integration for the atomly atomic state manager.
///
/// Adds:
///
/// * [AtomScope] — the runtime root that holds an `AtomStore` and
///   exposes it through an `InheritedModel` with per-aspect rebuilds.
/// * `BuildContext` extensions on every [Atom]: `watch`, `read`,
///   `select`, `set`, `update`, `refresh`, `invalidate`, plus
///   `when` for `Atom<AtomValue<T>>`.
/// * [AtomBuilder] / [AtomAsyncBuilder] — single-atom builder widgets.
/// * [AtomConsumer] — multi-atom builder.
/// * [AtomListener] — side-effect-only widget for snackbars, nav, etc.
///
/// ```dart
/// import 'package:atomly_flutter/atomly_flutter.dart';
///
/// final counter = Atom(0);
///
/// void main() {
///   runApp(const AtomScope(child: MyApp()));
/// }
///
/// class CounterText extends StatelessWidget {
///   const CounterText({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     return Text('${counter.watch(context)}');
///   }
/// }
/// ```
library;

// Re-export the core so users only need a single import.
export 'package:atomly/atomly.dart';

export 'src/atom_builder.dart';
export 'src/atom_consumer.dart';
export 'src/atom_listener.dart';
export 'src/atom_scope.dart';
export 'src/context_extensions.dart';
