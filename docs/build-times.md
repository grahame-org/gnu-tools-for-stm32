# Build Times

## Overview

Each build stage in
[`build-toolchain.yml`](../.github/workflows/build-toolchain.yml) runs as a
separate CI job.  The wall-clock duration of every job is visible in the
GitHub Actions UI at the job level.  In addition, the
[`build-stage`](../.github/actions/build-stage/action.yml) composite action
emits a `build-time-seconds` output that records the actual compile time
(excluding runner setup overhead) for each stage that performs a build.

> **Planned**: A consolidated **Build Stage Timings** table written to the
> workflow Job Summary is tracked in
> [issue #287](https://github.com/grahame-org/gnu-tools-for-stm32/issues/287)
> and has not yet been implemented.  The per-job duration indicators in the
> Actions UI are the current way to inspect stage timings.

---

## Reference Timing Table

The table below shows cold-cache build times measured on a standard
GitHub-hosted `ubuntu-latest` runner.  Times include runner setup overhead
(checkout, disk cleanup, and dependency installation, typically 2–3 min) as
well as the actual build.  Actual times will vary with runner load, compiler
version, and the size of the source trees.

| CI job | Stage | Description | Typical cold-cache build time |
|--------|-------|-------------|-------------------------------|
| `build-binutils` | III-0 | binutils | ~12 min (estimated; see note) |
| `build-gdb` | III-6 | gdb | ~7 min |
| `build-gcc-first` | III-1 | gcc-first | ~11 min |
| `build-newlib` | III-2 | newlib | ~20 min |
| `build-newlib-nano` | III-3 | newlib-nano | ~17 min |
| `build-gcc-final-rmprofile` | III-4a | gcc-final (rmprofile) | ~35 min (parallel with III-4b) |
| `build-gcc-final-aprofile` | III-4b | gcc-final (aprofile) | ~35 min (parallel with III-4a) |
| `build-gcc-final-merge` | III-4-merge | gcc-final merge | ~1 min |
| `build-gcc-size-libstdcxx` | III-5 | gcc-size-libstdcxx | ~63 min |

> **Note on `build-binutils` timing:** The binutils source changes very rarely,
> so the `build-binutils` cache is almost always warm and the build step is
> skipped.  The ~12 min figure is an approximation; observe a run where the
> binutils cache key changes (e.g., after a binutils source update) to get a
> precise measurement.

---

## Reading Per-Stage Timings in CI

Each build stage runs as its own CI job.  To see how long each stage took:

1. Open the [Actions tab](https://github.com/grahame-org/gnu-tools-for-stm32/actions)
   of the repository.
2. Click the `Build STM32 Toolchain` workflow run you are interested in.
3. The job list shows each stage as a separate entry
   (`build-binutils`, `build-gdb`, `build-gcc-first`, etc.) with its elapsed
   duration displayed next to the job name.

---

## Cache Hit Behaviour

When the cache for a stage is still valid (the source tree and build inputs
have not changed since the last run), the build step is skipped and the job
completes in under a minute.  In this case the job duration shown in the
Actions UI reflects only runner setup overhead, not any real build work.

---

## Using Timings for Optimisation

To compare the build-time impact of a source change:

1. Identify the workflow run **before** your change and the run **after**.
2. Open each run in the Actions UI (see
   [Reading Per-Stage Timings in CI](#reading-per-stage-timings-in-ci)).
3. Compare the per-job durations in the job list.

Jobs unaffected by your change will show a very short duration (< 1 min,
indicating a cache hit), so you can quickly focus on the stages that actually
rebuilt.
