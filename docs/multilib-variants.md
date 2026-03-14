# Multilib Variant Catalog

This document catalogs all `MULTILIB_REQUIRED` directory paths for the `rmprofile`
and `aprofile` GCC multilib configurations, statically derived from the GCC ARM
multilib makefiles.

**Sources analyzed:**
- `src/gcc/gcc/config/arm/t-rmprofile`
- `src/gcc/gcc/config/arm/t-aprofile`
- `src/gcc/gcc/config/arm/t-multilib` (base/default variants)

The make-variable option form (e.g. `mthumb/march=armv7-m/mfloat-abi=soft`) is
translated to a filesystem path using the `MULTILIB_DIRNAMES` mappings defined in
these makefiles (e.g. `arm-none-eabi/lib/thumb/v7-m/nofp/`).

---

## Base variants (t-multilib — always built)

| Profile | Library path |
|---------|-------------|
| base | `arm-none-eabi/lib/thumb/nofp/` |
| base | `arm-none-eabi/lib/arm/v5te/softfp/` |
| base | `arm-none-eabi/lib/arm/v5te/hard/` |
| base | `arm-none-eabi/lib/thumb/v7/nofp/` |
| base | `arm-none-eabi/lib/thumb/v7+fp/softfp/` |
| base | `arm-none-eabi/lib/thumb/v7+fp/hard/` |
| base | `arm-none-eabi/lib/thumb/v7-r+fp.sp/softfp/` |
| base | `arm-none-eabi/lib/thumb/v7-r+fp.sp/hard/` |

**Total: 8 base variants**

---

## rmprofile variants (t-rmprofile — M-profile cores)

| Profile | Library path |
|---------|-------------|
| rmprofile | `arm-none-eabi/lib/thumb/v6-m/nofp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v7-m/nofp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v7e-m/nofp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8-m.base/nofp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8-m.main/nofp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v7e-m+fp/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v7e-m+fp/softfp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v7e-m+dp/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v7e-m+dp/softfp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8-m.main+fp/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8-m.main+fp/softfp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8-m.main+dp/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8-m.main+dp/softfp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+mve/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+pacbti/bp/nofp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+pacbti+fp/bp/softfp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+pacbti+fp/bp/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+pacbti+dp/bp/softfp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+pacbti+dp/bp/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+pacbti+mve/bp/hard/` |

**Total: 20 rmprofile variants**

---

## aprofile variants (t-aprofile — A-profile cores)

| Profile | Library path |
|---------|-------------|
| aprofile | `arm-none-eabi/lib/thumb/v7-a/nofp/` |
| aprofile | `arm-none-eabi/lib/thumb/v7-a+fp/hard/` |
| aprofile | `arm-none-eabi/lib/thumb/v7-a+fp/softfp/` |
| aprofile | `arm-none-eabi/lib/thumb/v7-a+simd/hard/` |
| aprofile | `arm-none-eabi/lib/thumb/v7-a+simd/softfp/` |
| aprofile | `arm-none-eabi/lib/thumb/v7ve+simd/hard/` |
| aprofile | `arm-none-eabi/lib/thumb/v7ve+simd/softfp/` |
| aprofile | `arm-none-eabi/lib/thumb/v8-a/nofp/` |
| aprofile | `arm-none-eabi/lib/thumb/v8-a+simd/hard/` |
| aprofile | `arm-none-eabi/lib/thumb/v8-a+simd/softfp/` |

**Total: 10 aprofile variants**

---

## Disjointness

**rmprofile and aprofile `MULTILIB_REQUIRED` sets are disjoint** — no library path
appears in both lists.

The sets are disjoint by design: rmprofile covers M-profile architectures
(`v6-m`, `v7-m`, `v7e-m`, `v8-m.*`, `v8.1-m.*`) while aprofile covers A-profile
architectures (`v7-a`, `v7ve`, `v8-a`). These are completely separate ARM
architecture families with no path overlap.

---

## MULTILIB_REQUIRED entries (make form)

For reference, the raw `MULTILIB_REQUIRED` entries from each file:

### t-multilib

```
mthumb/mfloat-abi=soft
marm/march=armv5te+fp/mfloat-abi=softfp
marm/march=armv5te+fp/mfloat-abi=hard
mthumb/march=armv7/mfloat-abi=soft
mthumb/march=armv7+fp/mfloat-abi=softfp
mthumb/march=armv7+fp/mfloat-abi=hard
mthumb/march=armv7-r+fp.sp/mfloat-abi=softfp
mthumb/march=armv7-r+fp.sp/mfloat-abi=hard
```

### t-rmprofile

```
mthumb/march=armv6s-m/mfloat-abi=soft
mthumb/march=armv7-m/mfloat-abi=soft
mthumb/march=armv7e-m/mfloat-abi=soft
mthumb/march=armv8-m.base/mfloat-abi=soft
mthumb/march=armv8-m.main/mfloat-abi=soft
mthumb/march=armv7e-m+fp/mfloat-abi=hard
mthumb/march=armv7e-m+fp/mfloat-abi=softfp
mthumb/march=armv7e-m+fp.dp/mfloat-abi=hard
mthumb/march=armv7e-m+fp.dp/mfloat-abi=softfp
mthumb/march=armv8-m.main+fp/mfloat-abi=hard
mthumb/march=armv8-m.main+fp/mfloat-abi=softfp
mthumb/march=armv8-m.main+fp.dp/mfloat-abi=hard
mthumb/march=armv8-m.main+fp.dp/mfloat-abi=softfp
mthumb/march=armv8.1-m.main+mve/mfloat-abi=hard
mthumb/march=armv8.1-m.main+pacbti/mbranch-protection=standard/mfloat-abi=soft
mthumb/march=armv8.1-m.main+pacbti+fp/mbranch-protection=standard/mfloat-abi=softfp
mthumb/march=armv8.1-m.main+pacbti+fp/mbranch-protection=standard/mfloat-abi=hard
mthumb/march=armv8.1-m.main+pacbti+fp.dp/mbranch-protection=standard/mfloat-abi=softfp
mthumb/march=armv8.1-m.main+pacbti+fp.dp/mbranch-protection=standard/mfloat-abi=hard
mthumb/march=armv8.1-m.main+pacbti+mve/mbranch-protection=standard/mfloat-abi=hard
```

### t-aprofile

```
mthumb/march=armv7-a/mfloat-abi=soft
mthumb/march=armv7-a+fp/mfloat-abi=hard
mthumb/march=armv7-a+fp/mfloat-abi=softfp
mthumb/march=armv7-a+simd/mfloat-abi=hard
mthumb/march=armv7-a+simd/mfloat-abi=softfp
mthumb/march=armv7ve+simd/mfloat-abi=hard
mthumb/march=armv7ve+simd/mfloat-abi=softfp
mthumb/march=armv8-a/mfloat-abi=soft
mthumb/march=armv8-a+simd/mfloat-abi=hard
mthumb/march=armv8-a+simd/mfloat-abi=softfp
```

---

## Dirnames mapping reference

The option form is translated to a directory name using these `MULTILIB_DIRNAMES`
mappings (from `t-multilib`, `t-rmprofile`, and `t-aprofile`):

| Option | Directory name |
|--------|---------------|
| `mthumb` | `thumb` |
| `marm` | `arm` |
| `mfloat-abi=soft` | `nofp` |
| `mfloat-abi=softfp` | `softfp` |
| `mfloat-abi=hard` | `hard` |
| `mbranch-protection=standard` | `bp` |
| `march=armv5te+fp` | `v5te` |
| `march=armv7` | `v7` |
| `march=armv7+fp` | `v7+fp` |
| `march=armv7-r+fp.sp` | `v7-r+fp.sp` |
| `march=armv6s-m` | `v6-m` |
| `march=armv7-m` | `v7-m` |
| `march=armv7e-m` | `v7e-m` |
| `march=armv7e-m+fp` | `v7e-m+fp` |
| `march=armv7e-m+fp.dp` | `v7e-m+dp` |
| `march=armv8-m.base` | `v8-m.base` |
| `march=armv8-m.main` | `v8-m.main` |
| `march=armv8-m.main+fp` | `v8-m.main+fp` |
| `march=armv8-m.main+fp.dp` | `v8-m.main+dp` |
| `march=armv8.1-m.main+mve` | `v8.1-m.main+mve` |
| `march=armv8.1-m.main+pacbti` | `v8.1-m.main+pacbti` |
| `march=armv8.1-m.main+pacbti+fp` | `v8.1-m.main+pacbti+fp` |
| `march=armv8.1-m.main+pacbti+fp.dp` | `v8.1-m.main+pacbti+dp` |
| `march=armv8.1-m.main+pacbti+mve` | `v8.1-m.main+pacbti+mve` |
| `march=armv7-a` | `v7-a` |
| `march=armv7-a+fp` | `v7-a+fp` |
| `march=armv7-a+simd` | `v7-a+simd` |
| `march=armv7ve+simd` | `v7ve+simd` |
| `march=armv8-a` | `v8-a` |
| `march=armv8-a+simd` | `v8-a+simd` |
