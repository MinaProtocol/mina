open Core
open Async

let main nodes =
  printf "host started: %s\n" (Sexp.to_string_hum ([%sexp_of: Mnt_cycle_search_testbridge.Node.t list] nodes));
  printf "starting search\n";
  let%bind () = 
    Deferred.List.iter 
      nodes 
      ~f:(fun n -> 
        let%map cycles = Mnt_cycle_search_testbridge.get_cycles n 0 10 in
        printf "%s\n" (Sexp.to_string_hum ([%sexp_of: (int * string) list] cycles))
      )
  in
  Async.never ()
;;


let () = Mnt_cycle_search_testbridge.cmd main
;;

let () = never_returns (Scheduler.go ())
;;
