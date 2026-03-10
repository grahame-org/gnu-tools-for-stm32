# Build Times Reference

This document records measured build times for each job in
`build-toolchain.yml`, derived from actual GitHub Actions workflow logs.
Two scenarios are covered: **cold cache** (worst case — nothing cached) and
**warm cache** (best case — all stage caches populated).

---

## Methodology

- All timings were read directly from the `started_at` / `completed_at`
  fields of individual job steps in the GitHub Actions API.
- **Build time** is the duration of the `Build stage – <name>` step (or
  `Build toolchain – final assembly` for `build-final`) only — it excludes
  runner setup, checkout, disk-space cleanup, dependency installation, and
  cache I/O.
- **Job wall-clock time** is the total duration from job start to job end,
  including all setup overhead and cache operations.
- **Runner overhead** denotes the fixed per-job cost that cannot be cached:
  checkout (~37 s), free-disk-space (~45–86 s), apt install (~35 s), and
  Python venv setup (~4 s); in practice ~2–3 min per job.

### Source runs

| Scenario | Run ID | Branch | Date (UTC) |
|----------|--------|--------|------------|
| Cold cache — gcc chain | `22884303566` | merge queue (`13.3.rel1`) | 2026-03-10 |
| Cold cache — full parallel structure | `22875928379` | `copilot/parallel-newlib-build` | 2026-03-09 |
| Cold cache — confirmation | `22892923563` | `copilot/parallel-newlib-build` | 2026-03-10 |

---

## Per-stage build times (compilation only)

Pure compilation durations — the time the build script ran, excluding all
runner setup and cache I/O.

| Job | Stage | Build script | Build time (cold cache) |
|-----|-------|--------------|-------------------------|
| `build-binutils` | III-0 | `build-binutils.sh` | ~1 min |
| `build-gcc-first` | III-1 | `build-gcc-first.sh` | ~8 min |
| `build-newlib` | III-2 | `build-newlib.sh` | ~16 min |
| `build-newlib-nano` | III-3 | `build-newlib-nano.sh` | ~15 min |
| `build-gcc-final` | III-4 | `build-gcc-final.sh` | ~67 min |
| `build-gcc-size-libstdcxx` | III-5 | `build-gcc-size-libstdcxx.sh` | ~57 min |
| `build-gdb` | III-6 | `build-gdb.sh` | ~4 min |
| `build-final` | III-8–11 | `build-toolchain.sh` (pretidy/strip/specs only) | ~5 min |

> `build-newlib` and `build-newlib-nano` run in parallel (both depend only
> on `build-gcc-first`).  `build-gdb` also runs in parallel with the gcc /
> newlib chain (it depends only on `build-binutils`).

---

## End-to-end wall-clock times

### Cold cache (nothing cached)

The critical path through the dependency DAG is:

```
check-changes (~0 min)
  └─ build-binutils     ~4 min total  (~1 min build + ~3 min overhead)
       ├─ build-gdb     ~7 min total  (~4 min build + ~3 min overhead)   ← parallel
       └─ build-gcc-first   ~11 min total  (~8 min build + ~3 min overhead)
            ├─ build-newlib      ~19 min total  (~16 min build + ~3 min overhead)   ← parallel
            │    └─ build-gcc-final          ~70 min total  (~67 min build + ~3 min overhead)
            │         └─ build-gcc-size-libstdcxx  ~60 min total  (~57 min build + ~3 min overhead)
            │                └─ build-final  ~8 min total  (~5 min assembly + ~3 min overhead)
            └─ build-newlib-nano  ~18 min total  (~15 min build + ~3 min overhead)  ← parallel
```

**Cold cache critical-path total: ~172 min (~2 h 52 min)**

The bottleneck is the sequential gcc chain:
`binutils` → `gcc-first` → `newlib` → `gcc-final` → `gcc-size-libstdcxx` → final assembly.

Jobs that run off the critical path in parallel:

| Job | Runs in parallel with | Cold wall-clock time |
|-----|-----------------------|----------------------|
| `build-gdb` | gcc chain from `build-gcc-first` onwards | ~7 min |
| `build-newlib-nano` | `build-newlib` | ~18 min |

Both complete well before `build-gcc-final` finishes, so neither extends
the critical path.

### Warm cache (all stage caches populated)

When all per-stage caches are warm every build job skips its `Build stage`
step entirely and only pays runner-setup overhead plus cache-restore I/O.

| Job | Warm-cache job time |
|-----|---------------------|
| `build-binutils` | ~3 min |
| `build-gdb` | ~3 min |
| `build-gcc-first` | ~2–3 min |
| `build-newlib` | ~2 min |
| `build-newlib-nano` | ~2–3 min |
| `build-gcc-final` | ~3 min |
| `build-gcc-size-libstdcxx` | ~3 min |
| `build-final` | ~3 min (overhead + cache restores + `test_project` build) |

The `test_project` cmake build and artifact comparison in `build-final`
always run regardless of cache state; both complete in under 2 s.

The warm-cache wall-clock time is dominated by the sequential
job-dependency chain — each job must wait for its predecessor before GitHub
Actions will queue it — not by any compilation work.

**Warm cache critical-path total: ~18–20 min**

> **Full toolchain cache hit:** If the assembled `toolchain` cache key also
> hits (written by `build-final` on `push` and `pull_request` events), the
> entire workflow still runs each job but every `Build stage` step is
> skipped.  Only `build-final`'s `test_project` steps still execute
> unconditionally.

---

## Summary

| Scenario | End-to-end wall-clock time |
|----------|----------------------------|
| Cold cache (no prior builds) | ~172 min (~2 h 52 min) |
| Warm cache (all stage caches hit) | ~18–20 min |

The ~8.5× speedup from caching comes almost entirely from skipping
`build-gcc-final` (~67 min) and `build-gcc-size-libstdcxx` (~57 min).
