(* Testing
   -------

   Component: Free list
   Subject: Tests for free list representation
   Invocation: \
     dune exec src/lib/merkle_ledger_tests/main.exe -- test "free list"
*)

module L = Test.Location
module A = L.Addr
module F = Merkle_ledger.Free_list.Make (Test.Location)

let enumerate_unique_leaves_combinations max_depth =
  Sequence.range 0 max_depth
  |> Sequence.fold ~init:[ [] ] ~f:(fun acc _ ->
         List.map acc ~f:(List.cons Direction.Left)
         @ List.map acc ~f:(List.cons Direction.Right) )

let freelist_testable = Alcotest.testable F.pp F.equal

let gen max_depth =
  let open Quickcheck.Generator.Let_syntax in
  let%bind ledger_depth = Int.gen_incl 1 max_depth in
  let%map free_list = F.gen ~ledger_depth in
  (ledger_depth, free_list)

let test_de_serializaion =
  Alcotest.test_case "serialization/deserialization" `Quick (fun () ->
      Quickcheck.test (gen 5) ~f:(fun (ledger_depth, free_list) ->
          let bs = F.serialize ~ledger_depth free_list in
          let deserialized = F.deserialize ~ledger_depth bs in
          Alcotest.check freelist_testable
            "serialized and deserialized free lists are the same" free_list
            deserialized ) )

let tests = [ ("free list", [ test_de_serializaion ]) ]
