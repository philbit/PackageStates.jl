
Base.@kwdef struct PackageState
    timestamp::DateTime
    load_path::Vector{String}
    id::Base.PkgId
    dir::String
    head_tree_hash::String
    directory_tree_hash::String
    manifest_tree_hash::String
    project::Union{Nothing,String}
end

function Base.:(==)(s1::PackageState, s2::PackageState)
    s1.dir == s2.dir &&
    s1.id == s2.id &&
    s1.project == s2.project &&
    s1.load_path == s2.load_path &&
    s1.head_tree_hash == s2.head_tree_hash &&
    s1.directory_tree_hash == s2.directory_tree_hash &&
    s1.manifest_tree_hash == s2.manifest_tree_hash
end

const row_names = ["Timestamp",
                   "Load path",
                   "Package ID",
                   "Source path",
                   "Head tree hash",
                   "Directory t.h.",
                   "Manifest t.h.",
                   "Project"]

function tabledata(s::PackageState)
    data = [Dates.format(s.timestamp, "yyyy-mm-dd HH:MM"),
            s.load_path,
            s.id,
            s.dir,
            s.head_tree_hash,
            s.directory_tree_hash,
            s.manifest_tree_hash,
            s.project]
    return data
end

printtable(states::Vararg{PackageState, N}; kwargs...) where N = printtable(tabledata.(states)...; kwargs...)
function printtable(datavectors::Vararg{AbstractVector, N}; kwargs...) where N
    println()
    highlighters = PrettyTables.TextHighlighter[]
    if N > 1
        highlighters = [ PrettyTables.TextHighlighter(  (data, i, j) -> (i > 1) && length(unique(data[i,:]))> 1,
                                        crayon"fg:red")]
    end

    # Only set fixed column width when showing column labels and multiple columns
    table_kwargs = Dict{Symbol, Any}(
        :row_labels => row_names,
        :auto_wrap => true,
        :line_breaks => true,
        :alignment => :l,
        :show_column_labels => true,
        :highlighters => highlighters,
        :fixed_data_column_widths => min((displaysize(stdout)[2]-19-3*N)÷N,100*N)
    )

    pretty_table(hcat(datavectors...); table_kwargs..., kwargs...)
end

current_package_state(m::Module) = current_package_state(Base.root_module_key(m))
function current_package_state(pkg::Base.PkgId)
    date = now()
    #println("Detected loading: ", pkg)
    m = Base.root_module(pkg)
    #println("Path: ", pathof(m))
    #println("pkgdir: ", pkgdir(m))
    d = pkgdir(m)
    hth = tree_hash_fmt_head(d)
    dth = tree_hash_fmt_dir(d)
    project, mth = project_and_tree_hash(pkg)
    return PackageState(
            timestamp = date,
            dir = d,
            id = pkg,
            project = project,
            load_path = Base.load_path(),
            head_tree_hash = hth,
            directory_tree_hash = dth,
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
