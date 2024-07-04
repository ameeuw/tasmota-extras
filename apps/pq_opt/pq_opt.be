var pq_opt= module('pq_opt')


# float[n], float[n] -> bool[n]
def optimise_connected_load(price, load)

    return "optimise_connected_load"
end
# float[n], float[n] -> float[n]
def optimise_unconnected_load(price, load)

    return "optimise_unconnected_load"
end

# float[n] -> ModeEnum[n]
def schedule_heatpump_load(price)

end


pq_opt.optimise_connected_load=optimise_connected_load
pq_opt.optimise_unconnected_load=optimise_unconnected_load
pq_opt.schedule_heatpump_load=schedule_heatpump_load
return pq_opt