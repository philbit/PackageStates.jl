export get_state, get_state_on_load


get_state_on_load(m::Module) = get_state_on_load(m::Module, nothing)
get_state_on_load(m::Module, prop::Union{Nothing,Symbol}) = get_state(m, prop, 1)

get_state(m::Module) = current_package_state(m)
get_state(m::Module, idx) = get_state(m, nothing, idx)
function get_state(m::Module, prop::Union{Nothing,Symbol}, idx)
    prop !== nothing && !hasfield(PackageState, prop) && error("Can only get properties ", fieldnames(PackageState))
    !haskey(module_states, m) && error("Code state of module ", m, " not tracked")
    length(module_states[m]) < idx && error("Module ", m, " does not have ", idx, " states")
    return prop !== nothing ? getfield(module_states[m][idx], prop) : module_states[m][idx]
end