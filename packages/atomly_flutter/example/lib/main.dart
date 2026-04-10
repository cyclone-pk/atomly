// Comprehensive demo of every atomly_flutter feature.
//
// Run with:
//
//   cd packages/atomly_flutter/example
//   flutter run
//
// Sections (one tab each):
//   1. Counter        — sync atoms, computed, child rebuild isolation
//   2. Async user     — Atom.future + AtomAsyncBuilder + refresh
//   3. Family         — parameterized atoms keyed by id
//   4. Listener       — side effects (snackbar) without rebuilds
//   5. Override demo  — test overrides at the scope level

import 'package:atomly_flutter/atomly_flutter.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────
// 1. Sync state + computed
// ─────────────────────────────────────────────────────────────────────

final counter = Atom(0);
final doubled = Atom.computed((read) => read(counter) * 2);
final isEven = Atom.computed((read) => read(counter) % 2 == 0);

// ─────────────────────────────────────────────────────────────────────
// 2. Async state with Atom.future
// ─────────────────────────────────────────────────────────────────────

class User {
  final String id;
  final String name;
  final String email;

  const User({required this.id, required this.name, required this.email});
}

final selectedUserId = Atom('u_1');

// Simulated API. Fails roughly every fourth call so the error path
// shows up too.
int _userFetchCount = 0;
final user = Atom.future<User>((read) async {
  final id = read(selectedUserId);
  _userFetchCount++;
  await Future<void>.delayed(const Duration(milliseconds: 600));
  if (_userFetchCount % 4 == 0) {
    throw Exception('network blip');
  }
  return User(
    id: id,
    name: 'User $id',
    email: '$id@example.com',
  );
});

// ─────────────────────────────────────────────────────────────────────
// 3. Family — parameterized atoms
// ─────────────────────────────────────────────────────────────────────

final post = Atom.family<int, AtomValue<String>>(
  (id) => Atom.future((read) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return 'Post #$id — lorem ipsum dolor sit amet';
  }),
);

// ─────────────────────────────────────────────────────────────────────
// 5. Override demo — a separate counter that the scope below pins to 99
// ─────────────────────────────────────────────────────────────────────

final overriddenCounter = Atom(0);

// ─────────────────────────────────────────────────────────────────────
// App entry
// ─────────────────────────────────────────────────────────────────────

void main() {
  runApp(
    AtomScope(
      observers: [
        CallbackAtomObserver(
          onUpdate: (atom, prev, next) =>
              debugPrint('[atomly] $atom: $prev → $next'),
        ),
      ],
      child: const AtomlyDemoApp(),
    ),
  );
}

class AtomlyDemoApp extends StatelessWidget {
  const AtomlyDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'atomly demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: const _HomeShell(),
    );
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('atomly demo'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '1 · Counter'),
              Tab(text: '2 · Async'),
              Tab(text: '3 · Family'),
              Tab(text: '4 · Listener'),
              Tab(text: '5 · Override'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CounterPage(),
            _AsyncPage(),
            _FamilyPage(),
            _ListenerPage(),
            _OverridePage(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 1 — Counter
// ─────────────────────────────────────────────────────────────────────

class _CounterPage extends StatelessWidget {
  const _CounterPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('Sync atoms + computed atoms'),
          const SizedBox(height: 16),
          // Each child watches a different atom — only the matching
          // child rebuilds when that atom changes.
          const _CounterReadout(),
          const SizedBox(height: 8),
          const _DoubledReadout(),
          const SizedBox(height: 8),
          const _IsEvenReadout(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => counter.update(context, (v) => v - 1),
                  child: const Text('−1'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => counter.update(context, (v) => v + 1),
                  child: const Text('+1'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => counter.set(context, 0),
            child: const Text('reset'),
          ),
        ],
      ),
    );
  }
}

class _CounterReadout extends StatelessWidget {
  const _CounterReadout();
  @override
  Widget build(BuildContext context) {
    final value = counter.watch(context);
    return _Tile(label: 'counter', value: '$value');
  }
}

class _DoubledReadout extends StatelessWidget {
  const _DoubledReadout();
  @override
  Widget build(BuildContext context) {
    final value = doubled.watch(context);
    return _Tile(label: 'doubled (computed)', value: '$value');
  }
}

class _IsEvenReadout extends StatelessWidget {
  const _IsEvenReadout();
  @override
  Widget build(BuildContext context) {
    final v = isEven.watch(context);
    return _Tile(label: 'isEven (computed)', value: '$v');
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 2 — Async
// ─────────────────────────────────────────────────────────────────────

class _AsyncPage extends StatelessWidget {
  const _AsyncPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('Atom.future + AtomAsyncBuilder + refresh'),
          const SizedBox(height: 16),
          const _UserCard(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => selectedUserId.set(context, 'u_1'),
                  child: const Text('Select u_1'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => selectedUserId.set(context, 'u_2'),
                  child: const Text('Select u_2'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => selectedUserId.set(context, 'u_3'),
                  child: const Text('Select u_3'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => user.refresh(context),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 120,
        child: Center(
          child: AtomAsyncBuilder<User>(
            atom: user,
            loading: (_) =>
                const Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Loading…'),
            ]),
            data: (_, u) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(u.name,
                    style: Theme.of(context).textTheme.titleLarge),
                Text(u.email,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            error: (_, e, st) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Error: $e',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 3 — Family
// ─────────────────────────────────────────────────────────────────────

class _FamilyPage extends StatelessWidget {
  const _FamilyPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('Atom.family — parameterized atoms'),
          const SizedBox(height: 16),
          const Text(
            'Each tile below watches a separate post atom keyed by id. '
            'They load independently and dispose independently.',
          ),
          const SizedBox(height: 16),
          for (final id in [101, 102, 103])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PostTile(id: id),
            ),
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('$id')),
        title: AtomAsyncBuilder<String>(
          atom: post(id),
          loading: (_) => const Text('loading…'),
          data: (_, body) => Text(body),
          error: (_, e, st) => Text('error: $e'),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => post(id).refresh(context),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 4 — Listener (side effects without rebuilds)
// ─────────────────────────────────────────────────────────────────────

class _ListenerPage extends StatelessWidget {
  const _ListenerPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AtomListener<AtomValue<User>>(
        atom: user,
        onChange: (ctx, prev, next) {
          if (next case AtomError(:final error)) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('user fetch failed: $error')),
            );
          } else if (next case AtomData(:final value)) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('loaded ${value.name}')),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle('AtomListener — side effects'),
            const SizedBox(height: 16),
            const Text(
              'This page mounts an AtomListener over the user atom. '
              'Tap "Refresh user" — every change shows a snackbar without '
              'rebuilding the page. Some attempts will fail (the demo '
              'API throws roughly 1 in 4) so you can see both branches.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => user.refresh(context),
              child: const Text('Refresh user'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 5 — Override (test-style scope override)
// ─────────────────────────────────────────────────────────────────────

class _OverridePage extends StatelessWidget {
  const _OverridePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('Nested AtomScope with overrides'),
          const SizedBox(height: 16),
          const Text(
            'The inner scope below pins overriddenCounter to 99 — only '
            'inside its subtree. The outer scope still sees the real '
            'value (which starts at 0).',
          ),
          const SizedBox(height: 16),
          AtomBuilder<int>(
            atom: overriddenCounter,
            builder: (_, v, __) => _Tile(label: 'outer scope', value: '$v'),
          ),
          const SizedBox(height: 16),
          AtomScope(
            overrides: [overriddenCounter.overrideWithValue(99)],
            child: AtomBuilder<int>(
              atom: overriddenCounter,
              builder: (_, v, __) => _Tile(label: 'inner scope', value: '$v'),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => overriddenCounter.update(context, (v) => v + 1),
            child: const Text('+1 (outer only)'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Shared UI bits
// ─────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
