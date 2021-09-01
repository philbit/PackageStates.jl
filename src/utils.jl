tree_hash_fmt(d) = bytes2hex(Pkg.GitTools.tree_hash(d))

EMPTY_TREE_HASH = "none"

function project_and_tree_hash(pkg::Base.PkgId)
    for env in Base.load_path()
        project_file = Base.env_project_file(env)
        project_file isa String || continue
        mth = explicit_manifest_uuid_path_tree_hash(project_file,pkg)
        mth === nothing || return env, mth
    end
    return nothing, nothing
end

# Analogous to explicit_manifest_uuid_path from base/loading.jl,
# but returning the tree_hash in the manifest instead
function explicit_manifest_uuid_path_tree_hash(project_file::String, pkg::Base.PkgId)::Union{Nothing,String}
    manifest_file = Base.project_file_manifest_path(project_file)
    manifest_file === nothing && return nothing # no manifest, skip env

    d = Base.get_deps(Base.parsed_toml(manifest_file))
    entries = get(d, pkg.name, nothing)::Union{Nothing, Vector{Any}}
    entries === nothing && return nothing # TODO: allow name to mismatch?
    for entry in entries
        entry = entry::Dict{String, Any}
        uuid = get(entry, "uuid", nothing)::Union{Nothing, String}
        uuid === nothing && continue
        if Base.UUID(uuid) === pkg.uuid
            return get(entry, "git-tree-sha1", EMPTY_TREE_HASH)::Union{Nothing, String}
        end
    end
    return nothing
end