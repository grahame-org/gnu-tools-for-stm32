---
# CI Data Analysis
# Shared module for analyzing CI run data
#
# Usage:
#   imports:
#     - shared/ci-data-analysis.md
#
# This import provides:
# - Pre-download CI runs and artifacts
# - Build and test the project
# - Collect performance metrics

imports:
  - shared/jqschema.md

tools:
  cache-memory: true
  bash: ["*"]

steps:
  - name: Download CI workflow runs from last 7 days
    env:
      GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    run: |
      # Download workflow runs for the key workflows in this toolchain repo
      mkdir -p /tmp/ci-runs
      for workflow in build-toolchain.yml binutils-tests.yml gcc-selftests.yml gdb-selftests.yml libiberty-tests.yml shell-unit-tests.yml; do
        gh run list --repo ${{ github.repository }} --workflow="${workflow}" --limit 20 \
          --json databaseId,status,conclusion,createdAt,updatedAt,displayTitle,headBranch,event,url,workflowDatabaseId,number \
          > "/tmp/ci-runs/${workflow%.yml}.json" 2>/dev/null || echo "[]" > "/tmp/ci-runs/${workflow%.yml}.json"
      done

      # Merge all runs into a single file
      jq -s 'add' /tmp/ci-runs/*.json > /tmp/ci-runs.json

      # Create directory for artifacts
      mkdir -p /tmp/ci-artifacts

      echo "CI runs data saved to /tmp/ci-runs.json"
      echo "Artifacts saved to /tmp/ci-artifacts/"
---

# CI Data Analysis

Pre-downloaded CI run data is available for analysis:

## Available Data

1. **CI Runs**: `/tmp/ci-runs.json`
   - Recent workflow runs with status, timing, and metadata
   - Covers: build-toolchain, binutils-tests, gcc-selftests, gdb-selftests, libiberty-tests, shell-unit-tests

2. **CI Configuration**: `.github/workflows/`
   - Current workflow configuration files for each component

3. **Cache Memory**: `/tmp/cache-memory/`
   - Historical analysis data from previous runs

## Workflow Files Monitored

This is a **GNU Tools for STM32** bare-metal C/C++ toolchain repository. The key CI workflows are:

- **`build-toolchain.yml`** — Full toolchain build + test_project validation (main workflow)
- **`binutils-tests.yml`** — Binutils DejaGnu regression tests (gas, ld, binutils)
- **`gcc-selftests.yml`** — GCC internal selftests (`-fself-test`)
- **`gdb-selftests.yml`** — GDB `maintenance selftest`
- **`libiberty-tests.yml`** — libiberty unit tests (`make check`)
- **`shell-unit-tests.yml`** — Shell unit tests

> **Note**: There is no `ci.yml`, `go.mod`, `Makefile`, or `actions/setup/js/` directory.
> Build scripts are `build-toolchain.sh` and `build-prerequisites.sh`.
> There are no Go or Node.js sources to build or test.

## Analyzing Run Data

Parse the downloaded CI runs data:

```bash
# Analyze run data
cat /tmp/ci-runs.json | jq '
{
  total_runs: length,
  by_status: group_by(.status) | map({status: .[0].status, count: length}),
  by_conclusion: group_by(.conclusion) | map({conclusion: .[0].conclusion, count: length}),
  by_branch: group_by(.headBranch) | map({branch: .[0].headBranch, count: length}),
  by_event: group_by(.event) | map({event: .[0].event, count: length})
}'
```

**Metrics to extract:**
- Success rate per workflow
- Average duration per workflow
- Failure patterns (which jobs fail most often)
- Cache hit rates from step summaries

## Historical Context

Check cache memory for previous analyses:

```bash
# Read previous optimization recommendations
if [ -f /tmp/cache-memory/ci-coach/last-analysis.json ]; then
  cat /tmp/cache-memory/ci-coach/last-analysis.json
fi
```
