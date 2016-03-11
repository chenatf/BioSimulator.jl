type SSA <: Algorithm
    # state variables
    intensity::Float64

    # statistics
    steps::Int
    avg_steps::Float64
    counter::Int

    # metadata tags
    tags::Vector{Symbol}

    function SSA(args)
        new(0.0, 0, 0.0, 0, [:avg_steps])
    end
end

init(alg::SSA, rrxns, spcs, initial, params) = return;

function reset(alg::SSA, rxns, spcs, params)
    compute_statistics(alg)
    alg.steps = 0
    return;
end

function compute_statistics(alg::SSA)
    alg.avg_steps = cumavg(alg.avg_steps, alg.steps, alg.counter)
    alg.counter = alg.counter + 1
    return;
end

function step(alg::SSA, rxns, spcs, params, t, tf)
    alg.intensity = compute_propensities!(rxns, spcs, params)
    τ = ssa_update!(spcs, rxns, t, tf, alg.intensity)
    alg.steps = alg.steps + 1
    return τ;
end

function sample(rxns::ReactionVector, jump)
    ss = 0.0
    for i in eachindex(rxns)
        ss = ss + rxns[i].propensity
        if ss >= jump
            return i
        end
    end
    return 0
end

function ssa_step!(spcs::Vector{Int}, rxns::ReactionVector, intensity)
    u = rand()
    jump = intensity * u
    j = sample(rxns, jump)
    j > 0 ? update!(spcs, rxns[j]) : error("No reaction occurred!")
    return;
end

function ssa_update!(spcs::Vector{Int}, rxns::ReactionVector, t, tf, intensity)
    τ = rand(Exponential(1/intensity))
    t = t + τ
    if t > tf; return τ; end
    ssa_step!(spcs, rxns, intensity)
    return τ
end

function update!(spcs::Vector{Int}, r::ReactionChannel)
    for i in eachindex(spcs)
        spcs[i] = spcs[i] + (r.post[i] - r.pre[i])
    end
    return;
end
