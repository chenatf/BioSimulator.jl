import Base.Collections: PriorityQueue, peek
import Base.Order: ForwardOrdering

type NRM <: Algorithm
    # state variables
    intensity::Float64
    g::DiGraph
    pq::PriorityQueue{Int,Float64,ForwardOrdering}

    # statistics
    steps::Int
    avg_steps::Float64
    counter::Int

    # metadata tags
    tags::Vector{Symbol}

    function NRM(args)
        new(0.0, DiGraph(), PriorityQueue(Int,Float64), 0, 0.0, 0, [:avg_steps])
    end
end

function init(alg::NRM, rxns, spcs, initial, params)
    alg.g = init_dep_graph(rxns)
    alg.pq = init_pq(rxns) # Allocate the priority queue with zeros

    return;
end

function reset(alg::NRM, rxns, spcs, params)
    compute_statistics(alg)
    alg.steps = 0

    # Compute propensities and initialize the priority queue with firing times
    compute_propensities!(rxns, spcs, params)
    init_pq!(alg.pq, rxns)

    return;
end

function compute_statistics(alg::NRM)
    alg.avg_steps = cumavg(alg.avg_steps, alg.steps, alg.counter)
    alg.counter = alg.counter + 1
    return;
end

function step(alg::NRM, rxns, spcs, params, t, tf)
    τ = nrm_update!(spcs, rxns, t, tf, alg.g, alg.pq, params) - t
    alg.steps = alg.steps + 1

    return τ;
end

function nrm_update!(spcs::Vector{Int}, rxns::ReactionVector, t::Float64, tf::Float64, g::LightGraphs.DiGraph, pq, param::Parameters)
    μ, t = peek(pq)
    if t > tf; return t; end
    μ > 0 ? update!(spcs, rxns[μ]) : error("No reaction occurred!")
    update_dep_graph!(g, rxns, pq, spcs, param, μ, t)
    return t
end

function init_dep_graph(rxns::ReactionVector)
    m = length(rxns)
    d = length(rxns[1].pre)
    g = DiGraph(m)

    @inbounds for j in eachindex(rxns)
        r = rxns[j]
        pre = r.pre
        post = r.post

        # Search for reactions r_i with reactant or product of r_j as reactant
        @inbounds for k in eachindex(pre)
            if pre[k] != 0 || post[k] != 0
                @inbounds for i in eachindex(rxns)
                    if rxns[i].pre[k] != 0; add_edge!(g, j, i); end
                end
            end
        end
    end
    return g
end

function update_dep_graph!(g::LightGraphs.DiGraph, rxns::ReactionVector, pq, spcs::Vector{Int}, param::Parameters, μ::Int, t::Float64)
    dependents = neighbors(g, μ)
    r = rxns[μ]

    # Compute propensity of the reaction that fired and update the next firing time
    propensity!(r, spcs, param)
    pq[μ] = t + rand(Exponential(1 / r.propensity))

    # Compute propensities and firing times for dependent reactions
    @inbounds for α in dependents
        _r = rxns[α]
        old_propensity = _r.propensity
        propensity!(_r, spcs, param)
        if α != μ
            pq[α] = t + (old_propensity / _r.propensity) * (pq[α] - t)
        end
    end
    return g
end

function init_pq(rxns::ReactionVector)
    pq = PriorityQueue(Int,Float64)
    for j in eachindex(rxns)
        pq[j] = 0.0
    end
    return pq
end

function init_pq!(pq, rxns::ReactionVector)
    @inbounds for j in eachindex(rxns)
        pq[j] = rand(Exponential(1 / rxns[j].propensity))
    end
end
