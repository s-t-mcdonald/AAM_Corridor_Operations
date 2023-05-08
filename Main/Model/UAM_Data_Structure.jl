# Struct   UAM_Data
#
# Data Structure used to contain data used in optimization
#
# Author: Spencer McDonald
# MIT - ORC UAM Study
# email: mcdonst@mit.edu
# Website: https://www.spencertmcdonald.com/
# Mar 2021; Last revision: 13-Jan-2021

mutable struct UAM_Data
    
    Dir

    ## Optimization Parameters ##
    Time_Limit #Time limit for optimization model (s)
    Optimality_Gap #Optimality gap that will stop optmization (%)
    Margin

    ## Network Data ##
    Network
    Num_Vertiports #number of vertiports
    Num_Corridors
    Num_Lanes
    Route_Vec
    Route_Desc
    ID_Routes
    ID_Len
    Depart
    Arrival
    ODT
    East_Set
    West_Set
    Clear_Times
    Node_Neighbor
    Corridors
    C_dist
    Node_Dir
    Node_List
    Weights
    distmx
    LongLat
    pathmx
    Corridor_East
    Corridor_West
    Route_OD
    Corridor_Mat
    δe_in
    δw_in
    δe_out
    δw_out
    Corridor_Dist
    Num_Nodes
    Num_Edges
    Weather_Closures_Truth
    Weather_Closures_Predict
    open_prob_mx
    Route_Prob_Set
    Routes_Closed

    ## Time Data ##
    Time_Nodes #number of discretized time nodes
    Δt #Time Discretization
    Mult
    Buffer #Buffer for boundary conditions

    ## Vehicle Data ##
    Veh_Speed #Speed of the vehicle
    Max_Range

    ## Vertiport Data ##
    Num_Veh #number of vehicles
    Parking_Cap #maximum number of vehicles at a specific vertiport
    Operational_Cap
    TaT #turn around time (time nodes)
    
    ## Inputs ##
    ED #Estimated demand between the vertiports
    Demand_Requests
    Demand_Revenues
    Wait_Times 
    Con_List
    Dem_List
    Con_Matrix


end