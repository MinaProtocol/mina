open Core
open Async

let () = printf "monads time\n"
;;

let n = 0.3
;;

(*let _ = 
  let start = Time.now () in
  let xy = List.Let_syntax.(let%map x = [3; 4] and y = [5; 6] in x + y) in
  let%bind () = Async.after (Time.Span.of_sec n) in
  let%bind () = Async.after (Time.Span.of_sec n) in
  printf "monads time %f %f %s\n" n (Time.Span.to_sec (Time.diff (Time.now ()) start)) (List.to_string xy ~f:Int.to_string);
  Shutdown.shutdown 0;
  return ()
;;*)

(*let both t1 t2 =
  bind t1 ~f:(fun x1 ->
    bind t2 ~f:(fun x2 ->
      return (x1, x2)))

List.Let_syntax.Let_syntax.both*)

(*let%map x1 = t1
and x2 = t2
and ...
and xn = tn
in
e
  =>
Let_syntax.map
  (Let_syntax.both t1 (Let_syntax.both t2 (... (Let_syntax.both tn-1 tn))))`
  ~f:(fun (x1, (x2, ... (xn-1, xn))) -> e)*)

let my_cool_deferred_computation = 
  let start = Time.now () in
  let _xy_map = List.Let_syntax.(let%map x = [3; 4] and y = [5; 6] in x + y) in
  let _xy_bind = List.Let_syntax.(let%bind x = [3; 4] and y = [5; 6] in [ x + y ]) in
  let%bind () = Async.after (Time.Span.of_sec n) in
  let xy = 
    List.bind
      (List.bind [3; 4] ~f:(fun x1 -> 
         List.bind [5; 6] ~f:(fun x2 -> 
           List.return (x1, x2))))
      ~f:(fun (x, y) -> [ x + y ])
  in
  Deferred.bind (Async.after (Time.Span.of_sec n)) ~f:(fun () -> 
    Deferred.bind (Async.after (Time.Span.of_sec n)) ~f:(fun () -> 
      printf "monads time %f %f %s\n" n (Time.Span.to_sec (Time.diff (Time.now ()) start)) (List.to_string xy ~f:Int.to_string);
      Shutdown.shutdown 0;
      return ()
    )
  )
;;

let () = never_returns (Scheduler.go ())
;;
