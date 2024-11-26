# # My first execution

# > The data for this case is available in the folder [`data/case_1`](https://github.com/psrenergy/IARA.jl/tree/master/docs/src/tutorial/data/case_1)

# In this tutorial, we will build a simple case containing some basic elements that can help
# us understand some of the functionalities of the IARA package.

# We'll start by importing the necessary packages.
import Pkg #hide
Pkg.activate("../../..") #hide
Pkg.instantiate() #hide
using IARA
; #hide

# We also need to define a directory to store the case.
case_path = joinpath(@__DIR__, "data", "case_1")

#hide