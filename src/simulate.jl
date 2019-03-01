function parse_model(network::Network)
  state = [ x.population for (key, x) in species_list(network) ]
  model = ReactionSystem(network)

  return state, model
end

function simulate(network::Network, algname::SimulationAlgorithm; tfinal=0.0, rates_cache = HasRates)
  # build the internal representation of our stochastic process
  initial_state, model = parse_model(network)

  # feedforward down the chain...
  return simulate(initial_state, model, algname, tfinal, rates_cache)
end

function simulate(initial_state, model, algname, tfinal, rates_cache)
  # copy state
  state = copy(initial_state)

  # build the simulator
  simulator = build_simulator(algname, state, model, rates_cache)

  # feedforward down the chain...
  simulate!(simulator, state, model, tfinal)
end

function simulate!(simulator, state, model, tfinal)
  initialize!(simulator, state, model)

  while simulator.t < tfinal && first(simulator.algorithm.total_rate) > 0
    tnew = get_new_time(simulator)

    if tnew <= tfinal
      step!(simulator, state, model)
    else
      simulator.t = tfinal
    end
  end

  return state
end