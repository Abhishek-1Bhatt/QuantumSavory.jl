"""$TYPEDSIGNATURES

Assign a tag to a slot in a register.

See also: [`query`](@ref), [`untag!`](@ref)"""
function tag!(ref::RegRef, tag::Tag)
    id = guid()
    push!(ref.reg.guids, id)
    ref.reg.tag_info[id] = (tag, ref.idx, now(get_time_tracker(ref)))

    ref.reg.slot_guid[ref.idx] = id
end

tag!(ref, tag) = tag!(ref,Tag(tag))


"""$TYPEDSIGNATURES

Removes the first instance of tag from the list to tags associated with a [`RegRef`](@ref) in a [`Register`](@ref)

See also: [`query`](@ref), [`tag!`](@ref)
"""
function untag!(ref::RegRef, id::Int128)
    i = findfirst(==(id), ref.reg.guids)
    isnothing(i) ? throw(KeyError(tag)) : deleteat!(ref.reg.guids, i) # TODO make sure there is a clear error message
    delete!(ref.reg.tag_info, id)
    ref.reg.slot_guid[ref.idx] = -1
end


"""Wildcard type for use with the tag querying functionality.

Usually you simply want an instance of this type (available as the constant [`W`](@ref) or [`❓`](@ref)).

See also: [`query`](@ref), [`tag!`](@ref)"""
struct Wildcard end


"""A wildcard instance for use with the tag querying functionality.

See also: [`query`](@ref), [`tag!`](@ref), [`❓`](@ref)"""
const W = Wildcard()


"""A wildcard instance for use with the tag querying functionality.

This emoji can be inputted with the `\\:question:` emoji shortcut,
or you can simply use the ASCII alternative [`W`](@ref).

See also: [`query`](@ref), [`tag!`](@ref), [`W`](@ref)"""
const ❓ = W


"""
$TYPEDSIGNATURES

A query function that returns all slots of a register that have a given tag, with support for predicates and wildcards.


```jldoctest; filter = r"id = (\\d*), "
julia> r = Register(10);
       tag!(r[1], :symbol, 2, 3);
       tag!(r[2], :symbol, 4, 5);

julia> queryall(r, :symbol, ❓, ❓)
2-element Vector{@NamedTuple{slot::RegRef, id::Int128, tag::Tag}}:
 (slot = Slot 2, id = 2, tag = SymbolIntInt(:symbol, 4, 5)::Tag)
 (slot = Slot 1, id = 1, tag = SymbolIntInt(:symbol, 2, 3)::Tag)

julia> queryall(r, :symbol, ❓, >(4))
1-element Vector{@NamedTuple{slot::RegRef, id::Int128, tag::Tag}}:
 (slot = Slot 2, id = 2, tag = SymbolIntInt(:symbol, 4, 5)::Tag)

julia> queryall(r, :symbol, ❓, >(5))
@NamedTuple{slot::RegRef, id::Int128, tag::Tag}[]
```
"""
queryall(args...; filo=true, kwargs...) = query(args..., Val{true}(); filo, kwargs...)

"""
$TYPEDSIGNATURES

A query function searching for the first slot in a register that has a given tag.

Wildcards are supported (instances of `Wildcard` also available as the constants [`W`](@ref) or the emoji [`❓`](@ref) which can be entered as `\\:question:` in the REPL).
Predicate functions are also supported (they have to be `Int`↦`Bool` functions).
The order of query lookup can be specified in terms of FIFO or FILO and defaults to FILO if not specified.
The keyword arguments `locked` and `assigned` can be used to check, respectively,
whether the given slot is locked or whether it contains a quantum state.
The keyword argument `filo` can be used to specify whether the search should be done in a FIFO or FILO order,
defaulting to `filo=true` (i.e. a stack-like behavior).

```jldoctest; filter = r"id = (\\d*), "
julia> r = Register(10);
       tag!(r[1], :symbol, 2, 3);
       tag!(r[2], :symbol, 4, 5);


julia> query(r, :symbol, 4, 5)
(slot = Slot 2, id = 4, tag = SymbolIntInt(:symbol, 4, 5)::Tag)

julia> lock(r[1]);

julia> query(r, :symbol, 4, 5; locked=false) |> isnothing
false

julia> query(r, :symbol, ❓, 3)
(slot = Slot 1, id = 3, tag = SymbolIntInt(:symbol, 2, 3)::Tag)

julia> query(r, :symbol, ❓, 3; assigned=true) |> isnothing
true

julia> query(r, :othersym, ❓, ❓) |> isnothing
true

julia> tag!(r[5], Int, 4, 5);

julia> query(r, Float64, 4, 5) |> isnothing
true

julia> query(r, Int, 4, >(7)) |> isnothing
true

julia> query(r, Int, 4, <(7))
(slot = Slot 5, id = 5, tag = TypeIntInt(Int64, 4, 5)::Tag)
```

See also: [`queryall`](@ref), [`tag!`](@ref), [`W`](@ref), [`❓`](@ref)
"""
function query(reg::Register, tag::Tag, ::Val{allB}=Val{false}(); locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing, filo::Bool=true, ref=nothing) where {allB}
    _query(reg, tag, Val{allB}(), Val{filo}(); locked=locked, assigned=assigned, ref=ref)
end

function _query(reg::Register, tag::Tag, ::Val{allB}=Val{false}(), ::Val{filoB}=Val{true}(); locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing, ref=nothing) where {allB, filoB}
    result = NamedTuple{(:slot, :id, :tag), Tuple{RegRef, Int128, Tag}}[]
    op_guid = filoB ? reverse : identity
    for i in op_guid(reg.guids)
        slot = reg[reg.tag_info[i][2]]
        if reg.tag_info[i][1] == tag && _nothingor(ref, slot) # Need to check slot when calling from `query` dispatch on RegRef
            if _nothingor(locked, islocked(slot) && _nothingor(assigned, isassigned(slot)))
                allB ? push!(result, (slot=slot, id=i, tag=reg.tag_info[i][1])) : return (slot=slot, id=i, tag=reg.tag_info[i][1])
            end
        end
    end
    return allB ? result : nothing
end


"""
$TYPEDSIGNATURES

A [`query`](@ref) on a single slot of a register.

```jldoctest; filter = r"id = (\\d*), "
julia> r = Register(5);

julia> tag!(r[2], :symbol, 2, 3);

julia> query(r[2], :symbol, 2, 3)
(slot = Slot 2, id = 6, tag = SymbolIntInt(:symbol, 2, 3)::Tag)

julia> query(r[3], :symbol, 2, 3) === nothing
true

julia> queryall(r[2], :symbol, 2, 3)
1-element Vector{@NamedTuple{slot::RegRef, id::Int128, tag::Tag}}:
 (slot = Slot 2, id = 6, tag = SymbolIntInt(:symbol, 2, 3)::Tag)
```
"""
function query(ref::RegRef, tag::Tag, ::Val{allB}=Val{false}(); locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing, filo::Bool=true) where {allB}
    _query(ref.reg, tag, Val{allB}(), Val{filo}(); locked=locked, assigned=assigned, ref=ref)
end


"""
$TYPEDSIGNATURES

You are advised to actually use [`querydelete!`](@ref), not `query` when working with classical message buffers.
"""
function query(mb::MessageBuffer, tag::Tag, ::Val{allB}=Val{false}()) where {allB}
    i = findfirst(t->t.tag==tag, mb.buffer)
    return isnothing(i) ? nothing : (;depth=i, src=mb.buffer[i][1], tag=mb.buffer[i][2])
end



"""
$TYPEDSIGNATURES

A [`query`](@ref) for classical message buffers that also deletes the message out of the buffer.

```jldoctest
julia> net = RegisterNet([Register(3), Register(2)])
A network of 2 registers in a graph of 1 edges

julia> put!(channel(net, 1=>2), Tag(:my_tag));

julia> put!(channel(net, 1=>2), Tag(:another_tag, 123, 456));

julia> query(messagebuffer(net, 2), :my_tag)

julia> run(get_time_tracker(net))

julia> query(messagebuffer(net, 2), :my_tag)
(depth = 1, src = 1, tag = Symbol(:my_tag)::Tag)

julia> querydelete!(messagebuffer(net, 2), :my_tag)
(src = 1, tag = Symbol(:my_tag)::Tag)

julia> querydelete!(messagebuffer(net, 2), :my_tag) === nothing
true

julia> querydelete!(messagebuffer(net, 2), :another_tag, ❓, ❓)
(src = 1, tag = SymbolIntInt(:another_tag, 123, 456)::Tag)

julia> querydelete!(messagebuffer(net, 2), :another_tag, ❓, ❓) === nothing
true
```

You can also wait on a message buffer for a message to arrive before running a query:

```jldoctest
julia> using ResumableFunctions; using ConcurrentSim;

julia> net = RegisterNet([Register(3), Register(2), Register(3)])
A network of 3 registers in a graph of 2 edges

julia> env = get_time_tracker(net);

julia> @resumable function receive_tags(env)
           while true
               mb = messagebuffer(net, 2)
               @yield wait(mb)
               msg = querydelete!(mb, :second_tag, ❓, ❓)
               print("t=\$(now(env)): query returns ")
               if isnothing(msg)
                   println("nothing")
               else
                   println("\$(msg.tag) received from node \$(msg.src)")
               end
           end
       end
receive_tags (generic function with 1 method)

julia> @resumable function send_tags(env)
           @yield timeout(env, 1.0)
           put!(channel(net, 1=>2), Tag(:my_tag))
           @yield timeout(env, 2.0)
           put!(channel(net, 3=>2), Tag(:second_tag, 123, 456))
       end
send_tags (generic function with 1 method)

julia> @process send_tags(env);

julia> @process receive_tags(env);

julia> run(env, 10)
t=1.0: query returns nothing
t=3.0: query returns SymbolIntInt(:second_tag, 123, 456)::Tag received from node 3
```
"""
function querydelete!(mb::MessageBuffer, args...;filo=true)
    r = query(mb, args...)
    return isnothing(r) ? nothing : popat!(mb.buffer, r.depth)
end


"""
$TYPEDSIGNATURES

A [`query`](@ref) for [`Register`](@ref) or a register slot (i.e. a [`RegRef`](@ref)) that also deletes the tag.

```jldoctest; filter = r"id = (\\d*), "
julia> reg = Register(3)
       tag!(reg[1], :tagA, 1, 2, 3)
       tag!(reg[2], :tagA, 10, 20, 30)
       tag!(reg[2], :tagB, 6, 7, 8);

julia> queryall(reg, :tagA, ❓, ❓, ❓)
2-element Vector{@NamedTuple{slot::RegRef, id::Int128, tag::Tag}}:
 (slot = Slot 2, id = 4, tag = SymbolIntIntInt(:tagA, 10, 20, 30)::Tag)
 (slot = Slot 1, id = 3, tag = SymbolIntIntInt(:tagA, 1, 2, 3)::Tag)

julia> querydelete!(reg, :tagA, ❓, ❓, ❓)
(slot = Slot 2, id = 4, tag = SymbolIntIntInt(:tagA, 10, 20, 30)::Tag)

julia> queryall(reg, :tagA, ❓, ❓, ❓)
1-element Vector{@NamedTuple{slot::RegRef, id::Int128, tag::Tag}}:
 (slot = Slot 1, id = 3, tag = SymbolIntIntInt(:tagA, 1, 2, 3)::Tag)
```
"""
function querydelete!(reg::Union{Register,RegRef}, args...; kwa...)
    r = query(reg, args..., Val{false}(); kwa...)
    isnothing(r) || untag!(r.slot, r.id)
    return r
end


_nothingor(l,r) = isnothing(l) || l==r
_all() = true
_all(a::Bool) = a
_all(a::Bool, b::Bool) = a && b
_all(a::Bool, b::Bool, c::Bool) = a && b && c
_all(a::Bool, b::Bool, c::Bool, d::Bool) = a && b && c && d
_all(a::Bool, b::Bool, c::Bool, d::Bool, e::Bool) = a && b && c && d && e
_all(a::Bool, b::Bool, c::Bool, d::Bool, e::Bool, f::Bool) = a && b && c && d && e && f

# Create a query function for each combination of tag arguments and/or wildcard arguments
for (tagsymbol, tagvariant) in pairs(tag_types)
    sig = methods(tagvariant)[1].sig.parameters[2:end]
    args = (:a, :b, :c, :d, :e, :f, :g)[1:length(sig)]
    argssig = [:($a::$t) for (a,t) in zip(args, sig)]

    eval(quote function tag!(ref::RegRef, $(argssig...); kwa...)
        tag!(ref, ($tagvariant)($(args...)); kwa...)
    end end)

    eval(quote function Tag($(argssig...))
        ($tagvariant)($(args...))
    end end)

    eval(quote function query(tagcontainer, $(argssig...), ars...; kwa...)
        query(tagcontainer, ($tagvariant)($(args...)), ars...; kwa...)
    end end)

    int_idx_all = [i for (i,s) in enumerate(sig) if s == Int]
    int_idx_combs = powerset(int_idx_all, 1)
    for idx in int_idx_combs
        complement_idx = tuple(setdiff(1:length(sig), idx)...)
        sig_wild = collect(sig)
        sig_wild[idx] .= Union{Wildcard,Function}
        argssig_wild = [:($a::$t) for (a,t) in zip(args, sig_wild)]
        wild_checks = [:(isa($(args[i]),Wildcard) || $(args[i])(tag[$i])) for i in idx]
        nonwild_checks = [:(tag[$i]==$(args[i])) for i in complement_idx]
        newmethod_reg = quote function query(reg::Register, $(argssig_wild...), ::Val{allB}=Val{false}(); locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing, filo::Bool=true) where {allB}
            res = NamedTuple{(:slot, :id, :tag), Tuple{RegRef, Int128, Tag}}[]
            op_guid = filo ? reverse : identity
            for i in op_guid(reg.guids)
                tag = reg.tag_info[i][1]
                slot = reg[reg.tag_info[i][2]]
                if isvariant(tag, ($(tagsymbol,))[1]) # a weird workaround for interpolating a symbol as a symbol
                    (_nothingor(locked, islocked(slot)) && _nothingor(assigned, isassigned(slot))) || continue
                    if _all($(nonwild_checks...)) && _all($(wild_checks...))
                        allB ? push!(res, (slot=slot, id=i, tag=tag)) : return (slot=slot, id=i, tag=tag)
                    end
                end
            end
            allB ? res : nothing
        end end
        newmethod_mb = quote function query(mb::MessageBuffer, $(argssig_wild...))
            for (depth, (src, tag)) in pairs(mb.buffer)
                if isvariant(tag, ($(tagsymbol,))[1]) # a weird workaround for interpolating a symbol as a symbol
                    if _all($(nonwild_checks...)) && _all($(wild_checks...))
                        return (;depth, src, tag)
                    end
                end
            end
        end end
        newmethod_rr = quote function query(ref::RegRef, $(argssig_wild...), ::Val{allB}=Val{false}(); filo::Bool=true) where {allB}
            res = NamedTuple{(:slot, :id, :tag), Tuple{RegRef, Int128, Tag}}[]
            op_guid = filo ? reverse : identity
            for i in op_guid(ref.reg.guids)
                tag = ref.reg.tag_info[i][1]
                if isvariant(tag, ($(tagsymbol,))[1]) # a weird workaround for interpolating a symbol as a symbol
                    if _all($(nonwild_checks...)) && _all($(wild_checks...)) && (ref.reg[ref.reg.tag_info[i][2]] == ref)
                        allB ? push!(res, (slot=ref, id=i, tag=tag)) : return (slot=ref, id=i, tag=tag)
                    end
                end
            end
            allB ? res : nothing
        end end
        #println(sig)
        #println(sig_wild)
        #println(newmethod_reg)
        eval(newmethod_reg)
        eval(newmethod_mb) # TODO there is a lot of code duplication here
        eval(newmethod_rr) # TODO there is a lot of code duplication here
    end
end



"""Find an empty unlocked slot in a given [`Register`](@ref).

```jldoctest
julia> reg = Register(3); initialize!(reg[1], X); lock(reg[2]);

julia> findfreeslot(reg) == reg[3]
true

julia> lock(findfreeslot(reg));

julia> findfreeslot(reg) |> isnothing
true
```
"""
function findfreeslot(reg::Register; randomize=false)
    n_slots = length(reg.staterefs)
    perm = randomize ? randperm : (x->1:x)
    for i in perm(n_slots)
        slot = reg[i]
        if !islocked(slot)
            if !isassigned(slot)
                return slot
            elseif !iscoherent(slot)
                untag!(slot, reg.slot_guid[slot.idx])
                traceout!(slot)
                return slot
            end
        end
    end
end

function iscoherent(slot::RegRef; buffer_time=0.0)
    if !isassigned(slot) throw("Slot must be assigned with a quantum state before checking coherence") end
    if slot.reg.slot_guid[slot.idx] == -1 return true end
    return (now(get_time_tracker(slot))) + buffer_time - slot.reg.tag_info[slot.reg.slot_guid[slot.idx]][3] < slot.reg.retention_times[slot.idx]
end


function Base.isassigned(r::Register,i::Int) # TODO erase
    r.stateindices[i] != 0 # TODO this also usually means r.staterefs[i] !== nothing - choose one and make things consistent
end
Base.isassigned(r::RegRef) = isassigned(r.reg, r.idx)
