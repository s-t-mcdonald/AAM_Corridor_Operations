
using CSV, Base.Threads, DataFrames, Random

logrange(x1, x2, n) = (10^y for y in range(log10(x1), log10(x2), length=n))

##-------------------------Simulation 1--------------------------##
experiment_type = 1

# Modeling Parameters
LANES           = [2,4,8]
NUM_VEHICLES    = [3,5,9]
PARK_CAP_MULT   = [2]
AIR_SPEED       = [100]
MAX_ENDURANCE   = [90]
OPERATIONAL_CAP = [1]
TAT             = [5,15,30]
NETWORKS        = ["Victor_Network", "Grid_Network", "Direct_Network"]
WEATHER_CUTOFF  = [0]
WEATHER_SCEN    = [0]
FIXED_DIR       = [0]

# Demand and Passenger Parameters
MARGIN          = [3,5,10]
DEM_MIN_VERT    = [10]
DEMAND_ALPHA    = [30]

# Algorithmic Parameters
HORIZON         = [180]
TIME_DISC       = [1]
NUM_ROUTES      = [1]
PP_ALGO         = ["backward_one"]
TPR             = [0.7]
KNN             = [1]
PRED_TYPE       = ["Oracle"]
TIME_LIMIT      = [1800]
OPT_GAP         = [0.01]

# Random Seeds
SEEDS           = [405, 3453]

param_df    = DataFrame(PARAM = Int64[], HORIZON = Int64[], LANES = Int64[], MARGIN = Float64[], NUM_VEHICLES = Int64[], PARK_CAP_MULT = Float64[], AIR_SPEED = Float64[], MAX_ENDURANCE = Int64[], OPERATIONAL_CAP = Int64[], TAT = Int64[],
                    NETWORKS = Any[], WEATHER_SCEN = Int64[], WEATHER_CUTOFF = Int64[], FIXED_DIR = Int64[], DEM_MIN_VERT = Float64[], DEMAND_ALPHA = Float64[], TIME_DISC = Int64[], NUM_ROUTES = Int64[], PP_ALGO = Any[], TPR = Float64[], KNN = Int64[], PRED_TYPE = String[], SEEDS = Int64[], TIME_LIMIT = Int64[], OPT_GAP = Float64[])

PARAMS      = vcat(collect(Iterators.product(HORIZON, LANES, MARGIN, NUM_VEHICLES, PARK_CAP_MULT, AIR_SPEED, MAX_ENDURANCE, OPERATIONAL_CAP, TAT, NETWORKS, WEATHER_SCEN, WEATHER_CUTOFF, FIXED_DIR, DEM_MIN_VERT, DEMAND_ALPHA, TIME_DISC, NUM_ROUTES, PP_ALGO, TPR, KNN, PRED_TYPE, SEEDS, TIME_LIMIT, OPT_GAP))...)

k = 1
for p_num ∈ 1:length(PARAMS)
    global k
    
    if (PARAMS[p_num][10] == "Direct_Network") & (PARAMS[p_num][2] != LANES[1])
        continue
    end

    param_array = [p for p in PARAMS[p_num]]
    pushfirst!(param_array, k)
    push!(param_df, param_array)

    k = k + 1
end

CSV.write("Parameters/parameter_array_practical_$experiment_type.csv", param_df)
##-------------------------Simulation 1--------------------------##



##-------------------------Simulation 2--------------------------##
experiment_type = 2

# Modeling Parameters
LANES           = [2,4,8]
NUM_VEHICLES    = [5]
PARK_CAP_MULT   = [1.1,1.5,2]
AIR_SPEED       = [100]
MAX_ENDURANCE   = [90]
OPERATIONAL_CAP = [1]
TAT             = [15]
NETWORKS        = ["Victor_Network"]
WEATHER_CUTOFF  = [0]
WEATHER_SCEN    = [0]
FIXED_DIR       = [0,1]

# Demand and Passenger Parameters
MARGIN          = [3,5,10]
DEM_MIN_VERT    = [1, 5, 10]
DEMAND_ALPHA    = [30,60]

# Algorithmic Parameters
HORIZON         = [180]
TIME_DISC       = [1]
NUM_ROUTES      = [1]
PP_ALGO         = ["backward_one"]
TPR             = [0.7]
KNN             = [1]
PRED_TYPE       = ["Oracle"]
TIME_LIMIT      = [1800]
OPT_GAP         = [0.01]

# Random Seeds
SEEDS           = [405, 3453]

param_df    = DataFrame(PARAM = Int64[], HORIZON = Int64[], LANES = Int64[], MARGIN = Float64[], NUM_VEHICLES = Int64[], PARK_CAP_MULT = Float64[], AIR_SPEED = Float64[], MAX_ENDURANCE = Int64[], OPERATIONAL_CAP = Int64[], TAT = Int64[],
                    NETWORKS = Any[], WEATHER_SCEN = Int64[], WEATHER_CUTOFF = Int64[], FIXED_DIR = Int64[], DEM_MIN_VERT = Float64[], DEMAND_ALPHA = Float64[], TIME_DISC = Int64[], NUM_ROUTES = Int64[], PP_ALGO = Any[], TPR = Float64[], KNN = Int64[], PRED_TYPE = String[], SEEDS = Int64[], TIME_LIMIT = Int64[], OPT_GAP = Float64[])

PARAMS      = vcat(collect(Iterators.product(HORIZON, LANES, MARGIN, NUM_VEHICLES, PARK_CAP_MULT, AIR_SPEED, MAX_ENDURANCE, OPERATIONAL_CAP, TAT, NETWORKS, WEATHER_SCEN, WEATHER_CUTOFF, FIXED_DIR, DEM_MIN_VERT, DEMAND_ALPHA, TIME_DISC, NUM_ROUTES, PP_ALGO, TPR, KNN, PRED_TYPE, SEEDS, TIME_LIMIT, OPT_GAP))...)

k = 1
for p_num ∈ 1:length(PARAMS)
    global k

    param_array = [p for p in PARAMS[p_num]]
    pushfirst!(param_array, k)
    push!(param_df, param_array)

    k = k + 1
end

CSV.write("Parameters/parameter_array_practical_$experiment_type.csv", param_df)
##-------------------------Simulation 2--------------------------##



##-------------------------Simulation 3--------------------------##
experiment_type = 3

# Modeling Parameters
LANES           = [4]
NUM_VEHICLES    = [5]
PARK_CAP_MULT   = [2]
AIR_SPEED       = [100]
MAX_ENDURANCE   = [90]
OPERATIONAL_CAP = [1]
TAT             = [15]
NETWORKS        = ["Victor_Network"]
WEATHER_CUTOFF  = [0,1,2,3,4]
WEATHER_SCEN    = [1,2,3,4,5,6,7,8]
FIXED_DIR       = [0]

# Demand and Passenger Parameters
MARGIN          = [5]
DEM_MIN_VERT    = [2,5,10]
DEMAND_ALPHA    = [30]

# Algorithmic Parameters
HORIZON         = [180]
TIME_DISC       = [1]
NUM_ROUTES      = [1]
PP_ALGO         = ["backward_one"]
TPR             = [0]
KNN             = [1]
PRED_TYPE       = ["Oracle"]
TIME_LIMIT      = [1800]
OPT_GAP         = [0.01]

# Random Seeds
SEEDS           = [405, 3453, 234, 23421]

param_df    = DataFrame(PARAM = Int64[], HORIZON = Int64[], LANES = Int64[], MARGIN = Float64[], NUM_VEHICLES = Int64[], PARK_CAP_MULT = Float64[], AIR_SPEED = Float64[], MAX_ENDURANCE = Int64[], OPERATIONAL_CAP = Int64[], TAT = Int64[],
                    NETWORKS = Any[], WEATHER_SCEN = Int64[], WEATHER_CUTOFF = Int64[], FIXED_DIR = Int64[], DEM_MIN_VERT = Float64[], DEMAND_ALPHA = Float64[], TIME_DISC = Int64[], NUM_ROUTES = Int64[], PP_ALGO = Any[], TPR = Float64[], KNN = Int64[], PRED_TYPE = String[], SEEDS = Int64[], TIME_LIMIT = Int64[], OPT_GAP = Float64[])

PARAMS      = vcat(collect(Iterators.product(HORIZON, LANES, MARGIN, NUM_VEHICLES, PARK_CAP_MULT, AIR_SPEED, MAX_ENDURANCE, OPERATIONAL_CAP, TAT, NETWORKS, WEATHER_SCEN, WEATHER_CUTOFF, FIXED_DIR, DEM_MIN_VERT, DEMAND_ALPHA, TIME_DISC, NUM_ROUTES, PP_ALGO, TPR, KNN, PRED_TYPE, SEEDS, TIME_LIMIT, OPT_GAP))...)

k = 1
for p_num ∈ 1:length(PARAMS)
    global k


    if (PARAMS[p_num][12] == 0) & (PARAMS[p_num][11] != WEATHER_SCEN[1])
        continue
    end


    param_array = [p for p in PARAMS[p_num]]
    pushfirst!(param_array, k)
    push!(param_df, param_array)

    k = k + 1
end

CSV.write("Parameters/parameter_array_practical_$experiment_type.csv", param_df)
##-------------------------Simulation 3--------------------------##



##-------------------------Simulation 4--------------------------##
experiment_type = 4

# Modeling Parameters
LANES           = [4]
NUM_VEHICLES    = [5]
PARK_CAP_MULT   = [2]
AIR_SPEED       = [100]
MAX_ENDURANCE   = [90]
OPERATIONAL_CAP = [1]
TAT             = [15]
NETWORKS        = ["Victor_Network"]
WEATHER_CUTOFF  = [1,2,3]
WEATHER_SCEN    = [1,2,3,4,5]
FIXED_DIR       = [0]

# Demand and Passenger Parameters
MARGIN          = [5]
DEM_MIN_VERT    = [2,5,10]
DEMAND_ALPHA    = [30]

# Algorithmic Parameters
HORIZON         = [120]
TIME_DISC       = [1]
NUM_ROUTES      = [1]
PP_ALGO         = ["backward_one"]
TPR             = [0, 0.1, 0.5, 0.9]
KNN             = [1]
PRED_TYPE       = ["Oracle", "Open", "Stationary", "Dynamic", "LinearRegression"]
TIME_LIMIT      = [1800]
OPT_GAP         = [0.01]

# Random Seeds
SEEDS           = [405]

param_df    = DataFrame(PARAM = Int64[], HORIZON = Int64[], LANES = Int64[], MARGIN = Float64[], NUM_VEHICLES = Int64[], PARK_CAP_MULT = Float64[], AIR_SPEED = Float64[], MAX_ENDURANCE = Int64[], OPERATIONAL_CAP = Int64[], TAT = Int64[],
                    NETWORKS = Any[], WEATHER_SCEN = Int64[], WEATHER_CUTOFF = Int64[], FIXED_DIR = Int64[], DEM_MIN_VERT = Float64[], DEMAND_ALPHA = Float64[], TIME_DISC = Int64[], NUM_ROUTES = Int64[], PP_ALGO = Any[], TPR = Float64[], KNN = Int64[], PRED_TYPE = String[], SEEDS = Int64[], TIME_LIMIT = Int64[], OPT_GAP = Float64[])

PARAMS      = vcat(collect(Iterators.product(HORIZON, LANES, MARGIN, NUM_VEHICLES, PARK_CAP_MULT, AIR_SPEED, MAX_ENDURANCE, OPERATIONAL_CAP, TAT, NETWORKS, WEATHER_SCEN, WEATHER_CUTOFF, FIXED_DIR, DEM_MIN_VERT, DEMAND_ALPHA, TIME_DISC, NUM_ROUTES, PP_ALGO, TPR, KNN, PRED_TYPE, SEEDS, TIME_LIMIT, OPT_GAP))...)

k = 1
for p_num ∈ 1:length(PARAMS)
    global k


    if (PARAMS[p_num][12] == 0) & (PARAMS[p_num][11] != WEATHER_SCEN[1])
        continue
    end

    if (PARAMS[p_num][end-1] ∉ ["LinearRegression"]) & (PARAMS[p_num][end-3] != TPR[1])
        continue
    end

    if (PARAMS[p_num][end-1] ∈ ["LinearRegression"]) & (PARAMS[p_num][end-3] == TPR[1])
        continue
    end

    param_array = [p for p in PARAMS[p_num]]
    pushfirst!(param_array, k)
    push!(param_df, param_array)

    k = k + 1
end

CSV.write("Parameters/parameter_array_practical_$experiment_type.csv", param_df)
##-------------------------Simulation 4--------------------------##