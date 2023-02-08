open Core_kernel
open Signature_lib
open Mina_base
open Mina_base.Zkapp_command.Call_forest

(* TODO: move generators to the library once the code isn't actively being
     worked on *)
module Tree = struct
  include Tree

  module Stable = struct
    include Stable

    module V1 = struct
      include V1

      let quickcheck_generator account_update_gen account_update_digest_gen
          digest_gen =
        let open Quickcheck.Generator.Let_syntax in
        Quickcheck.Generator.fixed_point (fun self ->
            let%bind calls_length =
              Quickcheck.Generator.small_non_negative_int
            in
            let%map account_update = account_update_gen
            and account_update_digest = account_update_digest_gen
            and digest = digest_gen
            and calls =
              Quickcheck.Generator.list_with_length calls_length
                (With_stack_hash.quickcheck_generator self digest_gen)
            in
            { account_update; account_update_digest; calls } )
    end
  end
end

module Shape = struct
  include Shape

  let rec sexp_of_t = function
    | Node l ->
        let rec sexp_of_t_aux (i, t) =
          Sexp.List [ Sexp.Atom (Int.to_string i); sexp_of_t t ]
        in
        Sexp.List (List.map ~f:sexp_of_t_aux l)

  let rec compare (Node l_x) (Node l_y) =
    List.compare
      (fun (i_x, s_x) (i_y, s_y) ->
        match Int.compare i_x i_y with 0 -> compare s_x s_y | n -> n )
      l_x l_y
end

let quickcheck_generator account_update_gen account_update_digest_gen digest_gen
    =
  let open Quickcheck.Generator.Let_syntax in
  Quickcheck.Generator.list
    (With_stack_hash.Stable.V1.quickcheck_generator
       (Tree.Stable.V1.quickcheck_generator account_update_gen
          account_update_digest_gen digest_gen )
       digest_gen )

module Tree_test = struct
  let tree i calls =
    { Tree.calls; account_update = i; account_update_digest = () }

  let node i calls = { With_stack_hash.elt = tree i calls; stack_hash = () }

  let%test_unit "fold_forest" =
    [%test_result: int]
      (Tree.fold_forest [] ~f:(fun _ _ -> 0) ~init:1)
      ~expect:1 ;
    [%test_result: int]
      (Tree.fold_forest
         [ node 0 [ node 1 [ node 1 [] ] ]; node 2 [ node 3 [] ] ]
         ~f:(fun acc x -> acc + x)
         ~init:0 )
      ~expect:7

  let%test_unit "fold_forest2" =
    [%test_result: int]
      (Tree.fold_forest2_exn [] [] ~f:(fun _ _ _ -> 0) ~init:1)
      ~expect:1 ;
    [%test_result: int]
      (Tree.fold_forest2_exn
         [ node 0 [ node 1 [ node 2 [] ] ]; node 3 [ node 4 [] ] ]
         [ node 5 [ node 6 [ node 7 [] ] ]; node 8 [ node 9 [] ] ]
         ~f:(fun acc x y -> acc + x + y)
         ~init:0 )
      ~expect:45 ;
    try
      ignore
      @@ Tree.fold_forest2_exn
           [ node 0 [ node 1 [] ]; node 3 [ node 4 [] ] ]
           [ node 5 [ node 6 [ node 7 [] ] ]; node 8 [ node 9 [] ] ]
           ~f:(fun acc x y -> acc + x + y)
           ~init:0 ;
      assert false
    with _ -> assert true

  let%test_unit "iter_forest2_exn" =
    let expect = List.rev [ (1, 4); (2, 5); (3, 6) ] in
    let actual = ref [] in
    let f x y = actual := (x, y) :: !actual in
    Tree.iter_forest2_exn
      [ node 1 []; node 2 []; node 3 [] ]
      [ node 4 []; node 5 []; node 6 [] ]
      ~f ;
    [%test_result: (int * int) list] ~expect !actual ;
    try
      Tree.iter_forest2_exn
        [ node 1 []; node 2 []; node 3 [] ]
        [ node 4 []; node 5 [ node 0 [] ]; node 6 [] ]
        ~f ;
      assert false
    with _ -> assert true

  let%test_unit "iter2_exn" =
    let expect = List.rev [ (1, 4); (2, 5); (3, 6) ] in
    let actual = ref [] in
    let f x y = actual := (x, y) :: !actual in
    Tree.iter2_exn
      (tree 1 [ node 2 []; node 3 [] ])
      (tree 4 [ node 5 []; node 6 [] ])
      ~f ;
    [%test_result: (int * int) list] ~expect !actual ;
    try
      Tree.iter2_exn
        (tree 1 [ node 2 []; node 3 [] ])
        (tree 4 [ node 5 []; node 6 [ node 3 [] ] ])
        ~f ;
      assert false
    with _ -> assert true

  let%test_unit "mapi_with_trees preserves shape" =
    let open Quickcheck.Generator.Let_syntax in
    Quickcheck.test
      (Tree.Stable.V1.quickcheck_generator Int.quickcheck_generator
         Int.quickcheck_generator Int.quickcheck_generator ) ~f:(fun tree ->
        let tree' = Tree.mapi_with_trees tree ~f:(fun _ _ _ -> ()) in
        try
          Tree.fold2_exn tree tree' ~init:() ~f:(fun _ _ _ -> ()) ;
          assert true
        with _ -> assert false )

  let%test_unit "mapi_with_trees unit test" =
    [%test_result: (int, unit, unit) Tree.t]
      ~expect:(tree 2 [ node 0 []; node 4 [ node 6 [] ] ])
      (Tree.mapi_with_trees
         (tree 1 [ node 0 []; node 2 [ node 3 [] ] ])
         ~f:(fun _ x _ -> x * 2) )

  let%test_unit "mapi_forest_with_trees preserves shape" =
    let open Quickcheck.Generator.Let_syntax in
    Quickcheck.test
      (quickcheck_generator Int.quickcheck_generator Int.quickcheck_generator
         Int.quickcheck_generator ) ~f:(fun forest ->
        let forest' = Tree.mapi_forest_with_trees forest ~f:(fun _ _ _ -> ()) in
        try
          Tree.fold_forest2_exn forest forest' ~init:() ~f:(fun _ _ _ -> ()) ;
          assert true
        with _ -> assert false )

  let%test_unit "mapi_forest_with_trees unit test" =
    [%test_result: (int, unit, unit) t]
      ~expect:[ node 2 [ node 0 []; node 4 [ node 6 [] ] ]; node 4 [] ]
      (Tree.mapi_forest_with_trees
         [ node 1 [ node 0 []; node 2 [ node 3 [] ] ]; node 2 [] ]
         ~f:(fun _ x _ -> x * 2) )

  let%test_unit "mapi' preserves shape" =
    let open Quickcheck.Generator.Let_syntax in
    Quickcheck.test
      ( Quickcheck.Generator.tuple2 Int.quickcheck_generator
      @@ Tree.Stable.V1.quickcheck_generator Int.quickcheck_generator
           Int.quickcheck_generator Int.quickcheck_generator )
      ~f:(fun (i, tree) ->
        let _, tree' = Tree.mapi' ~i tree ~f:(fun _ _ -> ()) in
        try
          Tree.fold2_exn tree tree' ~init:() ~f:(fun _ _ _ -> ()) ;
          assert true
        with _ -> assert false )

  let%test_unit "mapi'" =
    [%test_result: int * (int, unit, unit) Tree.t]
      ~expect:(7, tree 4 [ node 4 []; node 7 [ node 9 [] ] ])
      (Tree.mapi' ~i:3
         (tree 1 [ node 0 []; node 2 [ node 3 [] ] ])
         ~f:(fun i x -> i + x) )

  (* let%test_unit "deferred_mapi_with_trees' equivalent to mapi_with_trees'" =
     Quickcheck.test
       ( Quickcheck.Generator.tuple2 Int.quickcheck_generator
       @@ Tree.Stable.V1.quickcheck_generator Int.quickcheck_generator
            Int.quickcheck_generator Int.quickcheck_generator )
       ~f:(fun (i, tree) ->
         let tree' = Tree.mapi_with_trees' ~i tree ~f:(fun _ _ _ -> ()) in
         Async_kernel.Deferred. tree'' =Tree.deferred_mapi_with_trees' ~i tree ~f:(fun _ _ _ ->
               Async_kernel.return () )
         in
         [%test_result: (int, unit, unit) Tree.t] ~expect:tree' tree'' ) *)
end

let%test_unit "shape" =
  let node i calls =
    { With_stack_hash.elt =
        { Tree.calls; account_update = i; account_update_digest = () }
    ; stack_hash = ()
    }
  in
  [%test_eq: Shape.t]
    (shape
       [ node 0
           [ node 1 [ node 2 [ node 3 [ node 4 [] ] ]; node 2 [] ]; node 1 [] ]
       ; node 0 []
       ] )
    (Node
       [ ( 0
         , Node
             [ ( 0
               , Node [ (0, Node [ (0, Node [ (0, Node []) ]) ]); (1, Node []) ]
               )
             ; (1, Node [])
             ] )
       ; (1, Node [])
       ] )
