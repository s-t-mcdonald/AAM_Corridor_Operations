using SparseArrays, Graphs
using Base.Threads

struct NegativeCycleError <: Exception end



function bellman_ford_shortest_paths_mod(
    graph, sources, distmx, travel_distmx, max_endurance)

    nvg = nv(graph)
    active = falses(nvg)
    active[sources] = true
    dists = fill(typemax(1.1), nvg)
    travel_dists = fill(0.0, nvg)
    open_probs = fill(0, nvg)
    init_prob = 1
    parents = zeros(Int, nvg)
    dists[sources] = 0
    travel_dists[sources] = 0
    no_changes = false
    new_active = falses(nvg)

    for i in vertices(graph)
        no_changes = true
        new_active .= false
        for u in vertices(graph)[active]
            for v in outneighbors(graph, u)

                relax_dist = distmx[u, v] + dists[u] 
                relaxed_travel_dist = travel_distmx[u,v] + travel_dists[u]
                
                if (dists[v] > relax_dist) & (travel_dists[v] < max_endurance)
                    dists[v] = relax_dist
                    travel_dists[v] = relaxed_travel_dist
                    parents[v] = u
                    no_changes = false
                    new_active[v] = true
                end
            end
        end
        if no_changes
            break
        end
        active, new_active = new_active, active
    end
    no_changes || throw(NegativeCycleError())
    return Graphs.BellmanFordState(parents, dists)
end


function construct_tsg(Data, weather_closures_pred, pp_algo, Fix_Dir)

    type = split(pp_algo, "_")[1]

    Time_Nodes = Data.Time_Nodes #number of discretized time nodes
    Buffer = Data.Buffer
    Num_Vertiports = Data.Num_Vertiports #number of vertiports
    Num_Corridors = Data.Num_Corridors #Number of Corridors
    Num_Lanes = Data.Num_Lanes #Number of Corridors
    C = Data.Corridors # Corridor List
    Node_Neighbor = Data.Node_Neighbor
    Δt = Data.Δt
    Veh_Speed = Data.Veh_Speed
    Corridors = Data.Corridors # Corridor List
    distmx = Data.distmx
    C_dist = Data.C_dist
    Corridor_Dist = Data.Corridor_Dist
    
    
    Nodes = length(Node_Neighbor)

    Time_Nodes = Time_Nodes
    Buffer = Buffer

    A = zeros(Time_Nodes+Buffer, Nodes, Num_Lanes)
    B = zeros(Time_Nodes+Buffer, Num_Vertiports)
    C = zeros(Num_Vertiports)

    A_Linear_Ind = LinearIndices(A)
    A_Cartesian_Ind = CartesianIndices(A)

    B_Linear_Ind = LinearIndices(B)
    B_Cartesian_Ind = CartesianIndices(B)
    B_offset = length(A_Cartesian_Ind)

    C_Linear_Ind = LinearIndices(C)
    C_Cartesian_Ind = CartesianIndices(C)
    C_offset = B_offset + length(B_Cartesian_Ind)

    Graph_Nodes = length(C_Cartesian_Ind) + C_offset

    g = DiGraph(Graph_Nodes)

    weight_mx = spzeros(Graph_Nodes, Graph_Nodes)
    for t = 1:Time_Nodes+Buffer, c = 1:Num_Corridors

        i = Corridors[c][1]
        j = Corridors[c][2]

        dist = Corridor_Dist[c]

        if t+TT(dist, Δt, Veh_Speed) > Time_Nodes+Buffer
            continue
        end

        close_val = sum(weather_closures_pred[t:t+TT(dist, Δt, Veh_Speed),i]) + sum(weather_closures_pred[t:t+TT(dist, Δt, Veh_Speed),j])

        if close_val > 0.5
            continue
        end

       
        for l = 1:Num_Lanes
            if (type == "forward")
                add_edge!(g, A_Linear_Ind[t,i,l], A_Linear_Ind[t+TT(dist, Δt, Veh_Speed),j,l])
                add_edge!(g, A_Linear_Ind[t,j,l], A_Linear_Ind[t+TT(dist, Δt, Veh_Speed),i,l])
            elseif  type == "backward"
                add_edge!(g, A_Linear_Ind[t+TT(dist, Δt, Veh_Speed),j,l], A_Linear_Ind[t,i,l])
                add_edge!(g, A_Linear_Ind[t+TT(dist, Δt, Veh_Speed),i,l], A_Linear_Ind[t,j,l])
            end
        end


    end


    return g, weight_mx
end


function update_weight_mx(Data, RMP, Φ_e_dual, Φ_w_dual, type)

    
    Time_Nodes = Data.Time_Nodes #number of discretized time nodes
    Num_Corridors = Data.Num_Corridors #Number of Corridors
    Num_Lanes = Data.Num_Lanes #Number of Corridors
    Corridors = Data.Corridors # Corridor List
    Δt = Data.Δt
    Veh_Speed = Data.Veh_Speed
    distmx =  Data.distmx
    Buffer = Data.Buffer
    Corridor_Dist = Data.Corridor_Dist
    ED = Data.ED
    Con_Matrix = Data.Con_Matrix
    Node_Neighbor = Data.Node_Neighbor
    Demand_Requests = Data.Demand_Requests
    Num_Requests = length(Demand_Requests)
    Num_Vertiports = Data.Num_Vertiports


    Nodes = length(Node_Neighbor)

    Time_Nodes = Time_Nodes
    Buffer = Buffer

    A = zeros(Time_Nodes+Buffer, Nodes, Num_Lanes)
    B = zeros(Time_Nodes+Buffer, Num_Vertiports)
    C = zeros(Num_Vertiports)

    A_Linear_Ind = LinearIndices(A)
    A_Cartesian_Ind = CartesianIndices(A)

    B_Linear_Ind = LinearIndices(B)
    B_Cartesian_Ind = CartesianIndices(B)
    B_offset = length(A_Cartesian_Ind)

    C_Linear_Ind = LinearIndices(C)
    C_Cartesian_Ind = CartesianIndices(C)
    C_offset = B_offset + length(B_Cartesian_Ind)

    Graph_Nodes = length(C_Cartesian_Ind) + C_offset

    # ind1 = findall(x -> abs(x) > 0.001, Φ_e_dual)
    # ind2 = findall(x -> abs(x) > 0.001, Φ_e_dual)

    prob_mx = spzeros(Graph_Nodes) 

    is = Int[]
    js = Int[]
    vs = Float64[]

    is_trav = Int[]
    js_trav = Int[]
    vs_trav = Float64[]

    for l = 1:Num_Lanes, t = 1:Time_Nodes+Buffer, c = 1:Num_Corridors

        n1 = Corridors[c][1]
        n2 = Corridors[c][2]

        dist = Corridor_Dist[c]

        if t+TT(dist, Δt, Veh_Speed) > Time_Nodes+Buffer
            continue
        end

        # weight_mx[A_Linear_Ind[t,n1,l], A_Linear_Ind[t+TT(dist, Δt, Veh_Speed),n2,l]] = distmx[n1,n2]  + Φ_e_dual[t,c,l] 
        # weight_mx[A_Linear_Ind[t,n2,l], A_Linear_Ind[t+TT(dist, Δt, Veh_Speed),n1,l]] = distmx[n2,n1]  + Φ_w_dual[t,c,l] 

        push!(is, A_Linear_Ind[t,n1,l])
        push!(js, A_Linear_Ind[t+TT(dist, Δt, Veh_Speed),n2,l])
        push!(vs, distmx[n1,n2]  + Φ_e_dual[t,c,l] )

        push!(is, A_Linear_Ind[t,n2,l])
        push!(js, A_Linear_Ind[t+TT(dist, Δt, Veh_Speed),n1,l])
        push!(vs, distmx[n2,n1]  + Φ_w_dual[t,c,l] )


        push!(is_trav, A_Linear_Ind[t,n1,l])
        push!(js_trav, A_Linear_Ind[t+TT(dist, Δt, Veh_Speed),n2,l])
        push!(vs_trav, distmx[n1,n2])

        push!(is_trav, A_Linear_Ind[t,n2,l])
        push!(js_trav, A_Linear_Ind[t+TT(dist, Δt, Veh_Speed),n1,l])
        push!(vs_trav, distmx[n2,n1])

        

    end


    if type == "forward"
        weight_mx = sparse(is, js, vs, Graph_Nodes, Graph_Nodes)
        travel_dist_mx = sparse(is_trav, js_trav, vs_trav, Graph_Nodes, Graph_Nodes)
    elseif type == "backward"
        weight_mx = sparse(js, is, vs, Graph_Nodes, Graph_Nodes)
        travel_dist_mx = sparse(js_trav, is_trav, vs_trav, Graph_Nodes, Graph_Nodes)
    end

    return weight_mx, travel_dist_mx, prob_mx

end


function backward_one(Data, D, Dists, New_Route_Desc, g, weight_mx, RMP)

    type = "backward"
    
    Time_Nodes = Data.Time_Nodes #number of discretized time nodes
    Num_Vertiports = Data.Num_Vertiports #number of vertiports
    Num_Lanes = Data.Num_Lanes #Number of Corridors
    C = Data.Corridors # Corridor List
    Node_Neighbor = Data.Node_Neighbor
    distmx =  Data.distmx
    Corridor_Mat = Data.Corridor_Mat
    Buffer = Data.Buffer
    Con_Matrix = Data.Con_Matrix
    Max_Range = Data.Max_Range

    Nodes = length(Node_Neighbor)

    Time_Nodes = Time_Nodes
    Buffer = Buffer

    A = zeros(Time_Nodes+Buffer, Nodes, Num_Lanes)
    B = zeros(Time_Nodes+Buffer, Num_Vertiports)
    C = zeros(Num_Vertiports)

    A_Linear_Ind = LinearIndices(A)
    A_Cartesian_Ind = CartesianIndices(A)

    B_Linear_Ind = LinearIndices(B)
    B_Cartesian_Ind = CartesianIndices(B)
    B_offset = length(A_Cartesian_Ind)

    C_Linear_Ind = LinearIndices(C)
    C_Cartesian_Ind = CartesianIndices(C)
    C_offset = B_offset + length(B_Cartesian_Ind)

    Graph_Nodes = length(C_Cartesian_Ind) + C_offset

    obj = objective_value(RMP["Model"])
    λ = RMP["λ"]
    κ = RMP["κ"]
    γ = RMP["γ"]
    β = RMP["β"]
    Φ_e = RMP["Φ_e"]
    Φ_w = RMP["Φ_w"]
    Φ_e = RMP["Φ_e"]
    Φ_w = RMP["Φ_w"]

    

    λ_dual_current = dual.(λ)
    κ_dual_current = dual.(κ)
    γ_dual_current = dual.(γ)
    β_dual_current = dual.(β)
    Φ_e_dual_current = dual.(Φ_e)
    Φ_w_dual_current = dual.(Φ_w)

    

    λ_dual = λ_dual_current
    κ_dual = κ_dual_current
    γ_dual = γ_dual_current
    β_dual = β_dual_current
    Φ_e_dual = Φ_e_dual_current
    Φ_w_dual = Φ_w_dual_current

  

    weight_mx, travel_dist_mx, prob_mx = update_weight_mx(Data, RMP, Φ_e_dual, Φ_w_dual, type)



    reduced_cost_min = 10^10
    pp_solve_time = 0
    var_added = 0

    for j = 1:Num_Vertiports

        for t = 1:Time_Nodes+Buffer

            for i = 1:Num_Vertiports
                if i == j
                    continue
                end

                if Con_Matrix[t,i,j] == -1
                    for l = 1:Num_Lanes
                        add_edge!(g, A_Linear_Ind[t,i,l], B_Linear_Ind[t,i]+B_offset)
                        rem_edge!(g, B_Linear_Ind[t,i]+B_offset, A_Linear_Ind[t,i,l])
                        weight_mx[A_Linear_Ind[t,i,l], B_Linear_Ind[t,i]+B_offset] = -( -λ_dual[t,i] - β_dual[t,i]) 
                    end  
                else
                    for l = 1:Num_Lanes
                        add_edge!(g, A_Linear_Ind[t,i,l], B_Linear_Ind[t,i]+B_offset)
                        rem_edge!(g, B_Linear_Ind[t,i]+B_offset, A_Linear_Ind[t,i,l])
                        weight_mx[A_Linear_Ind[t,i,l], B_Linear_Ind[t,i]+B_offset] = -( -λ_dual[t,i] - β_dual[t,i] + γ_dual[Con_Matrix[t,i,j]] ) 
                    end  
                end
                add_edge!(g, B_Linear_Ind[t,i]+B_offset, C_Linear_Ind[i]+C_offset)
                rem_edge!(g, C_Linear_Ind[i]+C_offset, B_Linear_Ind[t,i]+B_offset)

                
            end


            for l = 1:Num_Lanes
                add_edge!(g, B_Linear_Ind[t,j]+B_offset, A_Linear_Ind[t,j,l])
                rem_edge!(g, A_Linear_Ind[t,j,l], B_Linear_Ind[t,j]+B_offset)
                weight_mx[B_Linear_Ind[t,j]+B_offset, A_Linear_Ind[t,j,l]] = -κ_dual[t,j] 
            end   
            add_edge!(g, C_Linear_Ind[j]+C_offset, B_Linear_Ind[t,j]+B_offset) 
            rem_edge!(g, B_Linear_Ind[t,j]+B_offset, C_Linear_Ind[j]+C_offset)

        end

        weight_mx_tr = weight_mx#sparse(transpose(weight_mx))

        t_p_bell = @elapsed path_state = bellman_ford_shortest_paths_mod(g,C_Linear_Ind[j]+C_offset, weight_mx_tr, travel_dist_mx, Max_Range)

        t_p = 0
    
        pp_solve_time = pp_solve_time + t_p_bell

        for i = 1:Num_Vertiports
            if i == j 
                continue
            end
            path = enumerate_paths(path_state, C_Linear_Ind[i]+C_offset)

            if path == []
                # print("vertiport $i to vertiport $j\n")
                continue
            end

            weight = sum([weight_mx_tr[path[p],path[p+1]] for p = 1:length(path)-1]) 

            path = reverse(path) 
            dist = sum([distmx[A_Cartesian_Ind[path[p]][2],A_Cartesian_Ind[path[p+1]][2]] for p = 3:length(path)-3])

            # prob = prod([open_prob_mx[A_Cartesian_Ind[path[p]][1],A_Cartesian_Ind[path[p]][2]] for p = 3:length(path)-2])

            
            t = A_Cartesian_Ind[path[3]][1]
            k = A_Cartesian_Ind[path[end-2]][1]

            reduced_cost_min = minimum([reduced_cost_min, sign(weight)*abs(weight/obj)])

            if (sign(weight)*abs(weight/obj) < -10^-5) 

                var_added = var_added + 1

                push!(D, @variable(RMP["Model"], lower_bound = 0))

                if Con_Matrix[t,i,j] == -1
                    set_normalized_coefficient(λ[t,i], D[end], -1)
                    set_normalized_coefficient(β[t,i], D[end], -1)   
                else
                    set_normalized_coefficient(λ[t,i], D[end], -1)
                    set_normalized_coefficient(β[t,i], D[end], -1)   
                    set_normalized_coefficient(γ[Con_Matrix[t,i,j]], D[end], 1)
                end
          
                set_normalized_coefficient(κ[k,j], D[end], 1)

                for p = 3:length(path)-3

                    ind1 = A_Cartesian_Ind[path[p]]
                    ind2 = A_Cartesian_Ind[path[p+1]]

                    t1,n1,l = ind1[1], ind1[2], ind1[3]
                    t2,n2 = ind2[1], ind2[2]

                    if Corridor_Mat[n1,n2] > 0
                        set_normalized_coefficient(Φ_e[t1,Corridor_Mat[n1,n2],l], D[end], -1)
                    else
                        set_normalized_coefficient(Φ_w[t1,Corridor_Mat[n2,n1],l], D[end], -1)
                    end
                
                end

                ind1 = A_Cartesian_Ind[path[3]]

                t1,n1,l = ind1[1], ind1[2], ind1[3]

                push!(Dists, dist)

                k = length(D)
                new_path = [i]
                new_times = [t]

                for p = 3:length(path)-2
                    global l_val

                    ind = A_Cartesian_Ind[path[p]]

                    t_new,n_new,l_val = ind[1], ind[2], ind[3]

                    push!(new_times, t_new)
                    push!(new_path, n_new)
                
                end

                push!(New_Route_Desc, (k, t, new_path, new_times, l_val))

            end

        end
    end

    Margin = Data.Margin
    Demand_Revenues = Data.Demand_Revenues
    Weights = Data.Weights
    Route_Vec = Data.Route_Vec
    Demand_Requests = Data.Demand_Requests
    Num_Requests = length(Demand_Requests)
    RD = RMP["RD"]
    R = RMP["R"]

    @objective(RMP["Model"], Min, sum((Margin)*Demand_Revenues[n]*RD[n] for n = 1:Num_Requests) + sum(Weights[n]*R[n] for n = 1:length(Route_Vec)) + sum(Dists[d]*D[d] for d = 1:length(D)) );
    
    return D, Dists, New_Route_Desc, reduced_cost_min, pp_solve_time, var_added
end


function forward_one(Data, D, Dists, New_Route_Desc, g, weight_mx, RMP)

    type = "forward"
    
    Time_Nodes = Data.Time_Nodes #number of discretized time nodes
    Num_Vertiports = Data.Num_Vertiports #number of vertiports
    Num_Lanes = Data.Num_Lanes #Number of Corridors
    C = Data.Corridors # Corridor List
    Node_Neighbor = Data.Node_Neighbor
    distmx =  Data.distmx
    Corridor_Mat = Data.Corridor_Mat
    Buffer = Data.Buffer
    Con_Matrix = Data.Con_Matrix
    Max_Range = Data.Max_Range

    Nodes = length(Node_Neighbor)

    Time_Nodes = Time_Nodes
    Buffer = Buffer

    A = zeros(Time_Nodes+Buffer, Nodes, Num_Lanes)
    B = zeros(Time_Nodes+Buffer, Num_Vertiports)
    C = zeros(Num_Vertiports)

    A_Linear_Ind = LinearIndices(A)
    A_Cartesian_Ind = CartesianIndices(A)

    B_Linear_Ind = LinearIndices(B)
    B_Cartesian_Ind = CartesianIndices(B)
    B_offset = length(A_Cartesian_Ind)

    C_Linear_Ind = LinearIndices(C)
    C_Cartesian_Ind = CartesianIndices(C)
    C_offset = B_offset + length(B_Cartesian_Ind)

    Graph_Nodes = length(C_Cartesian_Ind) + C_offset

    obj = objective_value(RMP["Model"])
    λ = RMP["λ"]
    κ = RMP["κ"]
    γ = RMP["γ"]
    β = RMP["β"]
    Φ_e = RMP["Φ_e"]
    Φ_w = RMP["Φ_w"]
    Φ_e = RMP["Φ_e"]
    Φ_w = RMP["Φ_w"]

    

    λ_dual_current = dual.(λ)
    κ_dual_current = dual.(κ)
    γ_dual_current = dual.(γ)
    β_dual_current = dual.(β)
    Φ_e_dual_current = dual.(Φ_e)
    Φ_w_dual_current = dual.(Φ_w)

    

    λ_dual = λ_dual_current
    κ_dual = κ_dual_current
    γ_dual = γ_dual_current
    β_dual = β_dual_current
    Φ_e_dual = Φ_e_dual_current
    Φ_w_dual = Φ_w_dual_current

  

    weight_mx, travel_dist_mx, prob_mx = update_weight_mx(Data, RMP, Φ_e_dual, Φ_w_dual, type)



    reduced_cost_min = 10^10
    pp_solve_time = 0
    var_added = 0

    for i = 1:Num_Vertiports, j = 1:Num_Vertiports



        if i == j
            continue
        end

        for t = 1:Time_Nodes+Buffer
            if Con_Matrix[t,i,j] == -1
                for l = 1:Num_Lanes
                    rem_edge!(g, A_Linear_Ind[t,i,l], B_Linear_Ind[t,i]+B_offset)
                    add_edge!(g, B_Linear_Ind[t,i]+B_offset, A_Linear_Ind[t,i,l])
                    weight_mx[B_Linear_Ind[t,i]+B_offset, A_Linear_Ind[t,i,l]] = -( -λ_dual[t,i] - β_dual[t,i]) 
                end  
            else
                for l = 1:Num_Lanes
                    rem_edge!(g, A_Linear_Ind[t,i,l], B_Linear_Ind[t,i]+B_offset)
                    add_edge!(g, B_Linear_Ind[t,i]+B_offset, A_Linear_Ind[t,i,l])
                    weight_mx[B_Linear_Ind[t,i]+B_offset,A_Linear_Ind[t,i,l]] = -( -λ_dual[t,i] - β_dual[t,i] + γ_dual[Con_Matrix[t,i,j]] ) 
                end  
            end
            rem_edge!(g, B_Linear_Ind[t,i]+B_offset, C_Linear_Ind[i]+C_offset)
            add_edge!(g, C_Linear_Ind[i]+C_offset, B_Linear_Ind[t,i]+B_offset)

            for l = 1:Num_Lanes
                rem_edge!(g, B_Linear_Ind[t,j]+B_offset, A_Linear_Ind[t,j,l])
                add_edge!(g, A_Linear_Ind[t,j,l], B_Linear_Ind[t,j]+B_offset)
                weight_mx[A_Linear_Ind[t,j,l], B_Linear_Ind[t,j]+B_offset] = -κ_dual[t,j] 
            end   
            rem_edge!(g, C_Linear_Ind[j]+C_offset, B_Linear_Ind[t,j]+B_offset) 
            add_edge!(g, B_Linear_Ind[t,j]+B_offset, C_Linear_Ind[j]+C_offset)
        end

        weight_mx_tr = weight_mx#sparse(transpose(weight_mx))

        t_p_bell = @elapsed path_state = bellman_ford_shortest_paths_mod(g,C_Linear_Ind[i]+C_offset, weight_mx_tr, travel_dist_mx, Max_Range)

        t_p = 0
    
        pp_solve_time = pp_solve_time + t_p_bell

        path = enumerate_paths(path_state, C_Linear_Ind[j]+C_offset)

        if path == []
            # print("vertiport $i to vertiport $j\n")
            continue
        end

        weight = sum([weight_mx_tr[path[p],path[p+1]] for p = 1:length(path)-1]) 

        dist = sum([distmx[A_Cartesian_Ind[path[p]][2],A_Cartesian_Ind[path[p+1]][2]] for p = 3:length(path)-3])

        t = A_Cartesian_Ind[path[3]][1]
        k = A_Cartesian_Ind[path[end-2]][1]

        reduced_cost_min = minimum([reduced_cost_min, sign(weight)*abs(weight/obj)])

        if (sign(weight)*abs(weight/obj) < -10^-5) 

            var_added = var_added + 1

            push!(D, @variable(RMP["Model"], lower_bound = 0))

            if Con_Matrix[t,i,j] == -1
                set_normalized_coefficient(λ[t,i], D[end], -1)
                set_normalized_coefficient(β[t,i], D[end], -1)   
            else
                set_normalized_coefficient(λ[t,i], D[end], -1)
                set_normalized_coefficient(β[t,i], D[end], -1)   
                set_normalized_coefficient(γ[Con_Matrix[t,i,j]], D[end], 1)
            end
    
            set_normalized_coefficient(κ[k,j], D[end], 1)

            for p = 3:length(path)-3

                ind1 = A_Cartesian_Ind[path[p]]
                ind2 = A_Cartesian_Ind[path[p+1]]

                t1,n1,l = ind1[1], ind1[2], ind1[3]
                t2,n2 = ind2[1], ind2[2]

                if Corridor_Mat[n1,n2] > 0
                    set_normalized_coefficient(Φ_e[t1,Corridor_Mat[n1,n2],l], D[end], -1)
                else
                    set_normalized_coefficient(Φ_w[t1,Corridor_Mat[n2,n1],l], D[end], -1)
                end
            
            end

            ind1 = A_Cartesian_Ind[path[3]]

            t1,n1,l = ind1[1], ind1[2], ind1[3]

            push!(Dists, dist)

            k = length(D)
            new_path = [i]
            new_times = [t]

            for p = 3:length(path)-2
                global l_val

                ind = A_Cartesian_Ind[path[p]]

                t_new,n_new,l_val = ind[1], ind[2], ind[3]

                push!(new_times, t_new)
                push!(new_path, n_new)
            
            end

            push!(New_Route_Desc, (k, t, new_path, new_times, l_val))

        end

    end

    Margin = Data.Margin
    Demand_Revenues = Data.Demand_Revenues
    Weights = Data.Weights
    Route_Vec = Data.Route_Vec
    Demand_Requests = Data.Demand_Requests
    Num_Requests = length(Demand_Requests)
    RD = RMP["RD"]
    R = RMP["R"]

    @objective(RMP["Model"], Min, sum((Margin)*Demand_Revenues[n]*RD[n] for n = 1:Num_Requests) + sum(Weights[n]*R[n] for n = 1:length(Route_Vec)) + sum(Dists[d]*D[d] for d = 1:length(D)) );
    
    return D, Dists, New_Route_Desc, reduced_cost_min, pp_solve_time, var_added
end


