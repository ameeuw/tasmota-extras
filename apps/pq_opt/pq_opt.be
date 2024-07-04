var pq_opt= module('pq_opt')
import math


# float[n], float[<n] -> bool[n]
def optimise_connected_load(cost, load)
    var tot_costs  =[]
    for t0:0..(cost.size()-load.size())
     var weighted_cost= 0 
      for t:0..(load.size()-1) 
          weighted_cost += cost[t0+t]*load[t]
      end
      tot_costs.push(weighted_cost)
    end
    var min_cost_t = 0
    for i:0..(size(tot_costs)-1)
    if tot_costs[i]< tot_costs[min_cost_t] 
        min_cost_t = i
    end
    var schedule = []
    for t:0..(cost.size()-1)
        schedule.push(t>=min_cost_t && t<min_cost_t+load.size())
    end
    return schedule
end
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