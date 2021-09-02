
Base.@kwdef struct PackageState
    dir::String
    id::Base.PkgId
    project::Union{Nothing,String}
    load_path::Vector{String}
    tree_hash::String
    manifest_tree_hash::Union{Nothing,String}
end

current_package_state(m::Module) = current_package_state(Base.root_module_key(m))
function current_package_state(pkg::Base.PkgId)
    date = now()
    #println("Detected loading: ", pkg)
    m = Base.root_module(pkg)
    #println("Path: ", pathof(m))
    #println("pkgdir: ", pkgdir(m))
    d = pkgdir(m)
    th = tree_hash_fmt(d)
    project, mth = project_and_tree_hash(pkg)
    return date => PackageState(
            dir = d,
            id = pkg,
            project = project,
            load_path = Base.load_path(),
            tree_hash = th,
            manifest_tree_hash = mth)
end

module_states = Dict{Module, Vector{Pair{DateTime,PackageState}}}()

function on_load_package(pkg::Base.PkgId)
    m = Base.root_module(pkg)
    push!(module_states, m => [current_package_state(pkg)])
end

idxstates(m::Module, ::Val{i}) where {i<:Integer} = module_states[m][i]
idxstates(m::Module, ::Val{:on_load}) = first(module_states[m])
idxstates(m::Module, ::Val{:newest}) = last(module_states[m])
idxstates(m::Module, ::Val{:current}) = current_package_state(m)