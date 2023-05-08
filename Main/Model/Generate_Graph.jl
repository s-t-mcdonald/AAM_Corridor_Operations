# Syntax    Generate_Graph(dist, Δt, Veh_Speed)
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
using Graphs, Distributions, SparseArrays, Plots, Random, LinearAlgebra
import LazySets

function return_dist(point1, point2)

    diff = point1-point2
    val = diff.^2
    dist = sqrt(sum(val))

    return dist
end

function angle(a, b)
    return acosd(clamp(a⋅b/(norm(a)*norm(b)), -1, 1))
end



function Generate_Graph(Number_Nodes, Number_Vertiports, Ang_Cutoff)

    global rng
    
    g = SimpleGraph(Number_Nodes)
    
    Vertiport_Locations = rand(rng, Uniform(0,1), 2, Number_Vertiports)
    Nodes_Locations = rand(rng, Uniform(0,1), 2, Number_Nodes)
    
    Edges = Dict()
    LongLat = Dict()
    
    # Make Fully Connected
    for n1 = 1:Number_Nodes-1, n2 = n1+1:Number_Nodes
        add_edge!(g,n1,n2)
    end
    
    Flag = true
    while Flag
        Flag = false
    
        for n11 = 1:Number_Nodes-1, n12 = n11+1:Number_Nodes
            for n21 = 1:Number_Nodes-1, n22 = n21+1:Number_Nodes
                
                if (n11 ∈ [n21, n22]) | (n12 ∈ [n21, n22])
                    continue
                end
    
                if (!has_edge(g, n11, n12)) | (!has_edge(g, n21, n22))
                    continue
                end
    
                ls1 = LazySets.LineSegment(Nodes_Locations[:,n11], Nodes_Locations[:,n12])
                ls2 = LazySets.LineSegment(Nodes_Locations[:,n21], Nodes_Locations[:,n22])
    
                if LazySets.isdisjoint(ls1, ls2)
                    continue
                end
    
                dist1 = return_dist(Nodes_Locations[:,n11], Nodes_Locations[:,n12])
                dist2 = return_dist(Nodes_Locations[:,n21], Nodes_Locations[:,n22])
    
                if dist1 > dist2
                    rem_edge!(g, n11, n12)
                else
                    rem_edge!(g, n21, n22)
                end
    
                Flag = true
    
            end
        end
        
        
    end
    
    for n = 1:Number_Nodes
        nei = neighbors(g, n)
        
        for n1 ∈ nei, n2 ∈ nei
            if n1 == n2 
                continue
            end
            
            dist1 = return_dist(Nodes_Locations[:,n], Nodes_Locations[:,n1])
            dist2 = return_dist(Nodes_Locations[:,n], Nodes_Locations[:,n2])
            
            vec1 = Nodes_Locations[:,n1] - Nodes_Locations[:,n]
            vec2 = Nodes_Locations[:,n2] - Nodes_Locations[:,n]
            
            ang = angle(vec1, vec2)
            
            if ang < Ang_Cutoff
                if dist1 > dist2
                    rem_edge!(g, n, n1)
                else
                    rem_edge!(g, n, n2)
                end
            end
        end
    end
                
    
    
    final_g = SimpleGraph(Number_Vertiports + Number_Nodes)
    DistMx = spzeros(Number_Vertiports + Number_Nodes, Number_Vertiports + Number_Nodes)
    
    for v = 1:Number_Vertiports
        Shortest_N = 0
        Min_Dist = Inf
        for n = 1:Number_Nodes
            dist = return_dist(Vertiport_Locations[:,v], Nodes_Locations[:,n])
            if dist < Min_Dist
                Min_Dist = dist
                Shortest_N = n
            end
        end
    
        DistMx[v,Shortest_N] = Min_Dist
        DistMx[Shortest_N,v] = Min_Dist
        add_edge!(final_g, v, Shortest_N+Number_Vertiports)
    end
    
    for e ∈ edges(g)
        src = e.src
        dst = e.dst
    
        dist = return_dist(Nodes_Locations[:,src], Nodes_Locations[:,dst])
    
        add_edge!(final_g, src+Number_Vertiports, dst+Number_Vertiports)
        DistMx[src+Number_Vertiports, dst+Number_Vertiports] = dist
        DistMx[dst+Number_Vertiports, src+Number_Vertiports] = dist
    
    end

    k = 1
    for e ∈ edges(final_g)
        Edges[string(k)] = [round(Int,e.src), round(Int,e.dst), DistMx[e.src,e.dst]*100000]
        k = k + 1
    end
    
    Edges["Nodes"] = nv(final_g)
    Edges["Edges"] = ne(final_g)
    Edges["Number_of_Vertiports"] = Number_Vertiports
    
    for k = 1:Number_Vertiports
        LongLat[string(k-1)] = Vertiport_Locations[:,k]
    end
    
    for k = 1:Number_Nodes
        LongLat[string(k+Number_Vertiports-1)] = Nodes_Locations[:,k]
    end
    
    Point_Locations_X = [Vertiport_Locations[1,:]..., Nodes_Locations[1,:]...];
    Point_Locations_Y = [Vertiport_Locations[2,:]..., Nodes_Locations[2,:]...];


    p = plot()
    scatter!(p, Vertiport_Locations[1,:], Vertiport_Locations[2,:], markercolor=:blue, markersize=8);
    scatter!(p, Nodes_Locations[1,:], Nodes_Locations[2,:], markercolor=:red);

    for e ∈ edges(final_g)
        src = e.src
        dst = e.dst
        plot!(p, [Point_Locations_X[src], Point_Locations_X[dst]], [Point_Locations_Y[src], Point_Locations_Y[dst]], legend = false, linecolor=:green);
    end

    return Edges, LongLat, p
    
end

function Generate_Graph_Old(Number_Nodes, Number_Vertiports, Cutoff, Seed)
    
    min_cutoff = 0
    while true
        g, dists, points = euclidean_graph(Number_Nodes,2,cutoff=min_cutoff, seed=Seed)

        min_cutoff = min_cutoff + 0.01

        if is_connected(g)
            break
        end
    end

    Cutoff_Val = min_cutoff + (1-min_cutoff)*Cutoff
    g, dists, points = euclidean_graph(Number_Nodes,2,cutoff=Cutoff_Val, seed=Seed)
    
    Edges = Dict()
    LongLat = Dict()

    k = 1
    for e ∈ edges(g)
        Edges[string(k)] = [round(Int,e.src), round(Int,e.dst), dists[e]*80467.2]
        k = k + 1
    end

    Edges["Nodes"] = nv(g)
    Edges["Edges"] = ne(g)
    Edges["Number_of_Vertiports"] = Number_Vertiports
        
    for k = 1:Number_Nodes
        LongLat[string(k-1)] = points[:,k]
    end
    
    return Edges, LongLat
    
end
   