# Changelog

## 0.1.0

Initial release.

- `Atom<T>` core primitive with five constructors:
  `Atom(value)`, `Atom.computed`, `Atom.future`, `Atom.stream`,
  `Atom.family`.
- `AtomValue<T>` sealed class for async state (`AtomData` /
  `AtomLoading` / `AtomError`) with stale-while-revalidate
  `previousData` carry-through.
- `AtomStore` runtime with dependency tracking, automatic invalidation,
  auto-dispose, and override mechanism.
- `AtomLifecycle` API for advanced atoms (onDispose, dependency
  tracking via `lc.get`).
- Observer hook (`Atomly.observe`) for logging every read / write /
  dispose for DevTools or external integrations.
- Pure Dart, no code generation, no Flutter dependency.
