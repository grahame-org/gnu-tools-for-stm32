## Contributing guide

The issues and the pull-requests are not supported to submit problems or suggestions related to the software delivered in this repository.

For any question related to the product, the performance or characteristics, the tools, the environment, you can submit it to the ST Community on the STM32 [MCUs](https://community.st.com/t5/stm32cubeide-mcus/bd-p/stm32-mcu-cubeide-forum) or [MPUs](https://community.st.com/t5/stm32cubeide-mpus/bd-p/stm32-mpu-cubeide-forum) related pages or contact [ST Support Center](https://my.st.com/ols#/ols/) for any defect.

## Commit Message Guidelines

This repository uses the [Conventional Commits](https://www.conventionalcommits.org/) format for all commit messages. A CI check automatically validates commit messages on pull requests — PRs with non-conforming commit messages will fail.

### Format

```
<type>[(optional scope)][!]: <description>

[optional body]

[optional footer(s)]
```

- The **scope** is optional and written in parentheses, e.g. `feat(parser): ...`
- Append `!` after the type/scope to indicate a **breaking change**, e.g. `feat!: ...` or `feat(api)!: ...`

### Allowed Types

| Type       | When to use                                               |
|------------|-----------------------------------------------------------|
| `feat`     | A new feature                                             |
| `fix`      | A bug fix                                                 |
| `docs`     | Documentation changes only                               |
| `style`    | Formatting, whitespace — no logic change                 |
| `refactor` | Code restructuring without feature or bug change         |
| `test`     | Adding or updating tests                                 |
| `chore`    | Maintenance tasks (dependency updates, tooling, etc.)    |
| `ci`       | Changes to CI/CD configuration or scripts                |
| `build`    | Changes to the build system or external dependencies     |
| `perf`     | Performance improvements                                 |
| `revert`   | Reverts a previous commit                                |

### Examples

```
feat: add support for ARMv8-M architecture
fix: correct stack usage calculation for inline assembler
docs: update build instructions for macOS
ci: add commitlint check to pull request workflow
chore: upgrade toolchain to GCC 13.3
```

