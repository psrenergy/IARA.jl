# Contributing

IARA.jl is an open-source project, and we welcome contributions from the community. Whether you are a seasoned developer or a newcomer, your contributions are valuable to us.
We follow [JuMP's contribution guidelines](https://jump.dev/JuMP.jl/stable/developers/contributing/) in addition to some specific instructions that are detailed below.

# Code of Conduct

Please refer to the [Code of Conduct](https://github.com/psrenergy/IARA.jl/blob/main/CODE_OF_CONDUCT.md) for guidelines on how to interact with the community.


# Improve the documentation

The documentation is written in Markdown using [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl) and [Literate.jl](https://github.com/fredrikekre/Literate.jl).
The source code for the documentation can be found [here](https://github.com/psrenergy/IARA.jl/tree/main/docs).
Please refer to the [Style guide](./style_guide.md) for more details on how to write documentation.

In order to generate the documentation locally, you can run the following command in the root directory of the project:

```bash
julia --project=docs 'docs/make.jl'
```

# File a bug report or feature request

If you encounter a bug or have a feature request, please file an issue on our [GitHub Issues page](https://github.com/psrenergy/IARA.jl/issues). 

When filing a bug report, please include:
- A clear and descriptive title.
- A link (google drive, dropbox, etc.) to the files of the case you are working on.
- Steps to reproduce the issue.
- The expected behavior and what actually happens.
- Any relevant error messages or stack traces.
- Your Julia version and operating system details.

Providing this information will help us address the issue more efficiently. Thank you for your feedback!
