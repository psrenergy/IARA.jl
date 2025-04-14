# Style Guide

Most of the style guidelines are based on the [Julia Style Guide](https://docs.julialang.org/en/v1/manual/style-guide/) and the [JuMP Style Guide](https://jump.dev/JuMP.jl/stable/developers/style/).
Please refer to these guides for more details.

In this document we will cover some specific guidelines for IARA.jl.

## Code Formatting

To ensure uniform formatting, the project uses `JuliaFormatter.jl`. You can format your code just by running the following commands:

```bash
julia --project=format 'format/format.jl'
```

Make sure you format your code before committing it.
Otherwise, a CI job will run the `JuliaFormatter.jl` and raise an error if the code is not formatted correctly.

## Testing

We use [Test.jl](https://docs.julialang.org/en/v1/stdlib/Test/) for testing. The tests are located in the `test` directory of the project.

The tests are organized into subdirectories based on the module they test. 
Each module is related to a base case and its variants.
A base case is created in the `base_case` subdirectory, and its variants are created in their respective subdirectories, with a `modify_case.jl` file that modifies the base case and a `test_case.jl` file that contains the tests for that variant.


Example Case 1:

```
test/case_01
├── base_case
│   ├── ...
│   ├── build_case.jl
│   └── test_case.jl
├── ...
|
└── ac_line_case
    ├── ...
    ├── modify_case.jl
    └── test_case.jl
```

In order to run all the tests, you can run the following command in the root directory of the project:

```bash
julia --project=test -e "import Pkg; Pkg.Registry.update(); Pkg.test()"
```
