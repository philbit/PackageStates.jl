module PackageStates

using Pkg
using Dates

include("utils.jl")
include("trackpath.jl")
include("reviseinteraction.jl")
include("API.jl")

function __init__()
    push!(Base.package_callbacks, on_load_package)
end

end # module
