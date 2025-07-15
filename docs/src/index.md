# IARA: Interaction Assessment between Regulators and Agents

IARA is a computational model that provides the capability to simulate mechanism designs for economic dispatch and price formation in electricity markets. Through hourly simulations of large-scale systems, incorporating uncertainties, and with detailed representation of the physical components of generation, transmission, storage, and consumption, it is possible to assess the impacts on agents and the system of price formation mechanisms based on "cost," "bid," or any hybrid model between the two.

## Installation Guide

IARA.jl is a Julia package that can be installed using the Julia package manager. First, if you do not have Julia installed, you can download it from the [official website](https://julialang.org/downloads/). If you are using Julia for the first time, you can follow the [Getting Started](https://docs.julialang.org/en/v1/manual/getting-started/) guide.

To install IARA.jl, you can run the following command in the Julia REPL:

```julia
using Pkg

Pkg.add(url="https://github.com/psrenergy/IARA.jl")
```

This will install the package and its dependencies. You can then use the package by running:

```julia
using IARA
```

Now, let's [get started](tutorial/first_execution.md) on IARA.