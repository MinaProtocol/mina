open Async

let create_dir dir = Unix.mkdir dir ~p:()

let remove_dir dir =
  let%bind _ = Process.run_exn ~prog:"rm" ~args:["-rf"; dir] () in
  Deferred.unit

let try_finally ~(f : unit -> unit Deferred.t) ~finally =
  let open Deferred.Or_error in
  try_with f >>= (fun () -> ok_unit) |> ok_exn |> Deferred.bind ~f:finally

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
