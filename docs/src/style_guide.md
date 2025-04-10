# Style Guide

This document serves as the style guide for contributing to the `IARA.jl` project. Adhering to these guidelines ensures a consistent and maintainable codebase.

## General Principles
- **Consistency**: Maintain the existing style of the codebase.
- **Clarity**: Write code that is easy to read and understand, even if it requires more lines.
- **Optimization**: Prioritize readability over performance unless optimization is critical.

## Naming Standards
- Use `snake_case` for functions and variables.
- Use `CamelCase` for modules and types.
- Use `UPPER_CASE` for constants.

## Code Formatting with JuliaFormatter

To ensure uniform formatting, the project uses `JuliaFormatter.jl`. Follow these steps to format your code:

1. Install the package:
    ```julia
    using Pkg
    Pkg.add("JuliaFormatter")
    ```

2. Format your code:
    ```julia
    using JuliaFormatter
    format("docs")
    format("src")
    format("test")
    ```

3. Before submitting a pull request, ensure all changes are formatted.

For more details, refer to the [JuliaFormatter.jl documentation](https://domluna.github.io/JuliaFormatter.jl/stable/).
