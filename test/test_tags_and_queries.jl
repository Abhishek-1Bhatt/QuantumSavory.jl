using QuantumSavory
using QuantumSavory: tag_types
using QuantumSavory.ProtocolZoo: EntanglementCounterpart
using Test

@test tag_types.SymbolIntInt(:symbol1, 4, 5) == Tag(:symbol1, 4, 5)

function strip_id(query_result)
    return (;slot=query_result.slot, tag=query_result.tag)
end

strip_id(::Nothing) = nothing

r = Register(10)
tag!(r[1], :symbol1, 2, 3)
tag!(r[2], :symbol1, 4, 5)
tag!(r[3], :symbol1, 4, 1)
tag!(r[5], Int, 4, 5)

@test Tag(:symbol1, 2, 3) == tag_types.SymbolIntInt(:symbol1, 2, 3)
@test strip_id(query(r, :symbol1, 4, ❓)) == (slot=r[3], tag=tag_types.SymbolIntInt(:symbol1, 4, 1))
@test strip_id(query(r, :symbol1, 4, 5)) == (slot=r[2], tag=tag_types.SymbolIntInt(:symbol1, 4, 5))
@test strip_id(query(r, :symbol1, ❓, ❓)) == (slot=r[3], tag=tag_types.SymbolIntInt(:symbol1, 4, 1)) #returns latest tag in filo order
@test query(r, :symbol2, ❓, ❓) == nothing
@test strip_id(query(r, Int, 4, 5)) == (slot=r[5], tag=tag_types.TypeIntInt(Int, 4, 5))
@test query(r, Float32, 4, 5) == nothing
@test query(r, Int, 4, >(5)) == nothing
@test strip_id(query(r, Int, 4, <(6))) == (slot=r[5], tag=tag_types.TypeIntInt(Int, 4, 5))

@test strip_id.(queryall(r, :symbol1, ❓, ❓)) == [(slot=r[3], tag=Tag(:symbol1, 4, 1)), (slot=r[2], tag=Tag(:symbol1, 4, 5)), (slot=r[1], tag=Tag(:symbol1, 2, 3))] # filo by default
@test isempty(queryall(r, :symbol2, ❓, ❓))

@test strip_id(query(r[2], Tag(:symbol1, 4, 5))) == (slot=r[2], tag=Tag(:symbol1, 4, 5))
@test strip_id.(queryall(r[2], Tag(:symbol1, 4, 5))) == [(slot=r[2], tag=Tag(:symbol1, 4, 5))]
@test strip_id(query(r[2], :symbol1, 4, 5)) == (slot=r[2], tag=Tag(:symbol1, 4, 5))
@test strip_id.(queryall(r[2], :symbol1, 4, 5)) == [(slot=r[2], tag=Tag(:symbol1, 4, 5))]

@test strip_id(query(r[2], :symbol1, 4, ❓)) == (slot=r[2], tag=Tag(:symbol1, 4, 5))
@test strip_id.(queryall(r[2], :symbol1, 4, ❓)) == [(slot=r[2], tag=Tag(:symbol1, 4, 5))]

@test strip_id(querydelete!(r[2], :symbol1, 4, ❓)) == (slot=r[2], tag=Tag(:symbol1, 4, 5))
@test querydelete!(r[2], :symbol1, 4, ❓) === nothing
@test strip_id(querydelete!(r[3], :symbol1, 4, ❓)) == (slot=r[3], tag=Tag(:symbol1, 4, 1))

##
# tests for fifo and filo order queries (default is filo)
# for RegRefs

reg = Register(5)
tag!(reg[3], EntanglementCounterpart, 1, 10)
tag!(reg[3], EntanglementCounterpart, 2, 21)
tag!(reg[3], EntanglementCounterpart, 3, 30)
tag!(reg[3], EntanglementCounterpart, 2, 22)
tag!(reg[3], EntanglementCounterpart, 1, 10)
tag!(reg[3], EntanglementCounterpart, 6, 60)
tag!(reg[3], EntanglementCounterpart, 2, 23)
tag!(reg[3], EntanglementCounterpart, 1, 10)

@test query(reg[3], EntanglementCounterpart, 1, 11) === nothing
@test strip_id(query(reg[3], EntanglementCounterpart, 1, 10)) == (slot = reg[3], tag = Tag(EntanglementCounterpart,1,10))
@test strip_id(query(reg[3], EntanglementCounterpart, 1, 10, Val(false); filo=false)) == (slot = reg[3], tag = Tag(EntanglementCounterpart,1,10))
@test strip_id(query(reg[3], EntanglementCounterpart, 1, 10, Val(false); filo=true)) == (slot = reg[3], tag = Tag(EntanglementCounterpart,1,10))
@test query(reg[3], EntanglementCounterpart, 1, 10; filo=true).id > query(reg[3], EntanglementCounterpart, 1, 10; filo=false).id
@test query(reg[3], EntanglementCounterpart, 2, ❓; filo=true).tag[3] == 23
@test query(reg[3], EntanglementCounterpart, 2, ❓; filo=false).tag[3] == 21

@test strip_id(query(reg[3], EntanglementCounterpart, 2, ❓)) == (slot = reg[3], tag = Tag(EntanglementCounterpart,2,23))
@test strip_id(query(reg[3], EntanglementCounterpart, 2, ❓, Val(false); filo=false)) == (slot = reg[3], tag = Tag(EntanglementCounterpart,2,21))
@test strip_id(query(reg[3], EntanglementCounterpart, 2, ❓, Val(false); filo=true)) == (slot = reg[3], tag = Tag(EntanglementCounterpart,2,23))

@test queryall(reg, EntanglementCounterpart, 1, 11) == []
default_ids = [r.id for r in queryall(reg[3], EntanglementCounterpart, 1, 10)]
@test default_ids == sort(default_ids, rev=true)
fifo_ids = [r.id for r in queryall(reg[3], EntanglementCounterpart, 1, 10; filo=false)]
@test fifo_ids == sort(fifo_ids)
filo_ids = [r.id for r in queryall(reg[3], EntanglementCounterpart, 1, 10; filo=true)]
@test filo_ids == default_ids

##
# tests for fifo and filo order queries (default is filo)
# for Register

reg = Register(5)
for i in 2:4
    tag!(reg[i], EntanglementCounterpart, 1,  10+i)
    tag!(reg[i], EntanglementCounterpart, 2,  20+i)
    tag!(reg[i], EntanglementCounterpart, 3,  30+i)
    tag!(reg[i], EntanglementCounterpart, 2, 120+i)
    tag!(reg[i], EntanglementCounterpart, 1, 110+i)
    tag!(reg[i], EntanglementCounterpart, 6,  60+i)
    tag!(reg[i], EntanglementCounterpart, 2,  20+i)
    tag!(reg[i], EntanglementCounterpart, 1, 310+i)
end

@test query(reg, EntanglementCounterpart, 1, 10) === nothing
@test query(reg, EntanglementCounterpart, 1, 12) == (slot = reg[2], id = 13, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12) == query(reg, EntanglementCounterpart, ==(1), ==(12))
@test query(reg, Tag(EntanglementCounterpart, 1, 10)) === nothing
@test query(reg, Tag(EntanglementCounterpart, 1, 12)) == (slot = reg[2], id = 13, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12, Val(false); filo=false) == (slot = reg[2], id = 13, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12, Val(false); filo=true) == (slot = reg[2], id = 13, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12, Val(false); filo=false) == query(reg, EntanglementCounterpart, 1, ==(12), Val(false); filo=false)
@test query(reg, EntanglementCounterpart, 1, 12, Val(false); filo=true) == query(reg, EntanglementCounterpart, 1, ==(12), Val(false); filo=true)
@test query(reg, EntanglementCounterpart, 1, ❓, Val(false); filo=false) == (slot = reg[2], id = 13, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, ❓, Val(false); filo=true) == (slot = reg[4], id = 36, tag = Tag(EntanglementCounterpart,1,314))

@test strip_id(queryall(reg, EntanglementCounterpart, 1, ❓)) == [(slot = reg[4], tag = Tag(EntanglementCounterpart, 1, 314)), (slot = reg[4], tag = Tag(EntanglementCounterpart, 1, 114)), (slot = reg[4], tag = Tag(EntanglementCounterpart, 1, 14)), (slot = reg[3], tag = Tag(EntanglementCounterpart, 1, 313)), (slot = reg[3], tag = Tag(EntanglementCounterpart, 1, 113)), (slot = reg[3], tag = Tag(EntanglementCounterpart, 1, 13)), (slot = reg[2], tag = Tag(EntanglementCounterpart, 1, 312)), (slot = reg[2], tag = Tag(EntanglementCounterpart, 1, 112)), (slot = reg[2], tag = Tag(EntanglementCounterpart, 1, 12))]
@test strip_id(queryall(reg, EntanglementCounterpart, 1, ❓; filo=true)) == [(slot = reg[4], tag = Tag(EntanglementCounterpart, 1, 314)), (slot = reg[4], tag = Tag(EntanglementCounterpart, 1, 114)), (slot = reg[4], tag = Tag(EntanglementCounterpart, 1, 14)), (slot = reg[3], tag = Tag(EntanglementCounterpart, 1, 313)), (slot = reg[3], tag = Tag(EntanglementCounterpart, 1, 113)), (slot = reg[3], tag = Tag(EntanglementCounterpart, 1, 13)), (slot = reg[2], tag = Tag(EntanglementCounterpart, 1, 312)), (slot = reg[2], tag = Tag(EntanglementCounterpart, 1, 112)), (slot = reg[2], tag = Tag(EntanglementCounterpart, 1, 12))]
@test strip_id(queryall(reg, EntanglementCounterpart, 1, ❓; filo=false)) == reverse([(slot = reg[4], tag = Tag(EntanglementCounterpart, 1, 314)), (slot = reg[4], tag = Tag(EntanglementCounterpart, 1, 114)), (slot = reg[4], tag = Tag(EntanglementCounterpart, 1, 14)), (slot = reg[3], tag = Tag(EntanglementCounterpart, 1, 313)), (slot = reg[3], tag = Tag(EntanglementCounterpart, 1, 113)), (slot = reg[3], tag = Tag(EntanglementCounterpart, 1, 13)), (slot = reg[2], tag = Tag(EntanglementCounterpart, 1, 312)), (slot = reg[2], tag = Tag(EntanglementCounterpart, 1, 112)), (slot = reg[2], tag = Tag(EntanglementCounterpart, 1, 12))])

@test query(reg, EntanglementCounterpart, 2, 22) == (slot = reg[2], id = 19, tag = Tag(EntanglementCounterpart,2,22))
@test strip_id(queryall(reg, EntanglementCounterpart, 2, 22)) == [(slot = reg[2], tag = Tag(EntanglementCounterpart,2,22)), (slot = reg[2], tag = Tag(EntanglementCounterpart,2,22))]
@test strip_id(queryall(reg, Tag(EntanglementCounterpart, 2, 22))) == [(slot = reg[2], tag = Tag(EntanglementCounterpart,2,22)), (slot = reg[2], tag = Tag(EntanglementCounterpart,2,22))]
@test queryall(reg, EntanglementCounterpart, 2, 22) == queryall(reg, EntanglementCounterpart, ==(2), ==(22)) == queryall(reg, Tag(EntanglementCounterpart, 2, 22))
@test strip_id(queryall(reg, Tag(EntanglementCounterpart, 2, 22); filo=false)) == [(slot = reg[2], tag = Tag(EntanglementCounterpart,2,22)), (slot = reg[2], tag = Tag(EntanglementCounterpart,2,22))]
@test queryall(reg, EntanglementCounterpart, 2, 22; filo=false) == queryall(reg, EntanglementCounterpart, ==(2), ==(22); filo=false) == queryall(reg, Tag(EntanglementCounterpart, 2, 22); filo=false)

reg = Register(4)
tag!(reg[1], EntanglementCounterpart, 4, 9)
tag!(reg[1], EntanglementCounterpart, 5, 2)
tag!(reg[1], EntanglementCounterpart, 7, 7)
tag!(reg[1], EntanglementCounterpart, 4, 9)
tag!(reg[1], EntanglementCounterpart, 2, 3)
tag!(reg[1], EntanglementCounterpart, 4, 9)

@test [reg.tag_info[i][1] for i in reg.guids] == [Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 5, 2), Tag(EntanglementCounterpart, 7, 7), Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 2, 3), Tag(EntanglementCounterpart, 4, 9)]
querydelete!(reg[1], EntanglementCounterpart, 4, 9)
@test [reg.tag_info[i][1] for i in reg.guids] == [Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 5, 2), Tag(EntanglementCounterpart, 7, 7), Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 2, 3)]
querydelete!(reg[1], EntanglementCounterpart, 4, 9;filo=false)
@test [reg.tag_info[i][1] for i in reg.guids] == [Tag(EntanglementCounterpart, 5, 2), Tag(EntanglementCounterpart, 7, 7), Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 2, 3)]