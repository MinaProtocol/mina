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

  let indexed_runtime_table_cfg =
    [| Tick.Field.zero
     ; Tick.Field.one
     ; Tick.Field.(one + one)
     ; Tick.Field.(one + one + one)
    |]
  in

  let () =
    Tick.R1CS_constraint_system.(
      add_constraint cs
        (T
           (AddRuntimeTableCfg
              { id = 1l; first_column = indexed_runtime_table_cfg } ) ))
  in
  let () = Tick.R1CS_constraint_system.set_primary_input_size cs 1 in
  let _aux = Tick.R1CS_constraint_system.set_auxiliary_input_size cs 1 in
  let _gates, _lt, rt = Tick.R1CS_constraint_system.finalize_and_get_gates cs in
  assert (rt.(0).id = 1l) ;
  assert (Array.length rt = 1)

let test_compute_witness_returns_correctly_filled_runtime_tables_one_lookup () =
  let module Tick = Kimchi_backend.Pasta.Vesta_based_plonk in
  let module Impl = Snarky_backendless.Snark.Run.Make (Tick) in
  (* We have one table with ID 0, indexed from 0 to n, and we will fill with
     some values using the constraint RuntimeLookup.
     We start with one lookup
  *)
  let n = 10 in
  let indexed_runtime_table_cfg = Array.init n Tick.Field.of_int in
  let table_id = 0 in
  let table_id_var, idx1_var, v1_var =
    Snarky_backendless.Cvar.(Var 0, Var 1, Var 2)
  in
  let cs = Tick.R1CS_constraint_system.create () in
  (* Config *)
  Tick.R1CS_constraint_system.(
    add_constraint cs
      (T
         (AddRuntimeTableCfg
            { id = Int32.of_int table_id
            ; first_column = indexed_runtime_table_cfg
            } ) )) ;
  (* One lookup *)
  Tick.R1CS_constraint_system.(
    add_constraint cs
      (T (RuntimeLookup { table_id = table_id_var; idx = idx1_var; v = v1_var }))) ;
  let () = Tick.R1CS_constraint_system.set_primary_input_size cs 0 in
  let () = Tick.R1CS_constraint_system.set_auxiliary_input_size cs 3 in
  (* Random value for the lookup *)
  let idx = Random.int n in
  let v = Tick.Field.random () in
  (* For the external values to give to the compute witness fn *)
  let ftable_id = Tick.Field.of_int table_id in
  let fidx = Tick.Field.of_int idx in
  let external_values = Array.get [| ftable_id; fidx; v |] in
  let _ = Tick.R1CS_constraint_system.finalize cs in
  let _witnesses, runtime_tables =
    Tick.R1CS_constraint_system.compute_witness cs external_values
  in
  (* checking only one table has been created *)
  assert (Array.length runtime_tables = 1) ;
  let rt = runtime_tables.(0) in
  (* with the correct ID *)
  assert (Int32.(equal rt.id (of_int table_id))) ;
  let exp_rt = Array.init n (fun i -> if i = idx then v else Tick.Field.zero) in
  assert (Array.for_all2 Tick.Field.equal rt.data exp_rt)

let test_compute_witness_returns_correctly_filled_runtime_tables_multiple_lookup
    () =
  let module Tick = Kimchi_backend.Pasta.Vesta_based_plonk in
  let module Impl = Snarky_backendless.Snark.Run.Make (Tick) in
  (* We have one table with ID 0, indexed from 0 to n, and we will fill with
     some values using the constraint RuntimeLookup.
     We start with one lookup
  *)
  let n = 10 in
  let indexed_runtime_table_cfg = Array.init n Tick.Field.of_int in
  let table_id = 0 in
  let table_id_var = Snarky_backendless.Cvar.Var 0 in
  let cs = Tick.R1CS_constraint_system.create () in
  (* Config *)
  Tick.R1CS_constraint_system.(
    add_constraint cs
      (T
         (AddRuntimeTableCfg
            { id = Int32.of_int table_id
            ; first_column = indexed_runtime_table_cfg
            } ) )) ;
  (* nb of lookups *)
  let m = Random.int n in
  let exp_rt_data = Array.init n (fun _ -> Tick.Field.zero) in
  (* For the external values to give to the compute witness fn *)
  let ftable_id = Tick.Field.of_int table_id in
  let external_values = Array.init (1 + (m * 2)) (fun _ -> Tick.Field.zero) in
  external_values.(0) <- ftable_id ;
  let _ =
    List.init m (fun i ->
        let j = (2 * i) + 1 in
        let idx_var = Snarky_backendless.Cvar.Var j in
        let val_var = Snarky_backendless.Cvar.Var (j + 1) in
        (* One lookup *)
        let _ =
          Tick.R1CS_constraint_system.(
            add_constraint cs
              (T
                 (RuntimeLookup
                    { table_id = table_id_var; idx = idx_var; v = val_var } ) ))
        in
        (* Random value for the lookup *)
        let idx = Random.int n in
        let v = Tick.Field.random () in
        external_values.(j) <- Tick.Field.of_int idx ;
        external_values.(j + 1) <- v ;
        exp_rt_data.(idx) <- v ;
        (idx_var, val_var) )
  in
  let nb_aux = (2 * m) + 1 in
  let () = Tick.R1CS_constraint_system.set_primary_input_size cs 0 in
  let () = Tick.R1CS_constraint_system.set_auxiliary_input_size cs nb_aux in

  let _ = Tick.R1CS_constraint_system.finalize cs in
  let _witnesses, runtime_tables =
    Tick.R1CS_constraint_system.compute_witness cs (Array.get external_values)
  in
  (* checking only one table has been created *)
  assert (Array.length runtime_tables = 1) ;
  let rt = runtime_tables.(0) in
  (* with the correct ID *)
  assert (Int32.(equal rt.id (of_int table_id))) ;
  assert (Array.for_all2 Tick.Field.equal rt.data exp_rt_data)

let () =
  let open Alcotest in
  run "Test constraint construction"
    [ ( "Lookup tables"
      , [ test_case "Add one fixed table" `Quick
            test_finalize_and_get_gates_with_lookup_tables
        ; test_case "Add one runtime table cfg" `Quick
            test_finalize_and_get_gates_with_runtime_table_cfg
        ; test_case "Compute witness with one runtime table lookup" `Quick
            test_compute_witness_returns_correctly_filled_runtime_tables_one_lookup
        ; test_case "Compute witness with multiple runtime table lookup" `Quick
            test_compute_witness_returns_correctly_filled_runtime_tables_multiple_lookup
        ] )
    ]
