module PackageStates

using Pkg
using Dates
using PrettyTables
using LibGit2

include("utils.jl")
include("core.jl")
include("API.jl")

function __init__()
    push!(Base.package_callbacks, on_load_package)
end

end # module
