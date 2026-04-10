import 'package:atomly/atomly.dart';
import 'package:test/test.dart';

void main() {
  group('AtomValue', () {
    test('AtomData carries value as previousData', () {
      const v = AtomData<int>(42);
      expect(v.value, 42);
      expect(v.previousData, 42);
      expect(v.hasData, isTrue);
      expect(v.isLoading, isFalse);
      expect(v.hasError, isFalse);
    });

    test('AtomLoading optionally carries previousData', () {
      const empty = AtomLoading<int>();
      const stale = AtomLoading<int>(previousData: 7);
      expect(empty.previousData, isNull);
      expect(stale.previousData, 7);
      expect(empty.isLoading, isTrue);
    });

    test('AtomError carries error and previousData', () {
      const e = AtomError<int>(error: 'boom', previousData: 3);
      expect(e.error, 'boom');
      expect(e.previousData, 3);
      expect(e.hasError, isTrue);
    });

    test('when() pattern matches every state', () {
      const data = AtomData<int>(1);
      const loading = AtomLoading<int>();
      const error = AtomError<int>(error: 'x');

      String label(AtomValue<int> v) => v.when(
            data: (v) => 'data:$v',
            loading: (prev) => 'loading:$prev',
            error: (e, st, prev) => 'error:$e',
          );

      expect(label(data), 'data:1');
      expect(label(loading), 'loading:null');
      expect(label(error), 'error:x');
    });

    test('maybeWhen falls back to orElse', () {
      const v = AtomLoading<int>();
      final result = v.maybeWhen<String>(
        data: (v) => 'data',
        orElse: () => 'fallback',
      );
      expect(result, 'fallback');
    });

    test('factory constructors produce correct subtypes', () {
      expect(AtomValue.data(1), isA<AtomData<int>>());
      expect(AtomValue.loading<int>(), isA<AtomLoading<int>>());
      expect(AtomValue.error<int>('x'), isA<AtomError<int>>());
    });

    test('equality respects state and value', () {
      expect(const AtomData(1), const AtomData(1));
      expect(const AtomData(1), isNot(const AtomData(2)));
      expect(const AtomLoading<int>(previousData: 1),
          const AtomLoading<int>(previousData: 1));
    });
  });
}
