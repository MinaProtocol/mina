open Async

let create_dir dir = Unix.mkdir ~p:() dir

let remove_dirs dirs =
  let%bind _ = Process.run_exn ~prog:"rm" ~args:("-rf" :: dirs) () in
  Deferred.unit

let try_finally ~(f: unit -> unit Deferred.t) ~finally =
  let open Deferred.Or_error in
  try_with f >>= (fun () -> ok_unit) |> ok_exn |> Deferred.bind ~f:finally

let with_temp_dirs ~f dirs =
  let open Let_syntax in
  let%bind () = Deferred.List.iter ~f:create_dir dirs in
  try_finally ~f ~finally:(fun () -> remove_dirs dirs)
