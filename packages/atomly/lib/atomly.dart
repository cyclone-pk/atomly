/// Atomly — atomic state management for Dart and Flutter.
///
/// Import this library to get the pure-Dart core: `Atom<T>`,
/// `AtomValue<T>`, `AtomStore`, and the observer/reader plumbing.
///
/// For Flutter widgets and `BuildContext` extensions, also depend on
/// `package:atomly_flutter`.
///
/// ```dart
/// import 'package:atomly/atomly.dart';
///
/// final counter = Atom(0);
///
/// void main() {
///   final store = AtomStore();
///   print(store.read(counter)); // 0
///   store.update(counter, (v) => v + 1);
///   print(store.read(counter)); // 1
/// }
/// ```
library;

export 'src/atom.dart';
export 'src/atom_override.dart';
export 'src/atom_reader.dart';
export 'src/atom_store.dart' hide AtomStoreInternals;
export 'src/atom_value.dart';
export 'src/observer.dart';
