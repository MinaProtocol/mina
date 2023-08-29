open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let add_constraint c = assert_ { basic = c; annotation = None }

let add_plonk_constraint c =
  add_constraint
    (Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T c)

let fresh_int i = exists Field.typ ~compute:(fun () -> Field.Constant.of_int i)

let main_xor () =
  add_plonk_constraint
    (Xor
       { in1 = fresh_int 0
       ; in2 = fresh_int 0
       ; out = fresh_int 0
       ; in1_0 = fresh_int 0
       ; in1_1 = fresh_int 0
       ; in1_2 = fresh_int 0
       ; in1_3 = fresh_int 0
       ; in2_0 = fresh_int 0
       ; in2_1 = fresh_int 0
       ; in2_2 = fresh_int 0
       ; in2_3 = fresh_int 0
       ; out_0 = fresh_int 0
       ; out_1 = fresh_int 0
       ; out_2 = fresh_int 0
       ; out_3 = fresh_int 0
       } ) ;
  add_plonk_constraint (Raw { kind = Zero; values = [||]; coeffs = [||] })

let main_range_check0 () =
  add_plonk_constraint
    (RangeCheck0
       { v0 = fresh_int 0
       ; v0p0 = fresh_int 0
       ; v0p1 = fresh_int 0
       ; v0p2 = fresh_int 0
       ; v0p3 = fresh_int 0
       ; v0p4 = fresh_int 0
       ; v0p5 = fresh_int 0
       ; v0c0 = fresh_int 0
       ; v0c1 = fresh_int 0
       ; v0c2 = fresh_int 0
       ; v0c3 = fresh_int 0
       ; v0c4 = fresh_int 0
       ; v0c5 = fresh_int 0
       ; v0c6 = fresh_int 0
       ; v0c7 = fresh_int 0
       ; (* Coefficients *)
         compact = Field.Constant.zero
       } )

let main_range_check1 () =
  add_plonk_constraint
    (RangeCheck1
       { v2 = fresh_int 0
       ; v12 = fresh_int 0
       ; v2c0 = fresh_int 0
       ; v2p0 = fresh_int 0
       ; v2p1 = fresh_int 0
       ; v2p2 = fresh_int 0
       ; v2p3 = fresh_int 0
       ; v2c1 = fresh_int 0
       ; v2c2 = fresh_int 0
       ; v2c3 = fresh_int 0
       ; v2c4 = fresh_int 0
       ; v2c5 = fresh_int 0
       ; v2c6 = fresh_int 0
       ; v2c7 = fresh_int 0
       ; v2c8 = fresh_int 0
       ; v2c9 = fresh_int 0
       ; v2c10 = fresh_int 0
       ; v2c11 = fresh_int 0
       ; v0p0 = fresh_int 0
       ; v0p1 = fresh_int 0
       ; v1p0 = fresh_int 0
       ; v1p1 = fresh_int 0
       ; v2c12 = fresh_int 0
       ; v2c13 = fresh_int 0
       ; v2c14 = fresh_int 0
       ; v2c15 = fresh_int 0
       ; v2c16 = fresh_int 0
       ; v2c17 = fresh_int 0
       ; v2c18 = fresh_int 0
       ; v2c19 = fresh_int 0
       } )

let main_rot () =
  add_plonk_constraint
    (Rot64
       { word = fresh_int 0
       ; rotated = fresh_int 0
       ; excess = fresh_int 0
       ; bound_limb0 = fresh_int 0xFFF
       ; bound_limb1 = fresh_int 0xFFF
       ; bound_limb2 = fresh_int 0xFFF
       ; bound_limb3 = fresh_int 0xFFF
       ; bound_crumb0 = fresh_int 3
       ; bound_crumb1 = fresh_int 3
       ; bound_crumb2 = fresh_int 3
       ; bound_crumb3 = fresh_int 3
       ; bound_crumb4 = fresh_int 3
       ; bound_crumb5 = fresh_int 3
       ; bound_crumb6 = fresh_int 3
       ; bound_crumb7 = fresh_int 3
       ; two_to_rot = Field.Constant.one
       } ) ;
  add_plonk_constraint
    (Raw { kind = Zero; values = [| fresh_int 0 |]; coeffs = [||] })

let main_foreign_field_add () =
  add_plonk_constraint
    (ForeignFieldAdd
       { left_input_lo = fresh_int 0
       ; left_input_mi = fresh_int 0
       ; left_input_hi = fresh_int 0
       ; right_input_lo = fresh_int 0
       ; right_input_mi = fresh_int 0
       ; right_input_hi = fresh_int 0
       ; field_overflow = fresh_int 0
       ; carry = fresh_int 0
       ; foreign_field_modulus0 = Field.Constant.of_int 1
       ; foreign_field_modulus1 = Field.Constant.of_int 0
       ; foreign_field_modulus2 = Field.Constant.of_int 0
       ; sign = Field.Constant.of_int 0
       } ) ;
  add_plonk_constraint
    (Raw { kind = Zero; values = [| fresh_int 0 |]; coeffs = [||] })

let main_foreign_field_mul () =
  add_plonk_constraint
    (ForeignFieldMul
       { left_input0 = fresh_int 0
       ; left_input1 = fresh_int 0
       ; left_input2 = fresh_int 0
       ; right_input0 = fresh_int 0
       ; right_input1 = fresh_int 0
       ; right_input2 = fresh_int 0
       ; remainder01 = fresh_int 0
       ; remainder2 = fresh_int 0
       ; quotient0 = fresh_int 0
       ; quotient1 = fresh_int 0
       ; quotient2 = fresh_int 0
       ; quotient_hi_bound =
           exists Field.typ ~compute:(fun () ->
               let open Field.Constant in
               let two_to_21 = of_int Int.(2 lsl 21) in
               let two_to_42 = two_to_21 * two_to_21 in
               let two_to_84 = two_to_42 * two_to_42 in
               two_to_84 - one - one )
       ; product1_lo = fresh_int 0
       ; product1_hi_0 = fresh_int 0
       ; product1_hi_1 = fresh_int 0
       ; carry0 = fresh_int 0
       ; carry1_0 = fresh_int 0
       ; carry1_12 = fresh_int 0
       ; carry1_24 = fresh_int 0
       ; carry1_36 = fresh_int 0
       ; carry1_48 = fresh_int 0
       ; carry1_60 = fresh_int 0
       ; carry1_72 = fresh_int 0
       ; carry1_84 = fresh_int 0
       ; carry1_86 = fresh_int 0
       ; carry1_88 = fresh_int 0
       ; carry1_90 = fresh_int 0
       ; foreign_field_modulus2 = Field.Constant.one
       ; neg_foreign_field_modulus0 = Field.Constant.zero
       ; neg_foreign_field_modulus1 = Field.Constant.zero
       ; neg_foreign_field_modulus2 =
           Field.Constant.(
             let two_to_22 = of_int Int.(2 lsl 22) in
             let two_to_44 = two_to_22 * two_to_22 in
             let two_to_88 = two_to_44 * two_to_44 in
             two_to_88 - one)
       } ) ;
  add_plonk_constraint
    (Raw { kind = Zero; values = [| fresh_int 0 |]; coeffs = [||] })

let main_fixed_lookup_tables_simple () =
  (* We start with a simple test with a small and fixed lookup tables *)
  add_plonk_constraint
    (AddFixedLookupTable
       { id = 0l
       ; data =
           (* It is an indexed table containing the values [0, 1, 2, 3] *)
           [| [| Field.Constant.of_int 0
               ; Field.Constant.of_int 1
               ; Field.Constant.of_int 2
               ; Field.Constant.of_int 3
              |]
            ; [| Field.Constant.of_int 0
               ; Field.Constant.of_int 1
               ; Field.Constant.of_int 2
               ; Field.Constant.of_int 3
              |]
           |]
       } ) ;
  (* A lookup constraint consists of 7 values where the first one is the
     table id, and the 6 others are pairs of indexes/values. We can do a up to
     3 lookup in the same table. Here we check t[0] = 0, t[1] = 1, t[2] = 2 *)
  add_plonk_constraint
    (Lookup
       { (* table id *)
         w0 = fresh_int 0
       ; (* idx1 *) w1 = fresh_int 0
       ; (* v1 *) w2 = fresh_int 0
       ; (* idx2 *) w3 = fresh_int 1
       ; (* v2 *) w4 = fresh_int 1
       ; (* idx3 *) w5 = fresh_int 2
       ; (* v3 *) w6 = fresh_int 2
       } )

let main_fixed_lookup_tables_values_not_sorted () =
  add_plonk_constraint
    (AddFixedLookupTable
       { id = 0l
       ; data =
           (* It is an indexed table containing the values [0, 1, 2, 3] *)
           [| [| Field.Constant.of_int 0
               ; Field.Constant.of_int 1
               ; Field.Constant.of_int 2
               ; Field.Constant.of_int 3
              |]
            ; [| Field.Constant.of_int 87
               ; Field.Constant.of_int 84
               ; Field.Constant.of_int 83
               ; Field.Constant.of_int 5
              |]
           |]
       } ) ;
  add_plonk_constraint
    (Lookup
       { (* table id *)
         w0 = fresh_int 0
       ; (* idx1 *) w1 = fresh_int 0
       ; (* v1 *) w2 = fresh_int 87
       ; (* idx2 *) w3 = fresh_int 3
       ; (* v2 *) w4 = fresh_int 5
       ; (* idx3 *) w5 = fresh_int 1
       ; (* v3 *) w6 = fresh_int 84
       } ) ;

  (* Same index and values in the same constraint *)
  add_plonk_constraint
    (Lookup
       { (* table id *)
         w0 = fresh_int 0
       ; (* idx1 *) w1 = fresh_int 0
       ; (* v1 *) w2 = fresh_int 87
       ; (* idx2 *) w3 = fresh_int 0
       ; (* v2 *) w4 = fresh_int 87
       ; (* idx3 *) w5 = fresh_int 0
       ; (* v3 *) w6 = fresh_int 87
       } )

(* FIXME: This test seems to fail on random values. It is not added at the
   moment, and therefore prefixed with _.
   TODO: open a GitHub issue and link here
*)
let _main_fixed_lookup_tables_randomized () =
  let nb_lookups = 1 + Random.int 30 in
  let nb_tables = 1 + Random.int 100 in
  let lookup_tables =
    Array.init nb_tables ~f:(fun table_id ->
        let n_indexes = 1 + Random.int 20 in
        let n_indexes = 4 in
        let indexes = Array.init n_indexes ~f:Field.Constant.of_int in
        let values =
          Array.init n_indexes ~f:(fun i ->
              Field.Constant.of_int (Random.int 100) )
        in
        add_plonk_constraint
          (AddFixedLookupTable
             { id = Int.to_int32_exn table_id; data = [| indexes; values |] } ) ;
        [| indexes; values |] )
  in
  ignore
  @@ Array.init nb_lookups ~f:(fun i ->
         let table_id = 0 in
         let pickled_lt_data = lookup_tables.(table_id).(1) in
         let table_size = Array.length pickled_lt_data in
         let i1 = Random.int table_size in
         let v1 = pickled_lt_data.(i1) in
         let vv1 = exists Field.typ ~compute:(fun () -> v1) in
         let i2 = Random.int table_size in
         let v2 = pickled_lt_data.(i2) in
         let vv2 = exists Field.typ ~compute:(fun () -> v2) in
         let i3 = Random.int table_size in
         let v3 = pickled_lt_data.(i3) in
         let vv3 = exists Field.typ ~compute:(fun () -> v3) in
         add_plonk_constraint
           (Lookup
              { w0 = fresh_int table_id
              ; w1 = fresh_int i1
              ; w2 = vv1
              ; w3 = fresh_int i2
              ; w4 = vv2
              ; w5 = fresh_int i3
              ; w6 = vv3
              } ) )

let add_tests, get_tests =
  let tests = ref [] in
  ( (fun name testcases -> tests := (name, testcases) :: !tests)
  , fun () -> List.rev !tests )

let constraint_constants =
  { Snark_keys_header.Constraint_constants.sub_windows_per_window = 0
  ; ledger_depth = 0
  ; work_delay = 0
  ; block_window_duration_ms = 0
  ; transaction_capacity = Log_2 0
  ; pending_coinbase_depth = 0
  ; coinbase_amount = Unsigned.UInt64.of_int 0
  ; supercharged_coinbase_factor = 0
  ; account_creation_fee = Unsigned.UInt64.of_int 0
  ; fork = None
  }

let main_body ~(feature_flags : _ Plonk_types.Features.t) () =
  if feature_flags.rot then main_rot () ;
  if feature_flags.xor then main_xor () ;
  if feature_flags.range_check0 then main_range_check0 () ;
  if feature_flags.range_check1 then main_range_check1 () ;
  if feature_flags.foreign_field_add then main_foreign_field_add () ;
  if feature_flags.foreign_field_mul then main_foreign_field_mul () ;
  if feature_flags.lookup then (
    main_fixed_lookup_tables_simple () ;
    main_fixed_lookup_tables_values_not_sorted () )

let register_test name feature_flags1 feature_flags2 =
  let _tag, _cache_handle, proof, Pickles.Provers.[ prove1; prove2 ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N2)
      ~max_proofs_verified:(module Nat.N0)
      ~name:"optional_custom_gates"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "main1"
          ; prevs = []
          ; main =
              (fun _ ->
                main_body ~feature_flags:feature_flags1 () ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags = feature_flags1
          }
        ; { identifier = "main2"
          ; prevs = []
          ; main =
              (fun _ ->
                main_body ~feature_flags:feature_flags2 () ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags = feature_flags2
          }
        ] )
      ()
  in
  let module Proof = (val proof) in
  let test_prove1 () =
    let public_input1, (), proof1 =
      Async.Thread_safe.block_on_async_exn (fun () -> prove1 ())
    in
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Proof.verify [ (public_input1, proof1) ] ) )
  in
  let test_prove2 () =
    let public_input2, (), proof2 =
      Async.Thread_safe.block_on_async_exn (fun () -> prove2 ())
    in
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Proof.verify [ (public_input2, proof2) ] ) )
  in

  let open Alcotest in
  add_tests name
    [ test_case "prove 1" `Quick test_prove1
      (* ; test_case "prove 2" `Quick test_prove2 *)
    ]

let register_feature_test (name, specific_feature_flags) =
  (* Tests activating "on" logic*)
  register_test name specific_feature_flags specific_feature_flags
(* Tests activating "maybe on" logic *)
(* register_test *)
(*   (Printf.sprintf "%s (maybe)" name) *)
(*   specific_feature_flags Plonk_types.Features.none_bool *)

let () =
  let configurations =
    [ ("xor", Plonk_types.Features.{ none_bool with xor = true })
    ; ( "range check 0"
      , Plonk_types.Features.{ none_bool with range_check0 = true } )
    ; ( "range check 1"
      , Plonk_types.Features.{ none_bool with range_check1 = true } )
    ; ("rot", Plonk_types.Features.{ none_bool with rot = true })
    ; ( "foreign field addition"
      , Plonk_types.Features.{ none_bool with foreign_field_add = true } )
    ; ( "foreign field multiplication"
      , Plonk_types.Features.{ none_bool with foreign_field_mul = true } )
    ; ( "Fixed lookup tables"
      , Plonk_types.Features.{ none_bool with lookup = true } )
    ]
  in
  List.iter ~f:register_feature_test configurations ;
  Alcotest.run "Custom gates" (get_tests ())
