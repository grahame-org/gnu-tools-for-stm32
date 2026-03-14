# Build Times

## Overview

Build times are automatically recorded in every CI run of
[`build-toolchain.yml`](../.github/workflows/build-toolchain.yml) and appear
in the **GitHub Actions Job Summary** for each run.  Each build stage is timed
independently; the elapsed wall-clock time for each stage is reported at the
end of the workflow run so you can track how long individual stages take.

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
| `build-gcc-final` | III-4 | gcc-final | ~70 min |
| `build-gcc-size-libstdcxx` | III-5 | gcc-size-libstdcxx | ~63 min |

> **Note on `build-binutils` timing:** The binutils source changes very rarely,
> so the `build-binutils` cache is almost always warm and the build step is
> skipped.  The ~12 min figure is an approximation; observe a run where the
> binutils cache key changes (e.g., after a binutils source update) to get a
> precise measurement.

---

## Automated Timing in CI

Every `build-toolchain.yml` run emits a timing table in its **Job Summary**
under the heading **Build Stage Timings**.

To find the Job Summary:

1. Open the [Actions tab](https://github.com/grahame-org/gnu-tools-for-stm32/actions)
   of the repository.
2. Click the `Build toolchain` workflow run you are interested in.
3. The **Job Summary** panel is displayed at the top of the workflow run page,
   above the individual job list.  Scroll to the **Build Stage Timings** table
   to see per-stage elapsed times for that run.

---

## Cache Hit Behaviour

When the toolchain cache for a stage is still valid (the source tree and build
inputs have not changed since the last run), the stage is skipped and its
build time shows as `—` in the summary table.  Only stages that actually ran a
build contribute a timing value.

---

## Using Timings for Optimisation

To compare the impact of a source change on build time:

1. Identify the workflow run **before** your change and the run **after**.
2. Open the Job Summary for each run (see [Automated Timing in CI](#automated-timing-in-ci)).
3. Compare the per-stage elapsed times in the **Build Stage Timings** table.

Stages unaffected by your change will appear as `—` (cache hit) in both runs,
so you can quickly focus on the stages that actually rebuilt.
