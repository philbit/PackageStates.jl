[![Build status](https://github.com/philbit/PackageStates.jl/workflows/CI/badge.svg)](https://github.com/philbit/PackageStates.jl/actions)
[![codecov](https://codecov.io/gh/philbit/PackageStates.jl/branch/main/graph/badge.svg?token=M2OU2FOF6Q)](https://codecov.io/gh/philbit/PackageStates.jl)

# PackageStates.jl

In Julia, environments/projects are an efficient way to preserve the exact environment in which code was run, i.e. the versions of all packages. For computational/numerical code, this can ensure reproducibility. However, relying heavily on environments comes at a cost: If your workflow involves frequent switching between different projects, the version of loaded packages depends on when exactly the corresponding `using` directive was issued. This can lead to hard-to-debug situations of "wrong" verions being loaded, for example when environment switching is done programmatically and packages are implicitly loaded as dependencies. Wouldn't it be nice to have a tool to check which environment was active when a package was loaded and which exact version of the code the loaded version actually corresponds to? This is the purpose of `PackageStates.jl`. In short, it allows you to record and compare the versions of loaded packages and their desired versions in different environments.

## Disclaimer

Beyond this README, the documentation/docstrings are currently largely missing. This is the next important to-do item, but the current functionality also does not exceed the examples below by a lot.

## Usage tips
Consider adding `PackageStates.jl` to your default `@v1.X` environment, so it is always available even if you `Pkg.activate` a different environment. Adding it to your `startup.jl` can ensure it is always loaded before any other packages are loaded and can record away.

## Usage example

We will use two empty directories (called `/tmp/path/to/env_old` and `/tmp/path/to/env_new` in the following) as test environments. We set them up as follows in a fresh Julia session:

```julia
julia> using Pkg

# Switch to "env_new", explicitly add the current versions of
# one of JLD2's dependencies and JLD2 itself

julia> Pkg.activate("/tmp/path/to/env_new")
  Activating new environment at `/tmp/path/to/env_new/Project.toml`

julia> Pkg.add("Requires")
  # downloading/installing, output skipped
julia> Pkg.add("JLD2")
  # downloading/installing, output skipped

# Switch to "env_old", explicitly add an older version of
# Requires and of JLD2

julia> Pkg.activate("/tmp/path/to/env_old")
  Activating new environment at `/tmp/path/to/env_old/Project.toml`

julia> Pkg.add(name = "Requires", version = "1.1.2")
       # downloading/installing, output skipped
julia> Pkg.add(name = "JLD2", version = "0.4.13")
       # downloading/installing, output skipped

```


Now we have two environments with their corresponding `Project.toml` and `Manifest.toml` which contain two different versions of the `JLD2` package and one of its dependencies.

If you don't have `PackageStates.jl` itself available on your `LOAD_PATH` (for example, in the default `@v1.X` environment as suggested under Usage Tips above), also add it to the `env_old` environment using

```julia
julia> Pkg.add("PackageStates")
```

Similar to [Revise.jl](https://github.com/timholy/Revise.jl), PackageStates.jl can only record states of packages that were loaded after PackageStates itself was loaded. So, let's stay in `env_old` and load first PackageStates and then JLD2

```julia
julia> using PackageStates

julia> using JLD2
```

Let's check which modules have been recorded so far:
```julia
julia> recorded_modules()
Set{Module} with 9 elements:
  JLD2
  Compat
  OrderedCollections
  TranscodingStreams
  PackageStates
  Requires
  MacroTools
  FileIO
  DataStructures
```
This includes `PackageStates` itself, `JLD2` and `JLD2`s dependencies, excluding anything that was loaded before or by PackageStates. Specifically, stdlibs are always loaded at startup and PackageStates itself has a few dependencies outside stdlibs. If the list on your system contains fewer packages, additional packages with overlapping dependencies were loaded before `using PackageStates` (for example, Revise.jl or similar in your startup.jl). 

The central function to inquire about the state of a package is `state`, which returns a `PackageState` that is displayed in the REPL as follows:

```julia
julia> state(JLD2)

PackageState of JLD2 [033835bb-8acc-5ee8-8aae-3f567f8a3819]
┌───────────────┬────────────────────────────────────────────────────────────────────────────────────┐
│     Timestamp │ 2021-09-26 21:42                                                                   │
│     Load path │ ["/tmp/path/to/env_old/Project.toml",                                              │
│               │ "/Users/philip/.julia/environments/v1.6/Project.toml",                             │
│               │ "/Applications/Julia-1.6.app/Contents/Resources/julia/share/julia/stdlib/v1.6"]    │
│    Package ID │ JLD2 [033835bb-8acc-5ee8-8aae-3f567f8a3819]                                        │
│   Source path │ /Users/philip/.julia/packages/JLD2/VHRWL                                           │
│     Tree hash │ 59ee430ac5dc87bc3eec833cc2a37853425750b4                                           │
│ Manifest t.h. │ 59ee430ac5dc87bc3eec833cc2a37853425750b4                                           │
│       Project │ /tmp/path/to/env_old/Project.toml                                                  │
└───────────────┴────────────────────────────────────────────────────────────────────────────────────┘
```
By default, `state` returns the current state, not a state recorded in the past, so the time stamp will be the current time. The `PackageState` returned by it includes a number of things:

- Timestamp: The time at which the state was recorded
- Load path: The load path at the time of recording, the first path is the active project at the time of recording
- Package ID: The `Base.PkgID`
- Source path: The source path of the loaded version at the time of recording
- Tree hash: The tree hash of the source path of the loaded version at the time of recording (which, in the best case, can be translated to a git commit to identify the corresponding version of the code)
- Manifest t.h.: The tree hash for the package requested in Manifest.toml at the time of recording. This can be `nothing` (e.g., in the package's own environment, which doesn't contain a tree hash) or "none (package dev'ed)".
- Project: The project in which the above package was found at the time of recording. Always one of the entries of load path. The Manifest t.h. above is from this project.

The Project and Manifest tree hash therefore refer to the version that would have been loaded if the `using` directive had been issued at the time "Timestamp". In our example above, we are still in the environment where we issued the `using JLD2` directive, so the two tree hashes are identical.

Let's switch to the `env_new` environment and see what changes:
```julia
julia> Pkg.activate("/tmp/path/to/env_new")
  Activating environment at `/tmp/path/to/env_new/Project.toml`

julia> state(JLD2)

PackageState of JLD2 [033835bb-8acc-5ee8-8aae-3f567f8a3819]
┌───────────────┬────────────────────────────────────────────────────────────────────────────────────┐
│     Timestamp │ 2021-09-26 21:44                                                                   │
│     Load path │ ["/tmp/path/to/env_new/Project.toml",                                              │
│               │ "/Users/philip/.julia/environments/v1.6/Project.toml",                             │
│               │ "/Applications/Julia-1.6.app/Contents/Resources/julia/share/julia/stdlib/v1.6"]    │
│    Package ID │ JLD2 [033835bb-8acc-5ee8-8aae-3f567f8a3819]                                        │
│   Source path │ /Users/philip/.julia/packages/JLD2/VHRWL                                           │
│     Tree hash │ 59ee430ac5dc87bc3eec833cc2a37853425750b4                                           │
│ Manifest t.h. │ 192934b3e2a94e897ce177423fd6cf7bdf464bce                                           │
│       Project │ /tmp/path/to/env_new/Project.toml                                                  │
└───────────────┴────────────────────────────────────────────────────────────────────────────────────┘
```
The Manifest tree hash changed since this environment (indicated by "Project") now requests a different version of JLD2. The first tree hash is still the same as it corresponds to the loaded source (whose path did not change, either). However, the tree hash can in principle change as well if the any of the source files change (for example, for a package in its own environment or for a dev'ed package). Since `state` always returns the current state by default, the project and load path now reflect the current environment. We can access the state recorded on load by requesting it explicitly:

```julia
julia> state(JLD2, :on_load)

PackageState of JLD2 [033835bb-8acc-5ee8-8aae-3f567f8a3819]
┌───────────────┬────────────────────────────────────────────────────────────────────────────────────┐
│     Timestamp │ 2021-09-26 21:40                                                                   │
│     Load path │ ["/tmp/path/to/env_old/Project.toml",                                              │
│               │ "/Users/philip/.julia/environments/v1.6/Project.toml",                             │
│               │ "/Applications/Julia-1.6.app/Contents/Resources/julia/share/julia/stdlib/v1.6"]    │
│    Package ID │ JLD2 [033835bb-8acc-5ee8-8aae-3f567f8a3819]                                        │
│   Source path │ /Users/philip/.julia/packages/JLD2/VHRWL                                           │
│     Tree hash │ 59ee430ac5dc87bc3eec833cc2a37853425750b4                                           │
│ Manifest t.h. │ 59ee430ac5dc87bc3eec833cc2a37853425750b4                                           │
│       Project │ /tmp/path/to/env_old/Project.toml                                                  │
└───────────────┴────────────────────────────────────────────────────────────────────────────────────┘
```
This way, we can find out in retrospect in what environment which version of a package was loaded. Other possibilities are `:current` (the default) and `:newest` which corresponds to the newest recorded state, or an integer index refering to the states in the order they were recorded. Currently, the only automatic recording happens at load time of a package, so unless recording is triggered manually (see State diffing below), the two will be identical.

The great power of this simple "record keeping" is that it also works for implicitly loaded packages (as dependencies of other packages). You may be familiar with the warning message after `Pkg.add`ing and precompiling a package, if a different version of the same package is already loaded. However, no such warning is issued when simply `using` a package in an environment that requests a different version of the one already loaded. For example, if we now use Requires.jl in the current environment, we can see that the loaded version is different from the one requested in the project:

```julia
julia> using Requires

julia> state(Requires)

PackageState of Requires [ae029012-a4dd-5104-9daa-d747884805df]
┌───────────────┬────────────────────────────────────────────────────────────────────────────────────┐
│     Timestamp │ 2021-09-26 21:45                                                                   │
│     Load path │ ["/tmp/path/to/env_new/Project.toml",                                              │
│               │ "/Users/philip/.julia/environments/v1.6/Project.toml",                             │
│               │ "/Applications/Julia-1.6.app/Contents/Resources/julia/share/julia/stdlib/v1.6"]    │
│    Package ID │ Requires [ae029012-a4dd-5104-9daa-d747884805df]                                    │
│   Source path │ /Users/philip/.julia/packages/Requires/035xH                                       │
│     Tree hash │ cfbac6c1ed70c002ec6361e7fd334f02820d6419                                           │
│ Manifest t.h. │ 4036a3bd08ac7e968e27c203d45f5fff15020621                                           │
│       Project │ /tmp/path/to/env_new/Project.toml                                                  │
└───────────────┴────────────────────────────────────────────────────────────────────────────────────┘
```

Why? It could be because the source was modified, but let's find out:

```julia
julia> state(Requires, :on_load)

PackageState of Requires [ae029012-a4dd-5104-9daa-d747884805df]
┌───────────────┬────────────────────────────────────────────────────────────────────────────────────┐
│     Timestamp │ 2021-09-26 21:40                                                                   │
│     Load path │ ["/tmp/path/to/env_old/Project.toml",                                              │
│               │ "/Users/philip/.julia/environments/v1.6/Project.toml",                             │
│               │ "/Applications/Julia-1.6.app/Contents/Resources/julia/share/julia/stdlib/v1.6"]    │
│    Package ID │ Requires [ae029012-a4dd-5104-9daa-d747884805df]                                    │
│   Source path │ /Users/philip/.julia/packages/Requires/035xH                                       │
│     Tree hash │ cfbac6c1ed70c002ec6361e7fd334f02820d6419                                           │
│ Manifest t.h. │ cfbac6c1ed70c002ec6361e7fd334f02820d6419                                           │
│       Project │ /tmp/path/to/env_old/Project.toml                                                  │
└───────────────┴────────────────────────────────────────────────────────────────────────────────────┘
```

We see that the source was not modified, but that this version was loaded in the `env_old` environment (as a dependency of JLD2), where it corresponded exactly to the requested version.

## State diffing
Besides `recorded_modules` and `state`, there are convenience functions to compare states:

<img width="1184" alt="Screenshot 2021-09-26 at 21 48 00" src="https://user-images.githubusercontent.com/8332598/134892722-bced432c-57c3-482b-b009-c6c0b15d0491.png">


Similar to git diff, `diff_states` by default compares the `:newest` recorded state to the `:current` state. It returns a Boolean indicating whether the states differ and prints a pretty table with changes marked in red if they do. Printing can be disabled by passing `print = false`. The versions to compare can be specified as a pair:

```julia
julia> diff_states(JLD2, :on_load => :newest)
false
```
As mentioned above, the only automatic recording happens at load time of a package, so `:on_load` and `:newest` are still identical at this point. However, we can trigger recording of a state manually by passing `update = true`, provided we are comparing to the newest recorded to the current version (as is the default):

<img width="1180" alt="Screenshot 2021-09-26 at 21 49 33" src="https://user-images.githubusercontent.com/8332598/134892906-9582f9ea-2ce0-4e4e-b785-b8a2dc5e3e86.png">


Note that calling `diff_states` a second time returns `false` (no matter whether `update` is passed or not) as the newest recorded state is now identical to the current one. Comparing to the :on_load version instead can be done via `diff_states(JLD2, :on_load => :current)`.

For convenience `diff_states_all` can be used to call `diff_states` for all modules with the same argument and returns a list of all Modules for which the states differ.

## Possible future extensions
More triggers for automatic state recording, interaction with Revise if it is loaded (since the in-memory version of a package can change), ...
