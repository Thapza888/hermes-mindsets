# Target memory — convention

Per-target memory defeats the cold-start ceiling. Every hunt on a project loads its dir
first and writes it last. A hunt that leaves no trace is a re-hunt next week.

## Layout

```
~/.hermes/targets/<project>/
  surface.md      # the map: repo, branches, entry points, sinks, auth model, fuzzing gap
  beliefs.md      # hypotheses: id | belief | confidence | status
  dead-paths.md   # what died and why — never re-walk a dead path
  evidence/       # raw requests, ASAN logs, crash inputs, diffs
```

## Rules

- **Load order at hunt start:** `surface.md` → `beliefs.md` → `dead-paths.md`. Know what
  was already tried before probing.
- **Write before you stop:** update the surface map, close or open beliefs, log every dead
  path with one line. The next session inherits the map.
- **Evidence, not memory:** a belief cites a file in `evidence/`, or it is unverified.
- **Dead paths are gold:** a path that died is the reason the next session does not waste
  an hour. Record it.

## Helpers (toolchain/)

- `target-init.sh <project> [repo-url]` — scaffold.
- `belief.sh <project> "<belief>" [confidence]` — append a belief with an id.

A target dir is per-project and long-lived. It is the difference between starting from
your own prior work and starting from zero.
