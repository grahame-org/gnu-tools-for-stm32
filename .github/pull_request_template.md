## Description

<!-- Describe the changes introduced by this PR and why they are needed. -->

## Testing

<!-- Describe how these changes were tested. -->

## Checklist

- [ ] The PR title follows the Conventional Commits format (see note below)
- [ ] Changes are documented where appropriate

---

> [!IMPORTANT]
> **PR title must follow [Conventional Commits](https://www.conventionalcommits.org/) format.**
>
> PRs are squashed into the target branch using the **PR title** as the commit message.
> The PR title must therefore conform to commitlint requirements:
>
> ```
> <type>[(optional scope)][!]: <description>
> ```
>
> Common types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `build`, `perf`, `style`, `revert`
>
> [!NOTE]
> description **must not** start with uppercase letter
> 
> Examples: `feat: add ARMv8-M support`, `fix: correct stack calculation`, `docs: update build instructions`
>
> Individual commits **within** the PR do **not** need to follow this format.
