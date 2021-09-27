export recorded_modules, get_state, get_state_on_load, diff_state, diff_all_states
export PackageState

IntegerOrSymbol = Union{Integer, Symbol}

recorded_modules() = collect(keys(module_states))

get_state_on_load(m::Module) = get_state_on_load(m::Module, nothing)
get_state_on_load(m::Module, prop::Union{Nothing,Symbol}) = get_state(m, prop, :on_load)

get_state_complete(m::Module, idx::IntegerOrSymbol = :current) = get_state(m, nothing, idx)

# General function to get whole state or specific property
function get_state(m::Module, prop::Union{Nothing,Symbol} = nothing, idx::IntegerOrSymbol = :current)
    prop !== nothing && !hasfield(PackageState, prop) && error("Can only get properties ", fieldnames(PackageState))
    !haskey(module_states, m) && error("State of module ", m, " not tracked")
    idx isa Integer && (idx <= 0 || length(module_states[m]) < idx) && error("Index ", idx, " for module ", m, " is invalid")
    return prop !== nothing ? getfield(idxstates(m, Val(idx)), prop) : idxstates(m, Val(idx))
end

function diff_all_states(fromto::Pair{T1,T2} = (:on_load => :current); print::Bool = true, update::Bool = false) where {T1<:IntegerOrSymbol, T2<:IntegerOrSymbol}
    mods = Module[]
    for (mod, states) in module_states
        if diff_state(mod, fromto; print = print, update = update)
            push!(mods, mod)
        end
    end
    return mods
end

function diff_state(m::Module, fromto::Pair{T1,T2} = (:on_load => :current); print::Bool = true, update::Bool = false) where {T1<:IntegerOrSymbol, T2<:IntegerOrSymbol}
    fromstate = idxstates(m, Val(fromto[1]))
    tostate = idxstates(m, Val(fromto[2]))

    differencefound = fromstate ≠ tostate

    differencefound && print && printtable(fromstate, tostate; header = string.([fromto...,]))

    if update
        fromto[2] !== :current && error("diff_state: update is true but fromto[2] = ", fromto[2])
        # header_printed==true means there was a difference
        if differencefound
            push!(module_states[m], tostate)
        end
    end

    return differencefound
end