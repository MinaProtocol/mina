open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

(* Verify finalize_and_get_gates *)
let test_finalize_and_get_gates_with_lookup_tables () =
  let module Tick = Kimchi_backend.Pasta.Vesta_based_plonk in
  let cs = Tick.R1CS_constraint_system.create () in
  let xor_table =
    [| [| Tick.Field.zero; Tick.Field.zero; Tick.Field.zero |]
     ; [| Tick.Field.zero; Tick.Field.one; Tick.Field.one |]
     ; [| Tick.Field.one; Tick.Field.zero; Tick.Field.one |]
     ; [| Tick.Field.one; Tick.Field.one; Tick.Field.one |]
    |]
  in
  let and_table =
    [| [| Tick.Field.zero; Tick.Field.zero; Tick.Field.zero |]
     ; [| Tick.Field.zero; Tick.Field.one; Tick.Field.zero |]
     ; [| Tick.Field.one; Tick.Field.zero; Tick.Field.zero |]
     ; [| Tick.Field.one; Tick.Field.one; Tick.Field.one |]
    |]
  in
  let () =
    Tick.R1CS_constraint_system.(
      add_constraint cs (T (AddFixedLookupTable { id = 1l; data = xor_table })))
  in
  let () =
    Tick.R1CS_constraint_system.(
      add_constraint cs (T (AddFixedLookupTable { id = 2l; data = and_table })))
  in
  let () = Tick.R1CS_constraint_system.set_primary_input_size cs 1 in
  let _gates, lts, _rt =
    Tick.R1CS_constraint_system.finalize_and_get_gates cs
  in
  assert (lts.(0).id = 1l) ;
  assert (lts.(1).id = 2l) ;
  assert (Array.length lts = 2)

let test_finalize_and_get_gates_with_runtime_table_cfg () =
  let module Tick = Kimchi_backend.Pasta.Vesta_based_plonk in
  let cs = Tick.R1CS_constraint_system.create () in
  let () =
    Tick.R1CS_constraint_system.(
      add_constraint cs (T (AddRuntimeTableCfg { id = 1l; first_column = [||] })))
  in
  let () = Tick.R1CS_constraint_system.set_primary_input_size cs 1 in
  let _gates, _lt, rt = Tick.R1CS_constraint_system.finalize_and_get_gates cs in
  assert (rt.(0).id = 1l) ;
  assert (Array.length rt = 1)

let () =
  let open Alcotest in
  run "Test constraint construction"
    [ ( "Lookup tables"
      , [ test_case "Add one fixed table" `Quick
            test_finalize_and_get_gates_with_lookup_tables
        ; test_case "Add one runtime table cfg" `Quick
            test_finalize_and_get_gates_with_runtime_table_cfg
        ] )
    ]
