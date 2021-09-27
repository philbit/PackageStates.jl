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

remove_dateline_from_diff(diffstr) = join(split(diffstr, "\n")[union(2,4:end)], "\n")

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

        @test get_state(DummyPackage, :id) == Base.PkgId(Base.UUID("a5a70863-7a97-4c01-857e-744174fcb92d"), "DummyPackage")
        @test get_state(DummyPackage, :project) == joinpath(env1, "Project.toml")
        @test get_state(DummyPackage, :load_path)[1] == joinpath(env1, "Project.toml")
        @test get_state(DummyPackage, :tree_hash) == th1
        @test get_state(DummyPackage, :manifest_tree_hash) == get_state(DummyPackage, :tree_hash)
        
        Pkg.activate(env2)
        @test get_state(DummyPackage, :tree_hash) == th1
        @test get_state(DummyPackage, :manifest_tree_hash) == th2
        @test get_state(DummyPackage, :load_path)[1] == joinpath(env2, "Project.toml")
        
        @test @capture_out(diff_all_states(:on_load => :newest)) == ""
        @test get_state(DummyPackage, :manifest_tree_hash, :newest) == th1

        @test diff_state(DummyPackage, print = false)
        @test remove_dateline_from_diff(@capture_out(diff_state(DummyPackage))) == remove_dateline_from_diff(@capture_out(diff_state(DummyPackage, :on_load => :current)))
        
        diff_all_states(print = false, update = true)
        @test get_state(DummyPackage, :manifest_tree_hash, :newest) == th2
        @test @capture_out(diff_all_states(:on_load => :newest)) ≠ ""
        @test remove_dateline_from_diff(@capture_out(diff_state(DummyPackage, :on_load => :newest))) == remove_dateline_from_diff(@capture_out(diff_state(DummyPackage, :on_load => :current)))

        Pkg.activate(env1)
        @test diff_all_states(print=false) == [PackageStates]
    end
end
