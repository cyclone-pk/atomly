import 'dart:async';

import 'package:atomly/atomly.dart';
import 'package:test/test.dart';

void main() {
  group('AtomStore — value atoms', () {
    test('reads initial value', () {
      final counter = Atom(0);
      final store = AtomStore();
      expect(store.read(counter), 0);
    });

    test('set updates the value', () {
      final counter = Atom(0);
      final store = AtomStore();
      store.set(counter, 5);
      expect(store.read(counter), 5);
    });

    test('update applies the function', () {
      final counter = Atom(10);
      final store = AtomStore();
      store.update(counter, (v) => v + 3);
      expect(store.read(counter), 13);
    });

    test('subscribe fires on change', () {
      final counter = Atom(0);
      final store = AtomStore();
      var calls = 0;
      store.subscribe(counter, () => calls++);
      store.set(counter, 1);
      store.set(counter, 2);
      expect(calls, 2);
    });

    test('subscribe does not fire when value is identical', () {
      final counter = Atom(0);
      final store = AtomStore();
      var calls = 0;
      store.subscribe(counter, () => calls++);
      store.set(counter, 0);
      expect(calls, 0);
    });

    test('unsubscribe stops notifications', () {
      final counter = Atom(0);
      final store = AtomStore();
      var calls = 0;
      final dispose = store.subscribe(counter, () => calls++);
      store.set(counter, 1);
      dispose();
      store.set(counter, 2);
      expect(calls, 1);
    });
  });

  group('AtomStore — computed atoms', () {
    test('computes from another atom', () {
      final counter = Atom(2);
      final doubled = Atom.computed((read) => read(counter) * 2);
      final store = AtomStore();
      expect(store.read(doubled), 4);
    });

    test('invalidates when a dependency changes', () {
      final counter = Atom(2);
      final doubled = Atom.computed((read) => read(counter) * 2);
      final store = AtomStore();
      // Subscribe so the computed atom stays alive.
      store.subscribe(doubled, () {});
      expect(store.read(doubled), 4);
      store.set(counter, 5);
      expect(store.read(doubled), 10);
    });

    test('chains computed atoms', () {
      final a = Atom(1);
      final b = Atom.computed((read) => read(a) + 1);
      final c = Atom.computed((read) => read(b) * 10);
      final store = AtomStore()
        ..subscribe(c, () {});
      expect(store.read(c), 20);
      store.set(a, 4);
      expect(store.read(c), 50);
    });

    test('peek does not register a dependency', () {
      final counter = Atom(0);
      final once = Atom.computed((read) => read.peek(counter));
      final store = AtomStore()
        ..subscribe(once, () {});
      expect(store.read(once), 0);
      store.set(counter, 99);
      // peek did not subscribe, so once is not invalidated.
      expect(store.read(once), 0);
    });
  });

  group('AtomStore — future atoms', () {
    test('starts in loading state and resolves to data', () async {
      final user = Atom.future((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return 'alice';
      });
      final store = AtomStore();
      var notifications = 0;
      store.subscribe(user, () => notifications++);

      final initial = store.read(user);
      expect(initial, isA<AtomLoading<String>>());

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final settled = store.read(user);
      expect(settled, isA<AtomData<String>>());
      expect((settled as AtomData<String>).value, 'alice');
      expect(notifications, greaterThanOrEqualTo(1));
    });

    test('captures synchronous errors', () {
      final bad = Atom.future<String>((_) => throw StateError('nope'));
      final store = AtomStore();
      final value = store.read(bad);
      expect(value, isA<AtomError<String>>());
      expect((value as AtomError<String>).error, isA<StateError>());
    });

    test('captures asynchronous errors', () async {
      final bad = Atom.future<String>((_) async {
        await Future<void>.delayed(Duration.zero);
        throw StateError('async-nope');
      });
      final store = AtomStore()
        ..subscribe(Atom(0), () {}); // keep store alive
      store.subscribe(bad, () {});
      store.read(bad);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final v = store.read(bad);
      expect(v, isA<AtomError<String>>());
    });

    test('refresh re-runs the loader', () async {
      var calls = 0;
      final probe = Atom.future<int>((_) async {
        calls++;
        return calls;
      });
      final store = AtomStore();
      store.subscribe(probe, () {});
      store.read(probe);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect((store.read(probe) as AtomData<int>).value, 1);

      store.refresh(probe);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect((store.read(probe) as AtomData<int>).value, 2);
    });
  });

  group('AtomStore — stream atoms', () {
    test('emits values into AtomData', () async {
      final controller = StreamController<int>();
      final ticker = Atom.stream((_) => controller.stream);
      final store = AtomStore();
      store.subscribe(ticker, () {});

      expect(store.read(ticker), isA<AtomLoading<int>>());

      controller.add(7);
      await Future<void>.delayed(Duration.zero);
      expect((store.read(ticker) as AtomData<int>).value, 7);

      controller.add(8);
      await Future<void>.delayed(Duration.zero);
      expect((store.read(ticker) as AtomData<int>).value, 8);

      await controller.close();
    });

    test('captures stream errors', () async {
      final controller = StreamController<int>();
      final ticker = Atom.stream((_) => controller.stream);
      final store = AtomStore();
      store.subscribe(ticker, () {});
      store.read(ticker);

      controller.addError('boom');
      await Future<void>.delayed(Duration.zero);
      expect(store.read(ticker), isA<AtomError<int>>());

      await controller.close();
    });
  });

  group('AtomStore — auto-dispose', () {
    test('disposes when the last subscriber unsubscribes', () {
      var disposed = false;
      final probe = Atom.computed((read) {
        read.onDispose(() => disposed = true);
        return 42;
      });
      final store = AtomStore();
      final dispose = store.subscribe(probe, () {});
      expect(store.read(probe), 42);
      dispose();
      expect(disposed, isTrue);
    });

    test('keepAlive prevents auto-dispose', () {
      var disposed = false;
      final probe = Atom.computed((read) {
        read.onDispose(() => disposed = true);
        return 42;
      }).keepAlive();
      final store = AtomStore();
      final dispose = store.subscribe(probe, () {});
      dispose();
      expect(disposed, isFalse);
    });

    test('dispose cascades to dependencies that lose all dependents', () {
      var aDisposed = false;
      final a = Atom.computed((read) {
        read.onDispose(() => aDisposed = true);
        return 1;
      });
      final b = Atom.computed((read) => read(a) + 1);
      final store = AtomStore();
      final dispose = store.subscribe(b, () {});
      expect(store.read(b), 2);
      dispose();
      expect(aDisposed, isTrue);
    });
  });

  group('AtomStore — overrides', () {
    test('overrideWithValue replaces the initial value', () {
      final counter = Atom(0);
      final store = AtomStore(overrides: [counter.overrideWithValue(42)]);
      expect(store.read(counter), 42);
    });

    test('overrideWith substitutes a different atom', () {
      final user = Atom.future<String>((_) async => 'real');
      final store = AtomStore(overrides: [
        user.overrideWith(Atom.constant(AtomValue.data('fake'))),
      ]);
      expect((store.read(user) as AtomData<String>).value, 'fake');
    });
  });

  group('AtomStore — invalidate', () {
    test('drops cached state and re-creates on next read', () {
      var creates = 0;
      final probe = Atom.computed((read) {
        creates++;
        return creates;
      });
      final store = AtomStore()
        ..subscribe(probe, () {});
      expect(store.read(probe), 1);
      store.invalidate(probe);
      expect(store.read(probe), 2);
    });
  });

  group('AtomStore — observers', () {
    test('didCreate / didUpdate / didDispose are called', () {
      final counter = Atom(0);
      final created = <Atom<Object?>>[];
      final updated = <int>[];
      final disposed = <Atom<Object?>>[];
      final store = AtomStore();
      store.addObserver(CallbackAtomObserver(
        onCreate: (a, _) => created.add(a),
        onUpdate: (_, prev, next) => updated.add(next as int),
        onDispose: (a, _) => disposed.add(a),
      ));
      final off = store.subscribe(counter, () {});
      store.set(counter, 1);
      store.set(counter, 2);
      off();
      expect(created, [counter]);
      expect(updated, [1, 2]);
      expect(disposed, [counter]);
    });
  });

  group('AtomFamily', () {
    test('returns the same atom for the same argument', () {
      final post = Atom.family<int, int>((id) => Atom(id));
      expect(identical(post(1), post(1)), isTrue);
      expect(identical(post(1), post(2)), isFalse);
    });

    test('each family member has independent state', () {
      final post = Atom.family<int, int>((id) => Atom(id * 10));
      final store = AtomStore();
      expect(store.read(post(1)), 10);
      expect(store.read(post(2)), 20);
      store.set(post(1), 999);
      expect(store.read(post(1)), 999);
      expect(store.read(post(2)), 20);
    });

    test('release drops the cached factory entry', () {
      final post = Atom.family<int, int>((id) => Atom(id));
      final first = post(1);
      post.release(1);
      final second = post(1);
      expect(identical(first, second), isFalse);
    });
  });

  group('AtomStore — disposal', () {
    test('throws when used after dispose', () {
      final counter = Atom(0);
      final store = AtomStore();
      store.dispose();
      expect(() => store.read(counter), throwsStateError);
    });
  });
}
