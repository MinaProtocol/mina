open Async

let create_dir dir = Unix.mkdir ~p:() dir

let remove_dirs dirs = Process.run_exn ~prog:"rm" ~args:("-rf" :: dirs) ()
