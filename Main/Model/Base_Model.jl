# Module Base_Model
#
# Returns the base optimization model used for optimizing the schedule 
#
# Author: Spencer McDonald
# MIT - ORC UAM Study
# email: mcdonst@mit.edu
# Website: https://www.spencertmcdonald.com/
# Mar 2021; Last revision: 1-Jan-2021


module Base_Model

    include("TT.jl")

    using JuMP, Gurobi, DataFrames, Graphs

    export Gen_Model_SS, Gen_CF_Model_SS, Gen_Model_SS_Fidelity

    const GRB_ENV = Gurobi.Env()

    function Gen_Model_SS(Data, Fix_Dir)

        ## Optimization Parameters ##
        Margin = Data.Margin

        ## Network Data ##
        Num_Vertiports = Data.Num_Vertiports #number of vertiports
        Num_Corridors = Data.Num_Corridors
        Num_Lanes = Data.Num_Lanes
        Route_Vec = Data.Route_Vec
        Depart = Data.Depart
        Arrival = Data.Arrival
        ODT = Data.ODT
        East_Set = Data.East_Set
        West_Set = Data.West_Set
        Clear_Times = Data.Clear_Times
        Weights = Data.Weights
        Network = Data.Network
        
        ## Time Data ##
        Time_Nodes = Data.Time_Nodes #number of discretized time nodes
        Δt = Data.Δt #Time Discretization
        Buffer = Data.Buffer #Buffer for boundary conditions

        ## Vertiport Data ##
        Num_Veh = Data.Num_Veh #number of vehicles
        Parking_Cap = Data.Parking_Cap #maximum number of vehicles at a specific vertiport
        Operational_Cap = Data.Operational_Cap
        TaT = Data.TaT #turn around time (time nodes)
        
        ## Inputs ##
        Demand_Requests = Data.Demand_Requests
        Demand_Revenues = Data.Demand_Revenues
        Num_Requests = length(Demand_Requests)
        Wait_Times = Data.Wait_Times
        Con_List = Data.Con_List
        Dem_List = Data.Dem_List

        δe_in = Data.δe_in
        δe_out = Data.δe_out
        δw_out = Data.δw_out

        N_nodes = length(δe_in)

        print("---------------------Starting to Construct the Model-----------------\n")

        # define main problem
        BM =  Model(() -> Gurobi.Optimizer(GRB_ENV))
  
        # Vehicle Flow Network (VFN)
        @variable(BM, A[t = 1:Time_Nodes+Buffer, i = 1:Num_Vertiports] >= 0) # Begin Idle Arc
        @variable(BM, I[t = 0:Time_Nodes+Buffer, i = 1:Num_Vertiports] >= 0) # Idle Arc
        @variable(BM, R[n = 1:length(Route_Vec)] >= 0) # Route Arc
        @variable(BM, E[t = 1:Time_Nodes+Buffer, c = 1:Num_Corridors, l = 1:Num_Lanes] >= 0) # Route Arc
        @variable(BM, W[t = 1:Time_Nodes+Buffer, c = 1:Num_Corridors, l = 1:Num_Lanes] >= 0) # Route Arc
        @variable(BM, e[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes] >= 0) # Route Arc
        @variable(BM, w[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes] >= 0) # Route Arc

        # Passenger Flow Network (PFN)
        @variable(BM, TD[n = 1:Num_Requests, k = 1:Wait_Times[n]] >= 0) # Transport Demand Arc
        @variable(BM, RD[n = 1:Num_Requests] >= 0)
    
        # Standby Node - Flow Constraints
        @constraint(BM, λ[t = 1:Time_Nodes+Buffer, i = 1:Num_Vertiports],
            return_var(Data, A, t - TaT, [t-TaT,i]) + I[t-1,i] - I[t,i] - sum(R[n] for n in Depart[t][i]) == 0)

        # Arrival Node - Flow Constraints
        @constraint(BM, κ[t = 1:Time_Nodes+Buffer, i = 1:Num_Vertiports],
            sum(R[n] for n in Arrival[t][i]) - A[t,i] == 0)
    
        # Parking Capacity
        @constraint(BM, α[t = 0:Time_Nodes+Buffer, i = 1:Num_Vertiports],
            -I[t,i] - sum(return_var(Data, A, t-k, [t-k,i]) for k = 0:(TaT-1)) >= -Parking_Cap)

        # Arrival and Departure Capacity
        @constraint(BM, β[t = 1:Time_Nodes+Buffer, i = 1:Num_Vertiports],
            -A[t,i] - sum(R[n] for n in Depart[t][i]) >= -Operational_Cap*Δt )

        # Conjuction Capacity
        @constraint(BM, Φ_e[t = 1:Time_Nodes+Buffer, c = 1:Num_Corridors, l = 1:Num_Lanes],
            E[t,c,l] - sum(R[n] for n ∈ East_Set[t][c][l]) >= 0 )
        @constraint(BM, Φ_w[t = 1:Time_Nodes+Buffer, c = 1:Num_Corridors, l = 1:Num_Lanes],
            W[t,c,l] - sum(R[n] for n ∈ West_Set[t][c][l]) >= 0 )

        if Fix_Dir > 0.5
            @constraint(BM, [c = 1:Num_Corridors, t = 2:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes], e[c,t,l] == e[c,1,l])
            @constraint(BM, [c = 1:Num_Corridors, t = 2:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes], w[c,t,l] == w[c,1,l])
        end

        # Conjuction Capacity
        @constraint(BM, ToDeleteEast[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes, k = ((t-1)*Clear_Times[c]+1):minimum([(t*Clear_Times[c]),Time_Nodes+Buffer])],
            e[c,t,l] - E[k,c,l] >= 0 )
        @constraint(BM, ToDeleteWest[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes, k = ((t-1)*Clear_Times[c]+1):minimum([(t*Clear_Times[c]),Time_Nodes+Buffer])],
            w[c,t,l] - W[k,c,l] >= 0 )

        # Conjuction Capacity
        if Network != "Direct_Network"
            @constraint(BM, Φ[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c])-1, l = 1:Num_Lanes],
                e[c,t+1,l] + w[c,t,l] <= 1 )     
                
            @constraint(BM, Φ1[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c])-1, l = 1:Num_Lanes],
                e[c,t,l] + w[c,t+1,l] <= 1 )  
                
            @constraint(BM, Φ2[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes],
                e[c,t,l] + w[c,t,l] <= 1 )  

            @constraint(BM, Conjuc[t = 1:Time_Nodes+Buffer, n = 1:N_nodes, l = 1:Num_Lanes],
                sum(E[t,c,l] for (c,dist) ∈ δe_out[n]) + sum(W[t,c,l] for (c,dist) ∈ δw_out[n]) <= 1)
        end

        # Passenger Demand Node - Flow Constraints
        @constraint(BM, [n = 1:Num_Requests],
            RD[n] + sum(TD[n,k] for k = 1:Wait_Times[n]) == 1)

        # Passenger Capicity
        @constraint(BM, γ[z = 1:length(Con_List)],
            sum(R[n] for n in ODT[Con_List[z][1]][Con_List[z][2]][Con_List[z][3]])
            -sum(TD[n,k] for (n,k) ∈ Dem_List[z]) >= 0 )
        
        # Boundary Conditions
        @constraint(BM, η[t = [0, Time_Nodes+Buffer], i = 1:Num_Vertiports], I[t,i]== Num_Veh)
            
        # Objective Function
        @objective(BM, Min, sum((Margin)*Demand_Revenues[n]*RD[n] for n = 1:Num_Requests) + sum(Weights[n]*R[n] for n = 1:length(Route_Vec)) );

        print("---------------------Finished to Construct the Model-----------------\n")
        
        RMP = Dict("Model" => BM, "A" => A, "I" => I, "R" => R, "TD" => TD, "RD" => RD, "λ" => λ, "κ" => κ, "δ" => δ, 
                        "γ" => γ, "α" => α, "β" => β, "e" => e, "w" => w, "E" => E, "W" => W, "ToDeleteEast" => ToDeleteEast, "ToDeleteWest" => ToDeleteWest,
                        "Φ_e" => Φ_e, "Φ_w" => Φ_w, "η" => η)

        if Network != "Direct_Network"
            RMP["Conjuc"] = Conjuc
            RMP["Φ"] = Φ
            RMP["Φ1"] = Φ1
            RMP["Φ2"] = Φ2
        end

        return RMP

    end

    function Gen_CF_Model_SS(Data)

        ## Optimization Parameters ##
        Margin = Data.Margin

        ## Network Data ##
        Num_Vertiports = Data.Num_Vertiports #number of vertiports
        Num_Corridors = Data.Num_Corridors
        Num_Lanes = Data.Num_Lanes
        Clear_Times = Data.Clear_Times
        Network = Data.Network
        Corridor_Dist = Data.Corridor_Dist
        
        ## Time Data ##
        Time_Nodes = Data.Time_Nodes #number of discretized time nodes
        Δt = Data.Δt #Time Discretization
        Buffer = Data.Buffer #Buffer for boundary conditions

        ## Vehicle Data ##
        Veh_Speed = Data.Veh_Speed #Speed of the vehicle

        ## Vertiport Data ##
        Num_Veh = Data.Num_Veh #number of vehicles
        Parking_Cap = Data.Parking_Cap #maximum number of vehicles at a specific vertiport
        Operational_Cap = Data.Operational_Cap
        TaT = Data.TaT #turn around time (time nodes)
        
        ## Inputs ##
        Demand_Requests = Data.Demand_Requests
        Demand_Revenues = Data.Demand_Revenues
        Num_Requests = length(Demand_Requests)
        Wait_Times = Data.Wait_Times
        Con_List = Data.Con_List
        Dem_List = Data.Dem_List

        δe_in = Data.δe_in
        δw_in = Data.δw_in
        δe_out = Data.δe_out
        δw_out = Data.δw_out

        N_nodes = length(δe_in)

        # define main problem
        BM =  Model(() -> Gurobi.Optimizer(GRB_ENV))

        # Vehicle Flow Network (VFN)
        @variable(BM, A[t = 1:Time_Nodes+Buffer, j = 1:Num_Vertiports, l = 1:Num_Lanes] >= 0) # Begin Idle Arc
        @variable(BM, I[t = 0:Time_Nodes+Buffer, i = 1:Num_Vertiports] >= 0) # Idle Arc

        @variable(BM, D[t = 1:Time_Nodes+Buffer, i = 1:Num_Vertiports, j = 1:Num_Vertiports, l = 1:Num_Lanes] >= 0) # Route Arc

        @variable(BM, 1 >= E[t = 1:Time_Nodes+Buffer, j = 1:Num_Vertiports, c = 1:Num_Corridors, l = 1:Num_Lanes] >= 0) # Route Arc
        @variable(BM, 1 >= W[t = 1:Time_Nodes+Buffer, j = 1:Num_Vertiports, c = 1:Num_Corridors, l = 1:Num_Lanes] >= 0) # Route Arc
        @variable(BM, e[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes] >= 0) # Route Arc
        @variable(BM, w[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes] >= 0) # Route Arc
    
        # Passenger Flow Network (PFN)
        @variable(BM, 1 >= TD[n = 1:Num_Requests, k = 1:Wait_Times[n]] >= 0) # Transport Demand Arc
        @variable(BM, RD[n = 1:Num_Requests] >= 0)
    
        # Standby Node - Flow Constraints
        @constraint(BM, Standby_Node[t = 1:Time_Nodes+Buffer, i = 1:Num_Vertiports],
                    sum(return_var(Data, A, t - TaT, [t - TaT,i,l]) for l = 1:Num_Lanes) + I[t-1,i] - I[t,i] - sum(D[t,i,j,l] for j = 1:Num_Vertiports, l = 1:Num_Lanes) == 0)

        # Conjuction Nodes - Flow Constraints
        @constraint(BM, Conjuction_Nodes_Vertiport[t = 1:Time_Nodes+Buffer, i = 1:Num_Vertiports, j = 1:Num_Vertiports, l = 1:Num_Lanes],
            D[t,i,j,l] + sum(return_var(Data, E, t-TT(dist, Δt, Veh_Speed), [t-TT(dist, Δt, Veh_Speed),j,c,l]) - return_var(Data, W, t, [t,j,c,l]) for (c, dist) ∈ δe_in[i]) +
            sum(return_var(Data, W, t-TT(dist, Δt, Veh_Speed), [t-TT(dist, Δt, Veh_Speed),j,c,l]) - return_var(Data, E, t, [t,j,c,l]) for (c, dist) ∈ δw_in[i]) - return_var_A(Data, A, t, i, j, l) == 0)

        # Conjuction Nodes - Flow Constraints
        @constraint(BM, Conjuction_Nodes[t = 1:Time_Nodes+Buffer, j = 1:Num_Vertiports, n = Num_Vertiports+1:length(δe_in), l = 1:Num_Lanes],
            sum(return_var(Data, E, t-TT(dist, Δt, Veh_Speed), [t-TT(dist, Δt, Veh_Speed),j,c,l]) - return_var(Data, W, t, [t,j,c,l]) for (c, dist) ∈ δe_in[n]) +
            sum(return_var(Data, W, t-TT(dist, Δt, Veh_Speed), [t-TT(dist, Δt, Veh_Speed),j,c,l]) - return_var(Data, E, t, [t,j,c,l]) for (c, dist) ∈ δw_in[n]) == 0)
        
        # Parking Capacity
        @constraint(BM, Parking_Cap_Con[t = 1:Time_Nodes+Buffer, i = 1:Num_Vertiports],
            -sum(return_var(Data, A, t-k, [t-k,i,l]) for k = 0:(TaT-1), l = 1:Num_Lanes) -  I[t,i] >= -Parking_Cap)
            
        # Arrival and Departure Capacity
        @constraint(BM, β[t = 1:Time_Nodes+Buffer, i = 1:Num_Vertiports],
                    -sum(A[t,i,l] for l = 1:Num_Lanes) - sum(D[t,i,j,l] for j = 1:Num_Vertiports, l = 1:Num_Lanes) >= -Operational_Cap)
        
       # Conjuction Capacity
       @constraint(BM, ToDeleteEast[c = 1:Num_Corridors, j = 1:Num_Vertiports, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes, k = ((t-1)*Clear_Times[c]+1):minimum([(t*Clear_Times[c]),Time_Nodes+Buffer])],
           e[c,t,l] - E[k,j,c,l] >= 0 )
       @constraint(BM, ToDeleteWest[c = 1:Num_Corridors, j = 1:Num_Vertiports, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes, k = ((t-1)*Clear_Times[c]+1):minimum([(t*Clear_Times[c]),Time_Nodes+Buffer])],
           w[c,t,l] - W[k,j,c,l] >= 0 )

       # Conjuction Capacity
       if Network != "Direct_Network"
           @constraint(BM, Φ[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c])-1, l = 1:Num_Lanes],
               -e[c,t+1,l] - w[c,t,l] >= -1 )     
               
           @constraint(BM, Φ1[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c])-1, l = 1:Num_Lanes],
               -e[c,t,l] - w[c,t+1,l] >= -1 )  
               
           @constraint(BM, Φ2[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes],
               -e[c,t,l] - w[c,t,l] >= -1 )  

           @constraint(BM, Conjuc[t = 1:Time_Nodes+Buffer, n = 1:N_nodes, l = 1:Num_Lanes],
               sum(E[t,j,c,l] for j = 1:Num_Vertiports, (c,dist) ∈ δe_out[n]) + sum(W[t,j,c,l] for j = 1:Num_Vertiports, (c,dist) ∈ δw_out[n]) <= 1)
       end

        # Passenger Demand Node - Flow Constraints
        @constraint(BM, [n = 1:Num_Requests],
            RD[n] + sum(TD[n,k] for k = 1:Wait_Times[n]) == 1)

        # Passenger Capicity
        @constraint(BM, γ[z = 1:length(Con_List)],
            sum(D[Con_List[z][1],Con_List[z][2],Con_List[z][3],l] for l = 1:Num_Lanes) - sum(TD[n,k] for (n,k) ∈ Dem_List[z]) >= 0 )
        
        # Boundary Conditions
        @constraint(BM, η[t = [0, Time_Nodes+Buffer], i = 1:Num_Vertiports], I[t,i] == Num_Veh)
            
        # Objective Function
        @objective(BM, Min, sum((Margin)*Demand_Revenues[n]*RD[n] for n = 1:Num_Requests) + sum(Corridor_Dist[c]*(E[t,j,c,l] + W[t,j,c,l]) for t = 1:Time_Nodes+Buffer, j = 1:Num_Vertiports, c = 1:Num_Corridors, l = 1:Num_Lanes) );

        print("Finished Constructing the Model")
        BM = Dict("Model" => BM, "A" => A, "I" => I, "E" => W, "W" => W, "TD" => TD)

        return BM

    end


    function Gen_Model_SS_Fidelity(Data, num)

        ## Optimization Parameters ##
        Margin = Data.Margin

        ## Network Data ##
        Num_Vertiports = Data.Num_Vertiports #number of vertiports
        Num_Corridors = Data.Num_Corridors
        Num_Lanes = Data.Num_Lanes
        Route_Vec = Data.Route_Vec
        Depart = Data.Depart
        Arrival = Data.Arrival
        ODT = Data.ODT
        East_Set = Data.East_Set
        West_Set = Data.West_Set
        Clear_Times = Data.Clear_Times
        Weights = Data.Weights

        ## Time Data ##
        Time_Nodes = Data.Time_Nodes #number of discretized time nodes
        Δt = Data.Δt #Time Discretization
        Buffer = Data.Buffer #Buffer for boundary conditions

        ## Vertiport Data ##
        Num_Veh = Data.Num_Veh #number of vehicles
        Parking_Cap = Data.Parking_Cap #maximum number of vehicles at a specific vertiport
        Operational_Cap = Data.Operational_Cap
        TaT = Data.TaT #turn around time (time nodes)

        ## Inputs ##
        Demand_Requests = Data.Demand_Requests
        Demand_Revenues = Data.Demand_Revenues
        Num_Requests = length(Demand_Requests)
        Wait_Times = Data.Wait_Times
        Con_List = Data.Con_List
        Dem_List = Data.Dem_List
        δe_in = Data.δe_in
        δe_out = Data.δe_out
        δw_out = Data.δw_out

        N_nodes = length(δe_in)

        print("---------------------Starting to Construct the Model-----------------\n")

        # define main problem
        BM =  Model(() -> Gurobi.Optimizer(GRB_ENV))
  
        # Vehicle Flow Network (VFN)
        @variable(BM, A[t = 1:Time_Nodes+Buffer, i = 1:Num_Vertiports] >= 0) # Begin Idle Arc
        @variable(BM, I[t = 0:Time_Nodes+Buffer, i = 1:Num_Vertiports] >= 0) # Idle Arc
        @variable(BM, R[n = 1:length(Route_Vec)] >= 0) # Route Arc
        @variable(BM, E[t = 1:Time_Nodes+Buffer, c = 1:Num_Corridors, l = 1:Num_Lanes] >= 0) # Route Arc
        @variable(BM, W[t = 1:Time_Nodes+Buffer, c = 1:Num_Corridors, l = 1:Num_Lanes] >= 0) # Route Arc
        @variable(BM, e[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes] >= 0) # Route Arc
        @variable(BM, w[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes] >= 0) # Route Arc

        # Passenger Flow Network (PFN)
        @variable(BM, TD[n = 1:Num_Requests, k = 1:Wait_Times[n]] >= 0) # Transport Demand Arc
        @variable(BM, RD[n = 1:Num_Requests] >= 0)
    
        # Standby Node - Flow Constraints
        @constraint(BM, λ[t = 1:Time_Nodes+Buffer, i = 1:Num_Vertiports],
            return_var(Data, A, t - TaT, [t-TaT,i]) + I[t-1,i] - I[t,i] - sum(R[n] for n in Depart[t][i]) == 0)

        # Arrival Node - Flow Constraints
        @constraint(BM, κ[t = 1:Time_Nodes+Buffer, i = 1:Num_Vertiports],
            sum(R[n] for n in Arrival[t][i]) - A[t,i] == 0)
    
        # Parking Capacity
        if num < 3.5
            @constraint(BM, α[t = 0:Time_Nodes+Buffer, i = 1:Num_Vertiports],
                -I[t,i] - sum(return_var(Data, A, t-k, [t-k,i]) for k = 0:(TaT-1)) >= -Parking_Cap)
        end 
        # Arrival and Departure Capacity
        if num < 2.5
            @constraint(BM, β[t = 1:Time_Nodes+Buffer, i = 1:Num_Vertiports],
                -A[t,i] - sum(R[n] for n in Depart[t][i]) >= -1 )
        end
        # Conjuction Capacity
        @constraint(BM, Φ_e[t = 1:Time_Nodes+Buffer, c = 1:Num_Corridors, l = 1:Num_Lanes],
            E[t,c,l] - sum(R[n] for n ∈ East_Set[t][c][l]) >= 0 )
        @constraint(BM, Φ_w[t = 1:Time_Nodes+Buffer, c = 1:Num_Corridors, l = 1:Num_Lanes],
            W[t,c,l] - sum(R[n] for n ∈ West_Set[t][c][l]) >= 0 )

        # Conjuction Capacity
        @constraint(BM, ToDeleteEast[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes, k = ((t-1)*Clear_Times[c]+1):minimum([(t*Clear_Times[c]),Time_Nodes+Buffer])],
            e[c,t,l] - E[k,c,l] >= 0 )
        @constraint(BM, ToDeleteWest[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes, k = ((t-1)*Clear_Times[c]+1):minimum([(t*Clear_Times[c]),Time_Nodes+Buffer])],
            w[c,t,l] - W[k,c,l] >= 0 )

        # Conjuction Capacity

        if num < 0.5
            @constraint(BM, Φ[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c])-1, l = 1:Num_Lanes],
                e[c,t+1,l] + w[c,t,l] <= 1 )     
                
            @constraint(BM, Φ1[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c])-1, l = 1:Num_Lanes],
                e[c,t,l] + w[c,t+1,l] <= 1 )  
                
            @constraint(BM, Φ2[c = 1:Num_Corridors, t = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]), l = 1:Num_Lanes],
                e[c,t,l] + w[c,t,l] <= 1 )  
        end

        if num < 1.5
            @constraint(BM, Conjuc[t = 1:Time_Nodes+Buffer, n = 1:N_nodes, l = 1:Num_Lanes],
                sum(E[t,c,l] for (c,dist) ∈ δe_out[n]) + sum(W[t,c,l] for (c,dist) ∈ δw_out[n]) <= 1)
        end 

        # Passenger Demand Node - Flow Constraints
        @constraint(BM, [n = 1:Num_Requests],
            RD[n] + sum(TD[n,k] for k = 1:Wait_Times[n]) == 1)

        # Passenger Capicity
        @constraint(BM, γ[z = 1:length(Con_List)],
            sum(R[n] for n in ODT[Con_List[z][1]][Con_List[z][2]][Con_List[z][3]])
            -sum(TD[n,k] for (n,k) ∈ Dem_List[z]) >= 0 )
        
        # Boundary Conditions
        if num < 4.5
            @constraint(BM, η[t = [0, Time_Nodes+Buffer], i = 1:Num_Vertiports], I[t,i]== Num_Veh)
        end
        # Objective Function
        @objective(BM, Min, sum((Margin)*Demand_Revenues[n]*RD[n] for n = 1:Num_Requests) + sum(Weights[n]*R[n] for n = 1:length(Route_Vec)) );

        print("---------------------Finished to Construct the Model-----------------\n")
        
        RMP = Dict("Model" => BM, "A" => A, "I" => I, "R" => R, "TD" => TD, "RD" => RD, "e" => e, "w" => w, "E" => E, "W" => W)

        return RMP

    end



    function return_var(Data, var, t, index)

        Time_Nodes = Data.Time_Nodes
        Buffer = Data.Buffer
        
        if t < 1
            ans = 0
        elseif t > Time_Nodes+Buffer
            ans = 0
        else
            ans = var[index...]
        end
        
        return ans
    end

    function return_var_A(Data, var, t, i, j, l)

        Time_Nodes = Data.Time_Nodes
        Buffer = Data.Buffer
        
        if t < 1
            ans = 0
        elseif t > Time_Nodes+Buffer
            ans = 0
        elseif i != j
            ans = 0
        else
            ans = var[t,i,l]
        end
        
        return ans
    end

end
