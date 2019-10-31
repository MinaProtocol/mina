open Core
open Async

let create_dir dir = Unix.mkdir dir ~p:()

let remove_dir dir =
  let%bind _ = Process.run_exn ~prog:"rm" ~args:["-rf"; dir] () in
  Deferred.unit

let try_finally ~(f : unit -> 'a Deferred.t)
    ~(finally : unit -> unit Deferred.t) =
  try_with f
  >>= function
  | Ok x ->
      Deferred.map (finally ()) ~f:(Fn.const x)
  | Error exn ->
      finally () >>= fun () -> raise exn

let with_temp_dir ~f dir =
  let%bind temp_dir = Async.Unix.mkdtemp dir in
  try_finally ~f:(fun () -> f temp_dir) ~finally:(fun () -> remove_dir temp_dir)

let dup_stdout ?(f = Core.Fn.id) (process : Process.t) =
  Pipe.transfer ~f
    (Reader.pipe @@ Process.stdout process)
    (Writer.pipe @@ Lazy.force Writer.stdout)
  |> don't_wait_for

let dup_stderr ?(f = Core.Fn.id) (process : Process.t) =
  Pipe.transfer ~f
    (Reader.pipe @@ Process.stderr process)
    (Writer.pipe @@ Lazy.force Writer.stderr)
  |> don't_wait_for
