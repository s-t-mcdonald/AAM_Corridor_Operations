# Module Outer_Model
#
# Returns the full optimization model, including the corridor direction constraints
#
# Author: Spencer McDonald
# MIT - ORC UAM Study
# email: mcdonst@mit.edu
# Website: https://www.spencertmcdonald.com/
# Mar 2021; Last revision: 13-Jan-2021

module Outer_Model

    include("TT.jl")
    include("Base_Model.jl")

    using JuMP, Gurobi, DataFrames, Graphs, FileIO

    using .Base_Model

    export Return_Direct_Model_Corridor, Return_Direct_Model_SS_Lazy, Return_Direct_Model_SS_LazyOD

    const GRB_ENV = Gurobi.Env()


    ## Return the Stable Set RMP ##
    function Return_Direct_Model_Corridor(Data)

        Time_Nodes = Data.Time_Nodes
        Lane_Set = Data.Lane_Set
        Veh_Thru = Data.Veh_Thru
        Buffer = Data.Buffer
        Δt = Data.Δt
        Veh_Speed = Data.Veh_Speed
        Corridor_Set = Data.Corridor_Set
        
    
        Model = Gen_Base_Pass_Model(Data)

        BM = Model["Model"]
        R = Model["R"]
        
        @variable(BM, CLE[i = 1:Time_Nodes+Buffer, l = 1:size(Lane_Set,2), c = 1:size(Lane_Set,1)], Bin)
        @variable(BM, CLW[i = 1:Time_Nodes+Buffer, l = 1:size(Lane_Set,2), c = 1:size(Lane_Set,1)], Bin)
        
        
        @constraint(BM, [i = 1:Time_Nodes+Buffer, l = 1:size(Lane_Set,2), c = 1:size(Lane_Set,1)], CLE[i,l,c] + CLW[i,l,c] <= 1)
        

        Num_Corridors = size(Lane_Set,1)
        
        T_set = []
        for c = 1:Num_Corridors

            if Corridor_Set[c] == []
                continue
            end

            c_dist = Corridor_Set[c][1][2]
            Clear_Time = TT(c_dist, Δt, Veh_Speed)

            for l = 1:size(Lane_Set,2)
                for i = 1:Time_Nodes+Buffer
            
                    for j = 1:Clear_Time
                        if i-j < 1
                            continue
                        end
                        push!(T_set, (i-j, i, l, c))
                        push!(T_set, (i-j, i, l, c))
                    end

                end
            end
        end

        T_set = unique(T_set)
 

        @constraint(BM, [i = 1:Time_Nodes+Buffer, c = 1:Num_Corridors, l = 1:size(Lane_Set,2), (r1, dist) = Lane_Set[c,l,1]], R[i-TT(dist, Δt, Veh_Speed),r1] <= Veh_Thru*CLE[i,l,c])
        @constraint(BM, [i = 1:Time_Nodes+Buffer, c = 1:Num_Corridors, l = 1:size(Lane_Set,2), (r2, dist) = Lane_Set[c,l,2]], R[i-TT(dist, Δt, Veh_Speed),r2] <= Veh_Thru*CLW[i,l,c])


        @constraint(BM, [i = 1:length(T_set)], CLW[T_set[i][1], T_set[i][3], T_set[i][4]] + CLE[T_set[i][2], T_set[i][3], T_set[i][4]] <= 1)
        @constraint(BM, [i = 1:length(T_set)], CLE[T_set[i][1], T_set[i][3], T_set[i][4]] + CLW[T_set[i][2], T_set[i][3], T_set[i][4]] <= 1)

        
        print("\n----------Finished Constructing Model----------\n")

        
        return Model
        
    end


    function Return_Direct_Model_SS_Lazy(Data)

        Time_Nodes = Data.Time_Nodes
        Veh_Thru = Data.Veh_Thru
        Buffer = Data.Buffer
        Gr = Data.Gr
        Route_Vec = Data.Route_Vec
        ClearTimes = Data.ClearTimes
        Route_Vec_Simple = Data.Route_Vec_Simple        
        Route_Lanes = Data.Route_Lanes
        

        model = Gen_Base_Pass_Model(Data)

        BM = model["Model"]
        R = model["R"]

        Num_Routes = length(Route_Vec)


        @variable(BM, Xr[i = 1:Time_Nodes+Buffer, r = 1:Num_Routes], Bin, start = 0)
        @constraint(BM, Route_Avail[i = 1:Time_Nodes+Buffer, r = 1:Num_Routes], R[i,r] <= Veh_Thru*Xr[i,r])
        @constraint(BM, Route_Avail_Inv[i = 1:Time_Nodes+Buffer, r = 1:Num_Routes], Xr[i,r] <= R[i,r])

        function my_callback_function(cb_data)
    
            Xr_val = zeros(Time_Nodes+Buffer, Num_Routes)

            for i = 1:Time_Nodes+Buffer, r = 1:Num_Routes
                Xr_val[i, r] = callback_value(cb_data, Xr[i, r])
            end


            Pos_Array = findall(x -> x > 0.001, Xr_val)
       
            for ind1 = 1:length(Pos_Array)-1, ind2 = ind1:length(Pos_Array)
                if Xr_val[Pos_Array[ind1]] + Xr_val[Pos_Array[ind2]] > 1.001

                    (t1, r1) = (Pos_Array[ind1][1], Pos_Array[ind1][2])
                    (t2, r2) = (Pos_Array[ind2][1], Pos_Array[ind2][2])

                    (_, _, l1) = Route_Lanes[r1]
                    (_, _, l2) = Route_Lanes[r2]

                    r1_eff = Route_Vec_Simple[r1]
                    r2_eff = Route_Vec_Simple[r2]

                    if (t1 - t2 ∈ ClearTimes[r1_eff][r2_eff]) & (l1 == l2) & has_edge(Gr, r1_eff, r2_eff)

                        con = @build_constraint(Xr[t1,r1] + Xr[t2,r2] <=1)
                        MOI.submit(BM, MOI.LazyConstraint(cb_data), con)

                    end
                end
            end

        end
        MOI.set(BM, MOI.LazyConstraintCallback(), my_callback_function)


        print("\n----------Finished Constructing Model----------\n")


        return model
        
    end


    function Return_Direct_Model_SS_LazyOD(Data)

        Time_Nodes = Data.Time_Nodes
        Veh_Thru = Data.Veh_Thru
        Buffer = Data.Buffer
        Gr = Data.Gr
        Route_Vec = Data.Route_Vec
        Route_Set = Data.Route_Set
        ClearTimes = Data.ClearTimes
        Route_Vec_Simple = Data.Route_Vec_Simple        
        Route_Lanes = Data.Route_Lanes


        model = Gen_Base_Pass_Model(Data)

        BM = model["Model"]
        R = model["R"]

        Num_Routes = length(Route_Vec)

        @variable(BM, Xr[i = 1:Time_Nodes+Buffer, r = 1:Num_Routes], Bin, start = 0)
        @constraint(BM, Route_Avail[i = 1:Time_Nodes+Buffer, r = 1:Num_Routes], R[i,r] <= Veh_Thru*Xr[i,r])
        @constraint(BM, Route_Avail_Inv[i = 1:Time_Nodes+Buffer, r = 1:Num_Routes], Xr[i,r] <= R[i,r])

        function my_callback_function(cb_data)
    
            Xr_val = zeros(Time_Nodes+Buffer, Num_Routes)

            for i = 1:Time_Nodes+Buffer, r = 1:Num_Routes
                Xr_val[i, r] = callback_value(cb_data, Xr[i, r])
            end


            Pos_Array = findall(x -> x > 0.001, Xr_val)
   
            ODT = []
            for ind1 = 1:length(Pos_Array)-1, ind2 = ind1:length(Pos_Array)
                if Xr_val[Pos_Array[ind1]] + Xr_val[Pos_Array[ind2]] > 1.001

                    (t1, r1) = (Pos_Array[ind1][1], Pos_Array[ind1][2])
                    (t2, r2) = (Pos_Array[ind2][1], Pos_Array[ind2][2])

                    (_, _, l1) = Route_Lanes[r1]
                    (_, _, l2) = Route_Lanes[r2]

                    r1_eff = Route_Vec_Simple[r1]
                    r2_eff = Route_Vec_Simple[r2]

                    if (t1 - t2 ∈ ClearTimes[r1_eff][r2_eff]) & (l1 == l2) & has_edge(Gr, r1_eff, r2_eff)

                        Org1 = Route_Vec[r1][1][1]
                        Dst1 = Route_Vec[r1][1][end]

                        Org2 = Route_Vec[r2][1][1]
                        Dst2 = Route_Vec[r2][1][end]

                        if (Org1, Dst1, t1, Org2, Dst2, t2) ∉ ODT
                            push!(ODT, (Org1, Dst1, t1, Org2, Dst2, t2))                                 
                        end
        
                    end

                end
            end

            for (Org1, Dst1, t1, Org2, Dst2, t2) ∈ ODT

                
                for (r1, dist1) ∈ Route_Set[Org1, Dst1], (r2, dist2) ∈ Route_Set[Org2, Dst2]

                    (_, _, l1) = Route_Lanes[r1]
                    (_, _, l2) = Route_Lanes[r2]

                    r1_eff = Route_Vec_Simple[r1]
                    r2_eff = Route_Vec_Simple[r2]

                    if has_edge(Gr, r1_eff, r2_eff) & (l1 == l2)
                
                        for δt ∈ ClearTimes[r1_eff][r2_eff]
                            
                            if (t1-δt > Time_Nodes+Buffer) | (t1-δt < 1)
                                continue
                            end
                        
                            con = @build_constraint(Xr[t1,r1] + Xr[t1-δt,r2] <=1)
                            MOI.submit(BM, MOI.LazyConstraint(cb_data), con)
                          
                        end

                        for δt ∈ ClearTimes[r2_eff][r1_eff]
                        
                            if (t2-δt > Time_Nodes+Buffer) | (t2-δt < 1)
                                continue
                            end
                            con = @build_constraint(Xr[t2,r2] + Xr[t2-δt,r1] <=1)
                            MOI.submit(BM, MOI.LazyConstraint(cb_data), con)
                        
                        end

                    end

                end
            end

        end
        MOI.set(BM, MOI.LazyConstraintCallback(), my_callback_function)


        print("\n----------Finished Constructing Model----------\n")

        
        return model
        
    end



end