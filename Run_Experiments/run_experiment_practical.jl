using TOML, Gurobi, CSV, JuMP, Dates, Graphs, Base.Threads, Random, JSON   

include("../Main/Model/pricing_problem.jl")
include("../Main/Model/Update_Weather.jl")


function run_rmp_cg_model(Data, cg_df, pp_algo, Demand_df, a, weather_closures_pred, weather_closures_truth, weather_scen, weather_cutoff, Fix_Dir)

    Time_Limit  = Data.Time_Limit#Time limit for optimization model (s)
    Optimality_Gap = Data.Optimality_Gap #Optimality gap that will stop optmization (%)
    open_prob_mx = Data.open_prob_mx
    Demand_Requests = Data.Demand_Requests
    Route_Desc = Data.Route_Desc
    Con_List = Data.Con_List
    ODT = Data.ODT
    Dem_List = Data.Dem_List
    Num_Requests = length(Demand_Requests)
    Demand_Requests = Data.Demand_Requests
    Dir = Data.Dir
    Margin = Data.Margin
    Wait_Times = Data.Wait_Times
    Num_Nodes = Data.Num_Nodes
    Num_Corridors = Data.Num_Corridors
    Num_Lanes = Data.Num_Lanes
    Time_Nodes = Data.Time_Nodes
    Buffer = Data.Buffer
    pathmx = Data.pathmx
    distmx = Data.distmx
    Demand_Revenues = Data.Demand_Revenues
    Clear_Times = Data.Clear_Times
    Weights = Data.Weights

    RMP = Gen_Model_SS(Data, Fix_Dir)
    rmp = RMP["Model"]
    ToDeleteWest = RMP["ToDeleteWest"]
    ToDeleteEast = RMP["ToDeleteEast"]

    if weather_cutoff > 0
        Conjuc = RMP["Conjuc"]
        
        for t = 1:Time_Nodes+Buffer, n = 1:Num_Nodes
            for l = 1:Num_Lanes
                set_normalized_rhs(Conjuc[t,n,l],round(Int, 1-weather_closures_pred[t,n]))
            end
        end
    end

    set_optimizer_attributes(rmp, "TimeLimit" => Time_Limit, "MIPGap" => Optimality_Gap, "LPWarmStart" => 1, "OutputFlag" => 0)

    print("-----------------------Finding TSG----------------------\n")
    g_l, weight_mx = construct_tsg(Data, weather_closures_pred, pp_algo, Fix_Dir)
    print("-----------------------Found TSG----------------------\n")

    D = []
    Dists = []
    New_Route_Desc = []
    iter = 1
    total_solve_time = 0
    solve = 1
    while true
        global rmp_obj, rmp_solve_time, pp_solve_time

        optimize!(rmp)
        rmp_obj = objective_value(rmp)
        rmp_solve_time = solve_time(rmp)

        R_val = value.(RMP["R"])
        R_cost = sum([Weights[n]*R_val[n] for n = 1:length(R_val)])
        D_cost = 0
        if iter > 1
            D_val = value.(D)
            for n = 1:length(D_val)
                (k, t, path, times, l) = New_Route_Desc[n]
                D_cost = D_cost + D_val[n]*sum(distmx[path[p],path[p+1]] for p = 1:length(path)-1)
            end
        end
        TD_val = value.(RMP["TD"])

        Rev = Margin*sum([sum(Demand_Revenues[n]*TD_val[n,k] for k = 1:Wait_Times[n]) for n = 1:Num_Requests])
        Cost = R_cost + D_cost
        Profit = Rev-Cost

        print("\n------------------------------------------\n")
        print("RMP Objective: $rmp_obj | RMP Solve_Time: $rmp_solve_time")
        print("\n------------------------------------------\n")


        print("----------------------Adding Columns-------------------------\n")
        if pp_algo == "backward_one"
            D, Dists, New_Route_Desc, reduced_cost, pp_solve_time, var_added = backward_one(Data, D, Dists, New_Route_Desc, g_l, weight_mx, RMP)
        elseif pp_algo == "backward_all"
            D, Dists, New_Route_Desc, reduced_cost, pp_solve_time, var_added = backward_all(Data, D, Dists, New_Route_Desc, g_l, weight_mx, RMP)
        elseif pp_algo == "forward_one"
            D, Dists, New_Route_Desc, reduced_cost, pp_solve_time, var_added = forward_one(Data, D, Dists, New_Route_Desc, g_l, weight_mx, RMP)
        elseif pp_algo == "forward_all"
            D, Dists, New_Route_Desc, reduced_cost, pp_solve_time, var_added = backward_all(Data, D, Dists, New_Route_Desc, g_l, weight_mx, RMP)
        end
        print("----------------------Columns Added-------------------------\n")

        print("\n------------------------------------------\n")
        print("PP reduced_cost: $reduced_cost | PP Solve_Time: $pp_solve_time | Var Added: $var_added")
        print("\n------------------------------------------\n")

        push!(cg_df, [a, iter, rmp_obj, rmp_solve_time, reduced_cost, pp_solve_time, total_solve_time, var_added, Profit])

        total_solve_time = total_solve_time + pp_solve_time + rmp_solve_time

        iter = iter + 1

        if reduced_cost >= -10^-5
            break
        end

        if (iter > 10000) | (total_solve_time > Data.Time_Limit)
            solve = 0
            break
        end
        
    end

    if solve == 1
        rmp_cg_obj_relax = rmp_obj
        rmp_cg_solve_time_relax = total_solve_time
    else
        rmp_cg_solve_time_relax = -1
        rmp_cg_obj_relax = -1
    end


    print("------- Total CG Solve Time: $total_solve_time ---------\n")
    
    set_integer.(RMP["R"])
    set_integer.(D)
    set_binary.(RMP["e"])
    set_binary.(RMP["w"])
    set_binary.(RMP["TD"])


    set_optimizer_attributes(rmp, "TimeLimit" => Time_Limit, "MIPGap" => Optimality_Gap, "LPWarmStart" => 2, "DegenMoves" => 0, "OutputFlag" => 1, "Method" => 5)
    
    set_normalized_rhs.(ToDeleteWest, -10)
    set_normalized_rhs.(ToDeleteEast, -10)

    e = RMP["e"]
    w = RMP["w"]
    E = RMP["E"]
    W = RMP["W"]

    @constraint(rmp, [c = 1:Data.Num_Corridors, t = 1:ceil(Int, (Data.Time_Nodes+Data.Buffer)/Data.Clear_Times[c]), l = 1:Data.Num_Lanes],
            e[c,t,l] - sum(E[k,c,l] for k = ((t-1)*Data.Clear_Times[c]+1):minimum([(t*Data.Clear_Times[c]),Data.Time_Nodes+Data.Buffer])) >= 0)
    @constraint(rmp, [c = 1:Data.Num_Corridors, t = 1:ceil(Int, (Data.Time_Nodes+Data.Buffer)/Data.Clear_Times[c]), l = 1:Data.Num_Lanes],
            w[c,t,l] - sum(W[k,c,l] for k = ((t-1)*Data.Clear_Times[c]+1):minimum([(t*Data.Clear_Times[c]),Data.Time_Nodes+Data.Buffer])) >= 0)

    optimize!(rmp)

    if weather_cutoff > 0
        
        D_val = 1 .- round.(Int, value.(D))
        R_val = 1 .- round.(Int, value.(RMP["R"]))

        @constraint(rmp, sum(D_val[i]*D[i] for i = 1:length(D_val)) + sum(R_val[i]*RMP["R"][i] for i = 1:length(R_val)) == 0)

        for t = 1:Time_Nodes+Buffer, n = 1:Num_Nodes
            for l = 1:Num_Lanes
                set_normalized_rhs(Conjuc[t,n,l],round(Int, 1-weather_closures_truth[t,n]))
            end
        end

        optimize!(rmp)
    end

    
    try
        global rmp_cg_obj_int, rmp_cg_solve_time_int, rmp_cg_opt_gap

        rmp_cg_obj_int = objective_value(rmp)
        rmp_cg_solve_time_int = solve_time(rmp) + total_solve_time
        rmp_cg_opt_gap = relative_gap(rmp)
    catch
        global rmp_cg_obj_int, rmp_cg_solve_time_int, rmp_cg_opt_gap

        rmp_cg_obj_int = -1
        rmp_cg_solve_time_int = -1
        rmp_cg_opt_gap = -1
    end

    R = value.(RMP["R"])
    D = value.(D)
    TD = value.(RMP["TD"])
    e_val = value.(RMP["e"])
    w_val = value.(RMP["w"])

    corr_changes = zeros(Int, Num_Corridors, Num_Lanes)
    for c = 1:Num_Corridors, l = 1:Num_Lanes

        arr = zeros(ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c]))

        for i = 1:ceil(Int, (Time_Nodes+Buffer)/Clear_Times[c])
            arr[i] = e_val[c,i,l]-w_val[c,i,l]
        end

        arr = round.(Int, arr)
        changes = 0

        deleteat!(arr, findall(x->abs(x)<0.5,arr))

        for i = 2:length(arr)
            if abs(arr[i]-arr[i-1]) > 1.5
                changes = changes + 1
            end
        end

        corr_changes[c,l] = changes
    end
    total_num_corridor_changes = sum(corr_changes)

    print("Total Number Corridor Changes: $total_num_corridor_changes\n")

    Demand_Satisfied = [sum(TD[n,k] for k = 1:Wait_Times[n]) for n = 1:Num_Requests]
    Demand_df[:,"RMP_CG"] = Demand_Satisfied

    Percent_Satisfied = sum(Demand_Satisfied)/Num_Requests*100
    print("Percent of Demand Satisfied: $Percent_Satisfied\n")

    ind1 = findall(x -> x > 0.5, R)
    ind2 = findall(x -> x > 0.5, D)

    flights_df = DataFrame(param_num = Int64[], flight_num = Int64[], CG = Int64[], Transport = Int64[], Dist = Float64[], Shortest_Dist = Float64[], Lane = Int64[], Origin = Int64[], Destination = Int64[])

    route_num = 1
    Active_Routes = Dict()
    for r ∈ ind1
        (k, t, path, times, l) = Route_Desc[r]
        
        Transport = 0
        Time_Red = 0
        Prob = 0
        Flag = 0
        for z = 1:length(Con_List)
            if (r ∈ ODT[Con_List[z][1]][Con_List[z][2]][Con_List[z][3]]) 
                for (n,k) ∈ Dem_List[z]
                    if TD[n,k] > 0.5
                        Transport = 1
                        Time_Red = Demand_df[n,"Time_Red"]
                        Prob = Demand_df[n,"Prob"]
                        TD[n,k] = 0
                        Flag = 1
                        break
                    end
                end
            end
            if Flag == 1
                break
            end
        end

        Desc = Dict()
        Desc["CG"] = 0
        Desc["Index"] = k
        Desc["Depart_Time"] = t
        Desc["Path"] = path
        Desc["Times"] = times
        Desc["Lanes"] = l
        Desc["Transport"] = Transport
        Desc["Time_Red"] = Time_Red
        Desc["Prob"] = Prob
        Active_Routes[route_num] = Desc

        Org = path[1]
        Dst = path[end]

        Actual_Dist = sum(distmx[path[p],path[p+1]] for p = 1:length(path)-1)
        Shortest_Dist = pathmx[path[1], path[end]]

        push!(flights_df, [a, k, 0, Transport, Actual_Dist, Shortest_Dist, l, Org, Dst])
        route_num = route_num + 1
    end

    for r ∈ ind2
        (k, t, path, times, l) = New_Route_Desc[r]
        
        Transport = 0
        Time_Red = 0
        Prob = 0
        Flag = 0
        for z = 1:length(Con_List)
            if (r ∈ ODT[Con_List[z][1]][Con_List[z][2]][Con_List[z][3]]) 
                for (n,k) ∈ Dem_List[z]
                    if TD[n,k] > 0.5
                        Transport = 1
                        Time_Red = Demand_df[n,"Time_Red"]
                        Prob = Demand_df[n,"Prob"]
                        TD[n,k] = 0
                        Flag = 1
                        break
                    end
                end
            end
            if Flag == 1
                break
            end
        end

        Desc = Dict()
        Desc["CG"] = 1
        Desc["Index"] = k
        Desc["Depart_Time"] = t
        Desc["Path"] = path
        Desc["Times"] = times
        Desc["Lanes"] = l
        Desc["Transport"] = Transport
        Desc["Time_Red"] = Time_Red
        Desc["Prob"] = Prob
        Active_Routes[route_num] = Desc

        Org = path[1]
        Dst = path[end]

        Actual_Dist = sum(distmx[path[p],path[p+1]] for p = 1:length(path)-1)
        Shortest_Dist = pathmx[path[1], path[end]]

        push!(flights_df, [a, k, 1, Transport, Actual_Dist, Shortest_Dist, l, Org, Dst])
        route_num = route_num + 1
    end



    return cg_df, rmp_cg_obj_int, rmp_cg_solve_time_int, rmp_cg_opt_gap, rmp_cg_obj_relax, rmp_cg_solve_time_relax, Active_Routes, Demand_df, flights_df, iter, corr_changes
end



function run_experiment(Dir, experiment_type, a, time_disc, network, num_route, pp_algo, margin, num_veh, parking_cap, lane, horizon, air_speed, max_endurance, dem_per_vert_hour, dem_alpha, op_cap, tat, weather_scen, weather_cutoff, tpr, knn, pred_type, int_agg_df, Fix_Dir)

    cg_df = DataFrame(param_num = Int64[], cg_iteration = Int64[], rmp_obj = Float64[], rmp_solve_time = Float64[], reduced_cost = Float64[], pp_solve_time = Float64[], total_solve_time = Float64[], var_added = Int64[], profit = Float64[])
  
    ## Set Parameters and Gen Data ##
    parameters["network"]["num_routes"] = num_route
    parameters["vertiports"]["operational_capacity"] = op_cap
    parameters["vertiports"]["num_veh"] = num_veh
    parameters["vertiports"]["parking_capacity"] = parking_cap
    parameters["vertiports"]["turn_around_time"] = tat
    parameters["network"]["margin"] = margin
    parameters["network"]["num_lanes"] = lane
    parameters["time"]["discretization"] = time_disc
    parameters["time"]["horizon"] = horizon
    parameters["vehicle"]["vehicle_speed"] = air_speed*26.8224 #meter/min
    parameters["vehicle"]["max_endurance"] = max_endurance #hour
    
    route_seeding = "Compat_Lanes"
    Data, Demand_df = Data_Processing(Dir, route_seeding, Edges, LongLat, network, Raw_Demand, parameters, dem_per_vert_hour, dem_alpha)

    # Weather_Closures = Data.Weather_Closures
    Demand_Requests = Data.Demand_Requests
    Route_Desc = Data.Route_Desc
    Con_List = Data.Con_List
    ODT = Data.ODT
    Dem_List = Data.Dem_List
    Num_Requests = length(Demand_Requests)
    Demand_Requests = Data.Demand_Requests
    
    Demand_df[:,"param_num"] = [a for n = 1:Num_Requests]

    Visualization_Desc = Dict()
    Visualization_Desc["Max_Time"] = Data.Time_Nodes + Data.Buffer
    Visualization_Desc["Num_Vertiports"] = Data.Num_Vertiports
    Visualization_Desc["Time_Disc"] = Data.Δt

    Weather_Closures_Pred, Weather_Closures_Truth, Weather_Closures_Open = Update_Weather(Data.Dir, Data.Time_Nodes + Data.Buffer, Data.LongLat, Data.Num_Nodes, weather_scen, weather_cutoff, knn, pred_type, tpr)

    if weather_cutoff > 0
        cg_df, rmp_cg_obj_int, rmp_cg_solve_time_int, rmp_cg_opt_gap, rmp_cg_obj_relax, rmp_cg_solve_time_relax, Active_Routes, Demand_df, Flights_df, k, corr_changes = run_rmp_cg_model(Data, cg_df, pp_algo, Demand_df, a, Weather_Closures_Pred, Weather_Closures_Truth, weather_scen, weather_cutoff, Fix_Dir) 
    else
        cg_df, rmp_cg_obj_int, rmp_cg_solve_time_int, rmp_cg_opt_gap, rmp_cg_obj_relax, rmp_cg_solve_time_relax, Active_Routes, Demand_df, Flights_df, k, corr_changes = run_rmp_cg_model(Data, cg_df, pp_algo, Demand_df, a, Weather_Closures_Open, Weather_Closures_Open, weather_scen, weather_cutoff, Fix_Dir) 
    end
    push!(int_agg_df, [a, rmp_cg_obj_int, rmp_cg_obj_relax, rmp_cg_solve_time_int, rmp_cg_opt_gap, k, pred_type])

    Demand_df[:,"Type"] .= pred_type

    Flights_df[:,"Type"] .= pred_type
    
    writedlm(Dir*"Practical_Results/Experiment_$experiment_type/Results_$a/Description/Pred_Closures.csv",  Weather_Closures_Pred, ',')
    writedlm(Dir*"Practical_Results/Experiment_$experiment_type/Results_$a/Description/Truth_Closures.csv",  Weather_Closures_Truth, ',')

    writedlm(Dir*"Practical_Results/Experiment_$experiment_type/Results_$a/Description/corr_changes.csv",  corr_changes, ',')

    CSV.write(Dir*"Practical_Results/Experiment_$experiment_type/Results_$a/agg_results_int.csv", int_agg_df)
    CSV.write(Dir*"Practical_Results/Experiment_$experiment_type/Results_$a/demand_df.csv", Demand_df)
    CSV.write(Dir*"Practical_Results/Experiment_$experiment_type/Results_$a/flights_df.csv", Flights_df)

    CSV.write(Dir*"Practical_Results/Experiment_$experiment_type/Results_$a/cg_df.csv", cg_df)
    
    open(Dir*"Practical_Results/Experiment_$experiment_type/Results_$a/Description/Visualization_Desc.json", "w") do f
        write(f, JSON.json(Visualization_Desc))
    end

    open(Dir*"Practical_Results/Experiment_$experiment_type/Results_$a/Description/Active_Routes.json", "w") do f
        write(f, JSON.json(Active_Routes))
    end

    return nothing
    
end