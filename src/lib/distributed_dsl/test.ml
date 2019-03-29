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
          (predicate (fun s -> true))
          ~f:(fun t s -> s)
      ; on
          Condition_label.Todo
          (timeout (Time.Span.of_sec 4.0))
          ~f:(fun t s -> s)
      ; on
          Condition_label.Todo
          (msg (fun s m -> true))
          ~f:(fun t s -> s)
      ]
  in
  true*)
