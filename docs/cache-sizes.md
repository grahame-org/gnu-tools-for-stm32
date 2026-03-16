# Cache Sizes Reference

This document records the empirically measured GitHub Actions cache entry sizes
for every cache written by the `Build STM32 Toolchain` workflow, together with
an analysis of how those sizes affect the 10 GB repository cache budget —
particularly under `merge_group` conditions.

---

## Measurements

All sizes are the compressed zstd archive sizes reported by `actions/cache/save`.

### Stage caches (`stage-v2-*` key prefix)

These are written by the `build-stage` composite action.  All 7 are written on
`push` and `pull_request` events.  All 7 are also written on `merge_group`
events because every stage sets `save-in-merge-group: 'true'`.

| Cache key prefix | CI job | Cached paths | Measured size (bytes) | Measured size (MB) |
| --- | --- | --- | --- | --- |
| `stage-v2-<binutils-hash>` | `build-binutils` | `install-native` | 33,904,681 | 32.3 |
| `stage-v2-<gcc-first-hash>` | `build-gcc-first` | `install-native` | 336,301,240 | 320.8 |
| `stage-v2-<newlib-hash>` | `build-newlib` | `install-native` | 394,863,699 | 376.6 |
| `stage-v2-<newlib-nano-hash>` | `build-newlib-nano` | `build-native/target-libs` | 50,305,354 | 48.0 |
| `stage-v2-<gcc-final-hash>` | `build-gcc-final` | `install-native` | 890,962,404 | 849.9 |
| `stage-v2-<gcc-size-libstdcxx-hash>` | `build-gcc-size-libstdcxx` | `install-native` + `build-native/target-libs` | 1,937,959,379 | 1,848.1 |
| `stage-v2-<gdb-hash>` | `build-gdb` | `install-native` | 91,515,748 | 87.3 |
| **Total (7 stage caches)** | | | **3,735,812,505** | **3,563.0** |

### Other caches (not written in `merge_group`)

| Cache key prefix | CI job | Cached paths | Measured size (bytes) | Measured size (MB) | Written in `merge_group`? |
| --- | --- | --- | --- | --- | --- |
| `toolchain-v2-*` | `build-final` | `install-native` | 252,567,410 | 240.9 | No |
| `stage-v2-<final-hash>` (stage-final) | `build-final` | `install-native` | not yet measured | — | No |
| `ccache-gcc-final-*` | `build-gcc-final` | `~/.ccache` | not yet measured | — | No |
| `ccache-gcc-size-libstdcxx-*` | `build-gcc-size-libstdcxx` | `~/.ccache` | not yet measured | — | No |
| prerequisites | `build-binutils` / others | `build-native/host-libs` | not yet measured | — | No |

---

## Key Observations

**`gcc-size-libstdcxx` is the dominant entry at 1,848 MB.**  It caches two
paths together (`install-native` and `build-native/target-libs`), and the
+998 MB delta over `gcc-final` (850 MB) represents the unstripped
size-optimised libstdc++ object files and library archives produced by the
`gcc-size-libstdcxx` build.

**`gcc-final` at 850 MB is the second-largest entry** and represents the
largest single-path `install-native` snapshot.  The unstripped compiler
executables and DWARF debug info are the primary driver of this size.

**Strip reduces the install tree dramatically.**  The final `toolchain` cache
(post-strip, post-specs) is only 241 MB — a 72% reduction from `gcc-final`'s
850 MB.  This quantifies the contribution of unstripped DWARF debug info to the
intermediate stage cache sizes.

**`gdb` (87 MB) is surprisingly small** despite caching the same `install-native`
path at a later point in the chain than `newlib` (377 MB).  The gdb binary
itself compresses efficiently, and the gdb cache is saved from a runner that
started from the binutils baseline rather than the full gcc chain — so
`install-native` on the gdb runner contains only binutils + gdb artifacts, not
the full gcc/newlib tree.

---

## Budget Impact

The GitHub Actions cache budget for a repository defaults to **10 GB**.  All
cache entries for the repository — regardless of the event that wrote them —
count against this shared limit.  LRU eviction discards the
least-recently-used entries first when the limit is reached.

### Per-event write summary

| Event | Entries written | Approx. total written |
| --- | --- | --- |
| `merge_group` (cold build) | 7 stage caches | **~3.56 GB** |
| `push` / `pull_request` (cold build) | 7 stage caches + toolchain + stage-final + ccache entries + prerequisites | **≥3.80 GB** (ccache/prerequisites unknown) |

### Merge queue budget analysis

A single cold `merge_group` build writes approximately **3.56 GB** of stage
caches.  Against the 10 GB budget:

| Scenario | Cache consumed | Headroom remaining |
| --- | --- | --- |
| 1× cold `merge_group` build | ~3.56 GB | ~6.44 GB |
| 2× concurrent cold `merge_group` builds | ~7.12 GB | ~2.88 GB |
| 3× concurrent cold `merge_group` builds | ~10.68 GB | **budget exhausted** |

In steady state, a warm `push`/`pull_request` lineage already occupies at
least **~3.80 GB** of the budget (7 stage caches + toolchain, before ccache
entries are counted).  With a warm lineage resident:

| Scenario | Cache consumed | Headroom remaining |
| --- | --- | --- |
| Warm lineage + 1× cold `merge_group` build | ~7.36 GB | ~2.64 GB |
| Warm lineage + 2× cold `merge_group` builds | ~10.92 GB | **budget exhausted** |

**Conclusion: with a warm `push`/`pull_request` lineage in the cache store,
just 2 concurrent fully-cold `merge_group` builds are sufficient to exhaust
the 10 GB budget.**  LRU eviction at this point will target the oldest stage
cache entries — which are most likely to be the large `gcc-size-libstdcxx` or
`gcc-final` entries from earlier merge queue runs.  If those are evicted while
a downstream job in the same run still needs them, that job will fall through
to a full rebuild.

### Entries not written in `merge_group`

The `toolchain-v2-*`, `stage-final`, and all `ccache-*` entries are correctly
excluded from `merge_group` writes (the workflow guards these saves with
`github.event_name != 'merge_group'`).  This is an important design decision:
writing the ccache entries in particular — which are expected to be large —
from every merge queue build would make the budget pressure substantially
worse.

---

## How to Find Current Sizes

The compressed size of each cache entry is logged by `actions/cache/save` in
the step output of the relevant job, as a line of the form:

```
Cache Size: ~NNN MB (NNNNNNNN B)
```

To inspect sizes for a specific run:

1. Open the [Actions tab](https://github.com/grahame-org/gnu-tools-for-stm32/actions).
2. Select a completed cold-build run (one where the stage was actually built,
   not a cache hit).
3. Expand the relevant job (`build-gcc-size-libstdcxx`, `build-gcc-final`, etc.).
4. Look for the `Save cache – <stage-name>` step and expand it to find the
   `Cache Size` line.

---

*See also: [`docs/build-stages.md`](build-stages.md) — stage dependency and artifact reference;
[`docs/build-times.md`](build-times.md) — cold-cache build time reference*
