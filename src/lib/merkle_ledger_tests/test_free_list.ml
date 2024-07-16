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

let test_sd =
  Alcotest.test_case "serialization/deserialization" `Quick (fun () ->
      let ledger_depth = 3 in
      let freed =
        List.fold_left ~init:F.empty
          (Test.enumerate_dir_combinations ledger_depth)
          ~f:(fun freelist directions ->
            let a = A.of_directions directions in
            F.Location.add freelist (L.Account a) )
      in
      let bs = F.serialize ~ledger_depth freed in
      let deserialized = F.deserialize ~ledger_depth bs in
      [%test_eq: Int.t] (F.size freed) (F.size deserialized) )

let tests = [ ("free list", [ test_sd ]) ]
