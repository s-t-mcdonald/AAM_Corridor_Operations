
using TOML, Gurobi, CSV, JuMP, Dates, Graphs, Base.Threads, Random, JSON

include("Main/Model/TT.jl")
include("Main/Model/Base_Model.jl")
include("Main/Model/Data_Processing.jl")
include("Run_Experiments/run_experiment_practical.jl")


Dir = ""

experiment_type = parse(Int, ARGS[1])
experiment_id = parse(Int, ARGS[2])

param_array = CSV.read(Dir*"Parameters/parameter_array_practical_$experiment_type.csv", DataFrame);

# Modeling Parameters
horizon             = 180#param_array[experiment_id,"HORIZON"]
lane                = 4#param_array[experiment_id,"LANES"]
num_veh             = 5#param_array[experiment_id,"NUM_VEHICLES"]
parking_cap_mult    = param_array[experiment_id,"PARK_CAP_MULT"]
parking_cap         = ceil(Int,parking_cap_mult*num_veh)
air_speed           = param_array[experiment_id,"AIR_SPEED"]
max_endurance       = param_array[experiment_id,"MAX_ENDURANCE"]
op_cap              = param_array[experiment_id,"OPERATIONAL_CAP"]
tat                 = 15#param_array[experiment_id,"TAT"]
network             = param_array[experiment_id,"NETWORKS"]
weather_scen        = param_array[experiment_id,"WEATHER_SCEN"]
weather_cutoff      = param_array[experiment_id,"WEATHER_CUTOFF"]
fix_dir             = param_array[experiment_id,"FIXED_DIR"]
time_limit          = param_array[experiment_id,"TIME_LIMIT"]
opt_gap             = param_array[experiment_id,"OPT_GAP"]

if network == "Direct_Network"
    lane = 1
end

# Demand and Passenger Parameters
margin              = param_array[experiment_id,"MARGIN"]
dem_per_vert_hour   = 20#param_array[experiment_id,"DEM_MIN_VERT"]
dem_alpha           = param_array[experiment_id,"DEMAND_ALPHA"]

# Algorithmic Parameters
time_disc           = param_array[experiment_id,"TIME_DISC"]
num_route           = param_array[experiment_id,"NUM_ROUTES"]
pp_algo             = param_array[experiment_id,"PP_ALGO"]
tpr                 = param_array[experiment_id,"TPR"]
knn                 = param_array[experiment_id,"KNN"]
pred_type           = param_array[experiment_id,"PRED_TYPE"]

# Random Seeds
seed                = param_array[experiment_id,"SEEDS"]
Random.seed!(seed)
global rng = MersenneTwister(seed)


Raw_Demand = CSV.read(Dir*"Main/Inputs/commuting_flows.csv", DataFrame);
parameters = TOML.parsefile(Dir*"Main/Parameters/Parameters.toml")
parameters["optimization"]["time_limit"] = time_limit
parameters["optimization"]["optimality_gap"] = opt_gap

## Import Corridor Network ##
Edges = JSON.parsefile(Dir*"Main//Data//Networks//$network//Edges.json", dicttype=Dict)
LongLat = JSON.parsefile(Dir*"Main//Data//Networks//$network//LongLat.json", dicttype=Dict)

int_agg_df = DataFrame(param_num = Int64[], rmp_cg_obj = Float64[], rmp_cg_relax_obj = Float64[], rmp_cg_solve_time = Float64[], rmp_cg_opt_gap = Float64[], cg_iterations = Int64[], type = Any[])

try
    mkdir(Dir*"Practical_Results/Experiment_$experiment_type")
catch   
    nothing
end

try
    mkdir(Dir*"Practical_Results/Experiment_$experiment_type/Results_$experiment_id")
catch   
    nothing
end

try
    mkdir(Dir*"Practical_Results/Experiment_$experiment_type/Results_$experiment_id/Description")
catch   
    nothing
end
cp(Dir*"Main//Data//Networks//$network//Graph.gml", Dir*"Practical_Results/Experiment_$experiment_type/Results_$experiment_id/Description/Graph.gml", force=true)
cp(Dir*"Main//Data//Networks//$network//Edges.json", Dir*"Practical_Results/Experiment_$experiment_type/Results_$experiment_id/Description/Edges.json", force=true)
cp(Dir*"Parameters/parameter_array_practical_$experiment_type.csv", Dir*"Practical_Results/Experiment_$experiment_type/Results_$experiment_id/parameters.csv", force=true)

Flag = true#!(isfile(Dir*"Practical_Results/Experiment_$experiment_type/Results_$experiment_id/agg_results_int.csv"))


if Flag
    run_experiment(Dir, experiment_type, experiment_id, time_disc, network, num_route, pp_algo, margin, num_veh, parking_cap, lane, horizon, air_speed, max_endurance, dem_per_vert_hour, dem_alpha, op_cap, tat, weather_scen, weather_cutoff, tpr, knn, pred_type, int_agg_df, fix_dir)
end
