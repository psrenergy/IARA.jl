---
name: Bug report
about: Help us track down bugs in IARA

---

Welcome to IARA!

When writing the unexpected behaviour that you are experiencing please follow the [guidelines](https://discourse.julialang.org/t/please-read-make-it-easier-to-help-you/14757) to make it easier to help you. In particular, we kindly ask you to:

1. Provide the julia and IARA version that you are currently using. These can be obtained using the following commands:

```julia
julia> versioninfo()
Julia Version 1.11.1
Commit 8f5b7ca12a (2024-10-16 10:53 UTC)
Build Info:
  Official https://julialang.org/ release
Platform Info:
  OS: Windows (x86_64-w64-mingw32)
  CPU: 8 × Intel(R) Core(TM) i7-8550U CPU @ 1.80GHz
  WORD_SIZE: 64
  LLVM: libLLVM-16.0.6 (ORCJIT, skylake)

(@v1.11) pkg> st IARA
Status `C:\Users\gvidigal\.julia\environments\v1.11\Project.toml`
  [8de1ee9a] IARA v0.1.0 `https://github.com/psrenergy/IARA.jl#main`
```

2. If you encounter a julia error message, please provide the full stacktrace, such as the example below:

```julia
julia> error_example()
ERROR: Something broke.
Stacktrace:
 [1] error(s::String)
   @ Base .\error.jl:35
 [2] error_example()
   @ Main .\REPL[20]:2
 [3] top-level scope
   @ REPL[21]:1
```

3. Whenever possible, please provide a link (google drive, dropbox, etc.) to the files of the case you are experiencing trouble.

Thanks for contributing!