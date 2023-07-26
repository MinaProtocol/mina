(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^call forest$'
    Subject:    Test zkApp commands (call forests).
 *)

open Core_kernel
open Mina_base
open Zkapp_command.Call_forest

(* TODO: move generators to the library once the code isn't actively being
     worked on *)
module Tree = struct
  include Tree

  let gen account_update_gen account_update_digest_gen digest_gen =
    let open Quickcheck.Generator.Let_syntax in
    Quickcheck.Generator.fixed_point (fun self ->
        let%bind calls_length = Quickcheck.Generator.small_non_negative_int in
        let%map account_update = account_update_gen
        and account_update_digest = account_update_digest_gen
        and calls =
          Quickcheck.Generator.list_with_length calls_length
            (With_stack_hash.quickcheck_generator self digest_gen)
        in
        { account_update; account_update_digest; calls } )

  let quickcheck_generator = gen
end

module Shape = struct
  include Shape

  type t = Zkapp_command.Call_forest.Shape.t = Node of (int * t) list
  [@@deriving sexp, compare]
end

let gen account_update_gen account_update_digest_gen digest_gen =
  Quickcheck.Generator.list
    (With_stack_hash.Stable.V1.quickcheck_generator
       (Tree.gen account_update_gen account_update_digest_gen digest_gen)
       digest_gen )

let assert_error f arg =
  let result = try Some (f arg) with _ -> None in
  match result with
  | None ->
      ()
  | Some _ ->
      raise (Failure "function was expected to throw an error, but didn't.")

module Tree_test = struct
  let tree i calls =
    { Tree.calls; account_update = i; account_update_digest = () }

  let node i calls = { With_stack_hash.elt = tree i calls; stack_hash = () }

  let fold_forest () =
    [%test_result: int]
      (Tree.fold_forest [] ~f:(fun _ _ -> 0) ~init:1)
      ~expect:1 ;
    [%test_result: int]
      (Tree.fold_forest
         [ node 0 [ node 1 [ node 1 [] ] ]; node 2 [ node 3 [] ] ]
         ~f:(fun acc x -> acc + x)
         ~init:0 )
      ~expect:7

  let fold_forest2 () =
    [%test_result: int]
      (Tree.fold_forest2_exn [] [] ~f:(fun _ _ _ -> 0) ~init:1)
      ~expect:1 ;
    [%test_result: int]
      (Tree.fold_forest2_exn
         [ node 0 [ node 1 [ node 2 [] ] ]; node 3 [ node 4 [] ] ]
         [ node 5 [ node 6 [ node 7 [] ] ]; node 8 [ node 9 [] ] ]
         ~f:(fun acc x y -> acc + x + y)
         ~init:0 )
      ~expect:45

  let fold_forest2_fails () =
    assert_error
      (Tuple.T2.uncurry (Tree.fold_forest2_exn ~f:(fun _ _ _ -> ()) ~init:()))
      ( [ node 0 [ node 1 [] ]; node 3 [ node 4 [] ] ]
      , [ node 5 [ node 6 [ node 7 [] ] ]; node 8 [ node 9 [] ] ] )

  let iter_forest2_exn () =
    let expect = List.rev [ (1, 4); (2, 5); (3, 6) ] in
    let actual = ref [] in
    let f x y = actual := (x, y) :: !actual in
    Tree.iter_forest2_exn
      [ node 1 []; node 2 []; node 3 [] ]
      [ node 4 []; node 5 []; node 6 [] ]
      ~f ;
    [%test_result: (int * int) list] ~expect !actual

  let iter_forest2_exn_fails () =
    assert_error
      (Tuple.T2.uncurry (Tree.iter_forest2_exn ~f:(fun _ _ -> ())))
      ( [ node 1 []; node 2 []; node 3 [] ]
      , [ node 4 []; node 5 [ node 0 [] ]; node 6 [] ] )

  let iter2_exn () =
    let expect = List.rev [ (1, 4); (2, 5); (3, 6) ] in
    let actual = ref [] in
    let f x y = actual := (x, y) :: !actual in
    Tree.iter2_exn
      (tree 1 [ node 2 []; node 3 [] ])
      (tree 4 [ node 5 []; node 6 [] ])
      ~f ;
    [%test_result: (int * int) list] ~expect !actual

  let iter2_exn_fails =
    assert_error
      (Tuple.T2.uncurry (Tree.iter2_exn ~f:(fun _ _ -> ())))
      ( tree 1 [ node 2 []; node 3 [] ]
      , tree 4 [ node 5 []; node 6 [ node 3 [] ] ] )

  let mapi_with_trees_preserves_shape () =
    Quickcheck.test
      (Tree.gen Int.quickcheck_generator Int.quickcheck_generator
         Int.quickcheck_generator ) ~f:(fun tree ->
        let tree' = Tree.mapi_with_trees tree ~f:(fun _ _ _ -> ()) in
        ignore @@ Tree.fold2_exn tree tree' ~init:() ~f:(fun _ _ _ -> ()) )

  let mapi_with_trees_unit_test () =
    [%test_result: (int, unit, unit) Tree.t]
      ~expect:(tree 2 [ node 0 []; node 4 [ node 6 [] ] ])
      (Tree.mapi_with_trees
         (tree 1 [ node 0 []; node 2 [ node 3 [] ] ])
         ~f:(fun _ x _ -> x * 2) )

  let mapi_forest_with_trees_preserves_shape () =
    Quickcheck.test
      (gen Int.quickcheck_generator Int.quickcheck_generator
         Int.quickcheck_generator ) ~f:(fun forest ->
        let forest' = Tree.mapi_forest_with_trees forest ~f:(fun _ _ _ -> ()) in
        Tree.fold_forest2_exn forest forest' ~init:() ~f:(fun _ _ _ -> ()) )

  let mapi_forest_with_trees_unit_test () =
    [%test_result: (int, unit, unit) t]
      ~expect:[ node 2 [ node 0 []; node 4 [ node 6 [] ] ]; node 4 [] ]
      (Tree.mapi_forest_with_trees
         [ node 1 [ node 0 []; node 2 [ node 3 [] ] ]; node 2 [] ]
         ~f:(fun _ x _ -> x * 2) )

  let mapi_forest_with_trees_is_distributive () =
    Quickcheck.test
      (gen Int.quickcheck_generator Int.quickcheck_generator
         Int.quickcheck_generator ) ~f:(fun forest ->
        let f_1 = ( + ) 2 in
        let f_2 = ( * ) 3 in
        let forest_1 =
          Tree.mapi_forest_with_trees ~f:(fun _ x _ -> f_1 x)
          @@ Tree.mapi_forest_with_trees forest ~f:(fun _ x _ -> f_2 x)
        in
        let forest_2 =
          Tree.mapi_forest_with_trees forest ~f:(fun _ x _ -> f_1 @@ f_2 x)
        in
        [%test_eq: (int, int, int) t] forest_1 forest_2 )

  let mapi_prime_preserves_shape () =
    Quickcheck.test
      ( Quickcheck.Generator.tuple2 Int.quickcheck_generator
      @@ Tree.gen Int.quickcheck_generator Int.quickcheck_generator
           Int.quickcheck_generator )
      ~f:(fun (i, tree) ->
        let _, tree' = Tree.mapi' ~i tree ~f:(fun _ _ -> ()) in
        Tree.fold2_exn tree tree' ~init:() ~f:(fun _ _ _ -> ()) )

  let mapi_prime () =
    [%test_result: int * (int, unit, unit) Tree.t]
      ~expect:(7, tree 4 [ node 4 []; node 7 [ node 9 [] ] ])
      (Tree.mapi' ~i:3
         (tree 1 [ node 0 []; node 2 [ node 3 [] ] ])
         ~f:(fun i x -> i + x) )

  let mapi_forest_prime () =
    [%test_result:
      int * ((int, unit, unit) Tree.t, unit) With_stack_hash.t list]
      ~expect:(7, [ node 4 [ node 4 []; node 7 [ node 9 [] ] ] ])
      (Tree.mapi_forest' ~i:3
         [ node 1 [ node 0 []; node 2 [ node 3 [] ] ] ]
         ~f:(fun i x -> i + x) )

  (* map_forest (f_1 @@ f_2) forest <=> map_forest f_1 @@ map_forest f_2 *)
  let map_forest_is_distributive () =
    Quickcheck.test
      (gen Int.quickcheck_generator Int.quickcheck_generator
         Int.quickcheck_generator ) ~f:(fun forest ->
        let f_1 = ( + ) 2 in
        let f_2 = ( * ) 3 in
        let forest_1 =
          Tree.map_forest ~f:f_1 @@ Tree.map_forest forest ~f:f_2
        in
        let forest_2 = Tree.mapi_forest forest ~f:(fun _ x -> f_1 @@ f_2 x) in
        [%test_eq: (int, int, int) t] forest_1 forest_2 )

  let deferred_map_forest_equivalent_to_map_forest () =
    Quickcheck.test
      (gen Int.quickcheck_generator Int.quickcheck_generator
         Int.quickcheck_generator ) ~f:(fun x ->
        let tree_sync = Tree.map_forest ~f:(fun x -> x + 1) x in
        let tree_async =
          Async_unix.Thread_safe.block_on_async_exn (fun () ->
              Tree.deferred_map_forest
                ~f:(fun x _ -> Async_kernel.return (x + 1))
                x )
        in
        [%test_eq: (int, int, int) t] tree_sync tree_async )
end

let test_shape () =
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

let shape_indices_always_start_with_0_and_increse_by_1 () =
  Quickcheck.test
    (gen Int.quickcheck_generator Int.quickcheck_generator
       Int.quickcheck_generator ) ~f:(fun tree ->
      let rec check_shape (Shape.Node xs) =
        List.iteri xs ~f:(fun i (j, xs') ->
            [%test_eq: int] i j ;
            check_shape xs' )
      in
      check_shape (shape tree) )

let match_up_ok () =
  let l_1 = [ 1; 2; 3; 4; 5; 6 ] in
  let l_2 = [ (0, 'a'); (1, 'b'); (2, 'c'); (3, 'd') ] in
  let expect = [ (1, 'a'); (2, 'b'); (3, 'c'); (4, 'd') ] in
  [%test_result: (int * char) list] ~expect (match_up l_1 l_2)

let match_up_error () =
  let l_1 = [ 1; 2; 3 ] in
  let l_2 = [ (0, 'a'); (1, 'b'); (2, 'c'); (3, 'd') ] in
  assert_error (Tuple.T2.uncurry match_up) (l_1, l_2)

let match_up_error_2 () =
  let l_1 = [ 1; 2; 3 ] in
  let l_2 = [ (2, 'a'); (3, 'b'); (4, 'c'); (5, 'd') ] in
  assert_error (Tuple.T2.uncurry match_up) (l_1, l_2)

let match_up_empty () =
  let l_1 = [ 1; 2; 3; 4; 5; 6 ] in
  let l_2 = [ (1, 'a'); (2, 'b'); (3, 'c'); (4, 'd') ] in
  let expect = [] in
  [%test_result: (int * char) list] ~expect (match_up l_1 l_2)

let gen_forest_shape =
  let open Quickcheck.Generator.Let_syntax in
  let%bind forest =
    gen Int.quickcheck_generator Int.quickcheck_generator
      Unit.quickcheck_generator
  in
  let rec gen_shape (Shape.Node shape) =
    let%bind length = Int.gen_incl 0 (List.length shape) in
    let l = List.sub shape ~pos:0 ~len:length in
    let%map l =
      List.fold_left l ~init:(Quickcheck.Generator.return [])
        ~f:(fun acc (i, s) ->
          let%map acc = acc and s = gen_shape s in
          (i, s) :: acc )
    in
    Shape.Node (List.rev l)
  in
  let shape = shape forest in
  let%map shape = gen_shape shape in
  (forest, shape)

let mask () =
  Quickcheck.test gen_forest_shape ~f:(fun (f, s) ->
      [%test_result: Shape.t] ~expect:s (shape @@ mask f s) )

let to_account_updates_is_the_inverse_of_of_account_updates () =
  Quickcheck.test (Quickcheck.Generator.list Int.quickcheck_generator)
    ~f:(fun forest ->
      let forest' =
        to_account_updates
          (of_account_updates ~account_update_depth:Fn.id forest)
      in
      [%test_result: int list] ~expect:forest forest' )

let to_zkapp_command_with_hashes_list () =
  let node i hash calls =
    { With_stack_hash.elt = Tree_test.tree i calls; stack_hash = hash }
  in
  let computed =
    to_zkapp_command_with_hashes_list
      [ node 0 'a' [ node 1 'b' []; node 2 'c' [ node 3 'd' [] ] ]
      ; node 4 'e' [ node 5 'f' [] ]
      ]
  in
  let expect = [ (0, 'a'); (1, 'b'); (2, 'c'); (3, 'd'); (4, 'e'); (5, 'f') ] in
  [%test_result: (int * char) list] ~expect computed
