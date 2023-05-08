# Syntax    TT(dist, Δt, Veh_Speed)
#
# Inputs:
#    dist - distance units
#    Δt - time discretization units
#    Veh_Speed - vehicle speed units
#
# Outputs:
#    time_nodes - Number of time nodes it takes
#
# Author: Spencer McDonald
# MIT - ORC UAM Study
# email: mcdonst@mit.edu
# Website: https://www.spencertmcdonald.com/
# Mar 2021; Last revision: 13-Jan-2021

function TT(dist, Δt, Veh_Speed)
    
    time = dist / Veh_Speed/ Δt;
    
    time_nodes = round(Int, maximum([time, 1]))
    
    return time_nodes
    
end
   