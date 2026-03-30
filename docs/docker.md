# Docker Container Reference

This document describes the container architecture for the GNU Tools for STM32
Docker image: its contents, naming convention, how it is built and published,
and the Phase 1 assumptions that have been validated or deferred.

---

## 1. Container Overview

### What the image contains

The Docker image provides a ready-to-use `arm-none-eabi` bare-metal
cross-compilation toolchain built from the GNU Tools for STM32 sources.
Inside the container:

- The full toolchain is installed at `/opt/stm32-toolchain/`.
- `/opt/stm32-toolchain/bin` is on `$PATH` so all `arm-none-eabi-*` binaries
  are directly invocable without any extra setup.
- Runtime shared-library dependencies (`libncurses6`, `libexpat1`, `zlib1g`)
  are installed via the package manager.
- `LICENSE.md` is copied to `/licenses/LICENSE.md`.

The base OS is **Ubuntu 24.04**.

### What the image does NOT contain

- Source code (`src/`)
- Intermediate build artifacts (`build-native/`, `pkg/`)
- Build or test scripts
- Documentation
- Any build tooling (CMake, Make, GCC host compiler, etc.) — the image is
  intentionally kept minimal for use as a cross-compilation environment

---

## 2. Naming Convention

### Image name

```
stm32-toolchain-<branch>
```

The two CI workflows apply slightly different normalization:

- **`docker-dry-run`** uses the current ref name (`GITHUB_REF_NAME`), lower-cased
  with `/` replaced by `-`.
- **`docker-publish`** uses the repository default branch name, with `/` replaced
  by `-` (no lower-casing applied).

For example, on branch `13.3.rel1` both produce `stm32-toolchain-13.3.rel1`
because the branch name is already lower-case.

### Registry

```
ghcr.io/grahame-org/
```

Full image reference:

```
ghcr.io/grahame-org/stm32-toolchain-<branch>
```

### Tag scheme

| Tag | When applied | Triggered by |
|-----|-------------|--------------|
| `edge` | Latest build from the default branch | Push to `13.3.rel1` or `workflow_dispatch` |
| `latest` | Latest published release | GitHub release published |
| `v<version>` | Full semver (e.g. `v13.3.1`) | GitHub release published |
| `v<major>.<minor>` | Minor semver (e.g. `v13.3`) | GitHub release published |
| `v<major>` | Major semver (e.g. `v13`) | GitHub release published |
| `sha-<sha>` | Short commit SHA | Dry-run workflow only (not pushed) |

---

## 3. How the Image Is Built

### Dockerfile approach

The `Dockerfile` at the root of this repository uses a **two-stage build**:

1. **Builder stage** — copies the pre-built toolchain from `install-native/`
   (on the Docker build host) into `/opt/stm32-toolchain/` inside the
   intermediate layer.
2. **Final stage** — starts from a clean `ubuntu:24.04` base, installs only
   the required runtime shared libraries, then copies `/opt/stm32-toolchain/`
   from the builder stage.

The two-stage approach keeps the final image lean: only the toolchain binaries
and their runtime dependencies are present; no build tooling or intermediate
files are included.

### Dependency on `install-native/`

The Dockerfile **does not build the toolchain from source**. The build context
must include the `install-native/` directory, which is the output of running
`build-toolchain.sh` (or restoring it from the GitHub Actions cache).

The `.dockerignore` file limits the build context to `install-native/`, the
license files (`LICENSE.md`, `license.txt`), and the `Dockerfile`/`.dockerignore`
themselves, keeping the context transfer fast.

### OCI labels

The image is annotated with standard OCI labels:

```
org.opencontainers.image.source   = https://github.com/grahame-org/gnu-tools-for-stm32
org.opencontainers.image.description = GNU Tools for STM32 – arm-none-eabi cross-compilation toolchain
org.opencontainers.image.licenses = SEE_LICENSE
```

---

## 4. How to Build Locally

### Step 1 — Obtain `install-native/`

You need a fully built toolchain in `install-native/` before running
`docker build`. You have two options:

**Option A — Build from source (takes several hours):**

```bash
export JOBS=$(nproc)
./build-prerequisites.sh --skip_steps=mingw,howto,package_sources
./build-toolchain.sh --skip_steps=mingw,mingw-gdb-with-python,gdb-with-python,manual,package_sources
```

The toolchain will be installed to `install-native/`.

**Option B — Use a prebuilt `install-native/` directory:**

If you already have a compatible `install-native/` from another machine or
a tarball produced by a previous build (locally or in CI), copy or extract
it into this repository so that `install-native/` matches the output of
`./build-toolchain.sh`.

### Step 2 — Build the Docker image

```bash
docker build \
  -t ghcr.io/grahame-org/stm32-toolchain-13.3.rel1:edge \
  .
```

Replace `13.3.rel1` and `edge` with the appropriate branch name and tag.

### Step 3 — Verify the image

```bash
docker run --rm ghcr.io/grahame-org/stm32-toolchain-13.3.rel1:edge \
  arm-none-eabi-gcc --version
```

---

## 5. How to Use the Image

### Run a single command

```bash
docker run --rm ghcr.io/grahame-org/stm32-toolchain-13.3.rel1:edge \
  arm-none-eabi-gcc --version
```

### Cross-compile a project

Mount your source tree into the container and invoke the toolchain:

```bash
docker run --rm \
  -v "$(pwd):/work" \
  -w /work \
  ghcr.io/grahame-org/stm32-toolchain-13.3.rel1:edge \
  arm-none-eabi-gcc -mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mfloat-abi=hard \
  -O2 -c main.c -o main.o
```

### PATH note

`/opt/stm32-toolchain/bin` is already on `$PATH` inside the container via
the `ENV PATH` instruction in the Dockerfile. No additional `PATH` setup is
needed in your `docker run` command or `ENTRYPOINT`.

---

## 6. CI Workflow Summary

### `docker-dry-run` (`docker-dry-run.yml`)

**Triggers:**
- Push to `13.3.rel1`
- Every pull request
- Merge group
- Manual `workflow_dispatch`

**What it does:**
1. Restores `install-native/` from the GitHub Actions toolchain cache.
   Fails fast with an actionable error if the cache is absent (the
   `Build STM32 Toolchain` workflow must have run first on this branch).
2. Builds the Docker image locally (no push) using the
   `.github/actions/docker-build` composite action.
3. Tags the image with the short commit SHA (`sha-<sha>`).
4. Runs `arm-none-eabi-gcc --version` inside the container.
5. Mounts `test_project/` and runs a full CMake + Make build inside the
   container (CMake and Make are installed transiently via `apt-get` and
   discarded with `--rm`).

The dry-run image is never pushed to the registry.

### `docker-publish` (`docker-publish.yml`)

**Triggers:**
- Push to `13.3.rel1`
- GitHub release published
- Manual `workflow_dispatch`

**What it does:**
1. Restores `install-native/` from the GitHub Actions toolchain cache.
2. Builds the Docker image locally (no push yet) and loads it into the
   local Docker daemon.
3. Applies tags based on the trigger:
   - Push / workflow_dispatch → `edge`
   - Release published → `latest`, full semver, minor semver, major semver
4. Runs the same validation steps as the dry-run (version check + test_project
   CMake build).
5. Pushes all generated tags to `ghcr.io/grahame-org/`.

---

## 7. Assumptions and Validations

The following assumptions were identified in Phase 1 (issues 01–04 of the
docker plan). Their validation status is recorded here as the hand-off for
subsequent phases.

| Assumption | Status | Notes |
|------------|--------|-------|
| Toolchain binary runs inside the container | ✅ Validated | Confirmed by the `arm-none-eabi-gcc --version` step in both dry-run and publish workflows |
| `test_project` CMake build succeeds inside the container | ✅ Validated | Confirmed by the CMake + Make step in both dry-run and publish workflows |
| `install-native/` is present before `docker build` | ✅ Validated | Enforced by the `Check toolchain cache hit` step that fails fast if the cache is absent |
| `.dockerignore` keeps build context small | ✅ Validated | Context contains only `install-native/`, license files, and `Dockerfile`/`.dockerignore` |
| Image naming is predictable per workflow | ✅ Validated | Dry-run tags use `stm32-toolchain-<lowercased-ref>`; publish tags use `stm32-toolchain-<default-branch>` |
| Automated versioning via release-please | ⚠️ Deferred | Covered in issue 07/13 of the docker plan |
| Docker action for downstream consumers | ⚠️ Deferred | Covered in issue 09/13 of the docker plan |

---

## 8. Known Limitations

- **`install-native/` must exist before `docker build`.**
  The Dockerfile does not compile the toolchain from source. The caller is
  responsible for ensuring `install-native/` is populated (either by running
  `build-toolchain.sh` locally or by restoring the GitHub Actions cache).

- **Image is Linux/amd64 only.**
  The build host in CI is `ubuntu-latest` (x86_64). No multi-platform
  (`linux/arm64`, `linux/arm/v7`, etc.) builds are currently configured.

- **CMake and Make are not installed in the runtime image.**
  They are installed transiently inside containers at test time using
  `apt-get` and are discarded when the container exits. If you need to run
  CMake-based builds inside the container in production, install them in
  your own downstream image (`FROM ghcr.io/grahame-org/stm32-toolchain-...`).

- **No entrypoint script.**
  The image has no `ENTRYPOINT` or `CMD`; it relies on callers to provide
  the full command in `docker run`.
