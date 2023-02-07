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
        anotherdummy = mkdummypackage(tmp, "AnotherDummyPackage")
        

        # Julia on Windows computes a different tree hash before version 1.9.0
        # (after 1.9.0, it is fine for repos, but still differs for bare directories
        # using Pkg.GitTools.tree_hash, see tests further below)
        th_broken = Sys.iswindows() && Base.VERSION < v"1.9.0-"
        th1 = th_broken ? "1bd2b16b793dfbf96aef17385f635729ae32a43c" : "dd574217160ae714ff496b9239a5ae1a4d819aa8"
        th2 = th_broken ? "90ca0b300186580cfe89f5336ec58453257a1ec6" : "98cea5b18356123cda026692eafb1e4a55813dac"

        th_another = th_broken ? "eb224df14392b1d2e12f969907b6404cbd7ab543" : "cc7028d54f62f514daf4b627ad3b60df47ee018b"
        th_another_mod = th_broken ? "a43d3ea9c1d3f6804e709691a4d4317cac3ce5f9" : "3af98e735356d9fb59ccfda8a3264543dd290e1e"

        
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
        @test s.head_tree_hash == PackageStates.EMPTY_TREE_HASH
        @test s.directory_tree_hash == th1
        @test s.manifest_tree_hash == s.directory_tree_hash
        
        Pkg.activate(env2)

        s2 = state(DummyPackage)
        @test s2.head_tree_hash == PackageStates.EMPTY_TREE_HASH
        @test s2.directory_tree_hash == th1
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

        # Test developed package (with modification and commit)
        Pkg.develop(path=anotherdummy)
        @eval using AnotherDummyPackage
        sdev = state(AnotherDummyPackage)
        @test sdev.head_tree_hash == th_another
        @test sdev.directory_tree_hash == th_another
        @test sdev.manifest_tree_hash == PackageStates.EMPTY_TREE_HASH

        open(joinpath(anotherdummy, "src", "myfile.txt"), "w") do io
            write(io, "Hello world!")
        end
        # dirty: still old head, but altered working dir
        sdev2 = state(AnotherDummyPackage)
        @test sdev2.head_tree_hash == th_another
        @test sdev2.directory_tree_hash == th_another_mod

        # Commit the change
        r = LibGit2.GitRepo(anotherdummy)
        LibGit2.add!(r, "**")
        LibGit2.commit(r, "msg"; author=SIGNATURE, committer=SIGNATURE)
        # now clean again (head t.h. == directory t.h.)
        sdev3 = state(AnotherDummyPackage)
        @test sdev3.head_tree_hash == th_another_mod
        @test sdev3.directory_tree_hash == th_another_mod


        # On newer Windows Julia versions, where the tree hash for repos is not broken anymore (!th_broken),
        # it differs from the tree hash of the directory on disk.
        # This test to detect if it ever changes (then the heavy use_dir=false
        # branch could be removed from tree_hash_fmt_dir).
        th_dir_broken = Sys.iswindows() && !th_broken
        if th_dir_broken # could use @test ... broken=th_dir_broken here, but doesn't work on Julia 1.6
            @test PackageStates.tree_hash_fmt_dir(s.dir; use_dir = false) ≠ PackageStates.tree_hash_fmt_dir(s.dir; use_dir = true)
            @test PackageStates.tree_hash_fmt_dir(dummy; use_dir = false) ≠ PackageStates.tree_hash_fmt_dir(s.dir; use_dir = true)
        else
            @test PackageStates.tree_hash_fmt_dir(s.dir; use_dir = false) == PackageStates.tree_hash_fmt_dir(s.dir; use_dir = true)
            @test PackageStates.tree_hash_fmt_dir(dummy; use_dir = false) == PackageStates.tree_hash_fmt_dir(s.dir; use_dir = true)
        end

        @test recorded_modules() == Set([AnotherDummyPackage, DummyPackage, PackageStates])
    end
end
