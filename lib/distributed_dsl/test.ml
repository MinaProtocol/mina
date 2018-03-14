open Core_kernel
open Async_kernel


let%test "trivial" = true

(*let%test "paxos" = 
  let r, w = Linear_pipe.create () in
  let open Test_node in
  let _node = 
    make_node
      ~messages:r
      ~initial_state:4
      [ on 
          Condition_label.Todo
          (Predicate (fun s -> true))
          ~f:(fun t s -> s)
      ; on 
          Condition_label.Todo
          (Interval (Time.Span.of_sec 4.0))
          ~f:(fun t s -> s)
      ; on 
          Condition_label.Todo
          (Message (fun m -> true))
          ~f:(fun t s -> s)
      ]
  in
  true*)
