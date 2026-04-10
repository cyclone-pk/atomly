import 'package:atomly/atomly.dart';
import 'package:flutter/widgets.dart';

/// The runtime root of an atomly Flutter app.
///
/// Place a single `AtomScope` near the top of your widget tree —
/// typically wrapping `MaterialApp` / `CupertinoApp` — and every
/// descendant can read and write atoms via the `BuildContext`
/// extensions in this package:
///
/// ```dart
/// void main() {
///   runApp(const AtomScope(child: MyApp()));
/// }
///
/// class CounterText extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Text('${counter.watch(context)}');
///   }
/// }
/// ```
///
/// `AtomScope` owns an [AtomStore] and exposes it through an
/// `InheritedModel`. The InheritedModel uses the *atom* as the
/// rebuild "aspect", so widgets that watched only `counter` do not
/// rebuild when `userId` changes — even though both atoms live in the
/// same store. This is the same per-aspect filtering that `Provider`
/// achieves with one `InheritedWidget` per provider, but with a single
/// scope and zero per-atom widget boilerplate.
///
/// ## Test overrides
///
/// Pass [overrides] to substitute test doubles for any atom:
///
/// ```dart
/// testWidgets('shows test user', (tester) async {
///   await tester.pumpWidget(AtomScope(
///     overrides: [
///       user.overrideWith(Atom.constant(AtomValue.data(testUser))),
///     ],
///     child: const UserGreeting(),
///   ));
/// });
/// ```
///
/// ## Nesting
///
/// You can nest `AtomScope`s. Inner scopes shadow outer ones for any
/// atom they override; otherwise reads pass through to the nearest
/// scope that has the atom. Most apps only need one root scope.
class AtomScope extends StatefulWidget {
  /// The widget below this scope.
  final Widget child;

  /// Optional list of atom overrides applied to this scope's store.
  /// Build them with `atom.overrideWith(...)` /
  /// `atom.overrideWithValue(...)`.
  final List<AtomOverride>? overrides;

  /// Optional list of [AtomObserver]s to attach to the underlying
  /// store. Useful for logging, debugging, and DevTools integrations.
  final List<AtomObserver>? observers;

  /// Creates an atomly scope.
  const AtomScope({
    super.key,
    required this.child,
    this.overrides,
    this.observers,
  });

  /// Returns the store for the nearest enclosing scope.
  ///
  /// If [aspect] is provided, the calling element is registered as a
  /// dependent of that specific atom — only changes to that atom will
  /// trigger a rebuild. If [aspect] is `null`, the call does not
  /// register any dependency (use this for one-shot reads or writes).
  static AtomStore of(BuildContext context, {Atom<Object?>? aspect}) {
    final inherited = aspect == null
        ? context.getInheritedWidgetOfExactType<_AtomScopeInherited>()
        : InheritedModel.inheritFrom<_AtomScopeInherited>(
            context,
            aspect: aspect,
          );
    if (inherited == null) {
      throw FlutterError(
        'No AtomScope ancestor found.\n'
        'Wrap your app in an AtomScope:\n\n'
        '  runApp(const AtomScope(child: MyApp()));',
      );
    }
    return inherited.store;
  }

  /// Returns the store for the nearest enclosing scope, or `null` if
  /// none. Useful for libraries that want to support both atomly and
  /// non-atomly hosts.
  static AtomStore? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<_AtomScopeInherited>()
        ?.store;
  }

  @override
  State<AtomScope> createState() => _AtomScopeState();
}

class _AtomScopeState extends State<AtomScope> {
  late AtomStore _store;
  Set<Atom<Object?>> _changedSinceLastBuild = <Atom<Object?>>{};
  void Function()? _removeObserver;

  @override
  void initState() {
    super.initState();
    _store = AtomStore(overrides: widget.overrides);
    if (widget.observers != null) {
      for (final observer in widget.observers!) {
        _store.addObserver(observer);
      }
    }
    _removeObserver = _store.addObserver(
      CallbackAtomObserver(onUpdate: _handleAtomChange),
    );
  }

  void _handleAtomChange(Atom<Object?> atom, Object? previous, Object? next) {
    if (!mounted) return;
    setState(() {
      _changedSinceLastBuild.add(atom);
    });
  }

  @override
  void didUpdateWidget(covariant AtomScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.overrides, widget.overrides)) {
      // Overrides changed → rebuild the store. Rare in production,
      // common in widget tests.
      _removeObserver?.call();
      _store.dispose();
      _store = AtomStore(overrides: widget.overrides);
      if (widget.observers != null) {
        for (final observer in widget.observers!) {
          _store.addObserver(observer);
        }
      }
      _removeObserver = _store.addObserver(
        CallbackAtomObserver(onUpdate: _handleAtomChange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inherited = _AtomScopeInherited(
      store: _store,
      changed: _changedSinceLastBuild,
      child: widget.child,
    );
    _changedSinceLastBuild = <Atom<Object?>>{};
    return inherited;
  }

  @override
  void dispose() {
    _removeObserver?.call();
    _store.dispose();
    super.dispose();
  }
}

class _AtomScopeInherited extends InheritedModel<Atom<Object?>> {
  final AtomStore store;
  final Set<Atom<Object?>> changed;

  const _AtomScopeInherited({
    required this.store,
    required this.changed,
    required super.child,
  });

  @override
  bool updateShouldNotify(_AtomScopeInherited oldWidget) {
    return changed.isNotEmpty || !identical(store, oldWidget.store);
  }

  @override
  bool updateShouldNotifyDependent(
    _AtomScopeInherited oldWidget,
    Set<Atom<Object?>> dependencies,
  ) {
    if (!identical(store, oldWidget.store)) return true;
    for (final atom in dependencies) {
      if (changed.contains(atom)) return true;
    }
    return false;
  }
}
