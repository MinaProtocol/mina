(** Testing
    -------
    Component: Pickles
    Subject: Testing computation of the domains when fixed and runtime tables are present
    Invocation: dune exec \
      src/lib/pickles/test/optional_custom_gates/test_fix_domains.exe
*)

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

let add_constraint c =
  Pickles.Impls.Step.assert_ { basic = T c; annotation = None }

let etyp_unit =
  Composition_types.Spec.ETyp.T
    (Snarky_backendless.Typ.unit (), Core_kernel.Fn.id, Core_kernel.Fn.id)

let test_fix_domains_with_runtime_table_cfgs () =
  let table_sizes = [ [ 1 ]; [ 1; 1 ]; [ 1; 10; 42; 36 ] ] in
  (* Log2 value *)
  let exp_output = [ 3; 3; 7 ] in
  let feature_flags =
    Pickles_types.Plonk_types.Features.{ none_bool with runtime_tables = true }
  in
  assert (
    List.for_all2
      (fun table_sizes exp_output ->
        let main () =
          List.iteri
            (fun i table_size ->
              let first_column =
                Array.init table_size (fun _ ->
                    Pickles.Impls.Step.Field.Constant.random () )
              in
              add_constraint
                (AddRuntimeTableCfg { id = Int32.of_int i; first_column }) )
            table_sizes
        in
        let domains =
          Pickles__Fix_domains.domains ~feature_flags
            (module Pickles.Impls.Step)
            etyp_unit etyp_unit main
        in
        let log2_size = Pickles_base.Domain.log2_size domains.h in
        log2_size = exp_output )
      table_sizes exp_output )

let test_fix_domains_with_runtime_table_cfgs_and_fixed_lookup_tables () =
  (* Tables do not share the same ID *)
  let fixed_table_sizes = [ [ 1 ]; [ 1; 1 ]; [ 1; 10; 42; 36 ]; []; [ 1 ] ] in
  let rt_cfgs_table_sizes = [ [ 1 ]; [ 1; 1 ]; [ 1; 10; 42; 36 ]; [ 1 ]; [] ] in
  let exp_outputs = [ 3; 3; 8; 3; 3 ] in
  let feature_flags =
    Pickles_types.Plonk_types.Features.
      { none_bool with lookup = true; runtime_tables = true }
  in
  assert (
    List.for_all2
      (fun (fixed_table_sizes, rt_cfgs_table_sizes) exp_output ->
        let n_fixed_table_sizes = List.length fixed_table_sizes in
        let main () =
          List.iteri
            (fun i table_size ->
              let indexes =
                Array.init table_size Pickles.Impls.Step.Field.Constant.of_int
              in
              let values =
                Array.init table_size (fun _ ->
                    Pickles.Impls.Step.Field.Constant.random () )
              in
              add_constraint
                (AddFixedLookupTable
                   { id = Int32.of_int i; data = [| indexes; values |] } ) )
            fixed_table_sizes ;
          List.iteri
            (fun i table_size ->
              let first_column =
                Array.init table_size Pickles.Impls.Step.Field.Constant.of_int
              in
              add_constraint
                (AddRuntimeTableCfg
                   { id = Int32.of_int (n_fixed_table_sizes + i); first_column }
                ) )
            rt_cfgs_table_sizes
        in
        let domains =
          Pickles__Fix_domains.domains ~feature_flags
            (module Pickles.Impls.Step)
            etyp_unit etyp_unit main
        in
        let log2_size = Pickles_base.Domain.log2_size domains.h in
        log2_size = exp_output )
      (List.combine fixed_table_sizes rt_cfgs_table_sizes)
      exp_outputs )

let test_fix_domains_with_runtime_table_cfgs_and_fixed_lookup_tables_sharing_id
    () =
  let id = 0l in
  let fixed_lt_sizes = [ 3; 1; 7 ] in
  let rt_cfg_sizes = [ 3; 7; 8 ] in
  (* log2 value *)
  let exp_outputs = [ 4; 4; 5 ] in
  let feature_flags =
    Pickles_types.Plonk_types.Features.
      { none_bool with lookup = true; runtime_tables = true }
  in
  assert (
    List.for_all2
      (fun (fixed_table_size, rt_cfg_table_size) exp_output ->
        let main () =
          let indexes =
            Array.init fixed_table_size Pickles.Impls.Step.Field.Constant.of_int
          in
          let values =
            Array.init fixed_table_size (fun _ ->
                Pickles.Impls.Step.Field.Constant.random () )
          in
          add_constraint
            (AddFixedLookupTable { id; data = [| indexes; values |] }) ;
          let first_column =
            Array.init rt_cfg_table_size
              Pickles.Impls.Step.Field.Constant.of_int
          in
          add_constraint (AddRuntimeTableCfg { id; first_column })
        in
        let domains =
          Pickles__Fix_domains.domains ~feature_flags
            (module Pickles.Impls.Step)
            etyp_unit etyp_unit main
        in
        let log2_size = Pickles_base.Domain.log2_size domains.h in
        log2_size = exp_output )
      (List.combine fixed_lt_sizes rt_cfg_sizes)
      exp_outputs )

let test_fix_domains_with_fixed_lookup_tables () =
  let table_sizes = [ [ 1 ]; [ 1; 1 ]; [ 1; 10; 42; 36 ] ] in
  (* Log2 value *)
  let exp_output = [ 3; 3; 7 ] in
  let feature_flags =
    Pickles_types.Plonk_types.Features.{ none_bool with lookup = true }
  in
  assert (
    List.for_all2
      (fun table_sizes exp_output ->
        let main () =
          List.iteri
            (fun i table_size ->
              let indexes =
                Array.init table_size Pickles.Impls.Step.Field.Constant.of_int
              in
              let values =
                Array.init table_size (fun _ ->
                    Pickles.Impls.Step.Field.Constant.random () )
              in
              add_constraint
                (AddFixedLookupTable
                   { id = Int32.of_int i; data = [| indexes; values |] } ) )
            table_sizes
        in
        let domains =
          Pickles__Fix_domains.domains ~feature_flags
            (module Pickles.Impls.Step)
            etyp_unit etyp_unit main
        in
        let log2_size = Pickles_base.Domain.log2_size domains.h in
        log2_size = exp_output )
      table_sizes exp_output )

let () =
  let open Alcotest in
  run "Test Pickles.Fix_domains with custom gates"
    [ ( "domains"
      , [ test_case "With only fixed lookup tables" `Quick
            test_fix_domains_with_fixed_lookup_tables
        ; test_case "With only runtime table cfgs" `Quick
            test_fix_domains_with_runtime_table_cfgs
        ; test_case "With runtime table cfgs and fixed lookup tables" `Quick
            test_fix_domains_with_runtime_table_cfgs_and_fixed_lookup_tables
        ; test_case "With runtime table cfgs and fixed lookup tables sharing ID"
            `Quick
            test_fix_domains_with_runtime_table_cfgs_and_fixed_lookup_tables_sharing_id
        ] )
    ]
