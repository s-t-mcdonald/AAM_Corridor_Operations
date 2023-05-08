using TOML, Gurobi, CSV, JuMP, Dates, Graphs, Base.Threads, Random, JSON   

include("../Main/Model/pricing_problem.jl")
include("../Main/Model/Update_Weather.jl")


function run_cbf_model(Data, pp_algo, a, results_df, cg_df)

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
    Wait_Times = Data.Wait_Times

    ## CF Model ##
    BM_CF = Gen_CF_Model_SS(Data)

    optimize!(BM_CF["Model"])

    try
        global cf_obj_relax, cf_solve_time_relax

        cf_obj_relax = objective_value(BM_CF["Model"])
        cf_solve_time_relax = solve_time(BM_CF["Model"])
    catch
        global cf_obj_relax, cf_solve_time_relax

        cf_obj_relax = -1
        cf_solve_time_relax = -1
    end
    
    set_integer.(BM_CF["Model"][:D])
    set_integer.(BM_CF["Model"][:A])
    set_integer.(BM_CF["Model"][:E])
    set_integer.(BM_CF["Model"][:W])

    optimize!(BM_CF["Model"])

    TD = value.(BM_CF["Model"][:TD])

    Percent_Satisfied = sum(TD)/Num_Requests*100
    print("Percent of Demand Satisfied: $Percent_Satisfied\n")

    try
        global cf_obj_int, cf_solve_time_int, cf_opt_gap

        cf_obj_int = objective_value(BM_CF["Model"])
        cf_solve_time_int = solve_time(BM_CF["Model"])
        cf_opt_gap = relative_gap(BM_CF["Model"])
    catch
        global cf_obj_int, cf_solve_time_int, cf_opt_gap

        cf_obj_int = -1
        cf_solve_time_int = -1
        cf_opt_gap = -1
    end

    push!(results_df, [a, cf_obj_int, cf_solve_time_int, cf_opt_gap, cf_opt_gap, cf_obj_relax, cf_solve_time_relax, -1])

    BM_CF = nothing

    return results_df, cg_df
end


function run_fbf_model(Data, pp_algo, a, results_df, cg_df)

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
    Wait_Times = Data.Wait_Times
    Num_Nodes = Data.Num_Nodes
    Num_Lanes = Data.Num_Lanes
    Time_Nodes = Data.Time_Nodes
    Buffer = Data.Buffer
    pathmx = Data.pathmx
    distmx = Data.distmx

    RMP = Gen_Model_SS(Data, 0)
    rmp = RMP["Model"]
    ToDeleteWest = RMP["ToDeleteWest"]
    ToDeleteEast = RMP["ToDeleteEast"]

    weather_open = zeros(Int, Time_Nodes+Buffer, Num_Nodes)
    print("-----------------------Finding TSG----------------------\n")
    g_l, weight_mx = construct_tsg(Data, weather_open, pp_algo, 0)
    print("-----------------------Found TSG----------------------\n")

    D = []
    Dists = []
    New_Route_Desc = []
    k = 1
    total_solve_time = 0
    solve = 1
    while true

        # if k == 1 
        #     set_optimizer_attributes(rmp, "TimeLimit" => Time_Limit, "MIPGap" => Optimality_Gap, "LPWarmStart" => 1, "OutputFlag" => 1, "Method" => 5)
        # end

        global rmp_obj, rmp_solve_time, pp_solve_time

        set_optimizer_attributes(rmp, "TimeLimit" => Time_Limit, "MIPGap" => Optimality_Gap, "LPWarmStart" => 1, "OutputFlag" => 1, "Method" => 5)
        optimize!(rmp)
        rmp_obj = objective_value(rmp)
        rmp_solve_time = solve_time(rmp)

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
            D, Dists, New_Route_Desc, reduced_cost, pp_solve_time, var_added = forward_all(Data, D, Dists, New_Route_Desc, g_l, weight_mx, RMP)
        end
        print("----------------------Columns Added-------------------------\n")

        print("\n------------------------------------------\n")
        print("PP reduced_cost: $reduced_cost | PP Solve_Time: $pp_solve_time | Var Added: $var_added")
        print("\n------------------------------------------\n")

        total_solve_time = total_solve_time + pp_solve_time + rmp_solve_time

        push!(cg_df, [a, k, rmp_obj, rmp_solve_time, reduced_cost, pp_solve_time, total_solve_time, var_added])

        k = k + 1

        if reduced_cost >= -10^-5
            break
        end

        if (k > 10000) | (total_solve_time > Data.Time_Limit)
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


    set_optimizer_attributes(rmp, "TimeLimit" => Time_Limit, "MIPGap" => Optimality_Gap, "DegenMoves" => 0, "OutputFlag" => 1, "Method" => 5)
    
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

    R = value.(RMP["R"])
    D = value.(D)
    TD = value.(RMP["TD"])

    # Demand_Satisfied = [sum(TD[n,k] for k = 1:Wait_Times[n]) for n = 1:Num_Requests]

    Percent_Satisfied = sum(TD)/Num_Requests*100
    print("Percent of Demand Satisfied: $Percent_Satisfied\n")

    
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

    true_optimality_gap = (rmp_cg_obj_int-rmp_cg_obj_relax)/rmp_cg_obj_int

    push!(results_df, [a, rmp_cg_obj_int, rmp_cg_solve_time_int, true_optimality_gap, rmp_cg_opt_gap, rmp_cg_obj_relax, rmp_cg_solve_time_relax, k])


    return results_df, cg_df
end



function run_experiment(Dir, experiment_type, a, time_disc, network, num_route, route_seeding, pp_algo, margin, num_veh, parking_cap, lane, horizon, air_speed, max_endurance, dem_per_vert_hour, dem_alpha, op_cap, model)

    cg_df = DataFrame(param_num = Int64[], cg_iteration = Int64[], rmp_obj = Float64[], rmp_solve_time = Float64[], reduced_cost = Float64[], pp_solve_time = Float64[], total_solve_time = Float64[], var_added = Int64[])
    results_df = DataFrame(param_num = Int64[], obj = Float64[], solve_time = Float64[], true_gap = Float64[], mip_gap = Float64[], relaxed_objective = Float64[], relaxed_solve_time = Float64[], cg_iterations = Int64[])

    ## Set Parameters and Gen Data ##
    parameters["network"]["num_routes"] = num_route
    parameters["vertiports"]["operational_capacity"] = op_cap
    parameters["vertiports"]["num_veh"] = num_veh
    parameters["vertiports"]["parking_capacity"] = parking_cap
    parameters["network"]["margin"] = margin
    parameters["network"]["num_lanes"] = lane
    parameters["time"]["discretization"] = time_disc
    parameters["time"]["horizon"] = horizon
    parameters["vehicle"]["vehicle_speed"] = air_speed*26.8224 #meter/min
    parameters["vehicle"]["max_endurance"] = max_endurance #hour
    
    Data, Demand_df = Data_Processing(Dir, route_seeding, Edges, LongLat, network, Raw_Demand, parameters, dem_per_vert_hour, dem_alpha)

    if model == "CBF"
        results_df, cg_df = run_cbf_model(Data, pp_algo, a, results_df, cg_df)  
    elseif model == "FBF"
        results_df, cg_df = run_fbf_model(Data, pp_algo, a, results_df, cg_df)  
    end


    CSV.write(Dir*"Computational_Results/Experiment_$experiment_type/Results_$a/results_df.csv", results_df)
    CSV.write(Dir*"Computational_Results/Experiment_$experiment_type/Results_$a/cg_results_df.csv", cg_df)

    return nothing
    
end