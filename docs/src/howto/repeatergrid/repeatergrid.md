# [Entanglement Generation On A Repeater Grid](@id Entanglement-Generation-On-A-Repeater-Grid)

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

This section provides a detailed walkthrough of how QuantumSavory.jl can be used to simulate entanglement generation on a network of repeaters where each repeater relies only on local knowledge of the network.

For this example, we consider a square grid topology in which each node is connected to its nearest neighbors.
The registers act as repeater nodes. The nodes on the diagonal corners are Alice and Bob, the two special nodes that the network is trying to entangle through generating link-level entanglement at each edge and performing appropriate swaps at each node.

The goal is to establish entanglement between Alice and Bob by routing entanglement through any of the possible paths(horizontal or vertical) formed by local entanglement links and then swapping those links by performing entanglement swaps.

This employs functionality from the `ProtocolZoo` module of QuantumSavory to run the following Quantum Networking protocols:

- [`EntanglerProt`](@ref): Entangler protocol to produce link level entanglement at each edge in the network

- [`SwapperKeeper`](@ref): Swapper protocol runs at each node except at the Alice and Bob nodes, to perform swaps. The swaps are performed only if a query deems them useful for propagating entanglement closer and closer to Alice and Bob.

- [`EntanglementTracker`](@ref) Entanglement Tracker protocol to keep track of/and update the local link state-classical knowledge by querying for "entanglement update" messages generated by the other protocols (`SwapperProt` specifically).

All of the above protocols rely on the query and tagging functionality as described in the [Tagging and Querying](@ref tagging-and-querying) section.

Other than that, `ConcurrentSim` and `ResumableFunctions` are used in the backend to run the discrete event simulation. `Graphs` helps with some functionality needed for `RegisterNet` datastructure that forms the grid. `GLMakie` and `NetworkLayout` are used for visualization along with the visualization functionality implemented in `QuantumSavory` itself.

# Custom Predicate And Choosing function

```julia
function check_nodes(net, c_node, node; low=true)
    n = Int(sqrt(size(net.graph)[1])) # grid size
    c_x = c_node%n == 0 ? c_node ÷ n : (c_node ÷ n) + 1
    c_y = c_node - n*(c_x-1)
    x = node%n == 0 ? node ÷ n : (node ÷ n) + 1
    y = node - n*(x-1)
    return low ? (c_x - x) >= 0 && (c_y - y) >= 0 : (c_x - x) <= 0 && (c_y - y) <= 0
end
```

The Swapper Protocol is initialized with a custom predicate function which is then placed in a call to `queryall` inside the Swapper to pick the nodes that are suitable to perform a swap with. The criteria for "suitability" is described below.

This predicate function encodes most of the "logic" a local node will be performing.

The custom predicate function shown above is parametrized with `net` and `c_node` along with the keyword argument `low`, when initializing the Swapper Protocol. This predicate function `Int->Bool` selects the target remote nodes for which a swap is appropriate. The arguments are:

- `net`: The network of register nodes representing the graph structure, an instance of `RegisterNet`.

- `c_node`: The node in which the Swapper protocol would be running.

- `node`: As the [`queryall`](@ref) function goes through all the nodes linked with the current node, the custom predicate filters them depending on whether the node is suitable for a swap or not.

- `low`: The nodes in the grid are numbered as consecutive integers starting from 1. If the Swapper is running at some node n, we want a link closest to Alice and another closest to Bob to perform a swap. We communicate whether we are looking for nodes of the first kind or the latter with the `low` keyword.

Out of all the links at some node, the suitable ones are picked by computing the difference between the coordinates of the current node with the coordinates of the candidate node. A `low` node should have both of the `x` and `y` coordinate difference positive and vice versa for a non-`low` node.

As the Swapper gets a list of suitable candidates for a swap in each direction, the one with the furthest distance from the current node is chosen by summing the x distance and y-distance.

```julia
function choose_node(net, node, arr; low=true)
    grid_size = Int(sqrt(size(net.graph)[1]))
    return low ? argmax((distance.(grid_size, node, arr))) : argmin((distance.(grid_size, node, arr)))
end

function distance(n, a, b)
    x1 = a%n == 0 ? a ÷ n : (a ÷ n) + 1
    x2 = b%n == 0 ? b ÷ n : (b ÷ n) + 1
    y1 = a - n*(x1-1)
    y2 = b - n*(x2-1)

    return x1 - x2 + y1 - y2
end
```

# Simulation and Visualization

```julia
n = 6 # the size of the square grid network (n × n)
regsize = 8 # the size of the quantum registers at each node

graph = grid([n,n])

net = RegisterNet(graph, [Register(regsize, fill(5.0, regsize)) for i in 1:n^2])

sim = get_time_tracker(net)

# each edge is capable of generating raw link-level entanglement
for (;src, dst) in edges(net)
    eprot = EntanglerProt(sim, net, src, dst; rounds=-1, randomize=true)
    @process eprot()
end

# each node except the corners on one of the diagonals is capable of swapping entanglement
for i in 2:(n^2 - 1)
    l(x) = check_nodes(net, i, x)
    h(x) = check_nodes(net, i, x; low=false)
    cL(arr) = choose_node(net, i, arr)
    cH(arr) = choose_node(net, i, arr; low=false)
    swapper = SwapperKeeper(sim, net, i; nodeL = l, nodeH = h, chooseL = cL, chooseH = cH, rounds=-1)
    @process swapper()
end

for v in vertices(net)
    tracker = EntanglementTracker(sim, net, v)
    @process tracker()
end
```

We set up the simulation to run with a 6x6 grid of nodes above. Here, each node has 8 qubit slots.
Each vertical and horizontal edge runs an entanglement generation protocol. Each node in the network runs an entanglement tracker protocol and all of the nodes except the nodes that we're trying to connect, i.e., Alice' and Bob's nodes which are at the diagonal ends of the grid run the swapper protocol. The code that runs and visualizes this simulation is shown below

```julia
fig = Figure(;size=(600, 600))

# the network part of the visualization
layout = SquareGrid(cols=:auto, dx=10.0, dy=-10.0)(graph) # provided by NetworkLayout, meant to simplify plotting of graphs in 2D
_, ax, _, obs = registernetplot_axis(fig[1:2,1], net;registercoords=layout)

# the performance log part of the visualization
entlog = Observable(consumer.log) # Observables are used by Makie to update the visualization in real-time in an automated reactive way
ts = @lift [e[1] for e in $entlog]  # TODO this needs a better interface, something less cluncky, maybe also a whole Makie recipe
tzzs = @lift [Point2f(e[1],e[2]) for e in $entlog]
txxs = @lift [Point2f(e[1],e[3]) for e in $entlog]
Δts = @lift length($ts)>1 ? $ts[2:end] .- $ts[1:end-1] : [0.0]
entlogaxis = Axis(fig[1,2], xlabel="Time", ylabel="Entanglement", title="Entanglement Successes")
ylims!(entlogaxis, (-1.04,1.04))
stem!(entlogaxis, tzzs)
histaxis = Axis(fig[2,2], xlabel="ΔTime", title="Histogram of Time to Successes")
hist!(histaxis, Δts)

display(fig)

step_ts = range(0, 200, step=0.1)
record(fig, "grid_sim6x6hv.mp4", step_ts; framerate=10, visible=true) do t
    run(sim, t)
    notify.((obs,entlog))
    ylims!(entlogaxis, (-1.04,1.04))
    xlims!(entlogaxis, max(0,t-50), 1+t)
    autolimits!(histaxis)
end

```

# Result

```@repl
include("../../../../examples/repeatergrid/repeatergrid_async.jl") # hide
```

```@raw html
<video src="../grid_sim6x6hv.mp4" autoplay loop muted></video>
```