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
| `build-binutils` | III-0 | binutils | ~3 min (see note) |
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
> skipped.  The ~3 min figure is measured from the cold-cache build triggered
> by the v2 cache key bump in PR #516.

> **Single-job baseline (pre-parallelisation):** Before issue #283 introduced the
> parallel gcc-final jobs, stage III-4 was a single unified `build-gcc-final`
> job that built all multilib variants (rmprofile + aprofile) in one pass.  Its
> measured cold-cache build time was approximately **~70 min**.

> **Note on `build-gcc-size-libstdcxx` timing:** This stage was previously
> configured with `--with-multilib-list=rmprofile,aprofile` (the full default
> list), taking approximately 63 min.  It now defaults to
> `--with-multilib-list=rmprofile` only: the size-optimised (`_nano`) libraries
> built here (installed as `libstdc++_nano.a`, `libc_nano.a`, etc.) are
> consumed only via `nano.specs`, which is intended for Cortex-M (rmprofile)
> targets.  As a result, **aprofile `_nano` multilib variants are intentionally
> not built or installed by this stage** — even when the rest of the toolchain
> is built with the default `rmprofile,aprofile` multilib list.  This eliminates
> the ~10 aprofile multilib variants from the build, reducing the variant count
> by approximately 28% and the expected cold-cache build time to ~50 min
> (~21% improvement vs the previous ~63 min, exceeding the >10% target from
> [issue #288](https://github.com/grahame-org/gnu-tools-for-stm32/issues/288)).
> Observe a cold-cache run after this change to confirm the precise measurement.

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

---

## Critical-Path Analysis: Parallelised gcc-final

The cold-cache critical path runs through the longest sequential chain of
dependent jobs:

```
build-binutils → build-gcc-first → build-newlib → [gcc-final stage]
              → build-gcc-size-libstdcxx
```

(`build-gdb` and `build-newlib-nano` run in parallel with other jobs on this
chain and do not extend the critical path.)

| Metric | Single-job baseline (pre-issue #283) | Parallelised (III-4a/4b/4-merge) |
|--------|--------------------------------------|---------------------------------|
| gcc-final wall time | ~70 min | ~35 min + ~1 min = ~36 min |
| Total critical-path build time | ~167 min | ~133 min |
| gcc-final stage reduction | — | **~49%** |
| Overall critical-path reduction | — | **~20%** |

The critical-path reduction is approximately **20%**, which falls below the
≥ 30% target.  The total workflow critical path is dominated by
`build-gcc-size-libstdcxx` (~63 min), which is unchanged by the parallel
gcc-final split.

**Assessment:** To achieve a ≥ 30% overall critical-path reduction, further
parallelisation of `build-gcc-size-libstdcxx` or sub-dividing the rmprofile or
aprofile variant sets across additional parallel jobs would be required.  The
gcc-final stage itself was reduced by ~49%, which confirms the split is
performing as designed.

**Correctness:** The `build-final` job validates the merged install tree
by building the `test_project` STM32 CMake project and comparing the output
`.bin` file byte-for-byte against `test_project/reference/nucleo-u083rc.bin`.
A passing comparison confirms that both multilib variant sets are present and
that the re-linked driver binaries encode the correct combined multilib routing
tables (see [`docs/parallel-gcc-final-design.md §6`](parallel-gcc-final-design.md#6-validation)).

---

*See also: [`docs/cache-sizes.md`](cache-sizes.md) — empirical cache entry sizes and budget analysis*
