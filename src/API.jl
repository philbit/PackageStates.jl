export recorded_modules, state, diff_states, diff_states_all
export PackageState

IntegerOrSymbol = Union{Integer, Symbol}

recorded_modules() = Set(keys(module_states))

# General function to get whole state or specific property
function state(m::Module, idx::IntegerOrSymbol = :current)
    !haskey(module_states, m) && error("State of module ", m, " not tracked")
    idx isa Integer && (idx <= 0 || length(module_states[m]) < idx) && error("Index ", idx, " for module ", m, " is invalid")
    return idxstates(m, Val(idx))
end

function diff_states_all(fromto::Pair{T1,T2} = (:newest => :current); print::Bool = true, update::Bool = false) where {T1<:IntegerOrSymbol, T2<:IntegerOrSymbol}
    mods = Module[]
    for (mod, states) in module_states
        if diff_states(mod, fromto; print = print, update = update)
            push!(mods, mod)
        end
    end
    return mods
end

function diff_states(m::Module, fromto::Pair{T1,T2} = (:newest => :current); print::Bool = true, update::Bool = false) where {T1<:IntegerOrSymbol, T2<:IntegerOrSymbol}
    fromstate = idxstates(m, Val(fromto[1]))
    tostate = idxstates(m, Val(fromto[2]))

    differencefound = fromstate ≠ tostate

    differencefound && print && printtable(fromstate, tostate; column_labels = string.([fromto...,]))

    if update
        fromto !== (:newest => :current) && error("diff_state: update is true but comparing ", fromto, " rather than newest to current state")
        if differencefound
            push!(module_states[m], tostate)
        end
    end

    return differencefound
end