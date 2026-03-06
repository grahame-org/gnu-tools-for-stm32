---
# CI Optimization Analysis Strategies
# Reusable analysis patterns for CI optimization workflows
#
# Usage:
#   imports:
#     - shared/ci-optimization-strategies.md
#
# This import provides:
# - Test coverage analysis patterns
# - Performance bottleneck identification
# - Matrix strategy optimization techniques
---

# CI Optimization Analysis Strategies

Comprehensive strategies for analyzing CI workflows to identify optimization opportunities.

## Phase 1: CI Configuration Study

Read and understand the current CI workflow structure:

```bash
# List and read all CI workflow files
ls .github/workflows/*.yml
```

Most test/build workflows in this repository use a consistent three-job pattern:
- `check-changes` — uses `dorny/paths-filter` to detect relevant file changes; exposes a boolean output (e.g., `should-build` or `should-test`)
- Main job — gated with `if:` on the `check-changes` output; skipped on pull requests when no relevant files changed
- `<name>-status` — runs with `if: always()` so required status checks stay green when the main job is skipped

Note: some lightweight workflows (e.g., `commitlint.yml`) are single-job workflows that intentionally do not follow this pattern.

**Key aspects to analyze:**
- Job dependencies and parallelization opportunities
- Matrix strategy effectiveness
- Cache usage patterns (stage caches keyed on source-tree hashes via `git rev-parse HEAD:<dir>`)
- Paths-filter correctness — do the watched paths in each workflow match the files that actually affect that component?
- Timeout configurations
- Concurrency groups
- Artifact retention policies

## Phase 2: Test Coverage Analysis

### Critical: Ensure ALL Tests are Executed

**Step 1: Discover test assets**
```bash
# Find all shell test scripts
ls tests/test-*.sh

# Find all CI workflow files
ls .github/workflows/*.yml
```

**Step 2: Verify CI coverage**

For each test script discovered in `tests/`, confirm there is a corresponding CI workflow step that invokes it. Cross-reference test script names against the workflow YAML files to spot any orphaned tests.

**Step 3: Verify paths-filter correctness for each workflow**

For every CI workflow, check that its `dorny/paths-filter` paths list covers all the source directories and files that can affect that component. A common mistake is adding a new source directory without updating the corresponding workflow's filter.

**Required Action if Gaps Found:**
If any tests or relevant source paths are not covered:
1. **Missing path entries** — add entries to the workflow's `dorny/paths-filter` block so it triggers on the right changes
2. **Orphaned test scripts** — add invocations to the appropriate workflow job so every test in `tests/` is executed by CI

## Phase 3: Test Performance Optimization

### A. Test Splitting Analysis
- Review current test matrix configuration
- Analyze if test groups are balanced in execution time
- Suggest rebalancing to minimize longest-running group

### B. Test Parallelization Within Jobs
- Check if independent test or build jobs run sequentially when they could run in parallel
- Build stages use `jobs: $(nproc)` for multi-core compilation; verify this pattern is applied consistently
- Analyze if any stage cache steps could be parallelized or reordered to reduce wall-clock time

### C. Test Selection Optimization
- Suggest path-based test filtering to skip irrelevant tests
- Recommend running only affected tests for non-main branch pushes

### D. Test Timeout Optimization
- Review current timeout settings
- Check if timeouts are too conservative or too tight
- Suggest adjusting per-job timeouts based on historical data

### E. Test Dependencies Analysis
- Examine test job dependencies
- Suggest removing unnecessary dependencies to enable more parallelism

### F. Selective Test Execution
- Suggest running expensive tests only on main branch or on-demand
- Recommend running security scans conditionally

### G. Matrix Strategy Optimization
- Analyze if all integration test matrix jobs are necessary
- Check if some matrix jobs could be combined or run conditionally
- Suggest reducing matrix size for PR builds vs. main branch builds

## Phase 4: Resource Optimization

### Job Parallelization
- Identify jobs that could run in parallel but currently don't
- Restructure dependencies to reduce critical path
- Example: Could some test jobs start earlier?

### Cache Optimization
- Analyze cache hit rates
- Suggest caching more aggressively (dependencies, build artifacts)
- Check if cache keys are properly scoped

### Resource Right-Sizing
- Check if timeouts are set appropriately
- Evaluate if jobs could run on faster runners
- Review concurrency groups

### Artifact Management
- Check if retention days are optimal
- Identify unnecessary artifacts
- Example: Coverage reports only need 7 days retention

### Dependency Installation
- Check for redundant dependency installations
- Suggest using dependency caching more effectively
- Example: Sharing `node_modules` between jobs

## Phase 5: Cost-Benefit Analysis

For each potential optimization:
- **Impact**: How much time/cost savings?
- **Effort**: How difficult to implement?
- **Risk**: Could it break the build or miss issues?
- **Priority**: High/Medium/Low

## Optimization Categories

1. **Job Parallelization** - Reduce critical path
2. **Cache Optimization** - Improve cache hit rates
3. **Test Suite Restructuring** - Balance test execution
4. **Resource Right-Sizing** - Optimize timeouts and runners
5. **Artifact Management** - Reduce unnecessary uploads
6. **Matrix Strategy** - Balance breadth vs. speed
7. **Conditional Execution** - Skip unnecessary jobs
8. **Dependency Installation** - Reduce redundant work

## Expected Metrics

Track these metrics before and after optimization:
- Total CI duration (wall clock time)
- Critical path duration
- Cache hit rates
- Test execution time
- Resource utilization
- Cost per CI run
