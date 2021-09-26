
Base.@kwdef struct PackageState
    timestamp::DateTime
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
    return PackageState(
            timestamp = date,
            dir = d,
            id = pkg,
            project = project,
            load_path = Base.load_path(),
            tree_hash = th,
            manifest_tree_hash = mth)
end

module_states = Dict{Module, Vector{PackageState}}()

function on_load_package(pkg::Base.PkgId)
    m = Base.root_module(pkg)
    push!(module_states, m => [current_package_state(pkg)])
end

function idxstates(m::Module, ::Val{i}) where {i} 
    @assert(i isa Integer, "State index must be an integer or :on_load, :newest, :current")
    return module_states[m][i]
end
idxstates(m::Module, ::Val{:on_load}) = first(module_states[m])
idxstates(m::Module, ::Val{:newest}) = last(module_states[m])
idxstates(m::Module, ::Val{:current}) = current_package_state(m)

## Pretty printing

# one-line text output
Base.show(io::IO, s::PackageState) = print(io, "PackageState($(s.id))")

# fancy multi-line output
Base.show(io::IO, ::MIME"text/plain", s::PackageState) = print(io,
    """
        PackageState of $(s.id)
               Timestamp: $(Dates.format(s.timestamp, "yyyy-mm-dd HH:MM"))
                    Path: $(s.dir)
          Active project: $(s.project)
               Load path: $(s.load_path)
               Tree hash: $(s.tree_hash)
           Manifest t.h.: $(s.manifest_tree_hash)""")
