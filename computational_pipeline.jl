
using TOML, Gurobi, CSV, JuMP, Dates, Graphs, Base.Threads, Random, JSON

include("Main/Model/TT.jl")
include("Main/Model/Base_Model.jl")
include("Main/Model/Data_Processing.jl")
include("Main/Model/Generate_Graph.jl")
include("Run_Experiments/run_experiment_computational.jl")


Dir = ""

experiment_type = parse(Int, ARGS[1])
experiment_id = parse(Int, ARGS[2])

param_array = CSV.read(Dir*"Parameters/parameter_array_computational_$experiment_type.csv", DataFrame);

# Network Parameters
node_mult           = param_array[experiment_id,"NODE_MULT"]
vertiports          = param_array[experiment_id,"VERTIPORTS"]
ang_cutoff          = param_array[experiment_id,"ANG_CUTOFF"]

nodes = round(Int, node_mult*vertiports)

# Modeling Parameters
horizon             = param_array[experiment_id,"HORIZON"]
lane                = param_array[experiment_id,"LANES"]
margin              = param_array[experiment_id,"MARGIN"]
num_veh             = param_array[experiment_id,"NUM_VEHICLES"]
parking_cap         = param_array[experiment_id,"PARKING_CAP"]
air_speed           = param_array[experiment_id,"AIR_SPEED"]
max_endurance       = param_array[experiment_id,"MAX_ENDURANCE"]
op_cap              = param_array[experiment_id,"OPERATIONAL_CAP"]
network             = param_array[experiment_id,"NETWORKS"]
weather_scen        = param_array[experiment_id,"WEATHER_SCEN"]

if network == "Direct_Network"
    lane = 1
end

# Demand and Passenger Parameters
dem_per_vert_hour   = param_array[experiment_id,"DEM_MIN_VERT"]
dem_alpha           = param_array[experiment_id,"DEMAND_ALPHA"]

# Algorithmic Parameters
formulation         = param_array[experiment_id,"FORMULATION"]
time_disc           = param_array[experiment_id,"TIME_DISC"]
num_route           = param_array[experiment_id,"NUM_ROUTES"]
route_seeding       = param_array[experiment_id,"ROUTE_SEEDING"]
pp_algo             = param_array[experiment_id,"PP_ALGO"]
tpr                 = param_array[experiment_id,"TPR"]
knn                 = param_array[experiment_id,"KNN"]

# Random Seeds
seed                = param_array[experiment_id,"SEEDS"]
global rng = MersenneTwister(seed)

Raw_Demand = CSV.read(Dir*"Main/Inputs/commuting_flows.csv", DataFrame);
parameters = TOML.parsefile(Dir*"Main/Parameters/Parameters.toml")
parameters["optimization"]["time_limit"] = 1800
parameters["vertiports"]["turn_around_time"] = 15
parameters["optimization"]["optimality_gap"] = 0.01

## Import Corridor Network ##
if network == "Random_Network"
    Edges, LongLat, p = Generate_Graph(nodes,vertiports,ang_cutoff);
else
    Edges = JSON.parsefile(Dir*"Main//Data//Networks//$network//Edges.json", dicttype=Dict)
    LongLat = JSON.parsefile(Dir*"Main//Data//Networks//$network//LongLat.json", dicttype=Dict)
end

try
    mkdir(Dir*"Computational_Results/Experiment_$experiment_type")
catch   
    nothing
end

try
    mkdir(Dir*"Computational_Results/Experiment_$experiment_type/Results_$experiment_id")
catch   
    nothing
end
png(p, Dir*"Computational_Results/Experiment_$experiment_type/Results_$experiment_id/network_$experiment_id.png")
cp(Dir*"Parameters/parameter_array_computational_$experiment_type.csv", Dir*"Computational_Results/Experiment_$experiment_type/Results_$experiment_id/parameters.csv", force=true)

run_experiment(Dir, experiment_type, experiment_id, time_disc, network, num_route, route_seeding, pp_algo, margin, num_veh, 
              parking_cap, lane, horizon, air_speed, max_endurance, dem_per_vert_hour, dem_alpha, op_cap, formulation)