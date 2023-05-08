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

using DelimitedFiles, JSON, Statistics

function Update_Weather(Dir, Max_Time, LongLat, Num_Nodes, weather_scen, weather_cutoff, k_nn, pred_type, TPR)

    Weather_Closures_Pred   = zeros(Int, Max_Time, Num_Nodes)
    Weather_Closures_Truth  = zeros(Int, Max_Time, Num_Nodes)
    Weather_Closures_Open  = zeros(Int, Max_Time, Num_Nodes)
    
    if weather_cutoff == 0
        fpr = 0
        return Weather_Closures_Pred, Weather_Closures_Truth, Weather_Closures_Open, fpr
    end

    Truth = readdlm(Dir*"Main//Inputs//Weather_Scenarios//Weather_Cutoff_$weather_cutoff//Weather_Scenario_$weather_scen//Weather_Scenario_Truth.csv", ',', Float64)

    Preds = readdlm(Dir*"Main//Inputs//Weather_Scenarios//Weather_Cutoff_$weather_cutoff//Weather_Scenario_$weather_scen//$pred_type//Weather_Scenario_Pred.csv", ',', Float64)


    Closest_Stations_Time = []
    for t = 1:Max_Time

        if pred_type == "Dynamic"
            Stat_LonLat = readdlm(Dir*"Main//Inputs//Weather_Scenarios//Weather_Cutoff_$weather_cutoff//Weather_Scenario_$weather_scen//$pred_type//LonLats//Station_Lon_Lat_$t.csv", ',', Float64)
        else
            Stat_LonLat = readdlm(Dir*"Main//Inputs//Weather_Scenarios//Weather_Cutoff_$weather_cutoff//Weather_Scenario_$weather_scen//$pred_type//LonLats//Station_Lon_Lat_1.csv", ',', Float64)
        end

        Closest_Stations = []
        for n = 1:Num_Nodes
            LonLat_Val = LongLat[string(n-1)]
            
            Lon = LonLat_Val[1]
            Lat = LonLat_Val[2]

            Stat_Lons = Stat_LonLat[:,1]
            Stat_Lats = Stat_LonLat[:,2]

            LonDiffs = (Stat_Lons .- Lon).^2
            LatDiffs = (Stat_Lats .- Lat).^2

            Diffs = LonDiffs + LatDiffs

            sorted_perm = sortperm(Diffs)
            
            push!(Closest_Stations, sorted_perm)
        end
        push!(Closest_Stations_Time,Closest_Stations)
    end


    for t = 1:Max_Time, n = 1:Num_Nodes
        pred_val = mean(Preds[t,Closest_Stations_Time[t][n][1:k_nn]])
        truth_val = mean(Truth[t,Closest_Stations_Time[1][n][1:k_nn]])

        if pred_type ∈ ["Oracle", "Open", "Stationary", "Dynamic"]
            pred_bin = pred_val < 0.5
        else
            pred_bin = pred_val < TPR
        end
        
        truth_bin = truth_val > 0.5

        Weather_Closures_Pred[t,n] = pred_bin
        Weather_Closures_Truth[t,n] = truth_bin
    end

    print(sum(Weather_Closures_Pred-Weather_Closures_Truth))

    # if pred_type == "Oracle"
    #     Weather_Closures_Pred = Weather_Closures_Truth
    # end

    return Weather_Closures_Pred, Weather_Closures_Truth, Weather_Closures_Open
    
    
end