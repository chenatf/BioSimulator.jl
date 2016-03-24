import Base.show

immutable SimulationOutput
    species::DataFrame
    propensity::DataFrame
    metadata::Dict{Symbol,Any}
end

species(so::SimulationOutput)      = so.species
propensities(so::SimulationOutput) = so.propensity
metadata(so::SimulationOutput)     = so. metadata

function compile_data(overseer)
    species_data    = DataFrame()
    propensity_data = DataFrame()

    t_observer  = overseer.t_observer
    s_observers = overseer.s_observers
    r_observers = overseer.r_observers

    if !isempty(t_observer.states)
        species_data[t_observer.id]    = t_observer.states
        propensity_data[t_observer.id] = t_observer.states
    end

    for o in s_observers
        species_data[o.id] = o.states
    end

    for o in r_observers
        propensity_data[o.id] = o.states
    end

    return species_data, propensity_data
end

function compile_metadata(algorithm, tf, n, itr)
    mdata = Dict{Symbol,Any}()

    mdata[:algorithm] = string(typeof(algorithm))
    mdata[:time] = tf
    mdata[:pts] = n
    mdata[:itr] = itr

    tags = get_tags(algorithm)

    for tag in tags
        mdata[tag] = getfield(algorithm, tag)
    end

    return mdata
end

function Base.show(io::IO, x::SimulationOutput)
    @printf io "[algorithm] %s\n" x.metadata[:algorithm]
    @printf io "[species data] %d x %d\n" size(x.species, 1) size(x.species, 2)
    @printf io "[propensity data] %d x %d\n" size(x.propensity, 1) size(x.propensity, 2)
end

function cumavg(avg, x, n)
    avg = (x + n * avg) / (n + 1)
end

get_tags(algorithm) = algorithm.tags
