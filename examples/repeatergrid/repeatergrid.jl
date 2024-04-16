using QuantumSavory

# For Simulation
using ResumableFunctions
using ConcurrentSim
using QuantumSavory.ProtocolZoo
using Graphs

# For Plotting
using GLMakie
GLMakie.activate!(inline=false)
using NetworkLayout

## Custom Predicates used for local decisions in the swapper protocol running at each node

"""A predicate function that checks if a remote node is in the appropriate quadrant with respect to the local node."""
function check_nodes(net, c_node, node; low=true)
    n = Int(sqrt(size(net.graph)[1])) # grid size
    c_x = c_node%n == 0 ? c_node ÷ n : (c_node ÷ n) + 1
    c_y = c_node - n*(c_x-1)
    x = node%n == 0 ? node ÷ n : (node ÷ n) + 1
    y = node - n*(x-1)
    return low ? (c_x - x) >= 0 && (c_y - y) >= 0 : (c_x - x) <= 0 && (c_y - y) <= 0
end

"""A "cost" function for choosing the furthest node in the appropriate quadrant."""
function distance(n, a, b)
    x1 = a%n == 0 ? a ÷ n : (a ÷ n) + 1
    x2 = b%n == 0 ? b ÷ n : (b ÷ n) + 1
    y1 = a - n*(x1-1)
    y2 = b - n*(x2-1)
    return x1 - x2 + y1 - y2
end

"""A function that chooses the node in the appropriate quadrant that is furthest from the local node."""
function choose_node(net, node, arr; low=true)
    grid_size = Int(sqrt(size(net.graph)[1]))
    return low ? argmax((distance.(grid_size, node, arr))) : argmin((distance.(grid_size, node, arr)))
end

## Simulation

n = 6 # the size of the square grid network (n × n)

graph = grid([n,n])

net = RegisterNet(graph, [Register(8) for i in 1:n^2])

sim = get_time_tracker(net)

# each edge is capable of generating raw link-level entanglement
for (;src, dst) in edges(net)
    eprot = EntanglerProt(sim, net, src, dst; rounds=-1, randomize=true) # TODO needs margin
    @process eprot()
end

# each node except the corners on one of the diagonals is capable of swapping entanglement
for i in 2:(size(graph)[1] - 1)
    l(x) = check_nodes(net, i, x)
    h(x) = check_nodes(net, i, x; low=false)
    cL(arr) = choose_node(net, i, arr)
    cH(arr) = choose_node(net, i, arr; low=false)
    swapper = SwapperProt(sim, net, i; nodeL = l, nodeH = h, chooseL = cL, chooseH = cH, rounds=-1)
    @process swapper()
end

# each node is running entanglement tracking to keep track of classical data about the entanglement
for v in vertices(net)
    tracker = EntanglementTracker(sim, net, v)
    @process tracker()
end

## Visualization
layout = SquareGrid(cols=:auto, dx=10.0, dy=-10.0)(graph)
fig = Figure(resolution=(600, 600))
_, ax, _, obs = registernetplot_axis(fig[1,1], net;registercoords=layout)

display(fig)

step_ts = range(0, 10, step=0.1)
record(fig, "grid_sim6x6hv.mp4", step_ts; framerate=10, visible=true) do t
    run(sim, t)
    notify(obs)
end