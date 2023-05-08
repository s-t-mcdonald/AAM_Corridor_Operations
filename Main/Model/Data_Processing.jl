# Syntax    Data_Processing(Dir)
#
# Inputs:
#    Dir - directory to the UAM_Operations_Scheduler folder
#
# Outputs:
#    Data - Data with updated demand and time information
#    Model_Dict - Model dictionary with updated demand
#
# Author: Spencer McDonald
# MIT - ORC UAM Study
# email: mcdonst@mit.edu
# Website: https://www.spencertmcdonald.com/
# Mar 2021; Last revision: 13-Jan-2021

include("Update_Demand.jl")
include("..//Data//Constants.jl")
include("UAM_Data_Structure.jl")
include("TT.jl")


using CSV, DataFrames, FileIO, TOML, DelimitedFiles, SparseArrays
using Gurobi, JuMP, DataFrames, CSV, JSON, Graphs, JLD2;

using .Base_Model;

function Data_Processing(Dir, route_seeding, Edges, LongLat, Network, Raw_Demand, parameters, dem_per_vert_hour, demand_alpha);


    # ## Import Parameters ##
    # parameters = TOML.parsefile(Dir*"Main//Parameters//Parameters.toml")

    ## Extract Parameters ##
    # Model Parameters 
    Time_Limit      = parameters["optimization"]["time_limit"];
    Optimality_Gap  = parameters["optimization"]["optimality_gap"];

    # Network Parameters 
    Num_Vertiports  = Edges["Number_of_Vertiports"];
    Num_Lanes       = parameters["network"]["num_lanes"];
    Margin          = parameters["network"]["margin"];

    # Time Parameters
    Δt              = parameters["time"]["discretization"];
    Mult            = 1#parameters["time"]["graph_discretization_mult"];

    # Operational Parameters - Vehicle
    Veh_Speed       = parameters["vehicle"]["vehicle_speed"];
    Max_Endurance   = parameters["vehicle"]["max_endurance"];

    # Operational Parameters - Vertiports
    Num_Veh         = parameters["vertiports"]["num_veh"];
    TaT             = parameters["vertiports"]["turn_around_time"];
    Parking_Cap     = parameters["vertiports"]["parking_capacity"];
    Operational_Cap = parameters["vertiports"]["operational_capacity"];

    Max_Range = Veh_Speed*Max_Endurance
    print("Max Range: $Max_Range \n")

    Weather_Closures_Predict = []

    ## Calculate Parameters ##
    Time_Nodes, TaT, Buffer, ED, Demand_Requests, Demand_Revenues  = Calulations(parameters, Edges)

    ## Network_Processing ##
    Num_Corridors, Num_Lanes, Route_Vec, Route_Desc, ID_Routes, ID_Len, Depart, Arrival, ODT, East_Set, West_Set, Clear_Times, Node_Neighbor, Corridors, C_dist, Node_Dir, Node_List, Weights, distmx, pathmx, Corridor_East, Corridor_West, Route_OD, Corridor_Mat, δe_in, δw_in, δe_out, δw_out, Corridor_Dist, Num_Edges, open_prob_mx, Route_Prob_Set, Routes_Closed, Num_Nodes = Network_Processing(parameters, route_seeding, Edges, LongLat, Time_Nodes, Buffer, Δt, Mult, Veh_Speed, Max_Range)
    print("Finished Network Processing \n")

    Weather_Closures_Predict = []
    Weather_Closures_Truth = []
    Wait_Times = []
    Con_List = []
    Dem_List = []
    Con_Matrix = []

    # Store Data
    Data = UAM_Data(Dir, Time_Limit, Optimality_Gap, Margin, Network, Num_Vertiports, Num_Corridors, Num_Lanes, Route_Vec, Route_Desc, ID_Routes, 
                    ID_Len, Depart, Arrival, ODT, East_Set, West_Set, Clear_Times, Node_Neighbor, Corridors, C_dist, Node_Dir, Node_List, 
                    Weights, distmx, LongLat, pathmx, Corridor_East, Corridor_West, Route_OD, Corridor_Mat, δe_in, δw_in, δe_out, δw_out, 
                    Corridor_Dist, Num_Nodes, Num_Edges, Weather_Closures_Truth, Weather_Closures_Predict, open_prob_mx, Route_Prob_Set, Routes_Closed, Time_Nodes, Δt, Mult, Buffer,
                    Veh_Speed, Max_Range, Num_Veh, Parking_Cap, Operational_Cap, TaT, ED, Demand_Requests, Demand_Revenues, Wait_Times, Con_List, Dem_List, Con_Matrix)


    print("Number of Corridors: $Num_Corridors\n")
    if Network == "Random_Network"
        Data = Update_Demand_Fast(Data, dem_per_vert_hour)
    else
        Data = Update_Demand(Data, Raw_Demand, dem_per_vert_hour, demand_alpha)
    end

    Demand_Requests = Data.Demand_Requests
    Num_Requests = length(Demand_Requests)

    Wait_Times = []
    Con_List = []
    Dem_List = []
    for n = 1:Num_Requests
        
        t, i, j, Max_Wait_Time, Car_TT, Flying_TT, Vert_to_Vert, Org_Zip, Dst_Zip, Time_Red, Prob, Rev = Demand_Requests[n]
        
        New_Max_Wait_Time = Max_Wait_Time
        for k = 1:Max_Wait_Time

            if t+k-1 > Time_Nodes
                New_Max_Wait_Time = New_Max_Wait_Time - 1
                continue
            end

            if (t+k-1 ,i,j) ∈ Con_List

                ind = findfirst(x -> x == (t+k-1 ,i,j), Con_List)
                push!(Dem_List[ind], (n,k))

                continue
            end

            push!(Con_List, (t+k-1 ,i,j))
            push!(Dem_List, [(n,k)])
        end
        push!(Wait_Times, New_Max_Wait_Time)
    end

    Demand_df = DataFrame(demand_request = Int64[], departure_time = Int64[], org_vert = Int64[], dst_vert = Int64[], Max_Wait_Time = Int64[], Car_TT = Float64[], Flying_TT = Float64[], Vert_to_Vert_Dist = Float64[], Org_Zip = Int64[], Dst_Zip = Int64[], Time_Red = Float64[], Prob = Float64[], Revenue = Float64[])

    for n = 1:Num_Requests

        t, i, j, Max_Wait_Time, Car_TT, Flying_TT, Vert_to_Vert, Org_Zip, Dst_Zip, Time_Red, Prob, Rev = Demand_Requests[n]
        push!(Demand_df, [n, t, i, j, Max_Wait_Time, Car_TT, Flying_TT, Vert_to_Vert, Org_Zip, Dst_Zip, Time_Red, Prob, Rev])

    end


    Old_Con_List = deepcopy(Con_List)

    Con_Matrix = zeros(Time_Nodes+Buffer, Num_Vertiports, Num_Vertiports) .- 1
    for (t,i,j) ∈ Old_Con_List

        ind = findfirst(x -> x == (t,i,j), Con_List)
        Con_Matrix[t,i,j] = ind

    end
    Con_Matrix = round.(Int, Con_Matrix)
    
    Data.Wait_Times = Wait_Times
    Data.Con_List = Con_List
    Data.Dem_List = Dem_List
    Data.Con_Matrix = Con_Matrix

    print("-----------------Finished Constructing Data-----------------\n")

    return Data, Demand_df

end


function Calulations(parameters, Edges)

    Num_Vertiports  = Edges["Number_of_Vertiports"];
    
    # Time Parameters
    Δt              = parameters["time"]["discretization"];
    Horizon         = parameters["time"]["horizon"];

    # Operational Parameters - Vertiports
    TaT             = parameters["vertiports"]["turn_around_time"];

    # Time Parameters
    Δt              = parameters["time"]["discretization"];
    Horizon         = parameters["time"]["horizon"];

    # Time Calculations
    Time_Nodes = round(Int, (Horizon)/Δt)
    TaT = floor(Int, TaT/Δt-0.01) + 1;
    Buffer = 60#round(Int, 2*maximum([TaT, LT])) # Buffer at the begining of the model

    # Demand Calculations
    ED = zeros(Int, Time_Nodes, Num_Vertiports, Num_Vertiports)
    Demand_Requests = []
    Demand_Revenues = []

    return Time_Nodes, TaT, Buffer, ED, Demand_Requests, Demand_Revenues

end




function Network_Processing(parameters, route_seeding, Edges, LongLat, Time_Nodes, Buffer, Δt, Mult, Veh_Speed, Max_Range)

    ## Extract Parameters ##
    # Network Parameters 

    Num_Vertiports  = Edges["Number_of_Vertiports"];
    Num_Routes      = parameters["network"]["num_routes"];
    Num_Lanes       = parameters["network"]["num_lanes"];

    N_nodes = Edges["Nodes"]
    N_edges = Edges["Edges"]

    if route_seeding == "None"
        Num_Routes = 0
    elseif route_seeding == "All_Lanes"
        Lane_Set_East = 1:1:Num_Lanes
        Lane_Set_West = 1:1:Num_Lanes
    elseif route_seeding == "Compat_Lanes"
        Lane_Set_East = 1:2:Num_Lanes
        Lane_Set_West = 2:2:Num_Lanes
    end

    ## Network Processing ##


    ## Translate Corridor Network to Graph ##
    g = SimpleGraph(N_nodes)

    distmx = spzeros(N_nodes,N_nodes)

    for k = 1:N_edges

        val = Edges[string(k)]

        src = round(Int, val[1])
        dst = round(Int, val[2])
        dist = val[3]

        add_edge!(g,src,dst)
        add_edge!(g,dst,src)
        distmx[src,dst] = dist
        distmx[dst,src] = dist
    end
    print("Translated Corridor Network to Graph \n")



    ## Find the distance between all points ##
    print("Found distances between each corridor point \n")


    Num_Bridges = 0
    Flag = true
    while Flag

        Flag = false

        for e ∈ edges(g)
            
            if (length(neighbors(g, e.src)) == 2) & (e.src > Num_Vertiports) 

                n = deepcopy(neighbors(g, e.src))

                rem_edge!(g, n[1], e.src)
                rem_edge!(g, n[2], e.src)

                add_edge!(g, n[1], n[2])

                distmx[n[1], n[2]] = distmx[n[1], e.src] + distmx[e.src, n[2]]
                distmx[n[2], n[1]] = distmx[n[1], e.src] + distmx[e.src, n[2]]

                distmx[n[1], e.src] = 0
                distmx[e.src, n[1]] = 0

                distmx[n[2], e.src] = 0
                distmx[e.src, n[2]] = 0

                Num_Bridges = Num_Bridges + 1
                Flag = true

            end


            if (length(neighbors(g, e.dst)) == 2) & (e.dst > Num_Vertiports)

                n = deepcopy(neighbors(g, e.dst))

                rem_edge!(g, n[1], e.dst)
                rem_edge!(g, n[2], e.dst)

                add_edge!(g, n[1], n[2])

                distmx[n[1], n[2]] = distmx[n[1], e.dst] + distmx[e.dst, n[2]]
                distmx[n[2], n[1]] = distmx[n[1], e.dst] + distmx[e.dst, n[2]]

                distmx[n[1], e.dst] = 0
                distmx[e.dst, n[1]] = 0

                distmx[n[2], e.dst] = 0
                distmx[e.dst, n[2]] = 0

                Num_Bridges = Num_Bridges + 1
                Flag = true

            end

        end
    end
    print("Removed $Num_Bridges Number of Bridges in the Network \n")



    pathmx = zeros(N_nodes,N_nodes)
    for i = 1:Num_Vertiports, j = 1:Num_Vertiports

        if i == j
            continue
        end

        R = yen_k_shortest_paths(g, i, j, distmx, 1)

        if R.dists == []
            print("Cannot get from vertiport $i to vertiport $j \n")
            continue
        end

        pathmx[i,j] = R.dists[1]

    end
    

    ## Find the set of routes that correspond to each corridor ## 
    Corridors = []
    C_dist = []
    Node_Dir = zeros(Int, nv(g), nv(g))
    for e ∈ edges(g)

        push!(C_dist, distmx[e.src,e.dst])

        if e.src >= e.dst
                    
            push!(Corridors, (e.src, e.dst))
            Node_Dir[e.src, e.dst] = 1
            
        else
            
            push!(Corridors, (e.dst, e.src))
            Node_Dir[e.dst,e.src] = 0

        end
    end
    Num_Corridors = length(Corridors)
    print("Found all corridors in the network \n")


    Node_Neighbor = [[] for n = 1:nv(g)]
    for n = 1:nv(g)
        for nv in neighbors(g,n)
            push!(Node_Neighbor[n], (nv, distmx[nv,n]))
        end
    end
    print("Found all node neighbors \n")

    Node_List = zeros(Int, nv(g), nv(g))
    Corridor_Mat = zeros(Int, nv(g), nv(g))
    Clear_Times = []
    Corridor_Dist = []
    for k = 1:Num_Corridors

        ct = TT(distmx[Corridors[k][1], Corridors[k][2]], Δt, Veh_Speed)
        
        push!(Clear_Times, ct)
        push!(Corridor_Dist, distmx[Corridors[k][1], Corridors[k][2]])

        Node_List[Corridors[k][1],Corridors[k][2]] = k
        Node_List[Corridors[k][2],Corridors[k][1]] = k

        if Corridors[k][1] >= Corridors[k][2]
            Corridor_Mat[Corridors[k][1],Corridors[k][2]] = k
        else
            Corridor_Mat[Corridors[k][2],Corridors[k][1]] = -k
        end

    end
    max_clear = maximum(Clear_Times)
    print("Found clear times | Max Clear Time: $max_clear\n")


    
    
    print("Found the routes that correspond to each Conjuction \n")

    δe_in = [[] for n = 1:N_nodes]
    δw_in = [[] for n = 1:N_nodes]
    δe_out = [[] for n = 1:N_nodes]
    δw_out = [[] for n = 1:N_nodes]
    Num_Edges = []
    for n =1:N_nodes
        for k = 1:length(Corridors)

            if (n == Corridors[k][1]) 

                m = Corridors[k][2]

            elseif (n == Corridors[k][2])

                m = Corridors[k][1]
            
            else 
                continue
            end
            

            if n >= m
                
                push!(δe_in[n], (k, distmx[Corridors[k][1], Corridors[k][2]]))
                push!(δw_out[n], (k, distmx[Corridors[k][1], Corridors[k][2]]))
                
            else
                
                push!(δw_in[n], (k, distmx[Corridors[k][1], Corridors[k][2]]))
                push!(δe_out[n], (k, distmx[Corridors[k][1], Corridors[k][2]]))

            end

    
        end

        δe_in[n] = unique(δe_in[n])
        δw_out[n] = unique(δw_out[n])
        δw_in[n] = unique(δw_in[n])
        δe_out[n] = unique(δe_out[n])
        push!(Num_Edges, length(neighbors(g, n)) )
    end


    ## Find N number of shortest routes in the network ##
    Route_Vec = [] 
    Weights = []
    Route_Desc = []
    Route_OD = []
    Depart = [[[] for x = 1:Num_Vertiports] for y = 1:Time_Nodes+Buffer]
    Arrival = [[[] for x = 1:Num_Vertiports] for y = 1:Time_Nodes+Buffer]
    ODT = [[[[] for x = 1:Num_Vertiports] for y = 1:Num_Vertiports] for z = 1:Time_Nodes+Buffer]
    ID_Routes = Dict()
    ID_Len = Dict() 

    East_Set = [[[[] for x = 1:Num_Lanes] for y = 1:Num_Corridors] for z = 1:Time_Nodes+Buffer]
    West_Set = [[[[] for x = 1:Num_Lanes] for y = 1:Num_Corridors] for z = 1:Time_Nodes+Buffer]

    Corridor_East = []
    Corridor_West = []

    Routes_Closed = []

    if Num_Routes > 0.5
        k = 1
        k_start = 1
        for i = 1:Num_Vertiports, j = 1:Num_Vertiports

            if LongLat[string(i-1)][1] < LongLat[string(j-1)][1]
                Lane_Set = Lane_Set_East
            else
                Lane_Set = Lane_Set_West
            end

            if i == j 
                continue
            end

            R = yen_k_shortest_paths(g, i, j, distmx, Num_Routes)
            
            for r = 1:length(R.dists)

                path = R.paths[r]
                if R.dists[r] > Max_Range
                    continue
                end
                dist = sum(TT(distmx[path[i],path[i+1]], Δt, Veh_Speed) for i = 1:length(path)-1)

                for t = 1:(Time_Nodes+Buffer)
                    for l ∈ Lane_Set
                        
                        if t + dist > (Time_Nodes+Buffer)
                            continue
                        end

                        times = [t]
                        new_t = t
                        for p = 1:length(path)-1
                            new_t = new_t + TT(distmx[path[p],path[p+1]], Δt, Veh_Speed)
                            push!(times, new_t)
                        end

                        push!(Route_Vec, k)
                        push!(Weights, R.dists[r])
                        push!(Route_Desc, (k, t, path, times, l))
                        push!(Route_OD, (t, t+dist, i, j) )
                        push!(Depart[t][i], k)
                        push!(Arrival[t+dist][j], k)
                        push!(ODT[t][i][j], k)

                
                        ID = k
                        ID_Routes[string(ID)] = string.(path)
                        ID_Len[string(ID)] = R.dists[r]/1000

                        k = k + 1
                    end
                end

                East_Corridors = []
                West_Corridors = []
              
                for c = 1:length(Corridors)

                    if length(path) <= 1
                        continue
                    end

                    for p = 1:(length(path)-1)
                        if ((path[p],path[p+1]) == Corridors[c]) || ((path[p+1],path[p]) == Corridors[c])
                            
                            if p > 1
                                c_dist = sum(TT(distmx[path[i],path[i+1]], Δt, Veh_Speed) for i = 1:(p-1))
                            else
                                c_dist = 0
                            end
                            
                            if path[p] >= path[p+1]
                                
                                push!(East_Corridors, (c, c_dist))
                                
                            else
                                
                                push!(West_Corridors, (c, c_dist))
        
                            end
        
                        end
                    end   

                end


                for t = 1:(Time_Nodes+Buffer)
                    for l ∈ Lane_Set

                        if t + dist > (Time_Nodes+Buffer)
                            continue
                        end

                        route_east = []
                        route_west = []                      

                        for (c, c_dist) ∈ East_Corridors

                            node = Corridors[c][1]

                            push!(East_Set[t+c_dist][c][l], k_start)
                            push!(route_east, (t+c_dist, c, l) )
                        end

                        for (c, c_dist) ∈ West_Corridors

                            node = Corridors[c][2]

                            push!(West_Set[t+c_dist][c][l], k_start)
                            push!(route_west, (t+c_dist, c, l) )
                        end

                        push!(Corridor_East, route_east )
                        push!(Corridor_West, route_west )

                        k_start = k_start + 1
                    end
                end

            end
        end
    end
    Routes_Closed = unique(Routes_Closed)
    Num_Routes_Closed = length(Routes_Closed)
    print("Found all the routes in the network \n")
    print("$Num_Routes_Closed Number of Routes Closed Due to Weather\n")

    Route_Prob_Set = []

    Num_Nodes = nv(g)
    open_prob_mx = []

    return Num_Corridors, Num_Lanes, Route_Vec, Route_Desc, ID_Routes, ID_Len, Depart, Arrival, ODT, East_Set, West_Set, Clear_Times, Node_Neighbor, Corridors, C_dist, Node_Dir, Node_List, Weights, distmx, pathmx, Corridor_East, Corridor_West, Route_OD, Corridor_Mat, δe_in, δw_in, δe_out, δw_out, Corridor_Dist, Num_Edges, open_prob_mx, Route_Prob_Set, Routes_Closed, Num_Nodes

end