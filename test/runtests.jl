using Test
using Suppressor
using Pkg
using LibGit2
using PackageStates

const SIGNATURE = LibGit2.Signature("DUMMY", "DUMMY@DUMMY.DOM", round(time()), 0)

function mkdummypackage(tmpdir, name)
    targetdir = joinpath(tmpdir, name)
    cp(joinpath(@__DIR__, "test_packages", name), targetdir)
    LibGit2.with(LibGit2.init(targetdir)) do repo
        LibGit2.add!(repo, "*")
        LibGit2.commit(repo, "msg"; author=SIGNATURE, committer=SIGNATURE)
    end
    return targetdir
end

remove_dateline_from_diff(diffstr) = join(split(diffstr, "\n")[union(1:4,6:end)], "\n")
remove_dateline_and_header_from_diff(diffstr) = join(split(diffstr, "\n")[union(1:2,4,6:end)], "\n")

@testset "Basics" begin
    mktempdir() do tmp
        
        env1 = mkdir(joinpath(tmp, "env1"))
        env2 = mkdir(joinpath(tmp, "env2"))
        
        dummy = mkdummypackage(tmp, "DummyPackage")
        dummy2 = mkdummypackage(tmp, "DummyPackage_v2")
        
        th1 = Sys.iswindows() ? "1bd2b16b793dfbf96aef17385f635729ae32a43c" : "dd574217160ae714ff496b9239a5ae1a4d819aa8"
        th2 = Sys.iswindows() ? "90ca0b300186580cfe89f5336ec58453257a1ec6" : "98cea5b18356123cda026692eafb1e4a55813dac"

        Pkg.activate(env1)
        Pkg.add(path=dummy)
        Pkg.activate(env2)
        Pkg.add(path=dummy2)

        Pkg.activate(env1)
        @eval using DummyPackage

        s = state(DummyPackage)
        @test s.id == Base.PkgId(Base.UUID("a5a70863-7a97-4c01-857e-744174fcb92d"), "DummyPackage")
        @test s.project == joinpath(env1, "Project.toml")
        @test s.load_path[1] == joinpath(env1, "Project.toml")
        @test s.tree_hash == th1
        @test s.manifest_tree_hash == s.tree_hash
        
        Pkg.activate(env2)

        s2 = state(DummyPackage)
        @test s2.tree_hash == th1
        @test s2.manifest_tree_hash == th2
        @test s2.load_path[1] == joinpath(env2, "Project.toml")
        
        @test @capture_out(diff_states_all(:on_load => :newest)) == ""
        snew = state(DummyPackage, :newest)
        @test snew.manifest_tree_hash == th1

        @test diff_states(DummyPackage, print = false)
        @test @capture_out(diff_states(DummyPackage)) ≠ ""
        @test remove_dateline_from_diff(@capture_out(diff_states(DummyPackage))) == remove_dateline_from_diff(@capture_out(diff_states(DummyPackage, :newest => :current)))
        
        diff_states_all(print = false, update = true)
        supdated = state(DummyPackage, :newest)
        @test supdated.manifest_tree_hash == th2
        @test @capture_out(diff_states_all(:on_load => :newest)) ≠ ""
        @test remove_dateline_and_header_from_diff(@capture_out(diff_states(DummyPackage, :on_load => :newest))) == remove_dateline_and_header_from_diff(@capture_out(diff_states(DummyPackage, :on_load => :current)))
        Pkg.activate(env1)
        @test diff_states_all(:on_load => :current, print=false) == [PackageStates]

        @test recorded_modules() == Set([DummyPackage, PackageStates])
    end
end
