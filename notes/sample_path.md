
````julia
using InteractiveUtils
using NewBioSimulator
using Plots
````



````
Julia Version 1.1.0
Commit 80516ca202 (2019-01-21 21:24 UTC)
Platform Info:
  OS: macOS (x86_64-apple-darwin18.2.0)
  CPU: Intel(R) Core(TM) i7-4750HQ CPU @ 2.00GHz
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-6.0.1 (ORCJIT, haswell)
Environment:
  JULIA_EDITOR = atom  -a
  JULIA_NUM_THREADS = 4
````





## Example model

````julia
include(joinpath(@__DIR__, "test", "test-models", "kendall.jl"))

m = kendall()
m.reaction_list
````


````
OrderedCollections.OrderedDict{Symbol,NewBioSimulator.Reaction} with 3 entr
ies:
  :birth       => X -> 2 X…
  :death       => X -> ∅…
  :immigration => ∅ -> X…
````





## The SamplePath struct

Our software simulates stochastic processes $\{X_{t}\}_{t \ge 0}$ governed by Markovian dynamics.
A *sample path*, denoted $X_{t}(\omega)$, is a particular realization of the process.
This is precisely the type of data (time series) generated by `simulate`, independent of whether the state space involves population counts (well-mixed) or configurations of particles (lattice-based).
Namely, we need to keep track of each observation `u` and its time of observation `t`.
Because the observed values of well-mixed processes are vectors, our new `SamplePath` object is based on the work of RecursiveArrayTools.jl.

**NB: The ideas in that package may one day be migrated to Base. It's better than spinning up our own implementation.**

````julia

struct SamplePath{T,N,A,B} <: AbstractVectorOfArray{T, N}
  u::A
  t::B
end
````




### Basic functionality

First let's generate a single realization of the birth-death-immigration process:

````julia
# note: the parse_model business will go away one day
state, model = NewBioSimulator.parse_model(m)

# so will HasRates
xw = simulate(state, model, Direct(), 4.0, HasRates)
````


````
t: 143-element Array{Float64,1}:
 0.0                 
 0.020393928471780082
 0.025752292062921362
 0.29668498450289194 
 0.33538822275680974 
 0.37229296656521155 
 0.4344462689282344  
 0.4694995031646595  
 0.47641619686358305 
 0.5599006111234718  
 ⋮                   
 3.98172073663435    
 3.9829859412112683  
 3.9883499461447083  
 3.9884918760620285  
 3.9886252749204703  
 3.989274827708974   
 3.9928943766618707  
 3.993326371570482   
 4.0                 
x: 143-element Array{Array{Int64,1},1}:
 [5] 
 [4] 
 [3] 
 [4] 
 [3] 
 [2] 
 [1] 
 [2] 
 [3] 
 [2] 
 ⋮   
 [43]
 [44]
 [45]
 [44]
 [45]
 [46]
 [45]
 [44]
 [44]
````





#### Array interface

Get the value of the process at the $k$-th time step:
````julia
xw[1]
````


````
1-element Array{Int64,1}:
 5
````





Get the value of the $j$-th component at the $k$-th time step:
````julia
xw[1, end]
````


````
44
````





Support for the `Colon` and range indexing:
````julia
xw[:, 1]
````


````
1-element Array{Int64,1}:
 5
````



````julia
xw[1, 1:3]
````


````
3-element Array{Int64,1}:
 5
 4
 3
````





We can even iterate over the object:
````julia
# note you can try computing the sum using a for loop
# but it does not work unless you put the computation in a function
# it causes a weird variable scoping issue; may be a bug
sum(xw[1,i] for i in eachindex(xw))
````


````
3243
````



````julia
sum(xw)
````


````
1-element Array{Int64,1}:
 3243
````





### Plotting

The RecipesBase.jl package provides a nice interface for building visualizations:
````julia

# whenever Plots.jl sees a SamplePath object, replace it with the observation times and values
@recipe function f(xw::SamplePath)
  seriestype --> :steppre

  xw.t, xw'
end

# special case for SamplePath objects whose data is simply a number (as opposed to vector in general)...
@recipe function f(xw::SamplePath{T,1}) where {T}
  seriestype --> :steppre

  xw.t, xw.u
end
````




The `seriestype --> :steppre` syntax is to tell Plots.jl that the data should be plotted as a step function.
Those two recipes are all that are needed to make plotting work:
````julia
plot(xw,
  title  = "a sample path",
  xlabel = "t",
  ylabel = "X_t",
  legend = nothing)
````


![](figures/sample_path_13_1.svg)



## Generating ensembles

Usually we don't care about a single realization of a stochastic process and instead want to compute statistics from several realizations.
Internally, this is handled by the following object:

````julia

Ensemble{T,N,A,B} = Vector{SamplePath{T,N,A,B}}
````




which is an alias for a vector of `SamplePath`s.
As an example, let's generate `10` sample paths of our model:

````julia
ensemble = [simulate(state, model, Direct(), 4.0, HasRates) for i in 1:10]

ensemble[1]
````


````
t: 699-element Array{Float64,1}:
 0.0                
 0.01992609076552918
 0.02917540397161126
 0.05490463025597981
 0.06287076972260094
 0.11845020407240947
 0.2688743159331416 
 0.36406841090351183
 0.47245184426005987
 0.5385518812904962 
 ⋮                  
 3.9954407793482813 
 3.9972569504056774 
 3.9975128168790186 
 3.9978597955911517 
 3.9979744514488207 
 3.998023828612503  
 3.9989016104136526 
 3.9991350678610638 
 4.0                
x: 699-element Array{Array{Int64,1},1}:
 [5]  
 [4]  
 [5]  
 [6]  
 [7]  
 [6]  
 [7]  
 [8]  
 [9]  
 [10] 
 ⋮    
 [201]
 [202]
 [203]
 [204]
 [203]
 [204]
 [205]
 [206]
 [206]
````





The `Ensemble` alias is just there to make writing code easier.
For example, we can generate a default recipe for ensembles which visualizes a mean path.
This requires us to compute the mean value of the process at a particular time $t$ over several samples indexed by $\{\omega_{1}, \ldots, \omega_{n}\}$.
For now, we have a `get_regular_path` function that builds a `SamplePath` with observations at specific time points.
This is simply a constant interpolation of the data *that necessarily discards information about the process*.

````julia

@recipe function f(ens::Ensemble, epochs = 100)
  # regularize the sample paths
  tfinal = ens[1].t[end]

  reg = get_regular_ensemble(ens, tfinal, epochs)

  # extract the series data
  ts = reg[1].t
  xs = convert(Array, mean(reg)')

  ts, xs
end
````




Here `epochs` lets us specify the number of interpolation points to use.
**NB: We need a better interface and implementation for interpolating data**.

````julia
plot(ensemble, 10,
  title  = "mean path (n = 10)",
  xlabel = "t",
  ylabel = "E(X_t)",
  legend = nothing)
````


![](figures/sample_path_17_1.svg)