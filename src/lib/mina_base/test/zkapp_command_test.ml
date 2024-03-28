(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^zkApp commands$'
    Subject:    Test zkApp commands.
 *)

open Core_kernel
open Mina_base
open Zkapp_command

let account_update_or_stack_of_zkapp_command_list () =
  let open Call_forest in
  let zkapp_command_list_1 = [ 0; 0; 0; 0 ] in
  let node i calls =
    { With_stack_hash.elt =
        { Tree.calls; account_update = i; account_update_digest = () }
    ; stack_hash = ()
    }
  in
  let zkapp_command_list_1_res : (int, unit, unit) t =
    let n0 = node 0 [] in
    [ n0; n0; n0; n0 ]
  in
  let f_index = mapi ~f:(fun i _p -> i) in
  [%test_eq: (int, unit, unit) t]
    (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_1)
    zkapp_command_list_1_res ;
  let zkapp_command_list1_index : (int, unit, unit) t =
    let n i = node i [] in
    [ n 0; n 1; n 2; n 3 ]
  in
  [%test_eq: (int, unit, unit) t]
    ( of_account_updates ~account_update_depth:Fn.id zkapp_command_list_1
    |> f_index )
    zkapp_command_list1_index ;
  [%test_eq: int list]
    (to_account_updates
       (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_1) )
    zkapp_command_list_1 ;
  let zkapp_command_list_2 = [ 0; 0; 1; 1 ] in
  let zkapp_command_list_2_res =
    [ node 0 []; node 0 [ node 1 []; node 1 [] ] ]
  in
  let zkapp_command_list_2_index =
    [ node 0 []; node 1 [ node 2 []; node 3 [] ] ]
  in
  [%test_eq: (int, unit, unit) t]
    (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_2)
    zkapp_command_list_2_res ;
  [%test_eq: (int, unit, unit) t]
    ( of_account_updates ~account_update_depth:Fn.id zkapp_command_list_2
    |> f_index )
    zkapp_command_list_2_index ;
  [%test_eq: int list]
    (to_account_updates
       (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_2) )
    zkapp_command_list_2 ;
  let zkapp_command_list_3 = [ 0; 0; 1; 0 ] in
  let zkapp_command_list_3_res =
    [ node 0 []; node 0 [ node 1 [] ]; node 0 [] ]
  in
  let zkapp_command_list_3_index =
    [ node 0 []; node 1 [ node 2 [] ]; node 3 [] ]
  in
  [%test_eq: (int, unit, unit) t]
    (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_3)
    zkapp_command_list_3_res ;
  [%test_eq: (int, unit, unit) t]
    ( of_account_updates ~account_update_depth:Fn.id zkapp_command_list_3
    |> f_index )
    zkapp_command_list_3_index ;
  [%test_eq: int list]
    (to_account_updates
       (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_3) )
    zkapp_command_list_3 ;
  let zkapp_command_list_4 = [ 0; 1; 2; 3; 2; 1; 0 ] in
  let zkapp_command_list_4_res =
    [ node 0 [ node 1 [ node 2 [ node 3 [] ]; node 2 [] ]; node 1 [] ]
    ; node 0 []
    ]
  in
  let zkapp_command_list_4_index =
    [ node 0 [ node 1 [ node 2 [ node 3 [] ]; node 4 [] ]; node 5 [] ]
    ; node 6 []
    ]
  in
  [%test_eq: (int, unit, unit) t]
    (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_4)
    zkapp_command_list_4_res ;
  [%test_eq: (int, unit, unit) t]
    ( of_account_updates ~account_update_depth:Fn.id zkapp_command_list_4
    |> f_index )
    zkapp_command_list_4_index ;
  [%test_eq: int list]
    (to_account_updates
       (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_4) )
    zkapp_command_list_4

let wire_embedded_in_t () =
  let module Wire = Stable.Latest.Wire in
  Quickcheck.test ~trials:10 ~shrinker:Wire.shrinker Wire.gen ~f:(fun w ->
      [%test_eq: Wire.t] (to_wire (of_wire w)) w )

let wire_embedded_in_graphql () =
  let module Wire = Stable.Latest.Wire in
  Quickcheck.test ~shrinker:Wire.shrinker Wire.gen ~f:(fun w ->
      [%test_eq: Wire.t] (Wire.of_graphql_repr (Wire.to_graphql_repr w)) w )

(* These tests are wrapped so that the type of [full] does not have to be
   exposed (and can remain polymorphic). *)
module Test_derivers : sig
  val json_roundtrip_dummy : unit -> unit

  val full_circuit : unit -> unit
end = struct
  module Fd = Fields_derivers_zkapps.Derivers

  let full = deriver @@ Fd.o ()

  let json_roundtrip_dummy () =
    [%test_eq: t] dummy (dummy |> Fd.to_json full |> Fd.of_json full)

  let full_circuit () =
    Run_in_thread.block_on_async_exn
    @@ fun () -> Fields_derivers_zkapps.Test.Loop.run full dummy
end
