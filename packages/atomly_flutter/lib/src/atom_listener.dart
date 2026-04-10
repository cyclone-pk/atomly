import 'package:atomly/atomly.dart';
import 'package:flutter/widgets.dart';

import 'atom_scope.dart';

/// Runs [onChange] every time [atom] changes — *without* rebuilding the
/// widget tree.
///
/// `AtomListener` is the right tool for **side effects** that should
/// not influence layout: snackbars, navigation, dialogs, analytics,
/// haptics, audio cues, etc. Putting these inside `build` (or even
/// inside an `AtomBuilder`) couples them to rebuilds, which leads to
/// duplicate snackbars, lost navigation, and other classic bugs.
///
/// ```dart
/// AtomListener<AtomValue<User>>(
///   atom: user,
///   onChange: (context, previous, next) {
///     if (next case AtomError(:final error)) {
///       ScaffoldMessenger.of(context)
///         .showSnackBar(SnackBar(content: Text('$error')));
///     }
///   },
///   child: const HomeBody(),
/// );
/// ```
///
/// The listener fires once per change — it is not invoked on the
/// initial mount. The previous value is `null` for the first change.
class AtomListener<T> extends StatefulWidget {
  /// The atom to listen to.
  final Atom<T> atom;

  /// Callback invoked on every change. Receives the previous and next
  /// values; previous is `null` for the first change.
  final void Function(BuildContext context, T? previous, T next) onChange;

  /// The child to render. Not affected by atom changes.
  final Widget child;

  /// Creates an [AtomListener].
  const AtomListener({
    super.key,
    required this.atom,
    required this.onChange,
    required this.child,
  });

  @override
  State<AtomListener<T>> createState() => _AtomListenerState<T>();
}

class _AtomListenerState<T> extends State<AtomListener<T>> {
  void Function()? _unsubscribe;
  T? _previous;
  AtomStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AtomScope.of(context);
    if (identical(store, _store)) return;
    _unsubscribe?.call();
    _store = store;
    _previous = store.read(widget.atom);
    _unsubscribe = store.subscribe(widget.atom, _handleChange);
  }

  void _handleChange() {
    if (!mounted || _store == null) return;
    final next = _store!.read(widget.atom);
    final prev = _previous;
    _previous = next;
    widget.onChange(context, prev, next);
  }

  @override
  void didUpdateWidget(covariant AtomListener<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.atom, widget.atom) && _store != null) {
      _unsubscribe?.call();
      _previous = _store!.read(widget.atom);
      _unsubscribe = _store!.subscribe(widget.atom, _handleChange);
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
