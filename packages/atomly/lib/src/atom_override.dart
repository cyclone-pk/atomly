import 'package:meta/meta.dart';

import 'atom.dart';

/// A replacement of one atom with another inside an [AtomStore].
///
/// Overrides exist so tests (and scoped configurations) can substitute
/// alternate implementations of an atom without modifying the original
/// declaration. Build them with the extensions on [Atom]:
///
/// ```dart
/// AtomScope(
///   overrides: [
///     counter.overrideWithValue(42),
///     user.overrideWith(Atom.constant(AtomValue.data(testUser))),
///   ],
///   child: const MyApp(),
/// );
/// ```
///
/// You almost never construct this class directly. The constructor is
/// internal so users go through `atom.overrideWith(...)` /
/// `atom.overrideWithValue(...)`, which are type-safe per-atom.
@immutable
final class AtomOverride {
  /// The atom being replaced.
  final Atom<Object?> original;

  /// The atom that should be used in its place.
  final Atom<Object?> replacement;

  /// Internal — use the extensions on [Atom] instead.
  @internal
  const AtomOverride(this.original, this.replacement);
}

/// Type-safe builders for [AtomOverride] entries.
extension AtomOverrideBuilders<T> on Atom<T> {
  /// Returns an override that replaces this atom with [replacement] in
  /// any store that uses it.
  ///
  /// ```dart
  /// AtomScope(
  ///   overrides: [user.overrideWith(Atom.constant(AtomValue.data(testUser)))],
  ///   child: const MyApp(),
  /// );
  /// ```
  AtomOverride overrideWith(Atom<T> replacement) =>
      AtomOverride(this, replacement);

  /// Returns an override that pins this atom to [value]. Equivalent to
  /// `overrideWith(Atom(value))`.
  ///
  /// ```dart
  /// AtomScope(
  ///   overrides: [counter.overrideWithValue(42)],
  ///   child: const MyApp(),
  /// );
  /// ```
  AtomOverride overrideWithValue(T value) =>
      AtomOverride(this, Atom<T>(value));
}
