(* Benchmark the scheduler *)

open Stdune
open Dune

let () =
  Path.set_root (Path.External.cwd ());
  Path.set_build_dir (Path.Kind.of_string "_build")

let prog =
  Option.value_exn (Bin.which ~path:(Env.path Env.initial) "true")
let run () = Process.run ~env:Env.initial Strict prog []

let go ~jobs fiber =
  Scheduler.go fiber ~config:{ Config.default with concurrency = Fixed jobs }

let%bench "single" = go (run ()) ~jobs:1

let l = List.init ~len:100 ~f:ignore

let%bench "many" [@indexed jobs = [1; 2; 4; 8]] =
  go ~jobs (Fiber.parallel_iter l ~f:run)
