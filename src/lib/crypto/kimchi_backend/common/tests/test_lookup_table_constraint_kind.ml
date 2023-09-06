(** Testing
    -------
    Component: Kimchi_backend_common
    Subject: Testing computation of the witness and the tracking of fixed and
      runtime lookup tables
    Invocation: dune exec \
      src/lib/crypto/kimchi_backend/common/tests/test_lookup_table_constraint_kind.exe
*)

(* Keeping the test low-level for learning purposes *)

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Tick = Kimchi_backend.Pasta.Vesta_based_plonk
module Impl = Snarky_backendless.Snark.Run.Make (Tick)

let add_constraint c = Impl.assert_ { basic = T c; annotation = None }

(* Verify finalize_and_get_gates *)
let test_finalize_and_get_gates_with_lookup_tables () =
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
  let cs = Tick.R1CS_constraint_system.create () in

  let indexed_runtime_table_cfg = Array.init 4 Tick.Field.of_int in

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

let test_compute_witness_with_lookup_to_the_same_idx_twice () =
  (* See the comment in compute_witness when populating the runtime tables. The
     function does not check that the runtime table has already been set at a
     certain position, and it overwrites the previously set value *)
  let table_id = 0 in
  let table_size = 10 in
  let first_column = Array.init table_size Tick.Field.of_int in
  let repeated_idx = 0 in
  let other_idx = 1 in
  let fv2 = Tick.Field.random () in
  let fv3 = Tick.Field.random () in
  let external_values =
    Tick.Field.
      [| of_int table_id
       ; of_int repeated_idx
       ; random ()
       ; of_int repeated_idx
       ; fv2
       ; of_int other_idx
       ; fv3
      |]
  in
  let cs =
    Impl.constraint_system ~input_typ:Impl.Typ.unit ~return_typ:Impl.Typ.unit
      (fun () () ->
        let vtable_id =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(0))
        in
        let vidx1 =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(1))
        in
        let vv1 =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(2))
        in
        let vidx2 =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(3))
        in
        let vv2 =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(4))
        in
        let vidx3 =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(5))
        in
        let vv3 =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(6))
        in
        add_constraint
          (AddRuntimeTableCfg { id = Int32.of_int table_id; first_column }) ;
        add_constraint
          (Lookup
             { w0 = vtable_id
             ; w1 = vidx1
             ; w2 = vv1
             ; w3 = vidx2
             ; w4 = vv2
             ; w5 = vidx3
             ; w6 = vv3
             } ) )
  in
  let _ = Tick.R1CS_constraint_system.finalize cs in
  let _witnesses, runtime_tables =
    Tick.R1CS_constraint_system.compute_witness cs (Array.get external_values)
  in
  (* checking only one table has been created *)
  assert (Array.length runtime_tables = 1) ;
  let rt = runtime_tables.(0) in
  (* Second value is chosen *)
  assert (Tick.Field.equal rt.data.(repeated_idx) fv2) ;
  assert (Tick.Field.equal rt.data.(other_idx) fv3)

let test_compute_witness_returns_correctly_filled_runtime_tables_one_lookup () =
  (* We have one table with ID 0, indexed from 0 to n, and we will fill with
     some values using the constraint RuntimeLookup.
     We start with one lookup
  *)
  let n = 10 in
  let first_column = Array.init n Tick.Field.of_int in
  let table_id = 0 in
  let idx = Random.int n in
  let v = Tick.Field.random () in
  let external_values = Tick.Field.[| of_int table_id; of_int idx; v |] in
  let cs =
    Impl.constraint_system ~input_typ:Impl.Typ.unit ~return_typ:Impl.Typ.unit
      (fun () () ->
        let vtable_id =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(0))
        in
        let vidx =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(1))
        in
        let vv =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(2))
        in
        (* Config *)
        add_constraint
          (AddRuntimeTableCfg { id = Int32.of_int table_id; first_column }) ;
        add_constraint
          (Lookup
             { w0 = vtable_id
             ; w1 = vidx
             ; w2 = vv
             ; w3 = vidx
             ; w4 = vv
             ; w5 = vidx
             ; w6 = vv
             } ) )
  in
  let _ = Tick.R1CS_constraint_system.finalize cs in
  let _witnesses, runtime_tables =
    Tick.R1CS_constraint_system.compute_witness cs (Array.get external_values)
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
  (* We have one table with ID 0, indexed from 0 to n, and we will fill with
     some values using the constraint RuntimeLookup.
     We start with one lookup
  *)
  let n = 10 in
  let first_column = Array.init n Tick.Field.of_int in
  let table_id = 0 in
  let exp_rt_data = Array.init n (fun _ -> Tick.Field.zero) in
  (* nb of lookups *)
  let m = Random.int n in
  let external_values = Array.init (1 + (m * 2)) (fun _ -> Tick.Field.zero) in
  let cs =
    Impl.constraint_system ~input_typ:Impl.Typ.unit ~return_typ:Impl.Typ.unit
      (fun () () ->
        let vtable_id =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(0))
        in
        (* Config *)
        add_constraint
          (AddRuntimeTableCfg { id = Int32.of_int table_id; first_column }) ;
        ignore
        @@ List.init m (fun i ->
               let j = (2 * i) + 1 in
               let idx = Random.int n in
               let v = Tick.Field.random () in
               external_values.(j) <- Tick.Field.of_int idx ;
               external_values.(j + 1) <- v ;
               exp_rt_data.(idx) <- v ;
               let vidx =
                 Impl.exists Impl.Field.typ ~compute:(fun () ->
                     external_values.(j) )
               in
               let vv =
                 Impl.exists Impl.Field.typ ~compute:(fun () ->
                     external_values.(j + 1) )
               in
               add_constraint
                 (Lookup
                    { w0 = vtable_id
                    ; w1 = vidx
                    ; w2 = vv
                    ; w3 = vidx
                    ; w4 = vv
                    ; w5 = vidx
                    ; w6 = vv
                    } ) ) )
  in
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

(* Checking that lookups within a lookup table works correctly with the Lookup
   constraint in the case of the fixed lookup table does not share its ID with a
   runtime table *)
let test_compute_witness_with_fixed_lookup_table_and_runtime_table () =
  let n = 10 in
  (* Fixed table *)
  let fixed_lt_id = 2 in
  let indexes = Array.init n Tick.Field.of_int in
  let fixed_lt_values = Array.init n (fun _ -> Tick.Field.random ()) in
  let data = [| indexes; fixed_lt_values |] in
  (* Lookup info for fixed lookup *)
  let fixed_lookup_idx = 0 in
  let fixed_lookup_v = fixed_lt_values.(fixed_lookup_idx) in
  (* rt *)
  let rt_cfg_id = 3 in
  let first_column = Array.init n Tick.Field.of_int in
  let rt_idx = 1 in
  let rt_v = Tick.Field.random () in
  let external_values =
    [| Tick.Field.of_int fixed_lt_id
     ; Tick.Field.of_int rt_cfg_id
     ; Tick.Field.of_int fixed_lookup_idx
     ; fixed_lookup_v
     ; Tick.Field.of_int rt_idx
     ; rt_v
    |]
  in
  let cs =
    Impl.constraint_system ~input_typ:Impl.Typ.unit ~return_typ:Impl.Typ.unit
      (fun () () ->
        (* Add the fixed lookup table to the cs *)
        add_constraint
          (AddFixedLookupTable { id = Int32.of_int fixed_lt_id; data }) ;
        let vfixed_lt_id =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(0))
        in

        (* Runtime table cfg *)
        let vrt_cfg_id =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(1))
        in
        (* Config *)
        add_constraint
          (AddRuntimeTableCfg { id = Int32.of_int rt_cfg_id; first_column }) ;
        (* Lookup into fixed lookup table *)
        let vfixed_lookup_idx =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(2))
        in
        let vfixed_lookup_v =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(3))
        in
        add_constraint
          (Lookup
             { w0 = vfixed_lt_id
             ; w1 = vfixed_lookup_idx
             ; w2 = vfixed_lookup_v
             ; w3 = vfixed_lookup_idx
             ; w4 = vfixed_lookup_v
             ; w5 = vfixed_lookup_idx
             ; w6 = vfixed_lookup_v
             } ) ;
        (* Lookup into runtime table *)
        let vrt_idx =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(4))
        in
        let vrt_v =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(5))
        in
        add_constraint
          (Lookup
             { w0 = vrt_cfg_id
             ; w1 = vrt_idx
             ; w2 = vrt_v
             ; w3 = vrt_idx
             ; w4 = vrt_v
             ; w5 = vrt_idx
             ; w6 = vrt_v
             } ) )
  in

  let _ = Tick.R1CS_constraint_system.finalize cs in
  let _witnesses, runtime_tables =
    Tick.R1CS_constraint_system.compute_witness cs (Array.get external_values)
  in
  (* checking only one table has been created *)
  assert (Array.length runtime_tables = 1) ;
  let rt = runtime_tables.(0) in
  (* with the correct ID *)
  assert (Int32.(equal rt.id (of_int rt_cfg_id))) ;
  assert (Tick.Field.equal rt.data.(rt_idx) rt_v)

(* Checking that lookups within a lookup table works correctly with the Lookup
   constraint in the case of the fixed lookup table does share its ID with a
   runtime table. *)
let test_compute_witness_with_fixed_lookup_table_and_runtime_table_sharing_ids
    () =
  let n = 10 in
  (* Fixed table *)
  let fixed_lt_id = 2 in
  let rt_cfg_id = fixed_lt_id in
  let indexes = Array.init n Tick.Field.of_int in
  let fixed_lt_values = Array.init n (fun _ -> Tick.Field.random ()) in
  let data = [| indexes; fixed_lt_values |] in
  (* Lookup into fixed lookup table *)
  let fixed_lookup_idx = Random.int n in
  let fixed_lookup_v = fixed_lt_values.(fixed_lookup_idx) in
  let rt_idx = n + Random.int n in
  let rt_v = Tick.Field.random () in
  let external_values =
    [| Tick.Field.of_int fixed_lt_id
     ; Tick.Field.of_int rt_cfg_id
     ; Tick.Field.of_int fixed_lookup_idx
     ; fixed_lookup_v
     ; Tick.Field.of_int rt_idx
     ; rt_v
    |]
  in
  (* Extend the lookup table *)
  let first_column = Array.init n (fun i -> Tick.Field.of_int (n + i)) in
  let cs =
    Impl.constraint_system ~input_typ:Impl.Typ.unit ~return_typ:Impl.Typ.unit
      (fun () () ->
        (* Add the fixed lookup table to the cs *)
        add_constraint
          (AddFixedLookupTable { id = Int32.of_int fixed_lt_id; data }) ;

        let vfixed_lt_id =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(0))
        in
        let vrt_cfg_id =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(1))
        in
        (* Config *)
        add_constraint
          (AddRuntimeTableCfg { id = Int32.of_int rt_cfg_id; first_column }) ;
        let vfixed_lookup_idx =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(2))
        in
        let vfixed_lookup_v =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(3))
        in
        add_constraint
          (Lookup
             { w0 = vfixed_lt_id
             ; w1 = vfixed_lookup_idx
             ; w2 = vfixed_lookup_v
             ; w3 = vfixed_lookup_idx
             ; w4 = vfixed_lookup_v
             ; w5 = vfixed_lookup_idx
             ; w6 = vfixed_lookup_v
             } ) ;
        (* Lookup into runtime table *)
        let vrt_idx =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(4))
        in
        let vrt_v =
          Impl.exists Impl.Field.typ ~compute:(fun () -> external_values.(5))
        in
        add_constraint
          (Lookup
             { w0 = vrt_cfg_id
             ; w1 = vrt_idx
             ; w2 = vrt_v
             ; w3 = vrt_idx
             ; w4 = vrt_v
             ; w5 = vrt_idx
             ; w6 = vrt_v
             } ) )
  in
  let _ = Tick.R1CS_constraint_system.finalize cs in
  let _witnesses, runtime_tables =
    Tick.R1CS_constraint_system.compute_witness cs (Array.get external_values)
  in
  (* checking only one table has been created *)
  assert (Array.length runtime_tables = 1) ;
  let rt = runtime_tables.(0) in
  (* with the correct ID *)
  assert (Int32.(equal rt.id (of_int rt_cfg_id))) ;
  assert (Tick.Field.equal rt.data.(rt_idx - n) rt_v)

let test_cannot_finalize_twice_the_fixed_lookup_tables () =
  let module Tick = Kimchi_backend.Pasta.Vesta_based_plonk in
  let size = 1 + Random.int 100 in
  let indexes = Array.init size Tick.Field.of_int in
  let values = Array.init size (fun _ -> Tick.Field.random ()) in
  let cs = Tick.R1CS_constraint_system.create () in
  let () =
    Tick.R1CS_constraint_system.(
      add_constraint cs
        (T (AddFixedLookupTable { id = 1l; data = [| indexes; values |] })))
  in
  let () = Tick.R1CS_constraint_system.finalize_fixed_lookup_tables cs in
  Alcotest.check_raises "Finalize a second time the fixed lookup tables"
    (Failure "Fixed lookup tables have already been finalized") (fun () ->
      Tick.R1CS_constraint_system.finalize_fixed_lookup_tables cs )

let test_cannot_finalize_twice_the_runtime_table_cfgs () =
  let module Tick = Kimchi_backend.Pasta.Vesta_based_plonk in
  let size = 1 + Random.int 100 in
  let first_column = Array.init size Tick.Field.of_int in
  let cs = Tick.R1CS_constraint_system.create () in
  let () =
    Tick.R1CS_constraint_system.(
      add_constraint cs (T (AddRuntimeTableCfg { id = 1l; first_column })))
  in
  let () = Tick.R1CS_constraint_system.finalize_runtime_lookup_tables cs in
  Alcotest.check_raises
    "Runtime table configurations have already been finalized"
    (Failure "Runtime table configurations have already been finalized")
    (fun () -> Tick.R1CS_constraint_system.finalize_runtime_lookup_tables cs)

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
        ; test_case
            "Compute witness with runtime lookup at same index with\n\
            \          different values" `Quick
            test_compute_witness_with_lookup_to_the_same_idx_twice
        ; test_case
            "Compute witness with lookups within a runtime table and a fixed \
             lookup table, not sharing the same ID"
            `Quick
            test_compute_witness_with_fixed_lookup_table_and_runtime_table
        ; test_case
            "Compute witness with lookups within a runtime table and a fixed \
             lookup table, sharing the table ID"
            `Quick
            test_compute_witness_with_fixed_lookup_table_and_runtime_table_sharing_ids
        ; test_case "Check that fixed lookup tables cannot be finalized twice"
            `Quick test_cannot_finalize_twice_the_fixed_lookup_tables
        ; test_case
            "Check that runtime table configurations cannot be finalized twice"
            `Quick test_cannot_finalize_twice_the_runtime_table_cfgs
        ] )
    ]
