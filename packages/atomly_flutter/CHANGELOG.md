# Changelog

## 0.1.1

- Shorten the package description to fit pub.dev's 60–180 character window
  for search-result snippets.
- Bump `atomly` dependency to `^0.1.1`.

## 0.1.0

Initial release.

- `AtomScope` — `InheritedModel<Atom>` with per-aspect rebuild
  filtering. Optional `overrides:` map for tests and scoped
  configurations.
- `BuildContext` extensions on `Atom<T>`:
  `watch`, `read`, `select`, `when`, `listen`,
  `set`, `update`, `refresh`, `invalidate`.
- `AtomBuilder<T>` — single-atom builder widget.
- `AtomConsumer` — multi-atom consumer with a `watch` function.
- `AtomListener<T>` — pure side-effect widget.
- `Atomly.bootstrap()` helper for default global scopes.
