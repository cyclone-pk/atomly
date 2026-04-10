import 'package:meta/meta.dart';

/// The runtime state of an asynchronous [Atom].
///
/// `AtomValue` is the answer to the most common pain in async state
/// management: every async source can be in one of three states (loading,
/// data, or error), and you almost always want to keep the *previous*
/// data visible while a refresh is in flight. `AtomValue` makes both of
/// those first-class.
///
/// You produce one of these only when you read an `Atom.future` /
/// `Atom.stream`. They are sealed, so a `switch` exhausts them.
///
/// ```dart
/// final user = Atom.future((get) => api.fetchUser());
///
/// // In a widget:
/// final value = user.watch(context);
/// switch (value) {
///   case AtomData(:final value):     return Text(value.name);
///   case AtomLoading(:final previous): return previous == null
///       ? const CircularProgressIndicator()
///       : Text('${previous.name} (refreshing…)');
///   case AtomError(:final error):    return Text('Oops: $error');
/// }
/// ```
///
/// Or use the convenience [when]:
///
/// ```dart
/// value.when(
///   data: (u) => Text(u.name),
///   loading: () => const CircularProgressIndicator(),
///   error: (e, st) => Text('$e'),
/// )
/// ```
@immutable
sealed class AtomValue<T> {
  const AtomValue();

  /// The most recent successful data value, if one was ever observed.
  ///
  /// `AtomData.previousData` is itself, `AtomLoading.previousData` and
  /// `AtomError.previousData` carry the last successful value forward so
  /// you can render stale data while refreshing.
  T? get previousData;

  /// `true` if this is an [AtomData].
  bool get hasData => this is AtomData<T>;

  /// `true` if this is an [AtomLoading].
  bool get isLoading => this is AtomLoading<T>;

  /// `true` if this is an [AtomError].
  bool get hasError => this is AtomError<T>;

  /// Pattern-match helper. Provide a callback for every state.
  R when<R>({
    required R Function(T value) data,
    required R Function(T? previousData) loading,
    required R Function(Object error, StackTrace? stackTrace, T? previousData)
        error,
  }) {
    final v = this;
    if (v is AtomData<T>) return data(v.value);
    if (v is AtomLoading<T>) return loading(v.previousData);
    if (v is AtomError<T>) return error(v.error, v.stackTrace, v.previousData);
    throw StateError('unreachable: $runtimeType');
  }

  /// Like [when] but every callback is optional and falls back to
  /// [orElse]. Useful when you only care about one or two states.
  R maybeWhen<R>({
    R Function(T value)? data,
    R Function(T? previousData)? loading,
    R Function(Object error, StackTrace? stackTrace, T? previousData)? error,
    required R Function() orElse,
  }) {
    final v = this;
    if (v is AtomData<T> && data != null) return data(v.value);
    if (v is AtomLoading<T> && loading != null) return loading(v.previousData);
    if (v is AtomError<T> && error != null) {
      return error(v.error, v.stackTrace, v.previousData);
    }
    return orElse();
  }

  /// Convenient constructor for the data state.
  static AtomValue<T> data<T>(T value) => AtomData<T>(value);

  /// Convenient constructor for the loading state.
  static AtomValue<T> loading<T>({T? previousData}) =>
      AtomLoading<T>(previousData: previousData);

  /// Convenient constructor for the error state.
  static AtomValue<T> error<T>(
    Object error, {
    StackTrace? stackTrace,
    T? previousData,
  }) =>
      AtomError<T>(
        error: error,
        stackTrace: stackTrace,
        previousData: previousData,
      );
}

/// The async source has produced a value.
@immutable
final class AtomData<T> extends AtomValue<T> {
  /// The data.
  final T value;

  /// Creates a data state.
  const AtomData(this.value);

  @override
  T? get previousData => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AtomData<T> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AtomData($value)';
}

/// The async source is in flight. Carries the previous data forward
/// (if any) for stale-while-revalidate rendering.
@immutable
final class AtomLoading<T> extends AtomValue<T> {
  @override
  final T? previousData;

  /// Creates a loading state, optionally with a [previousData] carry.
  const AtomLoading({this.previousData});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AtomLoading<T> && other.previousData == previousData);

  @override
  int get hashCode => previousData.hashCode;

  @override
  String toString() => 'AtomLoading(previousData=$previousData)';
}

/// The async source produced an error.
@immutable
final class AtomError<T> extends AtomValue<T> {
  /// The error object.
  final Object error;

  /// Stack trace, when available.
  final StackTrace? stackTrace;

  @override
  final T? previousData;

  /// Creates an error state.
  const AtomError({
    required this.error,
    this.stackTrace,
    this.previousData,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AtomError<T> &&
          other.error == error &&
          other.previousData == previousData);

  @override
  int get hashCode => Object.hash(error, previousData);

  @override
  String toString() => 'AtomError($error, previousData=$previousData)';
}
