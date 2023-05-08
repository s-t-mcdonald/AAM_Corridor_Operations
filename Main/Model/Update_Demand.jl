# Syntax    Update_Demand(Data, Raw_Demand)
#
# Inputs:
#    Data - UAM Data File
#    Raw_Demand - raw demand data
#
# Outputs:
#    ED - Demand matrix
#
# Author: Spencer McDonald
# MIT - ORC UAM Study
# email: mcdonst@mit.edu
# Website: https://www.spencertmcdonald.com/
# Mar 2021; Last revision: 13-Jan-2021

using CSV, DataFrames, Dates, Distances, Random, ProgressBars, SparseArrays, StatsBase



function return_zips_time(Org_Zip, Dst_Zip, Sparse_ZIP_OD_TT)

    TT = Sparse_ZIP_OD_TT[Org_Zip,Dst_Zip]
    
    if TT < 0.1
        TT = 3*60
    end

    return TT

end

function return_zips_in_fips(Fips, ZIP_FIP)

    if typeof(Fips) != Int
        Fips = parse(Int, Fips)
    end

    df = ZIP_FIP[ ZIP_FIP.STCOUNTYFP .== Fips, :]

    Zips = unique(df.ZIP)

    return Zips
    
end

function Return_Travel_Times(Data, Org_Zip, Dst_Zip, Sparse_ZIP_OD_TT, Vert_Zips)

    Num_Vertiports = Data.Num_Vertiports
    LongLat = Data.LongLat
    Air_Speed = Data.Veh_Speed


    org_tt_vec = [return_zips_time(Org_Zip, Vert_Zips[string(i-1)], Sparse_ZIP_OD_TT) for i = 1:Num_Vertiports]
    dst_tt_vec = [return_zips_time(Vert_Zips[string(i-1)], Dst_Zip, Sparse_ZIP_OD_TT) for i = 1:Num_Vertiports]
  
    Min_Org_Vertiport = minimum(org_tt_vec)
    Org_Vertiport = argmin(org_tt_vec)
    
    Min_Dst_Vertiport = minimum(dst_tt_vec)
    Dst_Vertiport = argmin(dst_tt_vec)      
 
    Vert_to_Vert = haversine( (LongLat[string(Org_Vertiport-1)][1],LongLat[string(Org_Vertiport-1)][2]), (LongLat[string(Dst_Vertiport-1)][1],LongLat[string(Dst_Vertiport-1)][2]), 6.371*10^6)

    Car_TT = return_zips_time(Org_Zip, Dst_Zip, Sparse_ZIP_OD_TT)
    Flying_TT = Min_Org_Vertiport + Vert_to_Vert/Air_Speed + Min_Dst_Vertiport

    return Car_TT, Flying_TT, Org_Vertiport, Dst_Vertiport, Vert_to_Vert
        

end

function Update_Demand(Data, Raw_Demand, dem_per_vert_hour, demand_alpha)

    global rng

    ## Extract Local Variables ##
    Buffer = Data.Buffer
    Time_Nodes = Data.Time_Nodes
    pathmx = Data.pathmx
    Δt = Data.Δt
    Num_Vertiports = Data.Num_Vertiports
    distmx = Data.distmx
    LongLat = Data.LongLat
    Air_Speed = Data.Veh_Speed
    Dir = Data.Dir
    Max_Range = Data.Max_Range
    Veh_Speed = Data.Veh_Speed

    Time_Reds = [-(1/0.1)*log(prob/(1-prob))+demand_alpha for prob = 0:0.01:1]
    ind = findall(x -> (x > 10) & (x < 100), Time_Reds)

    Time_Reds = Time_Reds[ind]
    

    ZIP_FIP = CSV.read(Dir*"Main/Data/ZIP_FIP.csv", DataFrame);
    Zip_OD_TT = CSV.read(Dir*"Main/Data/ZIP_OD_TT.csv", DataFrame);
    # Zip_OD_TT = Zip_OD_TT[(Zip_OD_TT.OZCTA .< 30000) .& (Zip_OD_TT.DZCTA .< 30000), :]

    Sparse_ZIP_OD_TT = spzeros(30000, 30000)
    for i = 1:nrow(Zip_OD_TT)
        Sparse_ZIP_OD_TT[Zip_OD_TT[i,"OZCTA"], Zip_OD_TT[i,"DZCTA"]] = Zip_OD_TT[i,"EstTime"]
    end
    Zip_OD_TT = nothing

    
    Vert_Zips = JSON.parsefile(Dir*"Main//Data//Networks//Victor_Network//Vert_Zip.json", dicttype=Dict)
    
    ED = zeros(Int, Time_Nodes+Buffer, Num_Vertiports, Num_Vertiports)

    Demand_Requests = []
    Demand_Revenues = []

    for i in tqdm(1:nrow(Raw_Demand))
        
        Mean_Demand = Raw_Demand[i,"Commuting_Flow"]
        Std_Dev = Raw_Demand[i,"Std_Err"]



        Demand = round(Int, maximum([0, Mean_Demand + Std_Dev*randn(rng)]))

        Org_Fips    = Raw_Demand[i,"Org_Fips"]
        Org_Lat    = Raw_Demand[i,"Org_Lat"]
        Org_Lon    = Raw_Demand[i,"Org_Lon"]

        Dst_Fips    = Raw_Demand[i,"Dst_Fips"]
        Dst_Lat    = Raw_Demand[i,"Dst_Lat"]
        Dst_Lon    = Raw_Demand[i,"Dst_Lon"]

        org_dst_dist = haversine( (Org_Lat,Org_Lon), (Dst_Lat,Dst_Lon), 6.371*10^6)

        if ((org_dst_dist/Air_Speed) > 2*60) | (org_dst_dist < 8046.72)
            continue
        end

        Org_Zips    = return_zips_in_fips(Org_Fips, ZIP_FIP)
        Dst_Zips    = return_zips_in_fips(Dst_Fips, ZIP_FIP)

        Org_Zips = [rand(rng, Org_Zips) for i = 1:5]
        Dst_Zips = [rand(rng, Dst_Zips) for i = 1:5]

        # Car_TT, Flying_TT, Org_Vertiport, Dst_Vertiport, Vert_to_Vert = Return_Travel_Times(Data, Org_Zips[1], Dst_Zips[1])

        Travel_Times = []
        Valid_Demand = 0
        try
            for org_zip in Org_Zips, dst_zip in Dst_Zips
                Car_TT, Flying_TT, Org_Vertiport, Dst_Vertiport, Vert_to_Vert = Return_Travel_Times(Data, org_zip, dst_zip, Sparse_ZIP_OD_TT, Vert_Zips)

                push!(Travel_Times, (Car_TT, Flying_TT, Org_Vertiport, Dst_Vertiport, Vert_to_Vert, org_zip, dst_zip))

                if (Flying_TT < Car_TT) & (Vert_to_Vert < Max_Range)
                    Valid_Demand = 1
                end
            end
        catch
            nothing
        end

        if Valid_Demand == 1
            
            for d = 1:Demand

                Travel_Sample = rand(rng, Travel_Times)

                Car_TT = Travel_Sample[1]
                Flying_TT = Travel_Sample[2]
                Org_Vertiport = Travel_Sample[3]
                Dst_Vertiport = Travel_Sample[4]
                Vert_to_Vert = Travel_Sample[5]
                Org_Zip = Travel_Sample[6]
                Dst_Zip = Travel_Sample[7]

                min_prob = 1/(1+exp(-0.1*(10-demand_alpha)))
                max_prob = 1/(1+exp(-0.1*(100-demand_alpha)))
                prob = (max_prob-min_prob)*rand(rng) + min_prob

                Time_Red = rand(rng, Time_Reds)

                Min_Time_Saved =  Time_Red*Car_TT/100
                Actual_Time_Saved = (Car_TT-Flying_TT)
                Max_Wait_Time = Actual_Time_Saved-Min_Time_Saved

                # Time_Red = (Car_TT-Flying_TT)/Car_TT*100    
                # prob = 1/(1+exp(-0.1*(Time_Red-demand_alpha)))

                if Max_Wait_Time < 10
                    continue
                end

                Max_Wait_Time = maximum([round(Int, Max_Wait_Time/Δt),1])
                
                t = rand(rng, 1:60*5)

                if (t+TT(pathmx[Org_Vertiport,Dst_Vertiport], Δt, Veh_Speed) + 2 <= (Time_Nodes+Buffer)*Δt) & (t <= Time_Nodes*Δt)
                    push!(Demand_Requests, (floor(Int, t/Δt-0.001)+1, Org_Vertiport, Dst_Vertiport, Max_Wait_Time, Car_TT, Flying_TT, Vert_to_Vert, Org_Zip, Dst_Zip, Time_Red, prob, Vert_to_Vert))
                    push!(Demand_Revenues, Vert_to_Vert)
                end
            
            end

        end


    end

    indexs = shuffle(rng, collect(1:length(Demand_Requests)))
    Num_Requests = minimum([round(Int, dem_per_vert_hour*(Time_Nodes)*Num_Vertiports/60), length(Demand_Requests)])

    Demand_Requests = Demand_Requests[indexs[1:Num_Requests]]
    Demand_Revenues = Demand_Revenues[indexs[1:Num_Requests]]

    Data.ED = ED
    Data.Demand_Requests = Demand_Requests
    Data.Demand_Revenues = Demand_Revenues

    Num_Requests = length(Demand_Requests)
    print("Processed $Num_Requests Number of Ride Requests \n")
    


    return Data


end

function Update_Demand_Max(Data, Raw_Demand, demand_max, demand_alpha)

    global rng
    

    ## Extract Local Variables ##
    Buffer = Data.Buffer
    Time_Nodes = Data.Time_Nodes
    Δt = Data.Δt
    Num_Vertiports = Data.Num_Vertiports
    distmx = Data.distmx
    LongLat = Data.LongLat
    Air_Speed = Data.Veh_Speed
    Max_Range = Data.Max_Range
    
    
    ED = zeros(Int, Time_Nodes+Buffer, Num_Vertiports, Num_Vertiports)
    Demand_Requests = []
    Demand_Revenues = []


    for i = 1:Num_Vertiports, j = 1:Num_Vertiports, t = 1:Time_Nodes

        Vert_to_Vert = haversine( (LongLat[string(i-1)][1],LongLat[string(i-1)][2]), (LongLat[string(j-1)][1],LongLat[string(j-1)][2]), 6.371*10^6)

        if (Vert_to_Vert > Max_Range)
            continue
        end
            
        ED[t,i,j] = 1
        push!(Demand_Requests, (t, i, j, 1, 0, 0, 0, 0, 0, 0, 0, 0))
        push!(Demand_Revenues, Vert_to_Vert)
    

    end

     

    Data.ED = ED
    Data.Demand_Requests = Demand_Requests
    Data.Demand_Revenues = Demand_Revenues


    Num_Requests = length(Demand_Requests)
    print("Processed $Num_Requests Number of Ride Requests \n")
    


    return Data


end


function Update_Demand_Fast(Data, dem_per_vert_hour)

    global rng
    

    ## Extract Local Variables ##
    Buffer = Data.Buffer
    Time_Nodes = Data.Time_Nodes
    Δt = Data.Δt
    Num_Vertiports = Data.Num_Vertiports
    distmx = Data.distmx
    LongLat = Data.LongLat
    Air_Speed = Data.Veh_Speed
    

    Total_Number_Requests = round(Int, dem_per_vert_hour*(Time_Nodes)*Num_Vertiports/60)
    
    ED = zeros(Int, Time_Nodes+Buffer, Num_Vertiports, Num_Vertiports)
    Demand_Requests = []
    Demand_Revenues = []


    for d = 1:Total_Number_Requests

        i = sample(rng, collect(1:Num_Vertiports))
        j = sample(rng, collect(1:Num_Vertiports))
        while i == j
            j = sample(rng, collect(1:Num_Vertiports))
        end
        t = sample(rng, collect(1:(Time_Nodes+Buffer)))

        Vert_to_Vert = haversine( (LongLat[string(i-1)][1],LongLat[string(i-1)][2]), (LongLat[string(j-1)][1],LongLat[string(j-1)][2]), 6.371*10^6)
            
        push!(Demand_Requests, (t, i, j, 5, 0, 0, 0, 0, 0, 0, 0, 0))
        push!(Demand_Revenues, Vert_to_Vert)
    

    end


    Data.ED = ED
    Data.Demand_Requests = Demand_Requests
    Data.Demand_Revenues = Demand_Revenues


    Num_Requests = length(Demand_Requests)
    print("Processed $Num_Requests Number of Ride Requests \n")
    


    return Data


end

