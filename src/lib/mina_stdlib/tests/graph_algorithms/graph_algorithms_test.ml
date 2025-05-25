open Core_kernel

let test_tree_connectivity () =
  (*
        0
      /  \
      1   2
      |  / \
      3  4 5
  *)
  let tree =
    [ (0, [ 1; 2 ])
    ; (1, [ 3; 0 ])
    ; (2, [ 0; 4; 5 ])
    ; (3, [ 1 ])
    ; (4, [ 2 ])
    ; (5, [ 2 ])
    ]
  in
  let connectivity = Mina_stdlib.Graph_algorithms.connectivity (module Int) tree in
  Alcotest.(check int)
    "Tree connectivity should be 1" 1
    (Mina_stdlib.Nat.to_int connectivity)

let test_complete_graph_connectivity () =
  let complete_graph n =
    let all = List.init n ~f:Fn.id in
    List.init n ~f:(fun i -> (i, all))
  in
  let connectivity =
    Mina_stdlib.Graph_algorithms.connectivity (module Int) (complete_graph 4)
  in
  Alcotest.(check bool)
    "Complete graph has infinite connectivity" true
    (Mina_stdlib.Nat.at_least connectivity 10000)

let () =
  let open Alcotest in
  run "Graph Algorithms"
    [ ( "connectivity"
      , [ test_case "Tree connectivity" `Quick test_tree_connectivity
        ; test_case "Complete graph connectivity" `Quick
            test_complete_graph_connectivity
        ] )
    ]
