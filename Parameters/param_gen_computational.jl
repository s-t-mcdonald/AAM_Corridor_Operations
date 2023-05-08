
using CSV, Base.Threads, DataFrames, Random

logrange(x1, x2, n) = (10^y for y in range(log10(x1), log10(x2), length=n))

##-------------------------Simulation 1--------------------------##
experiment_type = 1

# Network Parameters
NODE_MULT       = [1,2,10]
VERTIPORTS      = [5,10,30,50]
ANG_CUTOFF      = [15]

# Modeling Parameters
LANES           = [4]
NUM_VEHICLES    = [5]
PARKING_CAP     = [8]
AIR_SPEED       = [100]
MAX_ENDURANCE   = [90]
OPERATIONAL_CAP = [1]
NETWORKS        = ["Random_Network"]
WEATHER_SCEN    = [0]

# Demand and Passenger Parameters
MARGIN          = [3]
DEM_MIN_VERT    = [1, 5, 10]
DEMAND_ALPHA    = [30]

# Algorithmic Parameters
FORMULATION     = ["FBF", "CBF"]
HORIZON         = [180]
TIME_DISC       = [1]
NUM_ROUTES      = [1]
ROUTE_SEEDING   = ["Compat_Lanes"]
PP_ALGO         = ["backward_one"]
TPR             = [0.7]
KNN             = [1]

# Random Seeds
SEEDS           = [4055, 345345, 120310, 25251]

param_df    = DataFrame(PARAM = Int64[], FORMULATION = String[], NODE_MULT = Float64[], VERTIPORTS = Int64[], ANG_CUTOFF = Float64[], HORIZON = Int64[], LANES = Int64[], MARGIN = Float64[], NUM_VEHICLES = Int64[], PARKING_CAP = Int64[], AIR_SPEED = Float64[], MAX_ENDURANCE = Int64[], OPERATIONAL_CAP = Int64[], 
                    NETWORKS = Any[], WEATHER_SCEN = Int64[], DEM_MIN_VERT = Float64[], DEMAND_ALPHA = Float64[], TIME_DISC = Int64[], NUM_ROUTES = Int64[], ROUTE_SEEDING = String[], PP_ALGO = Any[], TPR = Float64[], KNN = Int64[], SEEDS = Int64[])

PARAMS      = vcat(collect(Iterators.product(FORMULATION, NODE_MULT, VERTIPORTS, ANG_CUTOFF, HORIZON, LANES, MARGIN, NUM_VEHICLES, PARKING_CAP, AIR_SPEED, MAX_ENDURANCE, OPERATIONAL_CAP, NETWORKS, WEATHER_SCEN, DEM_MIN_VERT, DEMAND_ALPHA, TIME_DISC, NUM_ROUTES, ROUTE_SEEDING, PP_ALGO, TPR, KNN, SEEDS))...)

k = 1
for p_num ∈ 1:length(PARAMS)
    global k
    
    param_array = [p for p in PARAMS[p_num]]
    pushfirst!(param_array, k)
    push!(param_df, param_array)

    k = k + 1
end

CSV.write("Parameters/parameter_array_computational_$experiment_type.csv", param_df)
##-------------------------Simulation 1--------------------------##



##-------------------------Simulation 2--------------------------##
experiment_type = 2

# Network Parameters
NODE_MULT       = [1,2,10]
VERTIPORTS      = [5,10,25,50]
ANG_CUTOFF      = [15]

# Modeling Parameters
LANES           = [4]
NUM_VEHICLES    = [5]
PARKING_CAP     = [8]
AIR_SPEED       = [100]
MAX_ENDURANCE   = [90]
OPERATIONAL_CAP = [1]
NETWORKS        = ["Random_Network"]
WEATHER_SCEN    = [0]

# Demand and Passenger Parameters
MARGIN          = [3]
DEM_MIN_VERT  = [10]
DEMAND_ALPHA    = [30]

# Algorithmic Parameters
FORMULATION     = ["FBF"]
HORIZON         = [180]
TIME_DISC       = [1]
NUM_ROUTES      = [1]
ROUTE_SEEDING   = ["None", "All_Lanes", "Compat_Lanes"]
PP_ALGO         = ["forward_one", "forward_all", "backward_one", "backward_all"]
TPR             = [0.7]
KNN             = [1]

# Random Seeds
SEEDS           = [4055, 345345, 120310]

param_df    = DataFrame(PARAM = Int64[], FORMULATION = String[], NODE_MULT = Float64[], VERTIPORTS = Int64[], ANG_CUTOFF = Float64[], HORIZON = Int64[], LANES = Int64[], MARGIN = Float64[], NUM_VEHICLES = Int64[], PARKING_CAP = Int64[], AIR_SPEED = Float64[], MAX_ENDURANCE = Int64[], OPERATIONAL_CAP = Int64[], 
                    NETWORKS = Any[], WEATHER_SCEN = Int64[], DEM_MIN_VERT = Float64[], DEMAND_ALPHA = Float64[], TIME_DISC = Int64[], NUM_ROUTES = Int64[], ROUTE_SEEDING = String[], PP_ALGO = Any[], TPR = Float64[], KNN = Int64[], SEEDS = Int64[])

PARAMS      = vcat(collect(Iterators.product(FORMULATION, NODE_MULT, VERTIPORTS, ANG_CUTOFF, HORIZON, LANES, MARGIN, NUM_VEHICLES, PARKING_CAP, AIR_SPEED, MAX_ENDURANCE, OPERATIONAL_CAP, NETWORKS, WEATHER_SCEN, DEM_MIN_VERT, DEMAND_ALPHA, TIME_DISC, NUM_ROUTES, ROUTE_SEEDING, PP_ALGO, TPR, KNN, SEEDS))...)

k = 1
for p_num ∈ 1:length(PARAMS)
    global k
    
    param_array = [p for p in PARAMS[p_num]]
    pushfirst!(param_array, k)
    push!(param_df, param_array)

    k = k + 1
end

CSV.write("Parameters/parameter_array_computational_$experiment_type.csv", param_df)
##-------------------------Simulation 2--------------------------##


##-------------------------Simulation 3--------------------------##
experiment_type = 3

# Network Parameters
NODE_MULT       = [1,2,10]
VERTIPORTS      = [50]
ANG_CUTOFF      = [30, 15, -1]

# Modeling Parameters
LANES           = [4]
NUM_VEHICLES    = [5]
PARKING_CAP     = [8]
AIR_SPEED       = [100]
MAX_ENDURANCE   = [90]
OPERATIONAL_CAP = [1]
NETWORKS        = ["Random_Network"]
WEATHER_SCEN    = [0]

# Demand and Passenger Parameters
MARGIN          = [3]
DEM_MIN_VERT    = [1, 5, 20]
DEMAND_ALPHA    = [30]

# Algorithmic Parameters
FORMULATION     = ["FBF"]
HORIZON         = [60]
TIME_DISC       = [1]
NUM_ROUTES      = [1]
ROUTE_SEEDING   = ["Compat_Lanes"]
PP_ALGO         = ["backward_one"]
TPR             = [0.7]
KNN             = [1]

# Random Seeds
SEEDS           = [4055, 345345, 120310, 25251]

param_df    = DataFrame(PARAM = Int64[], FORMULATION = String[], NODE_MULT = Float64[], VERTIPORTS = Int64[], ANG_CUTOFF = Float64[], HORIZON = Int64[], LANES = Int64[], MARGIN = Float64[], NUM_VEHICLES = Int64[], PARKING_CAP = Int64[], AIR_SPEED = Float64[], MAX_ENDURANCE = Int64[], OPERATIONAL_CAP = Int64[], 
                    NETWORKS = Any[], WEATHER_SCEN = Int64[], DEM_MIN_VERT = Float64[], DEMAND_ALPHA = Float64[], TIME_DISC = Int64[], NUM_ROUTES = Int64[], ROUTE_SEEDING = String[], PP_ALGO = Any[], TPR = Float64[], KNN = Int64[], SEEDS = Int64[])

PARAMS      = vcat(collect(Iterators.product(FORMULATION, NODE_MULT, VERTIPORTS, ANG_CUTOFF, HORIZON, LANES, MARGIN, NUM_VEHICLES, PARKING_CAP, AIR_SPEED, MAX_ENDURANCE, OPERATIONAL_CAP, NETWORKS, WEATHER_SCEN, DEM_MIN_VERT, DEMAND_ALPHA, TIME_DISC, NUM_ROUTES, ROUTE_SEEDING, PP_ALGO, TPR, KNN, SEEDS))...)

k = 1
for p_num ∈ 1:length(PARAMS)
    global k
    
    param_array = [p for p in PARAMS[p_num]]
    pushfirst!(param_array, k)
    push!(param_df, param_array)

    k = k + 1
end

CSV.write("Parameters/parameter_array_computational_$experiment_type.csv", param_df)
##-------------------------Simulation 3--------------------------##


##-------------------------Simulation 4--------------------------##
experiment_type = 4

# Network Parameters
NODE_MULT       = [5]
VERTIPORTS      = [5,15,30,50]
ANG_CUTOFF      = [15]

# Modeling Parameters
LANES           = [4]
NUM_VEHICLES    = [5]
PARKING_CAP     = [8]
AIR_SPEED       = [100]
MAX_ENDURANCE   = [90]
OPERATIONAL_CAP = [1]
NETWORKS        = ["Random_Network"]
WEATHER_SCEN    = [0]

# Demand and Passenger Parameters
MARGIN          = [3]
DEM_MIN_VERT    = [1, 5, 20, 40]
DEMAND_ALPHA    = [30]

# Algorithmic Parameters
FORMULATION     = ["FBF"]
HORIZON         = [30, 60, 90, 120, 150, 180]
TIME_DISC       = [1]
NUM_ROUTES      = [1]
ROUTE_SEEDING   = ["Compat_Lanes"]
PP_ALGO         = ["backward_one"]
TPR             = [0.7]
KNN             = [1]

# Random Seeds
SEEDS           = [4055, 345345, 120310, 25251]

param_df    = DataFrame(PARAM = Int64[], FORMULATION = String[], NODE_MULT = Float64[], VERTIPORTS = Int64[], ANG_CUTOFF = Float64[], HORIZON = Int64[], LANES = Int64[], MARGIN = Float64[], NUM_VEHICLES = Int64[], PARKING_CAP = Int64[], AIR_SPEED = Float64[], MAX_ENDURANCE = Int64[], OPERATIONAL_CAP = Int64[], 
                    NETWORKS = Any[], WEATHER_SCEN = Int64[], DEM_MIN_VERT = Float64[], DEMAND_ALPHA = Float64[], TIME_DISC = Int64[], NUM_ROUTES = Int64[], ROUTE_SEEDING = String[], PP_ALGO = Any[], TPR = Float64[], KNN = Int64[], SEEDS = Int64[])

PARAMS      = vcat(collect(Iterators.product(FORMULATION, NODE_MULT, VERTIPORTS, ANG_CUTOFF, HORIZON, LANES, MARGIN, NUM_VEHICLES, PARKING_CAP, AIR_SPEED, MAX_ENDURANCE, OPERATIONAL_CAP, NETWORKS, WEATHER_SCEN, DEM_MIN_VERT, DEMAND_ALPHA, TIME_DISC, NUM_ROUTES, ROUTE_SEEDING, PP_ALGO, TPR, KNN, SEEDS))...)

k = 1
for p_num ∈ 1:length(PARAMS)
    global k
    
    param_array = [p for p in PARAMS[p_num]]
    pushfirst!(param_array, k)
    push!(param_df, param_array)

    k = k + 1
end

CSV.write("Parameters/parameter_array_computational_$experiment_type.csv", param_df)
##-------------------------Simulation 4--------------------------##




# ##-------------------------Simulation 1--------------------------##
# experiment_type = 1

# # Network Parameters
# NODE_MULT       = [1,2,10]
# VERTIPORTS      = [5,10,30]
# ANG_CUTOFF      = [30, 15, -1]

# # Modeling Parameters
# LANES           = [4]
# NUM_VEHICLES    = [5]
# PARKING_CAP     = [8]
# AIR_SPEED       = [100]
# MAX_ENDURANCE   = [90]
# OPERATIONAL_CAP = [1]
# NETWORKS        = ["Random_Network"]
# WEATHER_SCEN    = [0]

# # Demand and Passenger Parameters
# MARGIN          = [3]
# DEM_MIN_VERT    = [1, 5, 20]
# DEMAND_ALPHA    = [30]

# # Algorithmic Parameters
# FORMULATION     = ["FBF", "CBF"]
# HORIZON         = [60]
# TIME_DISC       = [1]
# NUM_ROUTES      = [1]
# ROUTE_SEEDING   = ["Compat_Lanes"]
# PP_ALGO         = ["backward_one"]
# TPR             = [0.7]
# KNN             = [1]

# # Random Seeds
# SEEDS           = [4055, 345345, 120310]

# param_df    = DataFrame(PARAM = Int64[], FORMULATION = String[], NODE_MULT = Float64[], VERTIPORTS = Int64[], ANG_CUTOFF = Float64[], HORIZON = Int64[], LANES = Int64[], MARGIN = Float64[], NUM_VEHICLES = Int64[], PARKING_CAP = Int64[], AIR_SPEED = Float64[], MAX_ENDURANCE = Int64[], OPERATIONAL_CAP = Int64[], 
#                     NETWORKS = Any[], WEATHER_SCEN = Int64[], DEM_MIN_VERT = Float64[], DEMAND_ALPHA = Float64[], TIME_DISC = Int64[], NUM_ROUTES = Int64[], ROUTE_SEEDING = String[], PP_ALGO = Any[], TPR = Float64[], KNN = Int64[], SEEDS = Int64[])

# PARAMS      = vcat(collect(Iterators.product(FORMULATION, NODE_MULT, VERTIPORTS, ANG_CUTOFF, HORIZON, LANES, MARGIN, NUM_VEHICLES, PARKING_CAP, AIR_SPEED, MAX_ENDURANCE, OPERATIONAL_CAP, NETWORKS, WEATHER_SCEN, DEM_MIN_VERT, DEMAND_ALPHA, TIME_DISC, NUM_ROUTES, ROUTE_SEEDING, PP_ALGO, TPR, KNN, SEEDS))...)

# k = 1
# for p_num ∈ 1:length(PARAMS)
#     global k
    
#     param_array = [p for p in PARAMS[p_num]]
#     pushfirst!(param_array, k)
#     push!(param_df, param_array)

#     k = k + 1
# end

# CSV.write("Parameters/parameter_array_computational_$experiment_type.csv", param_df)
# ##-------------------------Simulation 1--------------------------##



# ##-------------------------Simulation 2--------------------------##
# experiment_type = 2

# # Network Parameters
# NODE_MULT       = [2,10]
# VERTIPORTS      = [5,10,25,50]
# ANG_CUTOFF      = [30]

# # Modeling Parameters
# LANES           = [4]
# NUM_VEHICLES    = [5]
# PARKING_CAP     = [8]
# AIR_SPEED       = [100]
# MAX_ENDURANCE   = [90]
# OPERATIONAL_CAP = [1]
# NETWORKS        = ["Random_Network"]
# WEATHER_SCEN    = [0]

# # Demand and Passenger Parameters
# MARGIN          = [3]
# DEM_MIN_VERT  = [10]
# DEMAND_ALPHA    = [30]

# # Algorithmic Parameters
# FORMULATION     = ["FBF"]
# HORIZON         = [60]
# TIME_DISC       = [1]
# NUM_ROUTES      = [1]
# ROUTE_SEEDING   = ["None", "All_Lanes", "Compat_Lanes"]
# PP_ALGO         = ["forward_one", "forward_all", "backward_one", "backward_all"]
# TPR             = [0.7]
# KNN             = [1]

# # Random Seeds
# SEEDS           = [4055, 345345, 120310, 4395, 1931]

# param_df    = DataFrame(PARAM = Int64[], FORMULATION = String[], NODE_MULT = Float64[], VERTIPORTS = Int64[], ANG_CUTOFF = Float64[], HORIZON = Int64[], LANES = Int64[], MARGIN = Float64[], NUM_VEHICLES = Int64[], PARKING_CAP = Int64[], AIR_SPEED = Float64[], MAX_ENDURANCE = Int64[], OPERATIONAL_CAP = Int64[], 
#                     NETWORKS = Any[], WEATHER_SCEN = Int64[], DEM_MIN_VERT = Float64[], DEMAND_ALPHA = Float64[], TIME_DISC = Int64[], NUM_ROUTES = Int64[], ROUTE_SEEDING = String[], PP_ALGO = Any[], TPR = Float64[], KNN = Int64[], SEEDS = Int64[])

# PARAMS      = vcat(collect(Iterators.product(FORMULATION, NODE_MULT, VERTIPORTS, ANG_CUTOFF, HORIZON, LANES, MARGIN, NUM_VEHICLES, PARKING_CAP, AIR_SPEED, MAX_ENDURANCE, OPERATIONAL_CAP, NETWORKS, WEATHER_SCEN, DEM_MIN_VERT, DEMAND_ALPHA, TIME_DISC, NUM_ROUTES, ROUTE_SEEDING, PP_ALGO, TPR, KNN, SEEDS))...)

# k = 1
# for p_num ∈ 1:length(PARAMS)
#     global k
    
#     param_array = [p for p in PARAMS[p_num]]
#     pushfirst!(param_array, k)
#     push!(param_df, param_array)

#     k = k + 1
# end

# CSV.write("Parameters/parameter_array_computational_$experiment_type.csv", param_df)
# ##-------------------------Simulation 2--------------------------##
