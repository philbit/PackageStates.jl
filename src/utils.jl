const EMPTY_TREE_HASH = "missing"

function tree_hash_fmt_dir(d; use_dir = !Sys.iswindows())
    
    if use_dir
        return bytes2hex(Pkg.GitTools.tree_hash(d))
    end


    # The simple approach above yields a different tree hash on Windows, even if the directory is
    # a clean working copy of the repo
    # Same reason because of which this thing is in Pkg.jl/src/Operations.jl:
        # # Assert that the tarball unpacked to the tree sha we wanted
        # # TODO: Enable on Windows when tree_hash handles
        # # executable bits correctly, see JuliaLang/julia #33212.
        # if !Sys.iswindows()
        #     if SHA1(GitTools.tree_hash(unpacked)) != hash
        #         @warn "tarball content does not match git-tree-sha1"
        #         url_success = false
        #     end
        #     url_success || continue
        # end


    # Workaround for windows: copy the directory, create git repo, write-tree
    hash = mktempdir() do tmpdir
        repodir = joinpath(tmpdir, splitpath(realpath(d))[end])
        # If directory is a symlink, copying it would actually link to the same directory
        # modifying the target -> abort
        if islink(d)
            @warn("$(d): path is a symlink, not calculating tree hash")
            return EMPTY_TREE_HASH
        end

        cp(d, repodir)
        if !isdir(joinpath(repodir, ".git"))
            r = LibGit2.init(repodir)
        else
            r = LibGit2.GitRepo(repodir)
        end
        gi = LibGit2.GitIndex(r)
        LibGit2.add!(gi, "**"; flags = LibGit2.Consts.INDEX_ADD_FORCE)
        return string(LibGit2.write_tree!(gi))
    end
    return hash
end


function tree_hash_fmt_head(d)
    isdir(joinpath(d, ".git")) || return EMPTY_TREE_HASH
    commit = Pkg.Types.get_object_or_branch(LibGit2.GitRepo(d), "HEAD")[1]
    tree = LibGit2.peel(LibGit2.GitTree, commit)
    hash = LibGit2.GitHash(tree)
    return string(hash)
end

function project_and_tree_hash(pkg::Base.PkgId)
    for env in Base.load_path()
        project_file = Base.env_project_file(env)
        project_file isa String || continue
        mth = explicit_manifest_uuid_path_tree_hash(project_file,pkg)
        mth === nothing || return env, mth
    end
    return nothing, EMPTY_TREE_HASH
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
