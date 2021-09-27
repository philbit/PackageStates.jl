
Base.@kwdef struct PackageState
    timestamp::DateTime
    load_path::Vector{String}
    id::Base.PkgId
    dir::String
    tree_hash::String
    manifest_tree_hash::Union{Nothing,String}
    project::Union{Nothing,String}
end

function Base.:(==)(s1::PackageState, s2::PackageState)
    s1.dir == s2.dir && 
    s1.id == s2.id &&
    s1.project == s2.project &&
    s1.load_path == s2.load_path &&
    s1.tree_hash == s2.tree_hash &&
    s1.manifest_tree_hash == s2.manifest_tree_hash
end

const row_names = ["Timestamp",
                   "Load path",
                   "Package ID",
                   "Source path",
                   "Tree hash",
                   "Manifest t.h.",
                   "Project"]

function tabledata(s::PackageState)
    data = [Dates.format(s.timestamp, "yyyy-mm-dd HH:MM"),
            s.load_path,
            s.id,
            s.dir,
            s.tree_hash,
            s.manifest_tree_hash,
            s.project]
    return data
end

printtable(states::Vararg{PackageState, N}; kwargs...) where N = printtable(tabledata.(states)...; kwargs...)
function printtable(datavectors::Vararg{AbstractVector, N}; kwargs...) where N
    println()
    highlighters = ()
    if N > 1
        highlighters = ( Highlighter(  (data, i, j) -> (i > 1) && length(unique(data[i,:]))> 1,
                                        crayon"fg:red"),)
    end
    pretty_table(hcat(datavectors...),
                 row_names = row_names,
                 autowrap = true,
                 linebreaks = true,
                 columns_width = min((displaysize(stdout)[2]-18-3*N)÷N,100*N),
                 alignment = :l,
                 noheader = N == 1,
                 highlighters = highlighters; kwargs...)
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
Base.show(io::IO, ::MIME"text/plain", s::PackageState) = printtable(s; title = "PackageState of $(s.id)")