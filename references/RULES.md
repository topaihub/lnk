# lnk-v2 Project Rules

## Red Lines
- Commands MUST NOT import from `infra/` directly — only use `App` interfaces (`app.store`, `app.vcs`, `app.fs`)
- No `deprecatedWriter` — use `std.debug.print` for output
- All new interfaces must follow the vtable pattern in `core/`
- SQLite bindings use `@cImport` + C API, no Zig wrappers

## Verification Commands
```bash
zig build                    # Must compile clean
zig build run -- --version   # Smoke test
zig build run -- list        # Test with real DB
```

## Architecture

```
┌─────────────────────────────────────────────┐
│                  main.zig                    │
│           (table-based dispatch)             │
├─────────────────────────────────────────────┤
│                  app.zig                     │
│         App { store, vcs, fs }               │
├──────────┬──────────┬───────────────────────┤
│  Store   │   Vcs    │    Fs                  │  ← core/ interfaces (vtable)
├──────────┼──────────┼───────────────────────┤
│ sqlite   │  git     │  posix                 │  ← infra/ implementations
│ _store   │  _vcs    │  _fs                   │
└──────────┴──────────┴───────────────────────┘
```

## Dependency Rule
```
commands/ → app.zig → core/ (interfaces only)
main.zig → infra/ (wiring only)
```

Commands never import `infra/`. Only `main.zig` wires infra implementations to interfaces.

## Doc Index
- `references/RULES.md` — This file (red lines, architecture)
- `references/interface-pattern.md` — How to add new vtable interfaces
- `README.md` — Usage guide
