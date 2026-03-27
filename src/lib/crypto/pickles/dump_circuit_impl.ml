(* Dump Kimchi circuit gate data to JSON for each DSL operation.

   This module lives inside the pickles library so it has access to
   internal modules like Plonk_curve_ops.

   Usage: dune exec src/lib/pickles/dump_circuit/dump_circuit.exe *)

open Core_kernel

module Impl = Kimchi_pasta_snarky_backend.Step_impl

module Add = Plonk_curve_ops.Make_add(Impl)

module Step_SC = Scalar_challenge.Make
  (Impl)
  (Step_main_inputs.Inner_curve)
  (Import.Challenge.Make(Impl))
  (Endo.Step_inner_curve)

(* Instantiate Plonk_checks.Make for Type1 shifted values (Step/Tick side) *)
module Step_plonk_checks = struct
  include Plonk_checks
  include
    Plonk_checks.Make
      (Pickles_types.Shifted_value.Type1)
      (Plonk_checks.Scalars_tokens_interpreter.Tick)
end

let dump output_dir name circuit ~input_typ ~return_typ =
  let cs =
    Impl.constraint_system ~input_typ ~return_typ circuit
  in
  let json =
    Kimchi_pasta_constraint_system.Vesta_constraint_system.to_json cs
  in
  let path = output_dir ^ "/" ^ name ^ ".json" in
  Out_channel.write_all path ~data:(json ^ "\n") ;
  Printf.printf "Wrote %s\n" path ;
  (* Write cached constants *)
  let constants_path = output_dir ^ "/" ^ name ^ "_cached_constants.json" in
  let constants_json =
    Kimchi_pasta_constraint_system.Vesta_constraint_system.dump_cached_constants cs
  in
  Out_channel.write_all constants_path ~data:(constants_json ^ "\n") ;
  Printf.printf "Wrote %s\n" constants_path

(* ---- Field arithmetic circuits ---- *)

let mul_circuit (x : Impl.Field.t) () =
  let y =
    Impl.exists Impl.Field.typ ~compute:(fun () ->
        Impl.Field.Constant.of_int 3 )
  in
  Impl.Field.(x * y)

let inv_circuit (x : Impl.Field.t) () =
  Impl.Field.inv x

let div_circuit (x : Impl.Field.t) () =
  let y =
    Impl.exists Impl.Field.typ ~compute:(fun () ->
        Impl.Field.Constant.of_int 3 )
  in
  Impl.Field.(x / y)

let equals_circuit (x : Impl.Field.t) () =
  let y =
    Impl.exists Impl.Field.typ ~compute:(fun () ->
        Impl.Field.Constant.of_int 3 )
  in
  Impl.Field.equal x y

let if_circuit (x : Impl.Field.t) () =
  let y =
    Impl.exists Impl.Field.typ ~compute:(fun () ->
        Impl.Field.Constant.of_int 3 )
  in
  let b =
    Impl.exists Impl.Boolean.typ ~compute:(fun () -> true)
  in
  Impl.Field.if_ b ~then_:x ~else_:y

(* ---- Assertion circuits ---- *)

let assert_equal_circuit (x : Impl.Field.t) () =
  let y =
    Impl.exists Impl.Field.typ ~compute:(fun () ->
        Impl.Field.Constant.of_int 3 )
  in
  Impl.Field.Assert.equal x y

let assert_square_circuit (x : Impl.Field.t) () =
  let y =
    Impl.exists Impl.Field.typ ~compute:(fun () ->
        Impl.Field.Constant.of_int 9 )
  in
  Impl.assert_square x y

let pow2_pow_circuit (x : Impl.Field.t) () =
  let rec go acc i =
    if i = 0 then acc else go (Impl.Field.square acc) (i - 1)
  in
  let (_ : Impl.Field.t) = go x 16 in
  ()

let assert_non_zero_circuit (x : Impl.Field.t) () =
  Impl.Field.Assert.non_zero x

let assert_not_equal_circuit (x : Impl.Field.t) () =
  let y =
    Impl.exists Impl.Field.typ ~compute:(fun () ->
        Impl.Field.Constant.of_int 3 )
  in
  Impl.Field.Assert.not_equal x y

let unpack_circuit (x : Impl.Field.t) () =
  let _bits = Impl.Field.unpack x ~length:(Impl.Field.size_in_bits - 1) in
  ()

(* ---- Boolean circuits ---- *)

let bool_and_circuit (x : Impl.Boolean.var) () =
  let y =
    Impl.exists Impl.Boolean.typ ~compute:(fun () -> true)
  in
  Impl.Boolean.(x &&& y)

let bool_or_circuit (x : Impl.Boolean.var) () =
  let y =
    Impl.exists Impl.Boolean.typ ~compute:(fun () -> true)
  in
  Impl.Boolean.(x ||| y)

let bool_xor_circuit (x : Impl.Boolean.var) () =
  let y =
    Impl.exists Impl.Boolean.typ ~compute:(fun () -> true)
  in
  Impl.Boolean.(x lxor y)

let bool_all_circuit (x : Impl.Boolean.var) () =
  let y =
    Impl.exists Impl.Boolean.typ ~compute:(fun () -> true)
  in
  let w =
    Impl.exists Impl.Boolean.typ ~compute:(fun () -> true)
  in
  Impl.Boolean.all [ x; y; w ]

let bool_any_circuit (x : Impl.Boolean.var) () =
  let y =
    Impl.exists Impl.Boolean.typ ~compute:(fun () -> true)
  in
  let w =
    Impl.exists Impl.Boolean.typ ~compute:(fun () -> true)
  in
  Impl.Boolean.any [ x; y; w ]

let bool_assert_circuit (x : Impl.Boolean.var) () =
  Impl.Boolean.Assert.is_true x

(* ---- Kimchi gate circuits ---- *)

let add_complete_circuit (p1, p2) () =
  Add.add_fast ~check_finite:false p1 p2

let endo_scalar_circuit (scalar : Impl.Field.t) () =
  Scalar_challenge.to_field_checked (module Impl)
    ~endo:Endo.Wrap_inner_curve.scalar
    { Kimchi_types.inner = scalar }

let endo_mul_circuit (p, scalar) () =
  Step_SC.endo p { Kimchi_types.inner = scalar }

module Ops = Plonk_curve_ops.Make (Impl) (Step_main_inputs.Inner_curve)

let var_base_mul_circuit (g, scalar) () =
  Ops.scale_fast g ~num_bits:Impl.Field.size_in_bits
    (Pickles_types.Shifted_value.Type1.Shifted_value scalar)

module Public_input_scalar = struct
  type t = Impl.Field.t

  let typ = Impl.Field.typ

  module Constant = struct
    include Impl.Field.Constant

    let to_bigint = Impl.Bigint.of_field
  end
end

let scale_fast2_128_circuit (g, scalar) () =
  Ops.scale_fast2' (module Public_input_scalar) g scalar ~num_bits:128

let poseidon_circuit (state : Impl.Field.t array) () =
  let params =
    Sponge.Params.map Tick_field_sponge.params ~f:Impl.Field.constant
  in
  Step_main_inputs.Sponge.Permutation.block_cipher params state

(* ---- pow circuit (matches plonk_checks.ml scalars_env pow) ---- *)

let pow_ (x : Impl.Field.t) n =
  let open Impl.Field in
  let square x = x * x in
  let rec pow x n =
    if n = 0 then one
    else if n = 1 then x
    else
      let y = pow (square x) Int.(n / 2) in
      if n mod 2 = 0 then y else x * y
  in
  pow x n

let pow7_circuit (x : Impl.Field.t) () = pow_ x 7

let pow8_circuit (x : Impl.Field.t) () = pow_ x 8

(* ---- Linearization polynomial circuit ---- *)

(* Uses Plonk_checks.scalars_env directly, matching the step verifier.
   Input: (plonk_minimal, combined_evals) where plonk_minimal has
   alpha, beta, gamma, zeta and combined_evals has all evaluation pairs.

   Input layout (90 fields via flat array):
   0-29:  witness evals w (15 pairs of (zeta, zetaw))
   30-59: coefficient evals (15 pairs of (zeta, zetaw))
   60-61: z eval (1 pair)
   62-73: s evals (6 pairs)
   74-75: generic_selector (1 pair)
   76-77: poseidon_selector (1 pair)
   78-79: complete_add_selector (1 pair)
   80-81: mul_selector (1 pair)
   82-83: emul_selector (1 pair)
   84-85: endomul_scalar_selector (1 pair)
   86: alpha, 87: beta, 88: gamma, 89: zeta *)

let linearization_tick_circuit (inputs : Impl.Field.t array) () =
  let pair i = (inputs.(i), inputs.(i + 1)) in
  let w = Pickles_types.Vector.init Pickles_types.Nat.N15.n ~f:(fun i ->
    pair (2 * i)) in
  let coefficients = Pickles_types.Vector.init Pickles_types.Nat.N15.n ~f:(fun i ->
    pair (30 + 2 * i)) in
  let z = pair 60 in
  let s = Pickles_types.Vector.init Pickles_types.Nat.N6.n ~f:(fun i ->
    pair (62 + 2 * i)) in
  let combined_evals : (Impl.Field.t * Impl.Field.t, _) Kimchi_backend_common.Plonk_types.Evals.In_circuit.t =
    { w
    ; coefficients
    ; z
    ; s
    ; generic_selector = pair 74
    ; poseidon_selector = pair 76
    ; complete_add_selector = pair 78
    ; mul_selector = pair 80
    ; emul_selector = pair 82
    ; endomul_scalar_selector = pair 84
    ; range_check0_selector = Pickles_types.Opt.Nothing
    ; range_check1_selector = Pickles_types.Opt.Nothing
    ; foreign_field_add_selector = Pickles_types.Opt.Nothing
    ; foreign_field_mul_selector = Pickles_types.Opt.Nothing
    ; xor_selector = Pickles_types.Opt.Nothing
    ; rot_selector = Pickles_types.Opt.Nothing
    ; lookup_aggregation = Pickles_types.Opt.Nothing
    ; lookup_table = Pickles_types.Opt.Nothing
    ; lookup_sorted = Pickles_types.Vector.init Pickles_types.Nat.N5.n
        ~f:(fun _ -> Pickles_types.Opt.Nothing)
    ; runtime_lookup_table = Pickles_types.Opt.Nothing
    ; runtime_lookup_table_selector = Pickles_types.Opt.Nothing
    ; xor_lookup_selector = Pickles_types.Opt.Nothing
    ; lookup_gate_lookup_selector = Pickles_types.Opt.Nothing
    ; range_check_lookup_selector = Pickles_types.Opt.Nothing
    ; foreign_field_mul_lookup_selector = Pickles_types.Opt.Nothing
    }
  in
  let plonk_minimal :
    (Impl.Field.t, Impl.Field.t, Impl.Boolean.var) Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t =
    { alpha = inputs.(86)
    ; beta = inputs.(87)
    ; gamma = inputs.(88)
    ; zeta = inputs.(89)
    ; joint_combiner = None
    ; feature_flags =
        let f = Impl.Boolean.false_ in
        { Kimchi_backend_common.Plonk_types.Features.
          range_check0 = f; range_check1 = f
        ; foreign_field_add = f; foreign_field_mul = f
        ; xor = f; rot = f; lookup = f
        ; runtime_tables = f
        }
    }
  in
  let sponge_params =
    Sponge.Params.map Tick_field_sponge.params ~f:Impl.Field.constant
  in
  let domain_log2 = 16 in
  let domain =
    Plonk_checks.domain
      (module Impl.Field)
      ~shifts:(fun ~log2_size ->
        Common.tick_shifts ~log2_size
        |> Array.map ~f:Impl.Field.constant)
      ~domain_generator:(fun ~log2_size ->
        Backend.Tick.Field.domain_generator ~log2_size
        |> Impl.Field.constant)
      (Pickles_base.Domain.Pow_2_roots_of_unity domain_log2)
  in
  let module Env_bool = struct
    include Impl.Boolean
    type t = Impl.Boolean.var
  end in
  let module Env_field = struct
    include Impl.Field
    type bool = Env_bool.t
    let if_ (b : bool) ~then_ ~else_ =
      match Impl.Field.to_constant (b :> Impl.field_var) with
      | Some x ->
          if Impl.Field.Constant.(equal one) x then then_ ()
          else else_ ()
      | None ->
          Impl.Field.if_ b ~then_:(then_ ()) ~else_:(else_ ())
  end in
  let env =
    Plonk_checks.scalars_env
      (module Env_bool) (module Env_field)
      ~srs_length_log2:Common.Max_degree.step_log2
      ~zk_rows:3
      ~endo:(Impl.Field.constant Endo.Step_inner_curve.base)
      ~mds:sponge_params.mds
      ~field_of_hex:(fun s ->
        (* Pad short hex strings like "0x1" to full 64-char "0x0000...0001" *)
        let s =
          if String.is_prefix s ~prefix:"0x" || String.is_prefix s ~prefix:"0X" then
            let hex = String.drop_prefix s 2 in
            let padded = String.make (max 0 (64 - String.length hex)) '0' ^ hex in
            "0x" ^ padded
          else s
        in
        Kimchi_pasta.Pasta.Bigint256.of_hex_string s
        |> Kimchi_pasta.Pasta.Fp.of_bigint
        |> Impl.Field.constant)
      ~domain
      plonk_minimal combined_evals
  in
  Plonk_checks.Scalars_tokens_interpreter.Tick.constant_term env

(* ---- ft_eval0 circuit (Step 11a) ----
   Input layout (91 fields = linearization layout + p_eval0):
     0-29:   w (15 pairs)
     30-59:  coefficients (15 pairs)
     60-61:  z (pair)
     62-73:  s (6 pairs)
     74-85:  selectors (6 pairs: generic, poseidon, add, mul, emul, endoscalar)
     86:     alpha
     87:     beta
     88:     gamma
     89:     zeta
     90:     p_eval0 (public input evaluation at zeta)
*)
let ft_eval0_circuit (inputs : Impl.Field.t array) () =
  let pair i = (inputs.(i), inputs.(i + 1)) in
  let w = Pickles_types.Vector.init Pickles_types.Nat.N15.n ~f:(fun i ->
    pair (2 * i)) in
  let coefficients = Pickles_types.Vector.init Pickles_types.Nat.N15.n ~f:(fun i ->
    pair (30 + 2 * i)) in
  let z = pair 60 in
  let s = Pickles_types.Vector.init Pickles_types.Nat.N6.n ~f:(fun i ->
    pair (62 + 2 * i)) in
  let combined_evals : (Impl.Field.t * Impl.Field.t, _) Kimchi_backend_common.Plonk_types.Evals.In_circuit.t =
    { w
    ; coefficients
    ; z
    ; s
    ; generic_selector = pair 74
    ; poseidon_selector = pair 76
    ; complete_add_selector = pair 78
    ; mul_selector = pair 80
    ; emul_selector = pair 82
    ; endomul_scalar_selector = pair 84
    ; range_check0_selector = Pickles_types.Opt.Nothing
    ; range_check1_selector = Pickles_types.Opt.Nothing
    ; foreign_field_add_selector = Pickles_types.Opt.Nothing
    ; foreign_field_mul_selector = Pickles_types.Opt.Nothing
    ; xor_selector = Pickles_types.Opt.Nothing
    ; rot_selector = Pickles_types.Opt.Nothing
    ; lookup_aggregation = Pickles_types.Opt.Nothing
    ; lookup_table = Pickles_types.Opt.Nothing
    ; lookup_sorted = Pickles_types.Vector.init Pickles_types.Nat.N5.n
        ~f:(fun _ -> Pickles_types.Opt.Nothing)
    ; runtime_lookup_table = Pickles_types.Opt.Nothing
    ; runtime_lookup_table_selector = Pickles_types.Opt.Nothing
    ; xor_lookup_selector = Pickles_types.Opt.Nothing
    ; lookup_gate_lookup_selector = Pickles_types.Opt.Nothing
    ; range_check_lookup_selector = Pickles_types.Opt.Nothing
    ; foreign_field_mul_lookup_selector = Pickles_types.Opt.Nothing
    }
  in
  let plonk_minimal :
    (Impl.Field.t, Impl.Field.t, Impl.Boolean.var) Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t =
    { alpha = inputs.(86)
    ; beta = inputs.(87)
    ; gamma = inputs.(88)
    ; zeta = inputs.(89)
    ; joint_combiner = None
    ; feature_flags =
        let f = Impl.Boolean.false_ in
        { Kimchi_backend_common.Plonk_types.Features.
          range_check0 = f; range_check1 = f
        ; foreign_field_add = f; foreign_field_mul = f
        ; xor = f; rot = f; lookup = f
        ; runtime_tables = f
        }
    }
  in
  let sponge_params =
    Sponge.Params.map Tick_field_sponge.params ~f:Impl.Field.constant
  in
  let domain_log2 = 16 in
  let domain =
    Plonk_checks.domain
      (module Impl.Field)
      ~shifts:(fun ~log2_size ->
        Common.tick_shifts ~log2_size
        |> Array.map ~f:Impl.Field.constant)
      ~domain_generator:(fun ~log2_size ->
        Backend.Tick.Field.domain_generator ~log2_size
        |> Impl.Field.constant)
      (Pickles_base.Domain.Pow_2_roots_of_unity domain_log2)
  in
  let module Env_bool = struct
    include Impl.Boolean
    type t = Impl.Boolean.var
  end in
  let module Env_field = struct
    include Impl.Field
    type bool = Env_bool.t
    let if_ (b : bool) ~then_ ~else_ =
      match Impl.Field.to_constant (b :> Impl.field_var) with
      | Some x ->
          if Impl.Field.Constant.(equal one) x then then_ ()
          else else_ ()
      | None ->
          Impl.Field.if_ b ~then_:(then_ ()) ~else_:(else_ ())
  end in
  let env =
    Plonk_checks.scalars_env
      (module Env_bool) (module Env_field)
      ~srs_length_log2:Common.Max_degree.step_log2
      ~zk_rows:3
      ~endo:(Impl.Field.constant Endo.Step_inner_curve.base)
      ~mds:sponge_params.mds
      ~field_of_hex:(fun s ->
        let s =
          if String.is_prefix s ~prefix:"0x" || String.is_prefix s ~prefix:"0X" then
            let hex = String.drop_prefix s 2 in
            let padded = String.make (max 0 (64 - String.length hex)) '0' ^ hex in
            "0x" ^ padded
          else s
        in
        Kimchi_pasta.Pasta.Bigint256.of_hex_string s
        |> Kimchi_pasta.Pasta.Fp.of_bigint
        |> Impl.Field.constant)
      ~domain
      plonk_minimal combined_evals
  in
  let p_eval0 = [| inputs.(90) |] in
  Step_plonk_checks.ft_eval0
    (module Impl.Field)
    ~env ~domain plonk_minimal combined_evals p_eval0

(* ---- Tock linearization polynomial circuit ---- *)

module WrapImpl = Kimchi_pasta_snarky_backend.Wrap_impl

let dump_tock output_dir name circuit ~input_typ ~return_typ =
  let cs =
    WrapImpl.constraint_system ~input_typ ~return_typ circuit
  in
  let json =
    Kimchi_pasta_constraint_system.Pallas_constraint_system.to_json cs
  in
  let path = output_dir ^ "/" ^ name ^ ".json" in
  Out_channel.write_all path ~data:(json ^ "\n") ;
  Printf.printf "Wrote %s\n" path ;
  (* Write cached constants *)
  let constants_path = output_dir ^ "/" ^ name ^ "_cached_constants.json" in
  let constants_json =
    Kimchi_pasta_constraint_system.Pallas_constraint_system.dump_cached_constants cs
  in
  Out_channel.write_all constants_path ~data:(constants_json ^ "\n") ;
  Printf.printf "Wrote %s\n" constants_path

(* ---- Label-tracked dump for Tock circuits ----
   Uses set_constraint_logger to record label stack and constraint type
   for every constraint added during circuit generation. Outputs a
   _labels.jsonl file with one JSON object per constraint event. *)

let constraint_type_name (c : WrapImpl.Constraint.t) : string =
  match c with
  | Boolean _ -> "Boolean"
  | Equal _ -> "Equal"
  | Square _ -> "Square"
  | R1CS _ -> "R1CS"
  | Basic _ -> "Basic"
  | Poseidon _ -> "Poseidon"
  | EC_add_complete _ -> "EC_add_complete"
  | EC_scale _ -> "EC_scale"
  | EC_endoscale _ -> "EC_endoscale"
  | EC_endoscalar _ -> "EC_endoscalar"
  | Lookup _ -> "Lookup"
  | RangeCheck0 _ -> "RangeCheck0"
  | RangeCheck1 _ -> "RangeCheck1"
  | ForeignFieldAdd _ -> "ForeignFieldAdd"
  | ForeignFieldMul _ -> "ForeignFieldMul"
  | Xor _ -> "Xor"
  | Rot64 _ -> "Rot64"
  | AddFixedLookupTable _ -> "AddFixedLookupTable"
  | AddRuntimeTableCfg _ -> "AddRuntimeTableCfg"
  | Raw _ -> "Raw"

let json_escape s =
  String.concat_map s ~f:(fun c ->
    match c with
    | '"' -> "\\\""
    | '\\' -> "\\\\"
    | '\n' -> "\\n"
    | _ -> String.make 1 c)

let dump_tock_with_labels output_dir name circuit ~input_typ ~return_typ =
  let module PCS = Kimchi_pasta_snarky_backend.Pallas_based_plonk.R1CS_constraint_system in
  let events = ref [] in
  let label_stack = ref [] in
  WrapImpl.set_constraint_logger
    (fun ?at_label_boundary constraint_opt ->
       ( match at_label_boundary with
         | Some (`Start, lab) ->
             label_stack := lab :: !label_stack ;
             PCS.set_gate_label_stack !label_stack
         | Some (`End, _lab) ->
             label_stack := (match !label_stack with _ :: rest -> rest | [] -> []) ;
             PCS.set_gate_label_stack !label_stack
         | None -> () ) ;
       match constraint_opt with
       | Some c ->
           let path = String.concat ~sep:"/" (List.rev !label_stack) in
           events := (path, constraint_type_name c) :: !events
       | None -> () ) ;
  let cs =
    WrapImpl.constraint_system ~input_typ ~return_typ circuit
  in
  WrapImpl.clear_constraint_logger () ;
  PCS.set_gate_label_stack [] ;
  let json = PCS.to_json cs in
  let path = output_dir ^ "/" ^ name ^ ".json" in
  Out_channel.write_all path ~data:(json ^ "\n") ;
  Printf.printf "Wrote %s\n" path ;
  (* Write label events as JSONL *)
  let labels_path = output_dir ^ "/" ^ name ^ "_labels.jsonl" in
  let events_rev = List.rev !events in
  let lines = List.map events_rev ~f:(fun (path, ctype) ->
    Printf.sprintf "{\"label\":\"%s\",\"constraint\":\"%s\"}"
      (json_escape path) (json_escape ctype)) in
  Out_channel.write_all labels_path
    ~data:(String.concat ~sep:"\n" lines ^ "\n") ;
  Printf.printf "Wrote %s (%d constraint events)\n" labels_path (List.length events_rev) ;
  (* Write gate-level labels as JSONL *)
  let gate_labels_path = output_dir ^ "/" ^ name ^ "_gate_labels.jsonl" in
  let gate_labels_data = PCS.dump_gate_labels cs in
  Out_channel.write_all gate_labels_path ~data:(gate_labels_data ^ "\n") ;
  Printf.printf "Wrote %s\n" gate_labels_path ;
  (* Write cached constants *)
  let constants_path = output_dir ^ "/" ^ name ^ "_cached_constants.json" in
  let constants_json = PCS.dump_cached_constants cs in
  Out_channel.write_all constants_path ~data:(constants_json ^ "\n") ;
  Printf.printf "Wrote %s\n" constants_path

(* ---- Label-tracked dump for Tick circuits ----
   Same as dump_tock_with_labels but for Step/Tick (Vesta-based) circuits. *)

let constraint_type_name_tick (c : Impl.Constraint.t) : string =
  match c with
  | Boolean _ -> "Boolean"
  | Equal _ -> "Equal"
  | Square _ -> "Square"
  | R1CS _ -> "R1CS"
  | Basic _ -> "Basic"
  | Poseidon _ -> "Poseidon"
  | EC_add_complete _ -> "EC_add_complete"
  | EC_scale _ -> "EC_scale"
  | EC_endoscale _ -> "EC_endoscale"
  | EC_endoscalar _ -> "EC_endoscalar"
  | Lookup _ -> "Lookup"
  | RangeCheck0 _ -> "RangeCheck0"
  | RangeCheck1 _ -> "RangeCheck1"
  | ForeignFieldAdd _ -> "ForeignFieldAdd"
  | ForeignFieldMul _ -> "ForeignFieldMul"
  | Xor _ -> "Xor"
  | Rot64 _ -> "Rot64"
  | AddFixedLookupTable _ -> "AddFixedLookupTable"
  | AddRuntimeTableCfg _ -> "AddRuntimeTableCfg"
  | Raw _ -> "Raw"

let dump_tick_with_labels output_dir name circuit ~input_typ ~return_typ =
  let module VCS = Kimchi_pasta_snarky_backend.Vesta_based_plonk.R1CS_constraint_system in
  let events = ref [] in
  let label_stack = ref [] in
  Impl.set_constraint_logger
    (fun ?at_label_boundary constraint_opt ->
       ( match at_label_boundary with
         | Some (`Start, lab) ->
             label_stack := lab :: !label_stack ;
             VCS.set_gate_label_stack !label_stack
         | Some (`End, _lab) ->
             label_stack := (match !label_stack with _ :: rest -> rest | [] -> []) ;
             VCS.set_gate_label_stack !label_stack
         | None -> () ) ;
       match constraint_opt with
       | Some c ->
           let path = String.concat ~sep:"/" (List.rev !label_stack) in
           events := (path, constraint_type_name_tick c) :: !events
       | None -> () ) ;
  let cs =
    Impl.constraint_system ~input_typ ~return_typ circuit
  in
  Impl.clear_constraint_logger () ;
  VCS.set_gate_label_stack [] ;
  let json = Kimchi_pasta_constraint_system.Vesta_constraint_system.to_json cs in
  let path = output_dir ^ "/" ^ name ^ ".json" in
  Out_channel.write_all path ~data:(json ^ "\n") ;
  Printf.printf "Wrote %s\n" path ;
  (* Write label events as JSONL *)
  let labels_path = output_dir ^ "/" ^ name ^ "_labels.jsonl" in
  let events_rev = List.rev !events in
  let lines = List.map events_rev ~f:(fun (path, ctype) ->
    Printf.sprintf "{\"label\":\"%s\",\"constraint\":\"%s\"}"
      (json_escape path) (json_escape ctype)) in
  Out_channel.write_all labels_path
    ~data:(String.concat ~sep:"\n" lines ^ "\n") ;
  Printf.printf "Wrote %s (%d constraint events)\n" labels_path (List.length events_rev) ;
  (* Write gate-level labels as JSONL *)
  let gate_labels_path = output_dir ^ "/" ^ name ^ "_gate_labels.jsonl" in
  let gate_labels_data = VCS.dump_gate_labels cs in
  Out_channel.write_all gate_labels_path ~data:(gate_labels_data ^ "\n") ;
  Printf.printf "Wrote %s\n" gate_labels_path ;
  (* Write cached constants *)
  let constants_path = output_dir ^ "/" ^ name ^ "_cached_constants.json" in
  let constants_json = Kimchi_pasta_constraint_system.Vesta_constraint_system.dump_cached_constants cs in
  Out_channel.write_all constants_path ~data:(constants_json ^ "\n") ;
  Printf.printf "Wrote %s\n" constants_path

let linearization_tock_circuit (inputs : WrapImpl.Field.t array) () =
  let open WrapImpl in
  let pair i = (inputs.(i), inputs.(i + 1)) in
  let w = Pickles_types.Vector.init Pickles_types.Nat.N15.n ~f:(fun i ->
    pair (2 * i)) in
  let coefficients = Pickles_types.Vector.init Pickles_types.Nat.N15.n ~f:(fun i ->
    pair (30 + 2 * i)) in
  let z = pair 60 in
  let s = Pickles_types.Vector.init Pickles_types.Nat.N6.n ~f:(fun i ->
    pair (62 + 2 * i)) in
  let combined_evals : (Field.t * Field.t, _) Kimchi_backend_common.Plonk_types.Evals.In_circuit.t =
    { w
    ; coefficients
    ; z
    ; s
    ; generic_selector = pair 74
    ; poseidon_selector = pair 76
    ; complete_add_selector = pair 78
    ; mul_selector = pair 80
    ; emul_selector = pair 82
    ; endomul_scalar_selector = pair 84
    ; range_check0_selector = Pickles_types.Opt.Nothing
    ; range_check1_selector = Pickles_types.Opt.Nothing
    ; foreign_field_add_selector = Pickles_types.Opt.Nothing
    ; foreign_field_mul_selector = Pickles_types.Opt.Nothing
    ; xor_selector = Pickles_types.Opt.Nothing
    ; rot_selector = Pickles_types.Opt.Nothing
    ; lookup_aggregation = Pickles_types.Opt.Nothing
    ; lookup_table = Pickles_types.Opt.Nothing
    ; lookup_sorted = Pickles_types.Vector.init Pickles_types.Nat.N5.n
        ~f:(fun _ -> Pickles_types.Opt.Nothing)
    ; runtime_lookup_table = Pickles_types.Opt.Nothing
    ; runtime_lookup_table_selector = Pickles_types.Opt.Nothing
    ; xor_lookup_selector = Pickles_types.Opt.Nothing
    ; lookup_gate_lookup_selector = Pickles_types.Opt.Nothing
    ; range_check_lookup_selector = Pickles_types.Opt.Nothing
    ; foreign_field_mul_lookup_selector = Pickles_types.Opt.Nothing
    }
  in
  let plonk_minimal :
    (Field.t, Field.t, Boolean.var) Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t =
    { alpha = inputs.(86)
    ; beta = inputs.(87)
    ; gamma = inputs.(88)
    ; zeta = inputs.(89)
    ; joint_combiner = None
    ; feature_flags =
        let f = Boolean.false_ in
        { Kimchi_backend_common.Plonk_types.Features.
          range_check0 = f; range_check1 = f
        ; foreign_field_add = f; foreign_field_mul = f
        ; xor = f; rot = f; lookup = f
        ; runtime_tables = f
        }
    }
  in
  let sponge_params =
    Sponge.Params.map Tock_field_sponge.params ~f:Field.constant
  in
  let domain_log2 = 15 in
  let domain =
    Plonk_checks.domain
      (module Field)
      ~shifts:(fun ~log2_size ->
        Common.tock_shifts ~log2_size
        |> Array.map ~f:Field.constant)
      ~domain_generator:(fun ~log2_size ->
        Backend.Tock.Field.domain_generator ~log2_size
        |> Field.constant)
      (Pickles_base.Domain.Pow_2_roots_of_unity domain_log2)
  in
  let module Env_bool = struct
    include Boolean
    type t = Boolean.var
  end in
  let module Env_field = struct
    include Field
    type bool = Env_bool.t
    let if_ (b : bool) ~then_ ~else_ =
      match Field.to_constant (b :> field_var) with
      | Some x ->
          if Field.Constant.(equal one) x then then_ ()
          else else_ ()
      | None ->
          Field.if_ b ~then_:(then_ ()) ~else_:(else_ ())
  end in
  let env =
    Plonk_checks.scalars_env
      (module Env_bool) (module Env_field)
      ~srs_length_log2:Common.Max_degree.wrap_log2
      ~zk_rows:3
      ~endo:(Field.constant Endo.Wrap_inner_curve.base)
      ~mds:sponge_params.mds
      ~field_of_hex:(fun s ->
        let s =
          if String.is_prefix s ~prefix:"0x" || String.is_prefix s ~prefix:"0X" then
            let hex = String.drop_prefix s 2 in
            let padded = String.make (max 0 (64 - String.length hex)) '0' ^ hex in
            "0x" ^ padded
          else s
        in
        Kimchi_pasta.Pasta.Bigint256.of_hex_string s
        |> Kimchi_pasta.Pasta.Fq.of_bigint
        |> Field.constant)
      ~domain
      plonk_minimal combined_evals
  in
  Plonk_checks.Scalars_tokens_interpreter.Tock.constant_term env

(* ==== Finalize other proof circuit ====

   Tests Step_verifier.finalize_other_proof as a standalone circuit.

   Fixed parameters:
   - Proofs_verified = N2 (verifies 2 previous proofs)
   - step_domains = Known, single unique domain with log2_size = 16
   - zk_rows = 3
   - All feature flags = No (standard kimchi, no lookups)
   - num_chunks = 1

   Input layout (151 fields via flat array):

   Deferred_values (29 fields):
     0:      plonk.alpha (scalar_challenge inner)
     1:      plonk.beta
     2:      plonk.gamma
     3:      plonk.zeta (scalar_challenge inner)
     4:      plonk.zeta_to_srs_length
     5:      plonk.zeta_to_domain_size
     6:      plonk.perm
     7:      combined_inner_product (shifted_value)
     8:      b (shifted_value)
     9:      xi (scalar_challenge inner)
     10-25:  bulletproof_challenges[0..15] (prechallenge.inner)
     26:     branch_data.proofs_verified_mask[0] (boolean)
     27:     branch_data.proofs_verified_mask[1] (boolean)
     28:     branch_data.domain_log2

   All_evals (89 fields):
     29-30:    public_input (zeta[0], zetaw[0])
     31-60:    w[0..14] pairs (zeta, zetaw) = 30 fields
     61-90:    coefficients[0..14] pairs = 30 fields
     91-92:    z pair = 2 fields
     93-104:   s[0..5] pairs = 12 fields
     105-106:  generic_selector pair
     107-108:  poseidon_selector pair
     109-110:  complete_add_selector pair
     111-112:  mul_selector pair
     113-114:  emul_selector pair
     115-116:  endomul_scalar_selector pair
     117:      ft_eval1

   prev_challenges (32 fields):
     118-133:  prev_challenges[0][0..15]
     134-149:  prev_challenges[1][0..15]

   sponge_digest (1 field):
     150:      sponge_digest_before_evaluations

   Total: 151 fields
*)

(* ==== Phase 1 Sub-circuits ====

   These sub-circuits match individual steps of finalize_other_proof
   (step_verifier.ml:828-1165) for incremental JSON comparison testing. *)

(* Sub-circuit 1: expand_plonk (Steps 2+4)
   Expands scalar challenges alpha, zeta via endo.
   Computes zetaw = domain#generator * zeta.

   Input layout (4 fields):
     0: alpha (scalar_challenge inner)
     1: beta (plain field, identity transform)
     2: gamma (plain field, identity transform)
     3: zeta (scalar_challenge inner)

   The endo constant and domain generator are compile-time constants.
*)
let expand_plonk_circuit (inputs : Impl.Field.t array) () =
  let scalar =
    Scalar_challenge.to_field_checked (module Impl)
      ~endo:Endo.Wrap_inner_curve.scalar
  in
  let _alpha = scalar { Kimchi_types.inner = inputs.(0) } in
  let _beta = inputs.(1) in
  let _gamma = inputs.(2) in
  let zeta = scalar { Kimchi_types.inner = inputs.(3) } in
  let generator =
    Backend.Tick.Field.domain_generator ~log2_size:16
    |> Impl.Field.constant
  in
  let _zetaw = Impl.Field.mul generator zeta in
  ()

(* Sub-circuit 2: challenge_digest (Step 7a)
   Computes challenge digest from prev_challenges using opt_sponge.
   This matches the opt_sponge absorption pattern in step_verifier.ml:923-933.

   Input layout (34 fields):
     0-1:   mask (2 booleans for proofs_verified_mask)
     2-17:  prev_challenges[0] (16 field elements)
     18-33: prev_challenges[1] (16 field elements)

   Output: 1 field (the squeezed challenge digest)
*)
let challenge_digest_circuit (inputs : Impl.Field.t array) () =
  let open Pickles_types in
  let as_bool (x : Impl.Field.t) : Impl.Boolean.var =
    Impl.Boolean.Unsafe.of_cvar x
  in
  let sponge_params =
    Sponge.Params.map Tick_field_sponge.params ~f:Impl.Field.constant
  in
  let actual_width_mask =
    Vector.[ as_bool inputs.(0); as_bool inputs.(1) ]
  in
  let prev_challenges =
    Vector.[
      Vector.init Nat.N16.n ~f:(fun j -> inputs.(2 + j)) ;
      Vector.init Nat.N16.n ~f:(fun j -> inputs.(18 + j))
    ]
  in
  let module Opt_sponge = struct
    include Opt_sponge.Make (Impl) (Step_main_inputs.Sponge.Permutation)
  end
  in
  let _challenge_digest =
    let opt_sponge = Opt_sponge.create sponge_params in
    Vector.iter2
      (Vector.trim_front actual_width_mask
         (Nat.lte_exn Nat.N2.n Nat.N2.n) )
      prev_challenges
      ~f:(fun keep chals ->
        Vector.iter chals ~f:(fun chal ->
            Opt_sponge.absorb opt_sponge (keep, chal) ) ) ;
    Opt_sponge.squeeze opt_sponge
  in
  ()

(* Sub-circuit 3: b_correct (Step 12)
   Expands 16 bulletproof challenges via endo, builds challenge polynomial,
   evaluates at zeta and zetaw, checks b = b(zeta) + r * b(zetaw).

   Input layout (20 fields):
     0-15:  bulletproof_challenges (16 scalar_challenge inners)
     16:    zeta (already expanded)
     17:    zetaw (already expanded)
     18:    r (already expanded)
     19:    claimed_b (Type1 shifted value)
*)
let b_correct_circuit (inputs : Impl.Field.t array) () =
  let open Pickles_types in
  let scalar =
    Scalar_challenge.to_field_checked (module Impl)
      ~endo:Endo.Wrap_inner_curve.scalar
  in
  let bulletproof_challenges =
    Vector.init Nat.N16.n ~f:(fun i ->
      { Import.Bulletproof_challenge.prechallenge =
          { Kimchi_types.inner = inputs.(i) } })
  in
  let expanded_challenges =
    Vector.map bulletproof_challenges ~f:(fun b ->
      Import.Bulletproof_challenge.pack b |> scalar)
  in
  let zeta = inputs.(16) in
  let zetaw = inputs.(17) in
  let r = inputs.(18) in
  let claimed_b =
    Pickles_types.Shifted_value.Type1.Shifted_value inputs.(19)
  in
  let shift1 =
    Shifted_value.Type1.Shift.(
      map ~f:Impl.Field.constant (create (module Impl.Field.Constant)))
  in
  let challenge_poly =
    Staged.unstage
      (Wrap_verifier.challenge_polynomial
         (module Impl.Field)
         (Vector.to_array expanded_challenges))
  in
  let open Impl.Field in
  let b_actual =
    challenge_poly zeta + (r * challenge_poly zetaw)
  in
  let b_used =
    Shifted_value.Type1.to_field (module Impl.Field) ~shift:shift1 claimed_b
  in
  let _b_correct = equal b_used b_actual in
  ()

(* Sub-circuit 4: plonk_checks_passed (Step 13)
   Verifies that claimed perm value matches computed value.
   This isolates the Plonk_checks.checked / derive_plonk logic.

   The perm scalar from derive_plonk:
     perm = -(z_omega * beta * alpha^21 * zkp * prod_{i=0}^{5}(gamma + beta*s_i + w_i))
   Then Shifted_value.of_field wraps it, and Shifted_value.equal compares
   with the claimed value.

   Input layout (18 fields):
     0:     alpha (expanded to full field)
     1:     beta
     2:     gamma
     3:     zkPolynomial
     4:     z_omega (z eval at omega*zeta)
     5-10:  sigma[0..5] (sigma evals at zeta)
     11-16: w[0..5] (witness evals at zeta)
     17:    claimed_perm (Shifted_value.Type1 inner)
*)
let plonk_checks_passed_circuit (inputs : Impl.Field.t array) () =
  let open Impl.Field in
  let alpha = inputs.(0) in
  let beta = inputs.(1) in
  let gamma = inputs.(2) in
  let zkp = inputs.(3) in
  let z_omega = inputs.(4) in
  let sigma = Array.init 6 ~f:(fun i -> inputs.(Int.(5 + i))) in
  let w = Array.init 6 ~f:(fun i -> inputs.(Int.(11 + i))) in
  let claimed_perm = inputs.(17) in
  (* Compute alpha^21 via pow_ (same algorithm as scalars_env) *)
  let alpha_pow_21 = pow_ alpha 21 in
  (* derive_plonk perm formula *)
  let init = z_omega * beta * alpha_pow_21 * zkp in
  let raw_perm =
    Array.foldi sigma ~init ~f:(fun i acc s ->
      acc * (gamma + (beta * s) + w.(i)))
    |> negate
  in
  (* Type1.of_field: shifts computed value to match claimed inner.
     of_field raw = (raw - c) * scale, then compare inners.
     This matches PureScript's shiftedEqualType1 / ofFieldType1Circuit. *)
  let shift1 =
    Pickles_types.Shifted_value.Type1.Shift.(
      map ~f:constant (create (module Impl.Field.Constant)))
  in
  let (Pickles_types.Shifted_value.Type1.Shifted_value perm_shifted) =
    Pickles_types.Shifted_value.Type1.of_field (module Impl.Field) ~shift:shift1
      raw_perm
  in
  (* Compare claimed inner vs of_field(raw_perm) inner *)
  let _result = equal claimed_perm perm_shifted in
  ()

(* Sub-circuit 6: sponge_and_challenges (Steps 7+8)
   Reconstructs the Fiat-Shamir sponge state by absorbing all evaluation
   data, then squeezes xi and r challenges and expands them via endo.

   Input layout (124 fields):
     0-1:     mask (2 booleans)
     2-17:    prev_challenges[0] (16 fields)
     18-33:   prev_challenges[1] (16 fields)
     34:      sponge_digest_before_evaluations
     35:      ft_eval1
     36-37:   public_input (zeta, zetaw)
     38-67:   w[0..14] pairs = 30 fields
     68-97:   coefficients[0..14] pairs = 30 fields
     98-99:   z pair = 2 fields
     100-111: s[0..5] pairs = 12 fields
     112-123: selectors[0..5] pairs = 12 fields
*)
let sponge_and_challenges_circuit (inputs : Impl.Field.t array) () =
  let open Pickles_types in
  let open Kimchi_backend_common.Plonk_types in
  let as_bool (x : Impl.Field.t) : Impl.Boolean.var =
    Impl.Boolean.Unsafe.of_cvar x
  in
  let single x = [| x |] in
  let eval_pair i = (single inputs.(i), single inputs.(i + 1)) in
  let sponge_params =
    Sponge.Params.map Tick_field_sponge.params ~f:Impl.Field.constant
  in
  (* 1. Challenge digest via OptSponge *)
  let actual_width_mask =
    Vector.[ as_bool inputs.(0); as_bool inputs.(1) ]
  in
  let prev_challenges =
    Vector.[
      Vector.init Nat.N16.n ~f:(fun j -> inputs.(2 + j)) ;
      Vector.init Nat.N16.n ~f:(fun j -> inputs.(18 + j))
    ]
  in
  let module Opt_sponge = struct
    include Opt_sponge.Make (Impl) (Step_main_inputs.Sponge.Permutation)
  end
  in
  let challenge_digest =
    let opt_sponge = Opt_sponge.create sponge_params in
    Vector.iter2
      (Vector.trim_front actual_width_mask
         (Nat.lte_exn Nat.N2.n Nat.N2.n) )
      prev_challenges
      ~f:(fun keep chals ->
        Vector.iter chals ~f:(fun chal ->
            Opt_sponge.absorb opt_sponge (keep, chal) ) ) ;
    Opt_sponge.squeeze opt_sponge
  in
  (* 2. Main sponge: absorb sponge_digest *)
  let sponge =
    let sponge = Step_main_inputs.Sponge.create sponge_params in
    Step_main_inputs.Sponge.absorb sponge (`Field inputs.(34)) ;
    sponge
  in
  (* 3. Absorb challenge_digest *)
  Step_main_inputs.Sponge.absorb sponge (`Field challenge_digest) ;
  (* 4. Absorb ft_eval1 *)
  Step_main_inputs.Sponge.absorb sponge (`Field inputs.(35)) ;
  (* 5. Absorb public_input *)
  Array.iter ~f:(fun x -> Step_main_inputs.Sponge.absorb sponge (`Field x))
    (single inputs.(36)) ;
  Array.iter ~f:(fun x -> Step_main_inputs.Sponge.absorb sponge (`Field x))
    (single inputs.(37)) ;
  (* 6. Build evals and absorb via to_absorption_sequence *)
  let evals_evals :
    ( Impl.Field.t array * Impl.Field.t array
    , Impl.Boolean.var )
    Evals.In_circuit.t =
    { w = Vector.init Nat.N15.n ~f:(fun j -> eval_pair (38 + 2 * j))
    ; coefficients = Vector.init Nat.N15.n ~f:(fun j -> eval_pair (68 + 2 * j))
    ; z = eval_pair 98
    ; s = Vector.init Nat.N6.n ~f:(fun j -> eval_pair (100 + 2 * j))
    ; generic_selector = eval_pair 112
    ; poseidon_selector = eval_pair 114
    ; complete_add_selector = eval_pair 116
    ; mul_selector = eval_pair 118
    ; emul_selector = eval_pair 120
    ; endomul_scalar_selector = eval_pair 122
    ; range_check0_selector = Opt.Nothing
    ; range_check1_selector = Opt.Nothing
    ; foreign_field_add_selector = Opt.Nothing
    ; foreign_field_mul_selector = Opt.Nothing
    ; xor_selector = Opt.Nothing
    ; rot_selector = Opt.Nothing
    ; lookup_aggregation = Opt.Nothing
    ; lookup_table = Opt.Nothing
    ; lookup_sorted = Vector.init Nat.N5.n ~f:(fun _ -> Opt.Nothing)
    ; runtime_lookup_table = Opt.Nothing
    ; runtime_lookup_table_selector = Opt.Nothing
    ; xor_lookup_selector = Opt.Nothing
    ; lookup_gate_lookup_selector = Opt.Nothing
    ; range_check_lookup_selector = Opt.Nothing
    ; foreign_field_mul_lookup_selector = Opt.Nothing
    }
  in
  let xs = Evals.In_circuit.to_absorption_sequence evals_evals in
  List.iter xs ~f:(fun opt ->
    let absorb =
      Array.iter ~f:(fun x -> Step_main_inputs.Sponge.absorb sponge (`Field x))
    in
    match opt with
    | Nothing -> ()
    | Just (x1, x2) -> absorb x1 ; absorb x2
    | Maybe _ -> () (* unreachable: all optional fields are Nothing *)
  ) ;
  (* 7. Squeeze xi and r *)
  let assert_128_bits a =
    ignore
      ( Scalar_challenge.to_field_checked (module Impl)
          (Import.Scalar_challenge.create a)
          ~endo:Endo.Wrap_inner_curve.scalar
        : Impl.Field.t )
  in
  let squeeze_challenge () =
    let x = Step_main_inputs.Sponge.squeeze sponge in
    Util.Step.lowest_128_bits ~constrain_low_bits:true ~assert_128_bits x
  in
  let xi = squeeze_challenge () in
  let r_actual = squeeze_challenge () in
  (* 8. Expand xi and r to full field via endo *)
  let scalar =
    Scalar_challenge.to_field_checked (module Impl)
      ~endo:Endo.Wrap_inner_curve.scalar
  in
  let _xi_field = scalar (Import.Scalar_challenge.create xi) in
  let _r_field = scalar (Import.Scalar_challenge.create r_actual) in
  ()

(* Sub-circuit 7: combined_inner_product (Step 11)
   Computes the combined inner product used in bulletproof verification:
     CIP = sum_j xi^j f_j(zeta) + r * sum_j xi^j f_j(zetaw)
   where f_j includes sg_evals (challenge polynomial evaluations), public input,
   ft_eval, and all polynomial evaluations.

   Input layout (129 fields):
     0-1:     mask (2 booleans)
     2-17:    prev_challenges[0] (16 fields)
     18-33:   prev_challenges[1] (16 fields)
     34:      zeta
     35:      zetaw
     36:      xi (already expanded to full field)
     37:      r (already expanded to full field)
     38:      ft_eval0 (precomputed from PlonK relation)
     39:      ft_eval1
     40:      public_input at zeta
     41:      public_input at zetaw
     42-84:   evals at zeta (43 fields: z, 6 selectors, 15 w, 15 coeff, 6 s)
     85-127:  evals at zetaw (43 fields: same structure)
     128:     claimed_cip (Type1 shifted value inner)
*)
let cip_circuit (inputs : Impl.Field.t array) () =
  let open Pickles_types in
  let open Kimchi_backend_common.Plonk_types in
  let as_bool (x : Impl.Field.t) : Impl.Boolean.var =
    Impl.Boolean.Unsafe.of_cvar x
  in
  let single x = [| x |] in
  (* Parse inputs *)
  let actual_width_mask =
    Vector.[ as_bool inputs.(0); as_bool inputs.(1) ]
  in
  let prev_challenges =
    Vector.[
      Vector.init Nat.N16.n ~f:(fun j -> inputs.(2 + j)) ;
      Vector.init Nat.N16.n ~f:(fun j -> inputs.(18 + j))
    ]
  in
  let zeta = inputs.(34) in
  let zetaw = inputs.(35) in
  let xi = inputs.(36) in
  let r = inputs.(37) in
  let ft_eval0 = inputs.(38) in
  let ft_eval1 = inputs.(39) in
  let public_input_zeta = single inputs.(40) in
  let public_input_zetaw = single inputs.(41) in
  (* Build evals record for a 43-field block starting at base.
     to_list order: z, gen_sel, pos_sel, comp_add_sel, mul_sel, emul_sel,
     endo_scal_sel, 15 w, 15 coeff, 6 s *)
  let evals_at base : (Impl.Field.t array, Impl.Boolean.var) Evals.In_circuit.t =
    { w = Vector.init Nat.N15.n ~f:(fun j -> single inputs.(base + 7 + j))
    ; coefficients = Vector.init Nat.N15.n ~f:(fun j -> single inputs.(base + 22 + j))
    ; z = single inputs.(base)
    ; s = Vector.init Nat.N6.n ~f:(fun j -> single inputs.(base + 37 + j))
    ; generic_selector = single inputs.(base + 1)
    ; poseidon_selector = single inputs.(base + 2)
    ; complete_add_selector = single inputs.(base + 3)
    ; mul_selector = single inputs.(base + 4)
    ; emul_selector = single inputs.(base + 5)
    ; endomul_scalar_selector = single inputs.(base + 6)
    ; range_check0_selector = Opt.Nothing
    ; range_check1_selector = Opt.Nothing
    ; foreign_field_add_selector = Opt.Nothing
    ; foreign_field_mul_selector = Opt.Nothing
    ; xor_selector = Opt.Nothing
    ; rot_selector = Opt.Nothing
    ; lookup_aggregation = Opt.Nothing
    ; lookup_table = Opt.Nothing
    ; lookup_sorted = Vector.init Nat.N5.n ~f:(fun _ -> Opt.Nothing)
    ; runtime_lookup_table = Opt.Nothing
    ; runtime_lookup_table_selector = Opt.Nothing
    ; xor_lookup_selector = Opt.Nothing
    ; lookup_gate_lookup_selector = Opt.Nothing
    ; range_check_lookup_selector = Opt.Nothing
    ; foreign_field_mul_lookup_selector = Opt.Nothing
    }
  in
  let evals_zeta = evals_at 42 in
  let evals_zetaw = evals_at 85 in
  let claimed_cip = inputs.(128) in
  (* Compute challenge polynomials from prev_challenges *)
  let sg_olds =
    Vector.map prev_challenges ~f:(fun chals ->
        unstage (Wrap_verifier.challenge_polynomial (module Impl.Field)
                   (Vector.to_array chals)) )
  in
  (* Evaluate challenge polynomials at zeta and zetaw *)
  let sg_evals pt =
    Vector.map2
      ~f:(fun keep f -> (keep, f pt))
      (Vector.trim_front actual_width_mask
         (Nat.lte_exn Nat.N2.n Nat.N2.n) )
      sg_olds
  in
  let sg_evals1 = sg_evals zeta in
  let sg_evals2 = sg_evals zetaw in
  (* Build combine function matching step_verifier.ml lines 1083-1103 *)
  let combine ~ft ~sg_evals x_hat
      (e : (Impl.Field.t array, Impl.Boolean.var) Evals.In_circuit.t) =
    let sg_evals =
      sg_evals |> Vector.to_list
      |> List.map ~f:(fun (keep, eval) -> [| Opt.Maybe (keep, eval) |])
    in
    let a =
      Evals.In_circuit.to_list e
      |> List.map ~f:(function
           | Opt.Nothing ->
               [||]
           | Just a ->
               Array.map a ~f:Opt.just
           | Maybe (b, a) ->
               Array.map a ~f:(Opt.maybe b) )
    in
    let v =
      List.append sg_evals
        (Array.map ~f:Opt.just x_hat :: [| Opt.just ft |] :: a)
    in
    Common.combined_evaluation (module Impl) ~xi v
  in
  (* Compute actual CIP: combine_zeta + r * combine_zetaw
     OCaml right-to-left: zetaw combine computed first *)
  let open Impl.Field in
  let actual_cip =
    combine ~ft:ft_eval0 ~sg_evals:sg_evals1 public_input_zeta evals_zeta
    + r
      * combine ~ft:ft_eval1 ~sg_evals:sg_evals2 public_input_zetaw evals_zetaw
  in
  (* Compare with claimed CIP via Type1.to_field *)
  let shift1 =
    Shifted_value.Type1.Shift.(
      map ~f:constant (create (module Impl.Field.Constant)))
  in
  let expected =
    Shifted_value.Type1.to_field (module Impl.Field) ~shift:shift1
      (Shifted_value.Type1.Shifted_value claimed_cip)
  in
  let _result = equal expected actual_cip in
  ()

let finalize_other_proof_circuit (inputs : Impl.Field.t array) () =
  let open Pickles_types in
  let open Kimchi_backend_common.Plonk_types in
  let as_bool (x : Impl.Field.t) : Impl.Boolean.var =
    Impl.Boolean.Unsafe.of_cvar x
  in
  let single x = [| x |] in
  let eval_pair i = (single inputs.(i), single inputs.(i + 1)) in
  (* -- Deferred values -- *)
  let f_ = Impl.Boolean.false_ in
  let feature_flags =
    { Kimchi_backend_common.Plonk_types.Features.
      range_check0 = f_; range_check1 = f_
    ; foreign_field_add = f_; foreign_field_mul = f_
    ; xor = f_; rot = f_; lookup = f_
    ; runtime_tables = f_
    }
  in
  let plonk
    : ( Impl.Field.t
      , Impl.Field.t Import.Scalar_challenge.t
      , Impl.Field.t Shifted_value.Type1.t
      , (Impl.Field.t Shifted_value.Type1.t, Impl.Boolean.var) Opt.t
      , (Impl.Field.t Import.Scalar_challenge.t, Impl.Boolean.var) Opt.t
      , Impl.Boolean.var )
      Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t =
    { alpha = { Kimchi_types.inner = inputs.(0) }
    ; beta = inputs.(1)
    ; gamma = inputs.(2)
    ; zeta = { Kimchi_types.inner = inputs.(3) }
    ; zeta_to_srs_length = Shifted_value.Type1.Shifted_value inputs.(4)
    ; zeta_to_domain_size = Shifted_value.Type1.Shifted_value inputs.(5)
    ; perm = Shifted_value.Type1.Shifted_value inputs.(6)
    ; feature_flags
    ; joint_combiner = Opt.Nothing
    }
  in
  let deferred_values =
    { Composition_types.Wrap.Proof_state.Deferred_values.
      plonk
    ; combined_inner_product = Shifted_value.Type1.Shifted_value inputs.(7)
    ; b = Shifted_value.Type1.Shifted_value inputs.(8)
    ; xi = { Kimchi_types.inner = inputs.(9) }
    ; bulletproof_challenges =
        Vector.init Nat.N16.n ~f:(fun i ->
          { Import.Bulletproof_challenge.prechallenge =
              { Kimchi_types.inner = inputs.(10 + i) }
          })
    ; branch_data =
        { Import.Branch_data.Checked.Step.
          proofs_verified_mask =
            Vector.[ as_bool inputs.(26); as_bool inputs.(27) ]
        ; domain_log2 = inputs.(28)
        }
    }
  in
  (* -- All_evals -- *)
  let evals_evals :
    ( Impl.Field.t array * Impl.Field.t array
    , Impl.Boolean.var )
    Evals.In_circuit.t =
    { w = Vector.init Nat.N15.n ~f:(fun j -> eval_pair (31 + 2 * j))
    ; coefficients = Vector.init Nat.N15.n ~f:(fun j -> eval_pair (61 + 2 * j))
    ; z = eval_pair 91
    ; s = Vector.init Nat.N6.n ~f:(fun j -> eval_pair (93 + 2 * j))
    ; generic_selector = eval_pair 105
    ; poseidon_selector = eval_pair 107
    ; complete_add_selector = eval_pair 109
    ; mul_selector = eval_pair 111
    ; emul_selector = eval_pair 113
    ; endomul_scalar_selector = eval_pair 115
    ; range_check0_selector = Opt.Nothing
    ; range_check1_selector = Opt.Nothing
    ; foreign_field_add_selector = Opt.Nothing
    ; foreign_field_mul_selector = Opt.Nothing
    ; xor_selector = Opt.Nothing
    ; rot_selector = Opt.Nothing
    ; lookup_aggregation = Opt.Nothing
    ; lookup_table = Opt.Nothing
    ; lookup_sorted = Vector.init Nat.N5.n ~f:(fun _ -> Opt.Nothing)
    ; runtime_lookup_table = Opt.Nothing
    ; runtime_lookup_table_selector = Opt.Nothing
    ; xor_lookup_selector = Opt.Nothing
    ; lookup_gate_lookup_selector = Opt.Nothing
    ; range_check_lookup_selector = Opt.Nothing
    ; foreign_field_mul_lookup_selector = Opt.Nothing
    }
  in
  let all_evals :
    ( Impl.Field.t
    , Impl.Field.t array
    , Impl.Boolean.var )
    All_evals.In_circuit.t =
    { evals =
        { public_input = (single inputs.(29), single inputs.(30))
        ; evals = evals_evals
        }
    ; ft_eval1 = inputs.(117)
    }
  in
  (* -- prev_challenges -- *)
  let prev_challenges :
    ( (Impl.Field.t, Nat.N16.n) Vector.t
    , Nat.N2.n )
    Vector.t =
    Vector.[
      Vector.init Nat.N16.n ~f:(fun j -> inputs.(118 + j)) ;
      Vector.init Nat.N16.n ~f:(fun j -> inputs.(134 + j))
    ]
  in
  (* -- Sponge initialization (matches step_main.ml pattern) -- *)
  let sponge_params =
    Sponge.Params.map Tick_field_sponge.params ~f:Impl.Field.constant
  in
  let sponge =
    let sponge = Step_main_inputs.Sponge.create sponge_params in
    Step_main_inputs.Sponge.absorb sponge (`Field inputs.(150)) ;
    sponge
  in
  (* -- step_domains: Known, both branches use log2_size = 16 -- *)
  let step_domains :
    [ `Known of (Import.Domains.t, Nat.N2.n) Vector.t | `Side_loaded ] =
    let d = { Import.Domains.h = Pickles_base.Domain.Pow_2_roots_of_unity 16 } in
    `Known Vector.[ d; d ]
  in
  (* -- Call finalize_other_proof -- *)
  let _finalized, _challenges =
    Step_verifier.finalize_other_proof
      (module Nat.N2)
      ~step_domains
      ~zk_rows:3
      ~sponge
      ~prev_challenges
      deferred_values
      all_evals
  in
  ()

(* ==== Wrap finalize other proof circuit (Tock/Fq field) ====

   Tests Wrap_verifier.finalize_other_proof as a standalone circuit.

   Fixed parameters:
   - Proofs_verified = N2 (padded length)
   - domain = wrap_domain for proofs_verified=2, log2_size = 15
   - All optional evals = Nothing (standard kimchi, no lookups)

   Input layout (148 fields via flat array):

   Deferred_values (26 fields):
     0:      plonk.alpha (scalar_challenge inner)
     1:      plonk.beta
     2:      plonk.gamma
     3:      plonk.zeta (scalar_challenge inner)
     4:      plonk.zeta_to_srs_length
     5:      plonk.zeta_to_domain_size
     6:      plonk.perm
     7:      combined_inner_product (shifted_value Type2)
     8:      b (shifted_value Type2)
     9:      xi (scalar_challenge inner)
     10-25:  bulletproof_challenges[0..15] (prechallenge.inner)

   All_evals (89 fields):
     26-27:    public_input (zeta[0], zetaw[0])
     28-57:    w[0..14] pairs (zeta, zetaw) = 30 fields
     58-87:    coefficients[0..14] pairs = 30 fields
     88-89:    z pair = 2 fields
     90-101:   s[0..5] pairs = 12 fields
     102-103:  generic_selector pair
     104-105:  poseidon_selector pair
     106-107:  complete_add_selector pair
     108-109:  mul_selector pair
     110-111:  emul_selector pair
     112-113:  endomul_scalar_selector pair
     114:      ft_eval1

   prev_challenges (32 fields):
     115-130:  prev_challenges[0][0..15]
     131-146:  prev_challenges[1][0..15]

   sponge_digest (1 field):
     147:      sponge_digest_before_evaluations

   Total: 148 fields
*)

let finalize_other_proof_wrap_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let open Kimchi_backend_common.Plonk_types in
  let single x = [| x |] in
  let eval_pair i = (single inputs.(i), single inputs.(i + 1)) in
  (* -- Deferred values (Step type, no feature_flags/joint_combiner/branch_data) -- *)
  let plonk
    : ( Field.t
      , Field.t Import.Scalar_challenge.t
      , Field.t Shifted_value.Type2.t )
      Composition_types.Step.Proof_state.Deferred_values.Plonk.In_circuit.t =
    { alpha = { Kimchi_types.inner = inputs.(0) }
    ; beta = inputs.(1)
    ; gamma = inputs.(2)
    ; zeta = { Kimchi_types.inner = inputs.(3) }
    ; zeta_to_srs_length = Shifted_value.Type2.Shifted_value inputs.(4)
    ; zeta_to_domain_size = Shifted_value.Type2.Shifted_value inputs.(5)
    ; perm = Shifted_value.Type2.Shifted_value inputs.(6)
    }
  in
  let deferred_values =
    { Composition_types.Step.Proof_state.Deferred_values.
      plonk
    ; combined_inner_product = Shifted_value.Type2.Shifted_value inputs.(7)
    ; b = Shifted_value.Type2.Shifted_value inputs.(8)
    ; xi = { Kimchi_types.inner = inputs.(9) }
    ; bulletproof_challenges =
        Vector.init Nat.N16.n ~f:(fun i ->
          { Import.Bulletproof_challenge.prechallenge =
              { Kimchi_types.inner = inputs.(10 + i) }
          })
    }
  in
  (* -- All_evals (same structure as tick version, offset by 26) -- *)
  let evals_evals :
    ( Field.t array * Field.t array
    , Boolean.var )
    Evals.In_circuit.t =
    { w = Vector.init Nat.N15.n ~f:(fun j -> eval_pair (28 + 2 * j))
    ; coefficients = Vector.init Nat.N15.n ~f:(fun j -> eval_pair (58 + 2 * j))
    ; z = eval_pair 88
    ; s = Vector.init Nat.N6.n ~f:(fun j -> eval_pair (90 + 2 * j))
    ; generic_selector = eval_pair 102
    ; poseidon_selector = eval_pair 104
    ; complete_add_selector = eval_pair 106
    ; mul_selector = eval_pair 108
    ; emul_selector = eval_pair 110
    ; endomul_scalar_selector = eval_pair 112
    ; range_check0_selector = Opt.Nothing
    ; range_check1_selector = Opt.Nothing
    ; foreign_field_add_selector = Opt.Nothing
    ; foreign_field_mul_selector = Opt.Nothing
    ; xor_selector = Opt.Nothing
    ; rot_selector = Opt.Nothing
    ; lookup_aggregation = Opt.Nothing
    ; lookup_table = Opt.Nothing
    ; lookup_sorted = Vector.init Nat.N5.n ~f:(fun _ -> Opt.Nothing)
    ; runtime_lookup_table = Opt.Nothing
    ; runtime_lookup_table_selector = Opt.Nothing
    ; xor_lookup_selector = Opt.Nothing
    ; lookup_gate_lookup_selector = Opt.Nothing
    ; range_check_lookup_selector = Opt.Nothing
    ; foreign_field_mul_lookup_selector = Opt.Nothing
    }
  in
  let all_evals :
    ( Field.t
    , Field.t array
    , Boolean.var )
    All_evals.In_circuit.t =
    { evals =
        { public_input = (single inputs.(26), single inputs.(27))
        ; evals = evals_evals
        }
    ; ft_eval1 = inputs.(114)
    }
  in
  (* -- prev_challenges -- *)
  let old_bulletproof_challenges :
    ( (Field.t, Nat.N16.n) Vector.t
    , Nat.N2.n )
    Vector.t =
    Vector.[
      Vector.init Nat.N16.n ~f:(fun j -> inputs.(115 + j)) ;
      Vector.init Nat.N16.n ~f:(fun j -> inputs.(131 + j))
    ]
  in
  (* -- Sponge initialization -- *)
  let sponge_params =
    Sponge.Params.map Tock_field_sponge.params ~f:Field.constant
  in
  let sponge =
    let sponge = Wrap_main_inputs.Sponge.create sponge_params in
    Wrap_main_inputs.Sponge.absorb sponge inputs.(147) ;
    sponge
  in
  (* -- domain: wrap_domain for proofs_verified=2, log2_size = 15 -- *)
  let domain =
    Plonk_checks.domain
      (module Field)
      ~shifts:(fun ~log2_size ->
        Common.tock_shifts ~log2_size
        |> Array.map ~f:Field.constant)
      ~domain_generator:(fun ~log2_size ->
        Backend.Tock.Field.domain_generator ~log2_size
        |> Field.constant)
      (Pickles_base.Domain.Pow_2_roots_of_unity 15)
  in
  (* -- Call finalize_other_proof -- *)
  let _finalized, _challenges =
    Wrap_verifier.finalize_other_proof
      (module Nat.N2)
      ~domain:(domain :> _ Plonk_checks.plonk_domain)
      ~sponge
      ~old_bulletproof_challenges
      deferred_values
      all_evals
  in
  ()

(* IVP Wrap circuit: Wrap_verifier.incrementally_verify_proof on Tock/Pallas

   Input layout (177 fields):
   PackedStepPublicInput (n=1, dw=15), OCaml to_data order:
     0-1:   cip (split: sDiv2, sOdd)
     2-3:   b (split)
     4-5:   zetaToSrsLength (split)
     6-7:   zetaToDomainSize (split)
     8-9:   perm (split)
     10:    sponge_digest (255-bit)
     11-12: beta, gamma (128-bit)
     13-15: alpha, zeta, xi (128-bit)
     16-30: bulletproofChallenges[0..14] (128-bit)
     31:    should_finalize (1-bit)
     32:    messages_for_next_step_proof (255-bit)
     33:    messages_for_next_wrap_proof[0] (255-bit)
   IVP DeferredValues (Type1 shifted, d=16):
     34-37: alpha, beta, gamma, zeta (scalar challenges)
     38-40: perm, zetaToSrsLength, zetaToDomainSize (Type1)
     41-42: combinedInnerProduct, b (Type1)
     43:    xi (scalar challenge)
     44-59: bulletproofChallenges[0..15] (scalar challenges)
   Messages:
     60-89:   wComm[0..14] (15 × 2)
     90-91:   zComm (2)
     92-105:  tComm[0..6] (7 × 2)
   Opening proof:
     106-107: delta (2)
     108-109: sg (2)
     110-173: lr[0..15] (16 × 4)
     174:     z1 (Type1)
     175:     z2 (Type1)
   Verify:
     176:     claimedDigest
*)
let ivp_wrap_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let read_pt i : Wrap_main_inputs.Inner_curve.t =
    (inputs.(i), inputs.(i + 1))
  in
  (* ---- Public input (tagged array for x_hat MSM) ---- *)
  let public_input =
    let split i =
      `Field (inputs.(i), Boolean.Unsafe.of_cvar inputs.(i + 1))
    in
    let packed n i = `Packed_bits (inputs.(i), n) in
    Array.concat
      [ Array.init 5 ~f:(fun j -> split (2 * j))
      ; [| packed 255 10
         ; packed 128 11 ; packed 128 12
         ; packed 128 13 ; packed 128 14 ; packed 128 15 |]
      ; Array.init 15 ~f:(fun j -> packed 128 (16 + j))
      ; [| packed 1 31 ; packed 255 32 ; packed 255 33 |]
      ]
  in
  (* ---- Plonk deferred values ---- *)
  let feature_flags =
    Kimchi_backend_common.Plonk_types.Features.map
      Kimchi_backend_common.Plonk_types.Features.none_bool
      ~f:(fun _ -> Boolean.false_)
  in
  let plonk
    : ( Field.t
      , Field.t Import.Scalar_challenge.t
      , Field.t Shifted_value.Type1.t
      , (Field.t Shifted_value.Type1.t, Boolean.var) Opt.t
      , (Field.t Import.Scalar_challenge.t, Boolean.var) Opt.t
      , Boolean.var )
      Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t =
    { alpha = { Kimchi_types.inner = inputs.(34) }
    ; beta = inputs.(35)
    ; gamma = inputs.(36)
    ; zeta = { Kimchi_types.inner = inputs.(37) }
    ; perm = Shifted_value.Type1.Shifted_value inputs.(38)
    ; zeta_to_srs_length = Shifted_value.Type1.Shifted_value inputs.(39)
    ; zeta_to_domain_size = Shifted_value.Type1.Shifted_value inputs.(40)
    ; feature_flags
    ; joint_combiner = Opt.Nothing
    }
  in
  let advice =
    { Import.Types.Step.Bulletproof.Advice.
      combined_inner_product = Shifted_value.Type1.Shifted_value inputs.(41)
    ; b = Shifted_value.Type1.Shifted_value inputs.(42)
    }
  in
  let xi : Wrap_verifier.Scalar_challenge.t =
    { Kimchi_types.inner = inputs.(43) }
  in
  let claimed_bp_challenges =
    Array.init 16 ~f:(fun j -> inputs.(44 + j))
  in
  (* ---- Messages ---- *)
  let messages =
    { Kimchi_backend_common.Plonk_types.Messages.In_circuit.
      w_comm = Vector.init Nat.N15.n ~f:(fun j -> [| read_pt (60 + 2 * j) |])
    ; z_comm = [| read_pt 90 |]
    ; t_comm = Array.init 7 ~f:(fun j -> read_pt (92 + 2 * j))
    ; lookup = Opt.Nothing
    }
  in
  (* ---- Opening proof ---- *)
  let openings_proof =
    { Kimchi_backend_common.Plonk_types.Openings.Bulletproof.
      lr = Array.init 16 ~f:(fun j ->
        (read_pt (110 + 4 * j), read_pt (110 + 4 * j + 2)))
    ; z_1 = Shifted_value.Type1.Shifted_value inputs.(174)
    ; z_2 = Shifted_value.Type1.Shifted_value inputs.(175)
    ; delta = read_pt 106
    ; challenge_polynomial_commitment = read_pt 108
    }
  in
  let claimed_digest = inputs.(176) in
  (* ---- SRS (Step/Fp SRS for verifying Step proofs) ---- *)
  let srs = Kimchi_bindings.Protocol.SRS.Fp.create (1 lsl 16) in
  (* ---- Verification key (dummy, all commitments = Vesta generator) ---- *)
  let dummy_pt = Wrap_main_inputs.Inner_curve.Params.one in
  let dummy_comm = [| Wrap_main_inputs.Inner_curve.constant dummy_pt |] in
  let verification_key =
    { Plonk_verification_key_evals.Step.
      sigma_comm = Vector.init Nat.N7.n ~f:(fun _ -> dummy_comm)
    ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun _ -> dummy_comm)
    ; generic_comm = dummy_comm
    ; psm_comm = dummy_comm
    ; complete_add_comm = dummy_comm
    ; mul_comm = dummy_comm
    ; emul_comm = dummy_comm
    ; endomul_scalar_comm = dummy_comm
    ; xor_comm = Opt.Nothing
    ; range_check0_comm = Opt.Nothing
    ; range_check1_comm = Opt.Nothing
    ; foreign_field_add_comm = Opt.Nothing
    ; foreign_field_mul_comm = Opt.Nothing
    ; rot_comm = Opt.Nothing
    ; lookup_table_comm =
        Vector.init Plonk_types.Lookup_sorted_minus_1.n ~f:(fun _ -> Opt.Nothing)
    ; lookup_table_ids = Opt.Nothing
    ; runtime_tables_selector = Opt.Nothing
    ; lookup_selector_lookup = Opt.Nothing
    ; lookup_selector_xor = Opt.Nothing
    ; lookup_selector_range_check = Opt.Nothing
    ; lookup_selector_ffmul = Opt.Nothing
    }
  in
  (* ---- Sponge ---- *)
  let sponge_params =
    Sponge.Params.map Tock_field_sponge.params ~f:Field.constant
  in
  let sponge = Wrap_verifier.Opt.create sponge_params in
  (* ---- Step domains (1 branch, domain 2^16) ---- *)
  let step_domains = Vector.[
    { Import.Domains.h = Pickles_base.Domain.Pow_2_roots_of_unity 16 }
  ] in
  (* ---- which_branch (single branch, always selected) ---- *)
  let which_branch =
    Wrap_verifier.One_hot_vector.of_vector_unsafe Vector.[ Boolean.true_ ]
  in
  (* ---- Call IVP ---- *)
  let digest, (`Success _success, bp_challenges) =
    Wrap_verifier.incrementally_verify_proof
      (module Nat.N0)
      ~actual_proofs_verified_mask:Vector.[]
      ~step_domains
      ~srs
      ~verification_key
      ~xi
      ~sponge
      ~public_input
      ~sg_old:Vector.[]
      ~advice
      ~messages
      ~which_branch
      ~openings_proof
      ~plonk
  in
  (* ---- Assert digest matches (matches PureScript verify assertions) ---- *)
  Field.Assert.equal digest claimed_digest ;
  (* ---- Assert bulletproof challenges match ---- *)
  Array.iteri bp_challenges
    ~f:(fun i { Import.Bulletproof_challenge.prechallenge =
                  { Kimchi_types.inner = c } } ->
      Field.Assert.equal c claimed_bp_challenges.(i) ) ;
  ()

(* Wrap verify circuit (N1): calls Wrap_main.wrap_verify which does
   IVP + assertions (bulletproof_success, messages_for_next_wrap_proof hash,
   sponge_digest, bp_challenges).

   Input layout (196 fields):
   0-33:   public_input (34 fields, same as ivp_wrap)
   34-37:  plonk alpha, beta, gamma, zeta
   38-42:  plonk perm, zetaToSrs, zetaToDom, cip, b (Type1 shifted = 1 field each)
   43:     xi
   44-59:  claimed_bp_challenges (16 fields)
   60-89:  w_comm (15×2 = 30 fields)
   90-91:  z_comm (2 fields)
   92-105: t_comm (7×2 = 14 fields)
   106-109: delta, sg (4 fields)
   110-173: lr (16×4 = 64 fields)
   174-175: z1, z2 (2 fields, Type1 shifted)
   176:    sponge_digest_before_evaluations
   177:    messages_for_next_wrap_proof_digest
   178-193: new_bulletproof_challenges[0] (16 fields, N1 → 1 vector)
   194-195: prev_step_accs[0] (sg_old point, 2 fields, N1 → 1 point)
*)
let wrap_verify_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let read_pt i : Wrap_main_inputs.Inner_curve.t =
    (inputs.(i), inputs.(i + 1))
  in
  (* ---- Public input (same as ivp_wrap_circuit) ---- *)
  let public_input =
    let split i =
      `Field (inputs.(i), Boolean.Unsafe.of_cvar inputs.(i + 1))
    in
    let packed n i = `Packed_bits (inputs.(i), n) in
    Array.concat
      [ Array.init 5 ~f:(fun j -> split (2 * j))
      ; [| packed 255 10
         ; packed 128 11 ; packed 128 12
         ; packed 128 13 ; packed 128 14 ; packed 128 15 |]
      ; Array.init 15 ~f:(fun j -> packed 128 (16 + j))
      ; [| packed 1 31 ; packed 255 32 ; packed 255 33 |]
      ]
  in
  (* ---- Plonk deferred values ---- *)
  let feature_flags =
    Kimchi_backend_common.Plonk_types.Features.map
      Kimchi_backend_common.Plonk_types.Features.none_bool
      ~f:(fun _ -> Boolean.false_)
  in
  let plonk
    : ( Field.t
      , Field.t Import.Scalar_challenge.t
      , Field.t Shifted_value.Type1.t
      , (Field.t Shifted_value.Type1.t, Boolean.var) Opt.t
      , (Field.t Import.Scalar_challenge.t, Boolean.var) Opt.t
      , Boolean.var )
      Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t =
    { alpha = { Kimchi_types.inner = inputs.(34) }
    ; beta = inputs.(35)
    ; gamma = inputs.(36)
    ; zeta = { Kimchi_types.inner = inputs.(37) }
    ; perm = Shifted_value.Type1.Shifted_value inputs.(38)
    ; zeta_to_srs_length = Shifted_value.Type1.Shifted_value inputs.(39)
    ; zeta_to_domain_size = Shifted_value.Type1.Shifted_value inputs.(40)
    ; feature_flags
    ; joint_combiner = Opt.Nothing
    }
  in
  let xi : Wrap_verifier.Scalar_challenge.t =
    { Kimchi_types.inner = inputs.(43) }
  in
  let bulletproof_challenges =
    Vector.init Backend.Tick.Rounds.n ~f:(fun j ->
      { Import.Bulletproof_challenge.prechallenge =
          { Kimchi_types.inner = inputs.(44 + j) } })
  in
  (* ---- Messages ---- *)
  let messages =
    { Kimchi_backend_common.Plonk_types.Messages.In_circuit.
      w_comm = Vector.init Nat.N15.n ~f:(fun j -> [| read_pt (60 + 2 * j) |])
    ; z_comm = [| read_pt 90 |]
    ; t_comm = Array.init 7 ~f:(fun j -> read_pt (92 + 2 * j))
    ; lookup = Opt.Nothing
    }
  in
  (* ---- Opening proof ---- *)
  let openings_proof =
    { Kimchi_backend_common.Plonk_types.Openings.Bulletproof.
      lr = Array.init 16 ~f:(fun j ->
        (read_pt (110 + 4 * j), read_pt (110 + 4 * j + 2)))
    ; z_1 = Shifted_value.Type1.Shifted_value inputs.(174)
    ; z_2 = Shifted_value.Type1.Shifted_value inputs.(175)
    ; delta = read_pt 106
    ; challenge_polynomial_commitment = read_pt 108
    }
  in
  let sponge_digest_before_evaluations = inputs.(176) in
  let messages_for_next_wrap_proof_digest = inputs.(177) in
  (* ---- N1 specific: 1 set of new bp challenges + 1 prev_step_acc ---- *)
  let new_bulletproof_challenges : ((Field.t, Backend.Tock.Rounds.n) Vector.t, Nat.N1.n) Vector.t =
    Vector.[
      Vector.init Backend.Tock.Rounds.n ~f:(fun j -> inputs.(178 + j))
    ]
  in
  let prev_step_accs : (Wrap_main_inputs.Inner_curve.t, Nat.N1.n) Vector.t =
    Vector.[ read_pt 194 ]
  in
  (* ---- SRS ---- *)
  let srs = Kimchi_bindings.Protocol.SRS.Fp.create (1 lsl 16) in
  (* ---- Verification key (dummy) ---- *)
  let dummy_pt = Wrap_main_inputs.Inner_curve.Params.one in
  let dummy_comm = [| Wrap_main_inputs.Inner_curve.constant dummy_pt |] in
  let verification_key =
    { Plonk_verification_key_evals.Step.
      sigma_comm = Vector.init Nat.N7.n ~f:(fun _ -> dummy_comm)
    ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun _ -> dummy_comm)
    ; generic_comm = dummy_comm
    ; psm_comm = dummy_comm
    ; complete_add_comm = dummy_comm
    ; mul_comm = dummy_comm
    ; emul_comm = dummy_comm
    ; endomul_scalar_comm = dummy_comm
    ; xor_comm = Opt.Nothing
    ; range_check0_comm = Opt.Nothing
    ; range_check1_comm = Opt.Nothing
    ; foreign_field_add_comm = Opt.Nothing
    ; foreign_field_mul_comm = Opt.Nothing
    ; rot_comm = Opt.Nothing
    ; lookup_table_comm =
        Vector.init Plonk_types.Lookup_sorted_minus_1.n ~f:(fun _ -> Opt.Nothing)
    ; lookup_table_ids = Opt.Nothing
    ; runtime_tables_selector = Opt.Nothing
    ; lookup_selector_lookup = Opt.Nothing
    ; lookup_selector_xor = Opt.Nothing
    ; lookup_selector_range_check = Opt.Nothing
    ; lookup_selector_ffmul = Opt.Nothing
    }
  in
  let sponge_params =
    Sponge.Params.map Tock_field_sponge.params ~f:Field.constant
  in
  let step_domains = Vector.[
    { Import.Domains.h = Pickles_base.Domain.Pow_2_roots_of_unity 16 }
  ] in
  let which_branch =
    Wrap_verifier.One_hot_vector.of_vector_unsafe Vector.[ Boolean.true_ ]
  in
  let actual_proofs_verified_mask : (Boolean.var, Nat.N1.n) Vector.t =
    Vector.[ Boolean.true_ ]
  in
  Wrap_main.wrap_verify
    ~num_chunks:1
    ~max_proofs_verified:(module Nat.N1)
    ~max_proofs_verified_n:Nat.N1.n
    ~feature_flags:(Kimchi_backend_common.Plonk_types.Features.Full.none)
    ~sponge_params
    ~actual_proofs_verified_mask
    ~step_domains
    ~step_plonk_index:verification_key
    ~srs
    ~xi
    ~plonk
    ~combined_inner_product:(Shifted_value.Type1.Shifted_value inputs.(41))
    ~b:(Shifted_value.Type1.Shifted_value inputs.(42))
    ~public_input
    ~prev_step_accs
    ~messages
    ~openings_proof
    ~which_branch
    ~new_bulletproof_challenges
    ~sponge_digest_before_evaluations
    ~messages_for_next_wrap_proof_digest
    ~bulletproof_challenges

(* Wrap verify circuit (N2): same as wrap_verify_circuit but with 2 previous proofs.

   Input layout (212 fields):
   0-176:   Same as wrap_verify_circuit (IVP wrap input)
   177:     messages_for_next_wrap_proof_digest
   178-192: new_bulletproof_challenges[0] (15 fields, Backend.Tock.Rounds.n)
   193-207: new_bulletproof_challenges[1] (15 fields)
   208-209: prev_step_accs[0] (2 fields)
   210-211: prev_step_accs[1] (2 fields)
*)
let wrap_verify_n2_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let read_pt i : Wrap_main_inputs.Inner_curve.t =
    (inputs.(i), inputs.(i + 1))
  in
  (* ---- Public input (same as wrap_verify_circuit) ---- *)
  let public_input =
    let split i =
      `Field (inputs.(i), Boolean.Unsafe.of_cvar inputs.(i + 1))
    in
    let packed n i = `Packed_bits (inputs.(i), n) in
    Array.concat
      [ Array.init 5 ~f:(fun j -> split (2 * j))
      ; [| packed 255 10
         ; packed 128 11 ; packed 128 12
         ; packed 128 13 ; packed 128 14 ; packed 128 15 |]
      ; Array.init 15 ~f:(fun j -> packed 128 (16 + j))
      ; [| packed 1 31 ; packed 255 32 ; packed 255 33 |]
      ]
  in
  (* ---- Plonk deferred values (same as N1) ---- *)
  let feature_flags =
    Kimchi_backend_common.Plonk_types.Features.map
      Kimchi_backend_common.Plonk_types.Features.none_bool
      ~f:(fun _ -> Boolean.false_)
  in
  let plonk
    : ( Field.t
      , Field.t Import.Scalar_challenge.t
      , Field.t Shifted_value.Type1.t
      , (Field.t Shifted_value.Type1.t, Boolean.var) Opt.t
      , (Field.t Import.Scalar_challenge.t, Boolean.var) Opt.t
      , Boolean.var )
      Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t =
    { alpha = { Kimchi_types.inner = inputs.(34) }
    ; beta = inputs.(35)
    ; gamma = inputs.(36)
    ; zeta = { Kimchi_types.inner = inputs.(37) }
    ; perm = Shifted_value.Type1.Shifted_value inputs.(38)
    ; zeta_to_srs_length = Shifted_value.Type1.Shifted_value inputs.(39)
    ; zeta_to_domain_size = Shifted_value.Type1.Shifted_value inputs.(40)
    ; feature_flags
    ; joint_combiner = Opt.Nothing
    }
  in
  let xi : Wrap_verifier.Scalar_challenge.t =
    { Kimchi_types.inner = inputs.(43) }
  in
  let bulletproof_challenges =
    Vector.init Backend.Tick.Rounds.n ~f:(fun j ->
      { Import.Bulletproof_challenge.prechallenge =
          { Kimchi_types.inner = inputs.(44 + j) } })
  in
  (* ---- Messages (same as N1) ---- *)
  let messages =
    { Kimchi_backend_common.Plonk_types.Messages.In_circuit.
      w_comm = Vector.init Nat.N15.n ~f:(fun j -> [| read_pt (60 + 2 * j) |])
    ; z_comm = [| read_pt 90 |]
    ; t_comm = Array.init 7 ~f:(fun j -> read_pt (92 + 2 * j))
    ; lookup = Opt.Nothing
    }
  in
  (* ---- Opening proof (same as N1) ---- *)
  let openings_proof =
    { Kimchi_backend_common.Plonk_types.Openings.Bulletproof.
      lr = Array.init 16 ~f:(fun j ->
        (read_pt (110 + 4 * j), read_pt (110 + 4 * j + 2)))
    ; z_1 = Shifted_value.Type1.Shifted_value inputs.(174)
    ; z_2 = Shifted_value.Type1.Shifted_value inputs.(175)
    ; delta = read_pt 106
    ; challenge_polynomial_commitment = read_pt 108
    }
  in
  let sponge_digest_before_evaluations = inputs.(176) in
  let messages_for_next_wrap_proof_digest = inputs.(177) in
  (* ---- N2 specific: 2 sets of new bp challenges + 2 prev_step_accs ---- *)
  let new_bulletproof_challenges : ((Field.t, Backend.Tock.Rounds.n) Vector.t, Nat.N2.n) Vector.t =
    Vector.[
      Vector.init Backend.Tock.Rounds.n ~f:(fun j -> inputs.(178 + j)) ;
      Vector.init Backend.Tock.Rounds.n ~f:(fun j -> inputs.(193 + j))
    ]
  in
  let prev_step_accs : (Wrap_main_inputs.Inner_curve.t, Nat.N2.n) Vector.t =
    Vector.[ read_pt 208 ; read_pt 210 ]
  in
  (* ---- SRS ---- *)
  let srs = Kimchi_bindings.Protocol.SRS.Fp.create (1 lsl 16) in
  (* ---- Verification key (dummy) ---- *)
  let dummy_pt = Wrap_main_inputs.Inner_curve.Params.one in
  let dummy_comm = [| Wrap_main_inputs.Inner_curve.constant dummy_pt |] in
  let verification_key =
    { Plonk_verification_key_evals.Step.
      sigma_comm = Vector.init Nat.N7.n ~f:(fun _ -> dummy_comm)
    ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun _ -> dummy_comm)
    ; generic_comm = dummy_comm
    ; psm_comm = dummy_comm
    ; complete_add_comm = dummy_comm
    ; mul_comm = dummy_comm
    ; emul_comm = dummy_comm
    ; endomul_scalar_comm = dummy_comm
    ; xor_comm = Opt.Nothing
    ; range_check0_comm = Opt.Nothing
    ; range_check1_comm = Opt.Nothing
    ; foreign_field_add_comm = Opt.Nothing
    ; foreign_field_mul_comm = Opt.Nothing
    ; rot_comm = Opt.Nothing
    ; lookup_table_comm =
        Vector.init Plonk_types.Lookup_sorted_minus_1.n ~f:(fun _ -> Opt.Nothing)
    ; lookup_table_ids = Opt.Nothing
    ; runtime_tables_selector = Opt.Nothing
    ; lookup_selector_lookup = Opt.Nothing
    ; lookup_selector_xor = Opt.Nothing
    ; lookup_selector_range_check = Opt.Nothing
    ; lookup_selector_ffmul = Opt.Nothing
    }
  in
  let sponge_params =
    Sponge.Params.map Tock_field_sponge.params ~f:Field.constant
  in
  let step_domains = Vector.[
    { Import.Domains.h = Pickles_base.Domain.Pow_2_roots_of_unity 16 }
  ] in
  let which_branch =
    Wrap_verifier.One_hot_vector.of_vector_unsafe Vector.[ Boolean.true_ ]
  in
  let actual_proofs_verified_mask : (Boolean.var, Nat.N2.n) Vector.t =
    Vector.[ Boolean.true_ ; Boolean.true_ ]
  in
  Wrap_main.wrap_verify
    ~num_chunks:1
    ~max_proofs_verified:(module Nat.N2)
    ~max_proofs_verified_n:Nat.N2.n
    ~feature_flags:(Kimchi_backend_common.Plonk_types.Features.Full.none)
    ~sponge_params
    ~actual_proofs_verified_mask
    ~step_domains
    ~step_plonk_index:verification_key
    ~srs
    ~xi
    ~plonk
    ~combined_inner_product:(Shifted_value.Type1.Shifted_value inputs.(41))
    ~b:(Shifted_value.Type1.Shifted_value inputs.(42))
    ~public_input
    ~prev_step_accs
    ~messages
    ~openings_proof
    ~which_branch
    ~new_bulletproof_challenges
    ~sponge_digest_before_evaluations
    ~messages_for_next_wrap_proof_digest
    ~bulletproof_challenges

(* Full wrap_main circuit.

   Inlines the full wrap_main logic, replacing each `exists ~request` with
   `var_of_fields` to allocate structured variables from a flat input array.

   Layout: [wrap_statement | which_branch | prev_proof_state | prev_step_accs |
            old_bp_chals | evals | wrap_domain_indices | openings_proof | messages]

   Uses size_in_field_elements to compute offsets dynamically.

   ---- Application-specific parameters ----

   This fixture is for a single-branch fold operator (like running_sum):
     branches           = 1    (one Step circuit variant)
     step_widths        = [1]  (each branch verifies 1 previous proof)
     Max_proofs_verified = N2  (always 2 in Pickles, padded)
     Max_widths_by_slot = [N1; N0]  (slot 0 has 1 inner proof, slot 1 unused)
     feature_flags      = Features.Full.none (no optional Kimchi gates)
     num_chunks         = 1

   ---- TODO: fixture variants for comprehensive coverage ----

   1. Multi-branch (base+merge / IVC pattern):
      branches=2, step_widths=[0,2], Max_widths_by_slot=[N2,N1].
      Exercises Pseudo.choose / choose_key branch selection constraints,
      and old_bp_chals with larger slot sizes.

   2. Feature flags:
      feature_flags with e.g. xor=true, range_check=true.
      Changes VK structure (Opt.Just instead of Opt.Nothing),
      feature flag consistency assertions, Messages.wrap_typ shape.

   3. num_chunks > 1:
      Affects Plonk_types.All_evals.wrap_typ and Commitment_lengths.
      Relevant for very large circuits exceeding SRS degree.

   4. Different step_domains:
      Currently domain=2^16. Different step circuits may use different
      domains, changing lagrange commitment counts and constant values
      (but not circuit structure for single-branch).

   5. CheckedType / Typ.check constraints:
      The alloc_typ helper calls var_of_fields + constraint_system_auxiliary,
      which may introduce check constraints (e.g. Boolean.typ asserts 0-or-1,
      SizedF 128 asserts high bits zero). These should be audited against
      production wrap_main's `exists` calls to ensure the same checks fire.
      In particular, prev_proof_state uses wrap_typ with assert_16_bits,
      and the openings_proof Typ uses transport/transport_var which may
      elide or add checks vs the raw exists in production.
*)
let wrap_main_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let module Inner_curve = Wrap_main_inputs.Inner_curve in
  let feature_flags = Plonk_types.Features.Full.none in
  let num_chunks = 1 in
  let pos = ref 0 in
  let alloc_typ : type var value.
      (var, value) Typ.t -> var =
    fun typ ->
      let (Typ r) = typ in
      let size = r.size_in_field_elements in
      let fields = Array.sub inputs ~pos:!pos ~len:size in
      let var = r.var_of_fields (fields, r.constraint_system_auxiliary ()) in
      pos := !pos + size ;
      var
  in
  (* ---- 1. WrapStatement (public input) ---- *)
  (* Manually parse, matching wrap_main.ml's destructuring of
     Types.Wrap.Statement.In_circuit.t.
     Fields: plonk(7 + feature_flags), xi, combined_inner_product, b,
     branch_data, bulletproof_challenges(16), sponge_digest, msg_wrap, msg_step *)
  let at i = inputs.(i) in
  let feature_flags_var =
    Kimchi_backend_common.Plonk_types.Features.map
      Kimchi_backend_common.Plonk_types.Features.none_bool
      ~f:(fun _ -> Boolean.false_)
  in
  let plonk
      : ( Field.t
        , Field.t Import.Scalar_challenge.t
        , Field.t Shifted_value.Type1.t
        , (Field.t Shifted_value.Type1.t, Boolean.var) Opt.t
        , (Field.t Import.Scalar_challenge.t, Boolean.var) Opt.t
        , Boolean.var )
        Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t =
    { alpha = { Kimchi_types.inner = at 0 }
    ; beta = at 1
    ; gamma = at 2
    ; zeta = { Kimchi_types.inner = at 3 }
    ; perm = Shifted_value.Type1.Shifted_value (at 4)
    ; zeta_to_srs_length = Shifted_value.Type1.Shifted_value (at 5)
    ; zeta_to_domain_size = Shifted_value.Type1.Shifted_value (at 6)
    ; feature_flags = feature_flags_var
    ; joint_combiner = Opt.Nothing
    }
  in
  let xi : Wrap_verifier.Scalar_challenge.t = { Kimchi_types.inner = at 7 } in
  let combined_inner_product = Shifted_value.Type1.Shifted_value (at 8) in
  let b = Shifted_value.Type1.Shifted_value (at 9) in
  let branch_data = at 10 in
  let bulletproof_challenges =
    Vector.init Backend.Tick.Rounds.n ~f:(fun j ->
      { Import.Bulletproof_challenge.prechallenge =
          { Kimchi_types.inner = at (11 + j) } })
  in
  (* 11 + 16 = 27 *)
  let sponge_digest_before_evaluations = at 27 in
  let messages_for_next_wrap_proof_digest = at 28 in
  let messages_for_next_step_proof = at 29 in
  pos := 30 ;
  (* ---- 2. which_branch (single field) ---- *)
  let which_branch' = alloc_typ Field.typ in
  let which_branch = with_label "one_hot_which_branch" (fun () ->
    Wrap_verifier.One_hot_vector.of_index which_branch'
      ~length:Nat.N1.n)
  in
  (* ---- 3. Branch selection (single branch) ---- *)
  let step_widths : (int, Nat.N1.n) Vector.t = Vector.[ 1 ] in
  let actual_proofs_verified_mask = with_label "ones_vector" (fun () ->
    Util.Wrap.ones_vector
      ~first_zero:
        (Wrap_verifier.Pseudo.choose (which_branch, step_widths) ~f:Field.of_int)
      Nat.N2.n
    |> Vector.rev)
  in
  let step_domains : (Import.Domains.t, Nat.N1.n) Vector.t = Vector.[
    { Import.Domains.h = Pickles_base.Domain.Pow_2_roots_of_unity 16 }
  ] in
  let domain_log2 = with_label "domain_log2_choose" (fun () ->
    Wrap_verifier.Pseudo.choose
      ( which_branch
      , Vector.map ~f:(fun ds -> Pickles_base.Domain.log2_size ds.h) step_domains )
      ~f:Field.of_int)
  in
  (* ---- 4. Assert branch_data ---- *)
  with_label "branch_data_assert" (fun () ->
    Import.Branch_data.Checked.Wrap.pack
      { proofs_verified_mask =
          Vector.extend_front_exn actual_proofs_verified_mask Nat.N2.n Boolean.false_
      ; domain_log2
      }
    |> Field.Assert.equal branch_data) ;
  (* ---- 5. prev_proof_state ---- *)
  let prev_proof_state_typ =
    let open Import.Types.Step.Proof_state in
    wrap_typ
      ~assert_16_bits:(Wrap_verifier.assert_n_bits ~n:16)
      (Vector.init Nat.N2.n ~f:(fun _ -> Plonk_types.Features.none))
      (Shifted_value.Type2.wrap_typ Field.typ)
  in
  let prev_proof_state = with_label "alloc_prev_proof_state" (fun () ->
    alloc_typ prev_proof_state_typ) in
  (* ---- 6. step_plonk_index (dummy VK, single branch) ---- *)
  let dummy_pt = Inner_curve.Params.one in
  let dummy_comm = [| Inner_curve.constant dummy_pt |] in
  let step_plonk_index =
    let key =
      { Plonk_verification_key_evals.Step.
        sigma_comm = Vector.init Nat.N7.n ~f:(fun _ -> dummy_comm)
      ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun _ -> dummy_comm)
      ; generic_comm = dummy_comm
      ; psm_comm = dummy_comm
      ; complete_add_comm = dummy_comm
      ; mul_comm = dummy_comm
      ; emul_comm = dummy_comm
      ; endomul_scalar_comm = dummy_comm
      ; xor_comm = Opt.Nothing
      ; range_check0_comm = Opt.Nothing
      ; range_check1_comm = Opt.Nothing
      ; foreign_field_add_comm = Opt.Nothing
      ; foreign_field_mul_comm = Opt.Nothing
      ; rot_comm = Opt.Nothing
      ; lookup_table_comm =
          Vector.init Plonk_types.Lookup_sorted_minus_1.n ~f:(fun _ -> Opt.Nothing)
      ; lookup_table_ids = Opt.Nothing
      ; runtime_tables_selector = Opt.Nothing
      ; lookup_selector_lookup = Opt.Nothing
      ; lookup_selector_xor = Opt.Nothing
      ; lookup_selector_range_check = Opt.Nothing
      ; lookup_selector_ffmul = Opt.Nothing
      }
    in
    with_label "choose_key" (fun () ->
      Wrap_verifier.choose_key which_branch Vector.[ key ])
  in
  (* ---- 7. Feature flag consistency (all None for Features.none) ---- *)
  let () = with_label "feature_flag_consistency" (fun () ->
    let { Plonk_verification_key_evals.Step.
          sigma_comm = _; coefficients_comm = _; generic_comm = _; psm_comm = _
        ; complete_add_comm = _; mul_comm = _; emul_comm = _
        ; endomul_scalar_comm = _
        ; xor_comm; range_check0_comm; range_check1_comm
        ; foreign_field_add_comm; foreign_field_mul_comm; rot_comm
        ; lookup_table_comm =
            [ lookup_table_comm0; lookup_table_comm1
            ; lookup_table_comm2; lookup_table_comm3 ]
        ; lookup_table_ids = _; runtime_tables_selector
        ; lookup_selector_lookup; lookup_selector_xor
        ; lookup_selector_range_check; lookup_selector_ffmul
        } = step_plonk_index
    in
    let { Plonk_types.Features.Full.
          range_check0; range_check1; foreign_field_add; foreign_field_mul
        ; xor; rot; lookup; runtime_tables; uses_lookups = _
        ; table_width_at_least_1; table_width_at_least_2; table_width_3
        ; lookups_per_row_3 = _; lookups_per_row_4 = _
        ; lookup_pattern_xor; lookup_pattern_range_check
        } =
      Plonk_checks.expand_feature_flags
        (module struct type t = Boolean.var include Boolean end)
        plonk.feature_flags
    in
    let commitment_flag = function
      | Opt.Just _ -> Boolean.true_
      | Opt.Maybe (b, _) -> b
      | Opt.Nothing -> Boolean.false_
    in
    let assert_consistent comm flag =
      Boolean.Assert.( = ) (commitment_flag comm) (Lazy.force flag)
    in
    assert_consistent xor_comm xor ;
    assert_consistent range_check0_comm range_check0 ;
    assert_consistent range_check1_comm range_check1 ;
    assert_consistent foreign_field_add_comm foreign_field_add ;
    assert_consistent foreign_field_mul_comm foreign_field_mul ;
    assert_consistent rot_comm rot ;
    assert_consistent lookup_table_comm0 table_width_at_least_1 ;
    assert_consistent lookup_table_comm1 table_width_at_least_2 ;
    assert_consistent lookup_table_comm2 table_width_3 ;
    assert_consistent lookup_table_comm3 (lazy Boolean.false_) ;
    assert_consistent runtime_tables_selector runtime_tables ;
    assert_consistent lookup_selector_lookup lookup ;
    assert_consistent lookup_selector_xor lookup_pattern_xor ;
    assert_consistent lookup_selector_range_check lookup_pattern_range_check ;
    assert_consistent lookup_selector_ffmul foreign_field_mul)
  in
  (* ---- 8. prev_step_accs ---- *)
  let prev_step_accs = with_label "alloc_prev_step_accs" (fun () ->
    alloc_typ (Vector.wrap_typ Inner_curve.typ Nat.N2.n))
  in
  (* ---- 9. old_bp_chals (N1 single branch: [Vector N1 (Vector 15 Field.t)]) ---- *)
  (* For single-branch N1: Max_widths_by_slot.maxes = [N1; N0].
     Slot 0: 1 vector of 15 challenges = 15 fields.
     Slot 1: 0 vectors = 0 fields.
     Old_bulletproof_chals is a local GADT in wrap_main.ml, reproduced here. *)
  let module Old_bulletproof_chals = struct
    type t =
      | T :
          'n Nat.t
          * ((Field.t, Backend.Tock.Rounds.n) Vector.t, 'n) Vector.t
          -> t
  end in
  let old_bp_chals_slot0 : (Field.t, Backend.Tock.Rounds.n) Vector.t =
    Vector.init Backend.Tock.Rounds.n ~f:(fun j -> inputs.(!pos + j))
  in
  pos := !pos + Nat.to_int Backend.Tock.Rounds.n ;
  let old_bp_chals : (Old_bulletproof_chals.t, Nat.N2.n) Vector.t =
    Vector.[
      Old_bulletproof_chals.T (Nat.N1.n, Vector.[ old_bp_chals_slot0 ]) ;
      Old_bulletproof_chals.T (Nat.N0.n, Vector.[])
    ]
  in
  (* ---- 10. evals ---- *)
  let evals_typ =
    let ty = Plonk_types.All_evals.wrap_typ ~num_chunks Plonk_types.Features.Full.none in
    Vector.wrap_typ ty Nat.N2.n
  in
  let evals = with_label "alloc_evals" (fun () -> alloc_typ evals_typ) in
  (* ---- 11. wrap_domain_indices ---- *)
  let wrap_domain_indices = with_label "alloc_wrap_domain_indices" (fun () ->
    alloc_typ (Vector.wrap_typ Field.typ Nat.N2.n))
  in
  (* ---- 12. FOP loop ---- *)
  let sponge_params =
    Sponge.Params.map Tock_field_sponge.params ~f:Field.constant
  in
  let new_bulletproof_challenges =
    let wrap_domains =
      let all_possible_domains =
        Wrap_verifier.all_possible_domains ()
      in
      let shifts ~log2_size = Common.tock_shifts ~log2_size in
      let domain_generator ~log2_size =
        Backend.Tock.Field.domain_generator ~log2_size |> Field.constant
      in
      with_label "compute_wrap_domains" (fun () ->
        Vector.map wrap_domain_indices ~f:(fun index ->
          with_label "one_hot_wrap_domain" (fun () ->
            let which = Wrap_verifier.One_hot_vector.of_index index
              ~length:Wrap_verifier.num_possible_domains in
            Wrap_verifier.Pseudo.Domain.to_domain
              ~shifts ~domain_generator
              (which, all_possible_domains))))
    in
    with_label "fop_loop" (fun () ->
      Vector.mapn
        [ prev_proof_state.unfinalized_proofs
        ; old_bp_chals
        ; evals
        ; wrap_domains
        ]
        ~f:(fun [ { deferred_values; sponge_digest_before_evaluations = sponge_digest
                   ; should_finalize }
                ; old_bulletproof_challenges
                ; evals_i
                ; wrap_domain
                ] ->
          with_label "fop_proof" (fun () ->
            let sponge =
              let s = Wrap_main_inputs.Sponge.create sponge_params in
              Wrap_main_inputs.Sponge.absorb s sponge_digest ; s
            in
            let (T (_max_local, old_bulletproof_challenges)) =
              old_bulletproof_challenges
            in
            let old_bulletproof_challenges =
              Wrap_hack.Checked.pad_challenges old_bulletproof_challenges
            in
            let finalized, chals =
              with_label "finalize_other_proof" (fun () ->
                Wrap_verifier.finalize_other_proof
                  (module Wrap_hack.Padded_length)
                  ~domain:(wrap_domain :> _ Plonk_checks.plonk_domain)
                  ~sponge ~old_bulletproof_challenges
                  deferred_values evals_i)
            in
            with_label "fop_assert" (fun () ->
              Boolean.(Assert.any [ finalized; not should_finalize ])) ;
            chals)))
  in
  (* ---- 13. Build prev_statement + assert messages_for_next_step_proof ---- *)
  let prev_statement =
    let prev_messages_for_next_wrap_proof = with_label "hash_messages_for_next_wrap_proof" (fun () ->
      Vector.map2 prev_step_accs old_bp_chals
        ~f:(fun sacc (T (max_local_max_proofs_verified, chals)) ->
          with_label "hash_msg_per_proof" (fun () ->
            Wrap_hack.Checked.hash_messages_for_next_wrap_proof
              max_local_max_proofs_verified
              { challenge_polynomial_commitment = sacc
              ; old_bulletproof_challenges = chals
              })))
    in
    with_label "assert_messages_for_next_step_proof" (fun () ->
      Field.Assert.equal messages_for_next_step_proof
        prev_proof_state.messages_for_next_step_proof) ;
    { Import.Types.Step.Statement.
      messages_for_next_wrap_proof = prev_messages_for_next_wrap_proof
    ; proof_state = prev_proof_state
    }
  in
  (* ---- 14. openings_proof ---- *)
  let openings_proof_typ =
    let shift = Common.Shifts.tick1 in
    Plonk_types.Openings.Bulletproof.wrap_typ
      ( Impls.Wrap.Typ.transport Wrap_verifier.Other_field.Packed.typ
          ~there:(fun x ->
            match Shifted_value.Type1.of_field (module Backend.Tick.Field) ~shift x with
            | Shifted_value x -> x)
          ~back:(fun x ->
            Shifted_value.Type1.to_field (module Backend.Tick.Field) ~shift (Shifted_value x))
        |> Impls.Wrap.Typ.transport_var
             ~there:(fun (Shifted_value.Type1.Shifted_value x) -> x)
             ~back:(fun x -> Shifted_value x) )
      Inner_curve.typ
      ~length:(Nat.to_int Backend.Tick.Rounds.n)
  in
  let openings_proof = with_label "alloc_openings_proof" (fun () ->
    alloc_typ openings_proof_typ) in
  (* ---- 15. messages ---- *)
  let messages_typ =
    Plonk_types.Messages.wrap_typ Inner_curve.typ
      feature_flags
      ~dummy:Inner_curve.Params.one
      ~commitment_lengths:(Commitment_lengths.default ~num_chunks)
  in
  let messages = with_label "alloc_messages" (fun () -> alloc_typ messages_typ) in
  (* ---- 16. pack_statement + wrap_verify ---- *)
  let public_input = with_label "pack_statement_split_field" (fun () ->
    Array.map
      (Wrap_main.pack_statement Nat.N2.n prev_statement)
      ~f:(function
        | `Field (Shifted_value x) -> `Field (Wrap_main.split_field x)
        | `Packed_bits (x, n) -> `Packed_bits (x, n)))
  in
  let srs = Kimchi_bindings.Protocol.SRS.Fp.create (1 lsl 16) in
  with_label "wrap_verify" (fun () ->
  Wrap_main.wrap_verify
    ~num_chunks
    ~max_proofs_verified:(module Nat.N2)
    ~max_proofs_verified_n:Nat.N2.n
    ~feature_flags
    ~sponge_params
    ~actual_proofs_verified_mask
    ~step_domains
    ~step_plonk_index
    ~srs
    ~xi
    ~plonk
    ~combined_inner_product
    ~b
    ~public_input
    ~prev_step_accs
    ~messages
    ~openings_proof
    ~which_branch
    ~new_bulletproof_challenges
    ~sponge_digest_before_evaluations
    ~messages_for_next_wrap_proof_digest
    ~bulletproof_challenges)

(* ====================================================================
   Pseudo module sub-circuits: one_hot_vector, mask, choose, choose_key.
   Both Step (Fp/Vesta) and Wrap (Fq/Pallas) variants.
   ==================================================================== *)

(* one_hot_vector: of_index with length=1 (single branch) *)
let one_hot_n1_step_circuit (inputs : Impl.Field.t array) () =
  let open Impl in
  let open Pickles_types in
  let _v = with_label "one_hot_n1" (fun () ->
    One_hot_vector.Step.of_index inputs.(0) ~length:Nat.N1.n) in
  ()

let one_hot_n1_wrap_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let _v = with_label "one_hot_n1" (fun () ->
    One_hot_vector.Wrap.of_index inputs.(0) ~length:Nat.N1.n) in
  ()

(* one_hot_vector: of_index with length=3 (wrap_domain selection) *)
let one_hot_n3_step_circuit (inputs : Impl.Field.t array) () =
  let open Impl in
  let open Pickles_types in
  let _v = with_label "one_hot_n3" (fun () ->
    One_hot_vector.Step.of_index inputs.(0) ~length:Nat.N3.n) in
  ()

let one_hot_n3_wrap_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let _v = with_label "one_hot_n3" (fun () ->
    One_hot_vector.Wrap.of_index inputs.(0) ~length:Nat.N3.n) in
  ()

(* pseudo_mask: mask with length=1 *)
let pseudo_mask_n1_step_circuit (inputs : Impl.Field.t array) () =
  let open Impl in
  let open Pickles_types in
  let bits = One_hot_vector.Step.of_index inputs.(0) ~length:Nat.N1.n in
  let _result = with_label "pseudo_mask_n1" (fun () ->
    Pseudo.Step.mask bits (Vector.map (Vector.[ inputs.(1) ]) ~f:Fn.id)) in
  ()

let pseudo_mask_n1_wrap_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let bits = One_hot_vector.Wrap.of_index inputs.(0) ~length:Nat.N1.n in
  let _result = with_label "pseudo_mask_n1" (fun () ->
    Pseudo.Wrap.mask bits (Vector.map (Vector.[ inputs.(1) ]) ~f:Fn.id)) in
  ()

(* pseudo_mask: mask with length=3 *)
let pseudo_mask_n3_step_circuit (inputs : Impl.Field.t array) () =
  let open Impl in
  let open Pickles_types in
  let bits = One_hot_vector.Step.of_index inputs.(0) ~length:Nat.N3.n in
  let _result = with_label "pseudo_mask_n3" (fun () ->
    Pseudo.Step.mask bits Vector.[ inputs.(1); inputs.(2); inputs.(3) ]) in
  ()

let pseudo_mask_n3_wrap_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let bits = One_hot_vector.Wrap.of_index inputs.(0) ~length:Nat.N3.n in
  let _result = with_label "pseudo_mask_n3" (fun () ->
    Pseudo.Wrap.mask bits Vector.[ inputs.(1); inputs.(2); inputs.(3) ]) in
  ()

(* pseudo_choose: choose with length=1, mapping ints to field constants *)
let pseudo_choose_n1_step_circuit (inputs : Impl.Field.t array) () =
  let open Impl in
  let open Pickles_types in
  let bits = One_hot_vector.Step.of_index inputs.(0) ~length:Nat.N1.n in
  let _result = with_label "pseudo_choose_n1" (fun () ->
    Pseudo.Step.choose (bits, Vector.[ 42 ]) ~f:Field.of_int) in
  ()

let pseudo_choose_n1_wrap_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let bits = One_hot_vector.Wrap.of_index inputs.(0) ~length:Nat.N1.n in
  let _result = with_label "pseudo_choose_n1" (fun () ->
    Pseudo.Wrap.choose (bits, Vector.[ 42 ]) ~f:Field.of_int) in
  ()

(* pseudo_choose: choose with length=3, mapping ints to field constants *)
let pseudo_choose_n3_step_circuit (inputs : Impl.Field.t array) () =
  let open Impl in
  let open Pickles_types in
  let bits = One_hot_vector.Step.of_index inputs.(0) ~length:Nat.N3.n in
  let _result = with_label "pseudo_choose_n3" (fun () ->
    Pseudo.Step.choose (bits, Vector.[ 13; 14; 15 ]) ~f:Field.of_int) in
  ()

let pseudo_choose_n3_wrap_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let bits = One_hot_vector.Wrap.of_index inputs.(0) ~length:Nat.N3.n in
  let _result = with_label "pseudo_choose_n3" (fun () ->
    Pseudo.Wrap.choose (bits, Vector.[ 13; 14; 15 ]) ~f:Field.of_int) in
  ()

(* choose_key: single branch (N1) with dummy VK, matching wrap_main dump *)
let choose_key_n1_wrap_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let module Inner_curve = Wrap_main_inputs.Inner_curve in
  let which_branch = with_label "one_hot" (fun () ->
    Wrap_verifier.One_hot_vector.of_index inputs.(0) ~length:Nat.N1.n) in
  let dummy_pt = Inner_curve.Params.one in
  let dummy_comm = [| Inner_curve.constant dummy_pt |] in
  let key =
    { Plonk_verification_key_evals.Step.
      sigma_comm = Vector.init Nat.N7.n ~f:(fun _ -> dummy_comm)
    ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun _ -> dummy_comm)
    ; generic_comm = dummy_comm
    ; psm_comm = dummy_comm
    ; complete_add_comm = dummy_comm
    ; mul_comm = dummy_comm
    ; emul_comm = dummy_comm
    ; endomul_scalar_comm = dummy_comm
    ; xor_comm = Opt.Nothing
    ; range_check0_comm = Opt.Nothing
    ; range_check1_comm = Opt.Nothing
    ; foreign_field_add_comm = Opt.Nothing
    ; foreign_field_mul_comm = Opt.Nothing
    ; rot_comm = Opt.Nothing
    ; lookup_table_comm =
        Vector.init Plonk_types.Lookup_sorted_minus_1.n ~f:(fun _ -> Opt.Nothing)
    ; lookup_table_ids = Opt.Nothing
    ; runtime_tables_selector = Opt.Nothing
    ; lookup_selector_lookup = Opt.Nothing
    ; lookup_selector_xor = Opt.Nothing
    ; lookup_selector_range_check = Opt.Nothing
    ; lookup_selector_ffmul = Opt.Nothing
    }
  in
  let _index = with_label "choose_key" (fun () ->
    Wrap_verifier.choose_key which_branch Vector.[ key ]) in
  ()

(* Step IVP circuit: verifies a Wrap proof via IPA (Step/Tick/Fp side).

   The Step IVP runs on the Fp field and verifies Pallas commitments.
   Compared to the Wrap IVP (ivp_wrap_circuit above), key differences:
   - Field: Tick/Fp (not Tock/Fq)
   - Inner curve: Pallas (not Vesta)
   - SRS: Fq/Pallas SRS, domain 2^15 (not Fp/Vesta SRS, domain 2^16)
   - Shifted values: Type2 with Other_field.t = (Field.t, Boolean.var)
   - IPA rounds: 15 (not 16)
   - Takes sponge_after_index parameter (pre-absorbed verification key)
   - Proof bundled as Wrap_proof.Checked.t (not separate messages/openings)
   - Public input: Wrap statement (Type1 Fields, not Type2 SplitFields)

   Input layout (175 fields):
     Public input (Wrap statement packed for x_hat MSM):
       0-4:     Field × 5 (Type1 shifted): cip, b, ztSrs, ztDs, perm
       5-6:     Packed_bits 128 × 2 (challenges): beta, gamma
       7-9:     Packed_bits 128 × 3 (scalar challenges): alpha, zeta, xi
       10-12:   Packed_bits 255 × 3 (digests): sponge, msg_wrap, msg_step
       13-28:   Packed_bits 128 × 16 (bp challenges, Backend.Tick.Rounds.n)
       29:      Packed_bits 10 × 1 (branch_data)
     Private input:
       30:      plonk.alpha (scalar_challenge)
       31:      plonk.beta
       32:      plonk.gamma
       33:      plonk.zeta (scalar_challenge)
       34-35:   plonk.perm (Other_field = field + bool)
       36-37:   plonk.zeta_to_srs_length
       38-39:   plonk.zeta_to_domain_size
       40-41:   advice.combined_inner_product
       42-43:   advice.b
       44:      xi (scalar_challenge)
       45-59:   claimed_bp_challenges (15 = Tock.Rounds.n)
       60-89:   w_comm (15 × 2)
       90-91:   z_comm (1 × 2)
       92-105:  t_comm (7 × 2)
       106-107: delta (2)
       108-109: challenge_polynomial_commitment (2)
       110-169: lr (15 × 4)
       170-171: z_1 (Other_field, Type2 shifted)
       172-173: z_2 (Other_field, Type2 shifted)
       174:     claimed_digest
*)
let ivp_step_circuit (inputs : Impls.Step.Field.t array) () =
  let open Impls.Step in
  let open Pickles_types in
  let read_pt i : Step_main_inputs.Inner_curve.t =
    (inputs.(i), inputs.(i + 1))
  in
  let read_other_field i : Impls.Step.Other_field.t =
    (inputs.(i), Boolean.Unsafe.of_cvar inputs.(i + 1))
  in
  (* ---- Public input (Wrap statement packed for x_hat MSM) ---- *)
  let public_input =
    let packed n i = `Packed_bits (inputs.(i), n) in
    Array.concat
      [ Array.init 5 ~f:(fun j -> `Field inputs.(j))
      ; [| packed 128 5 ; packed 128 6 |]
      ; [| packed 128 7 ; packed 128 8 ; packed 128 9 |]
      ; [| packed 255 10 ; packed 255 11 ; packed 255 12 |]
      ; Array.init 16 ~f:(fun j -> packed 128 (13 + j))
      ; [| packed 10 29 |]
      ]
  in
  (* ---- Plonk deferred values (Type2 shifted, cross-field) ---- *)
  let feature_flags =
    Kimchi_backend_common.Plonk_types.Features.map
      Kimchi_backend_common.Plonk_types.Features.none_bool
      ~f:(fun _ -> Boolean.false_)
  in
  let plonk
    : ( Field.t
      , Field.t Kimchi_backend_common.Scalar_challenge.t
      , Impls.Step.Other_field.t Shifted_value.Type2.t
      , (Impls.Step.Other_field.t Shifted_value.Type2.t, Boolean.var) Opt.t
      , (Field.t Kimchi_backend_common.Scalar_challenge.t, Boolean.var) Opt.t
      , Boolean.var )
      Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t =
    { alpha = { Kimchi_types.inner = inputs.(30) }
    ; beta = inputs.(31)
    ; gamma = inputs.(32)
    ; zeta = { Kimchi_types.inner = inputs.(33) }
    ; perm = Shifted_value.Type2.Shifted_value (read_other_field 34)
    ; zeta_to_srs_length = Shifted_value.Type2.Shifted_value (read_other_field 36)
    ; zeta_to_domain_size = Shifted_value.Type2.Shifted_value (read_other_field 38)
    ; feature_flags
    ; joint_combiner = Opt.Nothing
    }
  in
  let advice =
    { Composition_types.Step.Bulletproof.Advice.
      combined_inner_product = Shifted_value.Type2.Shifted_value (read_other_field 40)
    ; b = Shifted_value.Type2.Shifted_value (read_other_field 42)
    }
  in
  let xi : Field.t Kimchi_backend_common.Scalar_challenge.t =
    { Kimchi_types.inner = inputs.(44) }
  in
  let claimed_bp_challenges =
    Array.init 15 ~f:(fun j -> inputs.(45 + j))
  in
  (* ---- Messages ---- *)
  let messages =
    { Kimchi_backend_common.Plonk_types.Messages.In_circuit.
      w_comm = Vector.init Nat.N15.n ~f:(fun j -> [| read_pt (60 + 2 * j) |])
    ; z_comm = [| read_pt 90 |]
    ; t_comm = Array.init 7 ~f:(fun j -> read_pt (92 + 2 * j))
    ; lookup = Opt.Nothing
    }
  in
  (* ---- Opening proof ---- *)
  let opening =
    { Kimchi_backend_common.Plonk_types.Openings.Bulletproof.
      lr = Array.init 15 ~f:(fun j ->
        (read_pt (110 + 4 * j), read_pt (110 + 4 * j + 2)))
    ; z_1 = Shifted_value.Type2.Shifted_value (read_other_field 170)
    ; z_2 = Shifted_value.Type2.Shifted_value (read_other_field 172)
    ; delta = read_pt 106
    ; challenge_polynomial_commitment = read_pt 108
    }
  in
  let proof : Wrap_proof.Checked.t = { messages ; opening } in
  let claimed_digest = inputs.(174) in
  (* ---- SRS (Pallas SRS, domain 2^15 for Wrap proofs) ---- *)
  let srs = Kimchi_bindings.Protocol.SRS.Fq.create (1 lsl 15) in
  (* ---- Verification key (dummy, all commitments = Pallas generator) ---- *)
  let dummy_pt = Step_main_inputs.Inner_curve.Params.one in
  let dummy_comm = [| Step_main_inputs.Inner_curve.constant dummy_pt |] in
  let verification_key =
    { Plonk_verification_key_evals.
      sigma_comm = Vector.init Nat.N7.n ~f:(fun _ -> dummy_comm)
    ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun _ -> dummy_comm)
    ; generic_comm = dummy_comm
    ; psm_comm = dummy_comm
    ; complete_add_comm = dummy_comm
    ; mul_comm = dummy_comm
    ; emul_comm = dummy_comm
    ; endomul_scalar_comm = dummy_comm
    }
  in
  (* ---- Sponge ---- *)
  let sponge = Step_main_inputs.Sponge.create Step_main_inputs.sponge_params in
  (* ---- Sponge after index (absorb verification key) ---- *)
  let sponge_after_index =
    Step_verifier.For_tests_only.sponge_after_index verification_key
  in
  (* ---- Call Step IVP ---- *)
  let digest, (`Success _success, bp_challenges) =
    Step_verifier.For_tests_only.incrementally_verify_proof
      (module Nat.N0)
      ~srs
      ~domain:(`Known (Pickles_base.Domain.Pow_2_roots_of_unity 15))
      ~srs
      ~verification_key
      ~xi
      ~sponge
      ~sponge_after_index
      ~public_input
      ~sg_old:Vector.[]
      ~advice
      ~proof
      ~plonk
  in
  (* ---- Assert digest matches ---- *)
  Field.Assert.equal digest claimed_digest ;
  (* ---- Assert bulletproof challenges match ---- *)
  Array.iteri bp_challenges
    ~f:(fun i { Import.Bulletproof_challenge.prechallenge =
                  { Kimchi_types.inner = c } } ->
      Field.Assert.equal c claimed_bp_challenges.(i) ) ;
  ()

(* Step_verifier.verify circuit calling the production function directly.

   Uses Per_proof_witness.typ to allocate the statement proof_state and
   wrap proof (matching production step_main.ml:verify_one), and
   Unfinalized.typ for the unfinalized proof. Then calls Step_verifier.verify
   with the exact same arguments as production code.

   Input layout: flat field array containing:
   - Per_proof_witness fields (via Per_proof_witness.typ with app_state=unit, N0)
     Contains: wrap_proof, proof_state (Type1, Tick.Rounds bp challenges),
     prev_proof_evals, empty prev_challenges/commitments for N0
   - Unfinalized proof fields (via Unfinalized.typ)
   - is_base_case boolean (1 field)
   - messages_for_next_wrap_proof digest (1 field)
   - messages_for_next_step_proof digest (1 field)

   Reference: step_verifier.ml:1242-1315, step_main.ml:17-117
*)
let step_verify_circuit (inputs : Impls.Step.Field.t array) () =
  let open Impls.Step in
  let open Pickles_types in
  let feature_flags =
    Kimchi_backend_common.Plonk_types.Features.Full.none
  in
  (* ---- Allocate Per_proof_witness via its Typ ---- *)
  let ppw_typ =
    Per_proof_witness.typ Typ.unit Nat.N0.n ~feature_flags ~num_chunks:1
  in
  let (Typ ppw_typ_record) = ppw_typ in
  let ppw_size = ppw_typ_record.size_in_field_elements in
  let ppw_fields = Array.sub inputs ~pos:0 ~len:ppw_size in
  let ppw =
    ppw_typ_record.var_of_fields
      (ppw_fields, ppw_typ_record.constraint_system_auxiliary ())
  in
  let pos = ref ppw_size in
  (* ---- Allocate Unfinalized via its Typ ---- *)
  let unfinalized_typ =
    Unfinalized.typ ~wrap_rounds:Backend.Tock.Rounds.n
  in
  let (Typ unfinalized_typ_record) = unfinalized_typ in
  let unfinalized_size = unfinalized_typ_record.size_in_field_elements in
  let unfinalized_fields = Array.sub inputs ~pos:!pos ~len:unfinalized_size in
  let unfinalized : Unfinalized.t =
    unfinalized_typ_record.var_of_fields
      (unfinalized_fields, unfinalized_typ_record.constraint_system_auxiliary ())
  in
  pos := !pos + unfinalized_size ;
  (* ---- Extra inputs ---- *)
  let is_base_case = Boolean.Unsafe.of_cvar inputs.(!pos) in
  pos := !pos + 1 ;
  let messages_for_next_wrap_proof = inputs.(!pos) in
  pos := !pos + 1 ;
  let messages_for_next_step_proof = inputs.(!pos) in
  pos := !pos + 1 ;
  (* ---- Build statement from Per_proof_witness (mirrors step_main.ml:77-80) ---- *)
  (* ppw.proof_state has messages_for_next_wrap_proof : unit because it's
     computed fresh by hash_messages. We update it with a real digest, exactly
     as step_main.ml does: { proof_state with messages_for_next_wrap_proof } *)
  let statement =
    { Import.Types.Wrap.Statement.
      proof_state =
        { ppw.proof_state with messages_for_next_wrap_proof }
    ; messages_for_next_step_proof
    }
  in
  (* ---- SRS and VK (dummy) ---- *)
  let srs = Kimchi_bindings.Protocol.SRS.Fq.create (1 lsl 15) in
  let dummy_pt = Step_main_inputs.Inner_curve.Params.one in
  let dummy_comm = [| Step_main_inputs.Inner_curve.constant dummy_pt |] in
  let verification_key =
    { Plonk_verification_key_evals.
      sigma_comm = Vector.init Nat.N7.n ~f:(fun _ -> dummy_comm)
    ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun _ -> dummy_comm)
    ; generic_comm = dummy_comm
    ; psm_comm = dummy_comm
    ; complete_add_comm = dummy_comm
    ; mul_comm = dummy_comm
    ; emul_comm = dummy_comm
    ; endomul_scalar_comm = dummy_comm
    }
  in
  let sponge_after_index =
    Step_verifier.For_tests_only.sponge_after_index verification_key
  in
  let _success =
    Step_verifier.verify
      ~proofs_verified:(module Nat.N0)
      ~is_base_case
      ~sg_old:Vector.[]
      ~sponge_after_index
      ~lookup_parameters:
        { use = Opt.Flag.No
        ; zero =
            { var =
                { challenge = Field.zero
                ; scalar = Shifted_value Field.zero
                }
            ; value =
                { challenge = Limb_vector.Challenge.Constant.zero
                ; scalar =
                    Shifted_value.Type1.Shifted_value Field.Constant.zero
                }
            }
        }
      ~feature_flags:(Kimchi_backend_common.Plonk_types.Features.of_full feature_flags)
      ~proof:ppw.wrap_proof
      ~srs
      ~wrap_domain:(`Known (Pickles_base.Domain.Pow_2_roots_of_unity 15))
      ~wrap_verification_key:verification_key
      statement
      unfinalized
  in
  ()

(* Step_verifier.verify circuit with N2 (2 previous proofs).
   Same as step_verify_circuit but with Per_proof_witness N2 and proofs_verified=N2.
   Input size: ppw(N2,unit)=269 + unfinalized=32 + 3 = 304 fields.
*)
let step_verify_n2_circuit (inputs : Impls.Step.Field.t array) () =
  let open Impls.Step in
  let open Pickles_types in
  let feature_flags =
    Kimchi_backend_common.Plonk_types.Features.Full.none
  in
  let ppw_typ =
    Per_proof_witness.typ Typ.unit Nat.N2.n ~feature_flags ~num_chunks:1
  in
  let (Typ ppw_typ_record) = ppw_typ in
  let ppw_size = ppw_typ_record.size_in_field_elements in
  let ppw_fields = Array.sub inputs ~pos:0 ~len:ppw_size in
  let ppw =
    ppw_typ_record.var_of_fields
      (ppw_fields, ppw_typ_record.constraint_system_auxiliary ())
  in
  let pos = ref ppw_size in
  let unfinalized_typ =
    Unfinalized.typ ~wrap_rounds:Backend.Tock.Rounds.n
  in
  let (Typ unfinalized_typ_record) = unfinalized_typ in
  let unfinalized_size = unfinalized_typ_record.size_in_field_elements in
  let unfinalized_fields = Array.sub inputs ~pos:!pos ~len:unfinalized_size in
  let unfinalized : Unfinalized.t =
    unfinalized_typ_record.var_of_fields
      (unfinalized_fields, unfinalized_typ_record.constraint_system_auxiliary ())
  in
  pos := !pos + unfinalized_size ;
  let is_base_case = Boolean.Unsafe.of_cvar inputs.(!pos) in
  pos := !pos + 1 ;
  let messages_for_next_wrap_proof = inputs.(!pos) in
  pos := !pos + 1 ;
  let messages_for_next_step_proof = inputs.(!pos) in
  pos := !pos + 1 ;
  let statement =
    { Import.Types.Wrap.Statement.
      proof_state =
        { ppw.proof_state with messages_for_next_wrap_proof }
    ; messages_for_next_step_proof
    }
  in
  let srs = Kimchi_bindings.Protocol.SRS.Fq.create (1 lsl 15) in
  let dummy_pt = Step_main_inputs.Inner_curve.Params.one in
  let dummy_comm = [| Step_main_inputs.Inner_curve.constant dummy_pt |] in
  let verification_key =
    { Plonk_verification_key_evals.
      sigma_comm = Vector.init Nat.N7.n ~f:(fun _ -> dummy_comm)
    ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun _ -> dummy_comm)
    ; generic_comm = dummy_comm
    ; psm_comm = dummy_comm
    ; complete_add_comm = dummy_comm
    ; mul_comm = dummy_comm
    ; emul_comm = dummy_comm
    ; endomul_scalar_comm = dummy_comm
    }
  in
  let sponge_after_index =
    Step_verifier.For_tests_only.sponge_after_index verification_key
  in
  let _success =
    Step_verifier.verify
      ~proofs_verified:(module Nat.N2)
      ~is_base_case
      ~sg_old:ppw.prev_challenge_polynomial_commitments
      ~sponge_after_index
      ~lookup_parameters:
        { use = Opt.Flag.No
        ; zero =
            { var =
                { challenge = Field.zero
                ; scalar = Shifted_value Field.zero
                }
            ; value =
                { challenge = Limb_vector.Challenge.Constant.zero
                ; scalar =
                    Shifted_value.Type1.Shifted_value Field.Constant.zero
                }
            }
        }
      ~feature_flags:(Kimchi_backend_common.Plonk_types.Features.of_full feature_flags)
      ~proof:ppw.wrap_proof
      ~srs
      ~wrap_domain:(`Known (Pickles_base.Domain.Pow_2_roots_of_unity 15))
      ~wrap_verification_key:verification_key
      statement
      unfinalized
  in
  ()

(* Full step verify_one circuit: FOP + message hash + IVP + assertions.
   Wraps Step_main.Make(Inductive_rule.Kimchi).verify_one with flat inputs.

   Input layout:
     Per_proof_witness (via Typ, app_state=unit, max_local=N0)
     Unfinalized proof (via Typ)
     messages_for_next_wrap_proof (1 field)
     must_verify (1 field as boolean)
*)
module Step_main_for_dump = Step_main.Make(Inductive_rule.Kimchi)

let full_step_verify_one_circuit (inputs : Impls.Step.Field.t array) () =
  let open Impls.Step in
  let open Pickles_types in
  let feature_flags =
    Kimchi_backend_common.Plonk_types.Features.Full.none
  in
  (* ---- Allocate Per_proof_witness via its Typ ---- *)
  (* Simple_chain: app_state=Field.typ, max_local_max_proofs_verified=N1 *)
  let ppw_typ =
    Per_proof_witness.typ Field.typ Nat.N1.n ~feature_flags ~num_chunks:1
  in
  let (Typ ppw_typ_record) = ppw_typ in
  let ppw_size = ppw_typ_record.size_in_field_elements in
  let ppw_fields = Array.sub inputs ~pos:0 ~len:ppw_size in
  let ppw =
    ppw_typ_record.var_of_fields
      (ppw_fields, ppw_typ_record.constraint_system_auxiliary ())
  in
  let pos = ref ppw_size in
  (* ---- Allocate Unfinalized via its Typ ---- *)
  let unfinalized_typ =
    Unfinalized.typ ~wrap_rounds:Backend.Tock.Rounds.n
  in
  let (Typ unfinalized_typ_record) = unfinalized_typ in
  let unfinalized_size = unfinalized_typ_record.size_in_field_elements in
  let unfinalized_fields = Array.sub inputs ~pos:!pos ~len:unfinalized_size in
  let unfinalized : Unfinalized.t =
    unfinalized_typ_record.var_of_fields
      (unfinalized_fields, unfinalized_typ_record.constraint_system_auxiliary ())
  in
  pos := !pos + unfinalized_size ;
  (* ---- Extra inputs ---- *)
  let messages_for_next_wrap_proof = inputs.(!pos) in
  pos := !pos + 1 ;
  let must_verify = Boolean.Unsafe.of_cvar inputs.(!pos) in
  pos := !pos + 1 ;
  (* ---- Build Types_map.For_step.t (compile-time constants) ---- *)
  let srs = Kimchi_bindings.Protocol.SRS.Fq.create (1 lsl 15) in
  let dummy_pt = Step_main_inputs.Inner_curve.Params.one in
  let dummy_comm = [| Step_main_inputs.Inner_curve.constant dummy_pt |] in
  let verification_key =
    { Plonk_verification_key_evals.
      sigma_comm = Vector.init Nat.N7.n ~f:(fun _ -> dummy_comm)
    ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun _ -> dummy_comm)
    ; generic_comm = dummy_comm
    ; psm_comm = dummy_comm
    ; complete_add_comm = dummy_comm
    ; mul_comm = dummy_comm
    ; emul_comm = dummy_comm
    ; endomul_scalar_comm = dummy_comm
    }
  in
  let d : _ Types_map.For_step.t =
    { max_proofs_verified = (module Nat.N1 : Nat.Add.Intf with type n = Nat.N1.n)
    ; public_input = Field.typ
    ; wrap_domain = `Known (Pickles_base.Domain.Pow_2_roots_of_unity 14)
    ; step_domains = `Known (Vector.singleton { Import.Domains.h = Pickles_base.Domain.Pow_2_roots_of_unity 16 })
    ; wrap_key = verification_key
    ; feature_flags
    ; num_chunks = 1
    ; zk_rows = 3
    }
  in
  (* ---- Call verify_one ---- *)
  let _chals, _verified =
    Step_main_for_dump.verify_one ~srs
      ppw d messages_for_next_wrap_proof unfinalized must_verify
  in
  ()


(* Full step verify_one circuit with N2 (2 previous proofs).
   Same as full_step_verify_one_circuit but with Per_proof_witness N2.
   Input size: ppw(N2,Field)=270 + unfinalized=32 + 2 = 304 fields.
*)
let full_step_verify_one_n2_circuit (inputs : Impls.Step.Field.t array) () =
  let open Impls.Step in
  let open Pickles_types in
  let feature_flags =
    Kimchi_backend_common.Plonk_types.Features.Full.none
  in
  let ppw_typ =
    Per_proof_witness.typ Field.typ Nat.N2.n ~feature_flags ~num_chunks:1
  in
  let (Typ ppw_typ_record) = ppw_typ in
  let ppw_size = ppw_typ_record.size_in_field_elements in
  let ppw_fields = Array.sub inputs ~pos:0 ~len:ppw_size in
  let ppw =
    ppw_typ_record.var_of_fields
      (ppw_fields, ppw_typ_record.constraint_system_auxiliary ())
  in
  let pos = ref ppw_size in
  let unfinalized_typ =
    Unfinalized.typ ~wrap_rounds:Backend.Tock.Rounds.n
  in
  let (Typ unfinalized_typ_record) = unfinalized_typ in
  let unfinalized_size = unfinalized_typ_record.size_in_field_elements in
  let unfinalized_fields = Array.sub inputs ~pos:!pos ~len:unfinalized_size in
  let unfinalized : Unfinalized.t =
    unfinalized_typ_record.var_of_fields
      (unfinalized_fields, unfinalized_typ_record.constraint_system_auxiliary ())
  in
  pos := !pos + unfinalized_size ;
  let messages_for_next_wrap_proof = inputs.(!pos) in
  pos := !pos + 1 ;
  let must_verify = Boolean.Unsafe.of_cvar inputs.(!pos) in
  pos := !pos + 1 ;
  let srs = Kimchi_bindings.Protocol.SRS.Fq.create (1 lsl 15) in
  let dummy_pt = Step_main_inputs.Inner_curve.Params.one in
  let dummy_comm = [| Step_main_inputs.Inner_curve.constant dummy_pt |] in
  let verification_key =
    { Plonk_verification_key_evals.
      sigma_comm = Vector.init Nat.N7.n ~f:(fun _ -> dummy_comm)
    ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun _ -> dummy_comm)
    ; generic_comm = dummy_comm
    ; psm_comm = dummy_comm
    ; complete_add_comm = dummy_comm
    ; mul_comm = dummy_comm
    ; emul_comm = dummy_comm
    ; endomul_scalar_comm = dummy_comm
    }
  in
  let d : _ Types_map.For_step.t =
    { max_proofs_verified = (module Nat.N2 : Nat.Add.Intf with type n = Nat.N2.n)
    ; public_input = Field.typ
    ; wrap_domain = `Known (Pickles_base.Domain.Pow_2_roots_of_unity 14)
    ; step_domains = `Known (Vector.singleton { Import.Domains.h = Pickles_base.Domain.Pow_2_roots_of_unity 16 })
    ; wrap_key = verification_key
    ; feature_flags
    ; num_chunks = 1
    ; zk_rows = 3
    }
  in
  let _chals, _verified =
    Step_main_for_dump.verify_one ~srs
      ppw d messages_for_next_wrap_proof unfinalized must_verify
  in
  ()

(* hash_messages_for_next_step_proof sub-circuit.

   Hashes the Messages_for_next_step_proof struct into a single digest.
   Uses sponge_after_index (VK hash) as the sponge initial state, then
   absorbs to_field_elements_without_index (app_state + sg + bp_challenges).

   This is the non-opt version (no proofs_verified_mask). For app_state = unit,
   MaxProofsVerified = 2, WrapIPARounds = 15:

   Input layout (90 fields):
     0-55:  VK commitments (28 comms × 2 coords)
            sigma_comm (7), coefficients_comm (15),
            generic_comm, psm_comm, complete_add_comm, mul_comm, emul_comm,
            endomul_scalar_comm
     56-57: sg_old[0] (x, y)
     58-72: bp_challenges[0] (15 fields)
     73-74: sg_old[1] (x, y)
     75-89: bp_challenges[1] (15 fields)

   Output: asserts digest equals a claimed value (field at index 90).
   Total: 91 fields.
*)
let hash_messages_for_next_step_proof_circuit (inputs : Impls.Step.Field.t array) () =
  let open Impls.Step in
  let open Pickles_types in
  let read_pt i : Step_main_inputs.Inner_curve.t =
    (inputs.(i), inputs.(i + 1))
  in
  (* ---- Build VK from inputs ---- *)
  let read_comm i = [| read_pt i |] in
  let verification_key =
    { Plonk_verification_key_evals.
      sigma_comm = Vector.init Nat.N7.n ~f:(fun j -> read_comm (2 * j))
    ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun j -> read_comm (14 + 2 * j))
    ; generic_comm = read_comm 44
    ; psm_comm = read_comm 46
    ; complete_add_comm = read_comm 48
    ; mul_comm = read_comm 50
    ; emul_comm = read_comm 52
    ; endomul_scalar_comm = read_comm 54
    }
  in
  (* ---- Compute sponge_after_index ---- *)
  let sponge_after_index =
    Step_verifier.For_tests_only.sponge_after_index verification_key
  in
  (* ---- Build Messages_for_next_step_proof ---- *)
  let sg0 = read_pt 56 in
  let bp0 = Vector.init Backend.Tock.Rounds.n ~f:(fun j -> inputs.(58 + j)) in
  let sg1 = read_pt 73 in
  let bp1 = Vector.init Backend.Tock.Rounds.n ~f:(fun j -> inputs.(75 + j)) in
  (* ---- Hash ---- *)
  let sponge = Step_main_inputs.Sponge.copy sponge_after_index in
  (* to_field_elements_without_index with app_state = unit:
     just sg + bp_challenges for each proof *)
  let absorb_proof sg bp =
    List.iter (Step_main_inputs.Inner_curve.to_field_elements sg)
      ~f:(fun x -> Step_main_inputs.Sponge.absorb sponge (`Field x)) ;
    Vector.iter bp ~f:(fun x -> Step_main_inputs.Sponge.absorb sponge (`Field x))
  in
  absorb_proof sg0 bp0 ;
  absorb_proof sg1 bp1 ;
  let digest = Step_main_inputs.Sponge.squeeze_field sponge in
  (* ---- Assert digest matches claimed ---- *)
  let claimed = inputs.(90) in
  Field.Assert.equal digest claimed

(* hash_messages_for_next_wrap_proof sub-circuit.

   Computes the wrap proof message digest by hashing sg + expanded bp challenges.
   Runs in the Wrap field (Fq).

   For max_proofs_verified = 1, padded to 2:
   - 1 dummy challenge vector (15 fields, absorbed into sponge)
   - 1 real challenge vector (15 fields, absorbed into sponge)
   - sg point (x, y) (2 fields, absorbed into sponge)
   - Total absorbed: 32 fields

   Input layout (33 fields):
     0-14:  dummy bp challenges (WrapIPARounds = 15 expanded fields)
     15-29: real bp challenges (WrapIPARounds = 15 expanded fields)
     30-31: sg (x, y)
     32:    claimed_digest

   Output: asserts digest equals claimed value.
*)
let hash_messages_for_next_wrap_proof_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  (* Build Messages_for_next_wrap_proof from flat inputs.
     Input layout (33 fields):
       0-14:  expanded bp challenges vector 0 (WrapIPARounds = 15)
       15-29: expanded bp challenges vector 1 (WrapIPARounds = 15)
       30-31: sg (x, y)
       32:    claimed_digest

     Uses max_proofs_verified = 2 (matching MaxProofsVerified convention).
     Both challenge vectors are circuit variables. *)
  let chals0 = Vector.init Backend.Tock.Rounds.n ~f:(fun j -> inputs.(j)) in
  let chals1 = Vector.init Backend.Tock.Rounds.n ~f:(fun j -> inputs.(15 + j)) in
  let sg : Wrap_main_inputs.Inner_curve.t = (inputs.(30), inputs.(31)) in
  let t : ( Wrap_main_inputs.Inner_curve.t
          , ((Impls.Wrap.Field.t, Backend.Tock.Rounds.n) Vector.t, Nat.N2.n) Vector.t )
          Composition_types.Wrap.Proof_state.Messages_for_next_wrap_proof.t =
    { challenge_polynomial_commitment = sg
    ; old_bulletproof_challenges = Vector.[ chals0; chals1 ]
    }
  in
  let digest =
    Wrap_hack.Checked.hash_messages_for_next_wrap_proof Nat.N2.n t
  in
  Field.Assert.equal digest inputs.(32)

(* x_hat sub-circuit: public input commitment (MSM) from IVP wrap.

   Input layout (34 fields):
     0-9:   PerProofTuple via split (5 × 2: sDiv2, sOdd)
     10:    packed 255 (digest)
     11-12: packed 128 (sg)
     13-15: packed 128 (old bp challenges × 3)
     16-30: packed 128 (w_comm challenges × 15)
     31:    packed 1 (proofs_verified)
     32-33: packed 255 (app_state × 2)

   Runs on Tock/Wrap side (Fq field, Vesta inner curve).
   Uses SRS Lagrange basis for domain 2^16 with 45 entries (after tag expansion).
*)
let xhat_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let module Inner_curve = Wrap_main_inputs.Inner_curve in
  let module Ops = Plonk_curve_ops.Make (Impls.Wrap) (Inner_curve) in
  (* SRS setup — set_urs_info called externally before circuit generation *)
  let srs = Kimchi_bindings.Protocol.SRS.Fp.create (1 lsl 16) in
  (* Single branch, domain 2^16 — lagrange helpers below are inlined for this case *)
  (* Build tagged public_input — same as IVP wrap *)
  let public_input =
    let split i =
      `Field (inputs.(i), Boolean.Unsafe.of_cvar inputs.(i + 1))
    in
    let packed n i = `Packed_bits (inputs.(i), n) in
    Array.concat
      [ Array.init 5 ~f:(fun j -> split (2 * j))
      ; [| packed 255 10
         ; packed 128 11 ; packed 128 12
         ; packed 128 13 ; packed 128 14 ; packed 128 15 |]
      ; Array.init 15 ~f:(fun j -> packed 128 (16 + j))
      ; [| packed 1 31 ; packed 255 32 ; packed 255 33 |]
      ]
  in
  (* Expand tags: Field(x,b) -> [Field(x,255); Field(b,1)], Packed(x,n) -> [Field(x,n)] *)
  let public_input =
    Array.concat_map public_input ~f:(function
      | `Field (x, b) ->
          [| `Field (x, Field.size_in_bits)
           ; `Field ((b :> Field.t), 1)
          |]
      | `Packed_bits (x, n) ->
          [| `Field (x, n) |] )
  in
  (* Helper: get SRS lagrange commitment at index i for domain 2^16 *)
  let lagrange_pt i =
    let d = Int.pow 2 16 in
    let chunks =
      (Kimchi_bindings.Protocol.SRS.Fp.lagrange_commitment srs d i).unshifted
    in
    Array.map chunks ~f:(function
      | Finite g ->
          Inner_curve.constant (Inner_curve.Constant.of_affine g)
      | Infinity ->
          assert false )
  in
  (* For single-branch, the domain-masking reduces to identity.
     lagrange ~domain srs i = lagrange_pt i
     scaled_lagrange ~domain c srs i = scale each point by c *)
  let scaled_lagrange_pt c i =
    let d = Int.pow 2 16 in
    let chunks =
      (Kimchi_bindings.Protocol.SRS.Fp.lagrange_commitment srs d i).unshifted
    in
    Array.map chunks ~f:(function
      | Finite g ->
          Inner_curve.Constant.scale (Inner_curve.Constant.of_affine g) c
          |> Inner_curve.constant
      | Infinity ->
          assert false )
  in
  let lagrange_with_correction_pt ~input_length i =
    let actual_shift =
      Ops.bits_per_chunk * Ops.chunks_needed ~num_bits:input_length
    in
    let rec field2pow f k =
      if k = 1 then f
      else
        let j = k - 1 in
        Inner_curve.Constant.Scalar.(f * field2pow f j)
    in
    let two_to_actual_shift =
      field2pow (Inner_curve.Constant.Scalar.of_int 2) actual_shift
    in
    let d = Int.pow 2 16 in
    let chunks =
      (Kimchi_bindings.Protocol.SRS.Fp.lagrange_commitment srs d i).unshifted
    in
    Array.map chunks ~f:(function
      | Finite g ->
          let open Inner_curve.Constant in
          let g = of_affine g in
          ( Inner_curve.constant g
          , Inner_curve.constant (negate (scale g two_to_actual_shift)) )
      | Infinity ->
          assert false )
  in
  (* Partition into constant_part and non_constant_part *)
  let constant_part, non_constant_part =
    List.partition_map
      Array.(to_list (mapi public_input ~f:(fun i t -> (i, t))))
      ~f:(fun (i, t) ->
        match[@warning "-4"] t with
        | `Field (Constant c, _) ->
            First
              ( if Field.Constant.(equal zero) c then None
              else if Field.Constant.(equal one) c then
                Some (lagrange_pt i)
              else
                Some
                  (scaled_lagrange_pt
                     (Inner_curve.Constant.Scalar.project
                        (Field.Constant.unpack c) )
                     i ) )
        | `Field x ->
            Second (i, x) )
  in
  (* Build terms *)
  let terms =
    List.map non_constant_part ~f:(fun (i, x) ->
        match x with
        | b, 1 ->
            assert_ (Constraint.boolean (b :> Field.t)) ;
            `Cond_add
              (Boolean.Unsafe.of_cvar b, lagrange_pt i)
        | x, n ->
            `Add_with_correction
              ( (x, n)
              , lagrange_with_correction_pt ~input_length:n i ) )
  in
  (* Compute correction = sum of correction points from Add_with_correction terms *)
  let correction =
    with_label __LOC__ (fun () ->
        List.reduce_exn
          (List.filter_map terms ~f:(function
            | `Cond_add _ ->
                None
            | `Add_with_correction (_, chunks) ->
                Some (Array.map ~f:snd chunks) ) )
          ~f:(Array.map2_exn ~f:(Ops.add_fast ?check_finite:None)) )
  in
  (* Module matching Wrap_verifier.Other_field.With_top_bit0 *)
  let module With_top_bit0 = struct
    module Constant = Wrap_main_inputs.Other_field
    type t = Impls.Wrap.Other_field.t
    let typ = Impls.Wrap.Other_field.typ_unchecked
  end in
  (* Fold: init = correction + constant_parts, then fold non-constant terms *)
  let x_hat =
    with_label __LOC__ (fun () ->
        let init =
          List.fold
            (List.filter_map ~f:Fn.id constant_part)
            ~init:correction
            ~f:(Array.map2_exn ~f:(Ops.add_fast ?check_finite:None))
        in
        List.fold terms ~init ~f:(fun acc term ->
            match term with
            | `Cond_add (b, g) ->
                with_label __LOC__ (fun () ->
                    Array.map2_exn acc g ~f:(fun acc g ->
                        Inner_curve.if_ b
                          ~then_:(Ops.add_fast g acc)
                          ~else_:acc ) )
            | `Add_with_correction ((x, num_bits), chunks) ->
                Array.map2_exn acc chunks ~f:(fun acc (g, _) ->
                    Ops.add_fast acc
                      (Ops.scale_fast2'
                         (module With_top_bit0)
                         g x ~num_bits ) ) ) )
    |> Array.map ~f:Inner_curve.negate
  in
  (* Add blinding generator H *)
  let _x_hat =
    with_label "x_hat blinding" (fun () ->
        Array.map x_hat ~f:(fun x_hat ->
            Ops.add_fast x_hat
              (Inner_curve.constant (Lazy.force Wrap_main_inputs.Generators.h)) ) )
  in
  ()

(* bullet_reduce sub-circuit: 16 rounds of endo_inv + endo + add_fast, then reduce.

   Input layout (80 fields):
     0-63:  lr[0..15] (16 × 4 fields: l.x, l.y, r.x, r.y)
     64-79: scalar_challenges[0..15]

   Runs on Tock/Wrap side (Fq field, Vesta inner curve).
*)
module WrapOps = Plonk_curve_ops.Make (Impls.Wrap) (Wrap_main_inputs.Inner_curve)

(* ft_comm sub-circuit: linearization polynomial commitment from IVP wrap.

   Input layout (17 fields):
     0-13: t_comm (7 points × 2 coords)
     14:   perm (Type1 shifted scalar)
     15:   zeta_to_srs_length (Type1 shifted scalar)
     16:   zeta_to_domain_size (Type1 shifted scalar)

   sigma_comm_last is a constant (Vesta generator, matching IVP's dummy_comm).
   Runs on Tock/Wrap side (Fq field, Vesta inner curve).
*)
let ftcomm_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let module Inner_curve = Wrap_main_inputs.Inner_curve in
  let read_pt i : Inner_curve.t = (inputs.(i), inputs.(i + 1)) in
  let t_comm = Array.init 7 ~f:(fun j -> read_pt (2 * j)) in
  let plonk =
    { Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.
      (* Only perm, zeta_to_srs_length, zeta_to_domain_size matter for ft_comm *)
      alpha = { Kimchi_types.inner = Field.zero }  (* unused *)
    ; beta = Field.zero  (* unused *)
    ; gamma = Field.zero  (* unused *)
    ; zeta = { Kimchi_types.inner = Field.zero }  (* unused *)
    ; perm = Shifted_value.Type1.Shifted_value inputs.(14)
    ; zeta_to_srs_length = Shifted_value.Type1.Shifted_value inputs.(15)
    ; zeta_to_domain_size = Shifted_value.Type1.Shifted_value inputs.(16)
    ; feature_flags =
        Kimchi_backend_common.Plonk_types.Features.map
          Kimchi_backend_common.Plonk_types.Features.none_bool
          ~f:(fun _ -> Boolean.false_)
    ; joint_combiner = Opt.Nothing
    }
  in
  let scale_fast = WrapOps.scale_fast
      ~num_bits:Wrap_main_inputs.Inner_curve.Constant.Scalar.size_in_bits
  in
  (* sigma_comm_last = constant Vesta generator (matching IVP's dummy_comm) *)
  let dummy_pt = Wrap_main_inputs.Inner_curve.Params.one in
  let sigma_comm_last = Inner_curve.constant dummy_pt in
  (* Dummy verification key with the right shape *)
  let dummy_comm = [| sigma_comm_last |] in
  let verification_key =
    { Plonk_verification_key_evals.Step.
      sigma_comm = Vector.init Nat.N7.n ~f:(fun _ -> dummy_comm)
    ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun _ -> dummy_comm)
    ; generic_comm = dummy_comm
    ; psm_comm = dummy_comm
    ; complete_add_comm = dummy_comm
    ; mul_comm = dummy_comm
    ; emul_comm = dummy_comm
    ; endomul_scalar_comm = dummy_comm
    ; xor_comm = Opt.Nothing
    ; range_check0_comm = Opt.Nothing
    ; range_check1_comm = Opt.Nothing
    ; foreign_field_add_comm = Opt.Nothing
    ; foreign_field_mul_comm = Opt.Nothing
    ; rot_comm = Opt.Nothing
    ; lookup_table_comm =
        Vector.init Plonk_types.Lookup_sorted_minus_1.n ~f:(fun _ -> Opt.Nothing)
    ; lookup_table_ids = Opt.Nothing
    ; runtime_tables_selector = Opt.Nothing
    ; lookup_selector_lookup = Opt.Nothing
    ; lookup_selector_xor = Opt.Nothing
    ; lookup_selector_range_check = Opt.Nothing
    ; lookup_selector_ffmul = Opt.Nothing
    }
  in
  let _ft_comm =
    Common.ft_comm
      ~add:(WrapOps.add_fast ?check_finite:None)
      ~scale:scale_fast ~negate:Inner_curve.negate
      ~verification_key:
        (Plonk_verification_key_evals.Step.forget_optional_commitments
           verification_key )
      ~plonk ~t_comm
  in
  ()

(* combine_poly sub-circuit: Split_commitments.combine from IVP wrap bulletproof.

   Input layout (37 fields):
     0-1:   x_hat (1 point)
     2-3:   ft_comm (1 point)
     4-5:   z_comm (1 point)
     6-35:  w_comm[0..14] (15 points)
     36:    xi (scalar challenge)

   Constant bases (from dummy verifier key): generic, psm, complete_add, mul,
   emul, endomul_scalar (6), coefficients_comm[0..14] (15), sigma_comm_init[0..5] (6).
   Total: 18 variable + 27 constant = 45 bases.

   Runs on Tock/Wrap side (Fq field, Vesta inner curve).
*)
let combine_poly_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let open Pickles_types in
  let module Inner_curve = Wrap_main_inputs.Inner_curve in
  let read_pt i : Inner_curve.t = (inputs.(i), inputs.(i + 1)) in
  let x_hat = [| read_pt 0 |] in
  let ft_comm = read_pt 2 in
  let z_comm = [| read_pt 4 |] in
  let w_comm = Vector.init Nat.N15.n ~f:(fun j ->
    [| read_pt (6 + 2 * j) |]) in
  let xi : Wrap_verifier.Scalar_challenge.t =
    { Kimchi_types.inner = inputs.(36) }
  in
  (* Verification key: all dummy (Vesta generator) *)
  let dummy_pt = Wrap_main_inputs.Inner_curve.Params.one in
  let dummy_comm = [| Inner_curve.constant dummy_pt |] in
  let m =
    Plonk_verification_key_evals.Step.forget_optional_commitments
      { Plonk_verification_key_evals.Step.
        sigma_comm = Vector.init Nat.N7.n ~f:(fun _ -> dummy_comm)
      ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun _ -> dummy_comm)
      ; generic_comm = dummy_comm
      ; psm_comm = dummy_comm
      ; complete_add_comm = dummy_comm
      ; mul_comm = dummy_comm
      ; emul_comm = dummy_comm
      ; endomul_scalar_comm = dummy_comm
      ; xor_comm = Opt.Nothing
      ; range_check0_comm = Opt.Nothing
      ; range_check1_comm = Opt.Nothing
      ; foreign_field_add_comm = Opt.Nothing
      ; foreign_field_mul_comm = Opt.Nothing
      ; rot_comm = Opt.Nothing
      ; lookup_table_comm =
          Vector.init Plonk_types.Lookup_sorted_minus_1.n ~f:(fun _ -> Opt.Nothing)
      ; lookup_table_ids = Opt.Nothing
      ; runtime_tables_selector = Opt.Nothing
      ; lookup_selector_lookup = Opt.Nothing
      ; lookup_selector_xor = Opt.Nothing
      ; lookup_selector_range_check = Opt.Nothing
      ; lookup_selector_ffmul = Opt.Nothing
      }
  in
  let sigma_comm_init, [ _ ] =
    Vector.split m.sigma_comm (snd (Plonk_types.Permuts_minus_1.add Nat.N1.n))
  in
  (* Assemble without_degree_bound exactly as in wrap_verifier.ml:1356-1408 *)
  let len_1, len_1_add = Plonk_types.(Columns.add Permuts_minus_1.n) in
  let len_2, len_2_add = Plonk_types.(Columns.add len_1) in
  let _len_3, len_3_add = Nat.N9.add len_2 in
  let _len_4, len_4_add = Nat.N6.add Plonk_types.Lookup_sorted.n in
  let len_5, len_5_add = Nat.N11.add Nat.N8.n in
  let len_6, len_6_add = Nat.N45.add len_5 in
  let without_degree_bound =
    let append_chain len second first =
      Vector.append first second len
    in
    (* sg_old = empty (0 proofs verified) *)
    Vector.[]
    |> append_chain
         (snd (Nat.N0.add len_6))
         ( [ x_hat
           ; [| ft_comm |]
           ; z_comm
           ; m.generic_comm
           ; m.psm_comm
           ; m.complete_add_comm
           ; m.mul_comm
           ; m.emul_comm
           ; m.endomul_scalar_comm
           ]
         |> append_chain len_3_add
              (Vector.append w_comm
                 (Vector.append m.coefficients_comm sigma_comm_init
                    len_1_add )
                 len_2_add )
         |> Vector.map ~f:Opt.just
         |> append_chain len_6_add
              ( [ Opt.Nothing  (* range_check0 *)
                ; Opt.Nothing  (* range_check1 *)
                ; Opt.Nothing  (* foreign_field_add *)
                ; Opt.Nothing  (* foreign_field_mul *)
                ; Opt.Nothing  (* xor *)
                ; Opt.Nothing  (* rot *)
                ]
              |> append_chain len_4_add
                   (Vector.init Plonk_types.Lookup_sorted.n
                      ~f:(fun _ -> Opt.Nothing))
              |> append_chain len_5_add
                   [ Opt.Nothing  (* lookup aggreg *)
                   ; Opt.Nothing  (* lookup_table *)
                   ; Opt.Nothing  (* runtime *)
                   ; Opt.Nothing  (* runtime_tables_selector *)
                   ; Opt.Nothing  (* lookup_selector_xor *)
                   ; Opt.Nothing  (* lookup_selector_lookup *)
                   ; Opt.Nothing  (* lookup_selector_range_check *)
                   ; Opt.Nothing  (* lookup_selector_ffmul *)
                   ] ) )
  in
  (* Inline Split_commitments.combine logic for all-Just, single-chunk,
     no-degree-bound case. Matches wrap_verifier.ml:496-565 exactly. *)
  let module IC = Wrap_main_inputs.Inner_curve in
  let module SC = Wrap_verifier.Scalar_challenge in
  (* reduce_without_degree_bound = fun x -> [x], so flat = to_list *)
  let flat = Vector.to_list without_degree_bound in
  (* go (List.rev flat) — process reversed, skipping Nothing, init first Just *)
  let open Impls.Wrap in
  let _combined =
    let combine_point_add (p : IC.t) (q : IC.t) =
      WrapOps.add_fast p q
    in
    let scale_and_add ~(acc : IC.t * Boolean.var) ~xi
        (p : (IC.t array, Boolean.var) Opt.t) =
      let acc_point, acc_non_zero = acc in
      match p with
      | Opt.Nothing -> acc
      | Opt.Just p_arr ->
        let p0 = p_arr.(Array.length p_arr - 1) in
        let base_point =
          IC.(if_ acc_non_zero
                ~then_:(combine_point_add p0 (SC.endo acc_point xi))
                ~else_:p0)
        in
        let point = ref base_point in
        for i = Array.length p_arr - 2 downto 0 do
          point := combine_point_add p_arr.(i) (SC.endo !point xi)
        done ;
        let point = IC.(if_ Boolean.true_ ~then_:!point ~else_:acc_point) in
        let non_zero = Boolean.(Boolean.true_ &&& Boolean.true_ ||| acc_non_zero) in
        (point, non_zero)
      | Opt.Maybe (keep, p_arr) ->
        let p0 = p_arr.(Array.length p_arr - 1) in
        let base_point =
          IC.(if_ acc_non_zero
                ~then_:(combine_point_add p0 (SC.endo acc_point xi))
                ~else_:p0)
        in
        let point = ref base_point in
        for i = Array.length p_arr - 2 downto 0 do
          point := combine_point_add p_arr.(i) (SC.endo !point xi)
        done ;
        let point = IC.(if_ keep ~then_:!point ~else_:acc_point) in
        let non_zero = Boolean.(keep &&& Boolean.true_ ||| acc_non_zero) in
        (point, non_zero)
    in
    let without_degree_bound_tagged =
      List.map flat ~f:(Opt.map ~f:(Array.map ~f:(fun x -> x)))
    in
    let rec go = function
      | [] -> failwith "empty"
      | init :: comms -> (
        match init with
        | Opt.Nothing -> go comms
        | Opt.Just p ->
          let init_point = p.(Array.length p - 1) in
          let init_acc = (init_point, Boolean.(Boolean.true_ &&& Boolean.true_)) in
          List.fold_left comms ~init:init_acc ~f:(fun acc p ->
            scale_and_add ~acc ~xi p)
        | Opt.Maybe (keep, p) ->
          let init_point = p.(Array.length p - 1) in
          let init_acc = (init_point, Boolean.(keep &&& Boolean.true_)) in
          List.fold_left comms ~init:init_acc ~f:(fun acc p ->
            scale_and_add ~acc ~xi p) )
    in
    let (point, non_zero) = go (List.rev without_degree_bound_tagged) in
    Boolean.Assert.is_true non_zero ;
    point
  in
  ()

(* Single bullet_reduce round: endoInv(l, u) + endo(r, u) + add_fast
   Input: l.x, l.y, r.x, r.y, scalar = 5 fields *)
let bullet_reduce_one_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let l : Wrap_main_inputs.Inner_curve.t = (inputs.(0), inputs.(1)) in
  let r : Wrap_main_inputs.Inner_curve.t = (inputs.(2), inputs.(3)) in
  let pre = Import.Scalar_challenge.create inputs.(4) in
  let left_term = Wrap_verifier.Scalar_challenge.endo_inv l pre in
  let right_term = Wrap_verifier.Scalar_challenge.endo r pre in
  let _result = WrapOps.add_fast left_term right_term in
  ()

let bullet_reduce_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let read_pt i : Wrap_main_inputs.Inner_curve.t =
    (inputs.(i), inputs.(i + 1))
  in
  let lr = Array.init 16 ~f:(fun j ->
    (read_pt (4 * j), read_pt (4 * j + 2)))
  in
  let prechallenges = Array.init 16 ~f:(fun j ->
    Import.Scalar_challenge.create inputs.(64 + j))
  in
  let terms =
    Array.map2_exn lr prechallenges ~f:(fun (l, r) pre ->
      let left_term = Wrap_verifier.Scalar_challenge.endo_inv l pre in
      let right_term = Wrap_verifier.Scalar_challenge.endo r pre in
      WrapOps.add_fast left_term right_term)
  in
  let _result =
    Array.reduce_exn terms ~f:(WrapOps.add_fast ?check_finite:None)
  in
  ()

let group_map_circuit (inputs : Impls.Wrap.Field.t array) () =
  let open Impls.Wrap in
  let module Inner_curve = Wrap_main_inputs.Inner_curve in
  let module M =
    Group_map.Bw19.Make (Field.Constant) (Field)
      (struct
        let params =
          Group_map.Bw19.Params.create
            (module Field.Constant)
            { b = Inner_curve.Params.b }
      end)
  in
  let group_map =
    Snarky_group_map.Checked.wrap
      (module Impl)
      ~potential_xs:M.potential_xs
      ~y_squared:(fun ~x ->
        Field.(
          (x * x * x)
          + (constant Inner_curve.Params.a * x)
          + constant Inner_curve.Params.b) )
    |> unstage
  in
  let _x, _y = group_map inputs.(0) in
  ()

(* x_hat sub-circuit for Step IVP: public input commitment using multiscale_known.
   Input layout (30 fields) — same as Step IVP public_input indices 0-29:
     0-4:   Field (255-bit)
     5-6:   packed 128
     7-9:   packed 128
     10-12: packed 255
     13-28: packed 128
     29:    packed 10

   Uses multiscale_known (pure constant corrections, no in-circuit Ops.add_fast
   for correction combining). Runs on Tick/Step side (Fp field, Pallas inner curve).
*)
let xhat_step_circuit (inputs : Impl.Field.t array) () =
  let open Impl in
  let module Inner_curve = Step_main_inputs.Inner_curve in
  let srs = Kimchi_bindings.Protocol.SRS.Fq.create (1 lsl 16) in
  let public_input =
    let packed n i = `Packed_bits (inputs.(i), n) in
    Array.concat
      [ Array.init 5 ~f:(fun j -> `Field inputs.(j))
      ; [| packed 128 5 ; packed 128 6 |]
      ; [| packed 128 7 ; packed 128 8 ; packed 128 9 |]
      ; [| packed 255 10 ; packed 255 11 ; packed 255 12 |]
      ; Array.init 16 ~f:(fun j -> packed 128 (13 + j))
      ; [| packed 10 29 |]
      ]
  in
  let domain = Pickles_base.Domain.Pow_2_roots_of_unity 16 in
  let lagrange_commitment ~domain:d srs i =
    let d = Pickles_base.Domain.size d in
    let chunks =
      (Kimchi_bindings.Protocol.SRS.Fq.lagrange_commitment srs d i).unshifted
    in
    match[@warning "-8"] chunks with
    | [| Finite g |] -> Inner_curve.Constant.of_affine g
    | _ -> assert false
  in
  let x_hat =
    with_label "x_hat" (fun () ->
        Step_verifier.For_tests_only.multiscale_known
          (Array.mapi public_input ~f:(fun i x ->
               (x, lagrange_commitment ~domain srs i) ) )
        |> Inner_curve.negate )
  in
  let _x_hat =
    with_label "x_hat blinding" (fun () ->
        Ops.add_fast x_hat
          (Inner_curve.constant (Lazy.force Step_main_inputs.Generators.h)) )
  in
  ()

(* ---- Step-field sub-circuits (Tick/Fp, Pallas inner curve) ---- *)

(* Single bullet_reduce round on Step field.
   Input: l.x, l.y, r.x, r.y, scalar = 5 fields *)
let bullet_reduce_one_step_circuit (inputs : Impl.Field.t array) () =
  let open Impl in
  let l : Step_main_inputs.Inner_curve.t = (inputs.(0), inputs.(1)) in
  let r : Step_main_inputs.Inner_curve.t = (inputs.(2), inputs.(3)) in
  let pre = Import.Scalar_challenge.create inputs.(4) in
  let left_term = Step_SC.endo_inv l pre in
  let right_term = Step_SC.endo r pre in
  let _result = Ops.add_fast left_term right_term in
  ()

(* bullet_reduce on Step field: 15 rounds (Wrap proof IPA).
   Input layout (75 fields):
     0-59:  lr[0..14] (15 × 4 fields: l.x, l.y, r.x, r.y)
     60-74: scalar_challenges[0..14] *)
let bullet_reduce_step_circuit (inputs : Impl.Field.t array) () =
  let open Impl in
  let read_pt i : Step_main_inputs.Inner_curve.t =
    (inputs.(i), inputs.(i + 1))
  in
  let lr = Array.init 15 ~f:(fun j ->
    (read_pt (4 * j), read_pt (4 * j + 2)))
  in
  let prechallenges = Array.init 15 ~f:(fun j ->
    Import.Scalar_challenge.create inputs.(60 + j))
  in
  let terms =
    Array.map2_exn lr prechallenges ~f:(fun (l, r) pre ->
      let left_term = Step_SC.endo_inv l pre in
      let right_term = Step_SC.endo r pre in
      Ops.add_fast left_term right_term)
  in
  let _result =
    Array.reduce_exn terms ~f:(Ops.add_fast ?check_finite:None)
  in
  ()

(* group_map on Step field (Pallas inner curve). Input: 1 field *)
let group_map_step_circuit (inputs : Impl.Field.t array) () =
  let open Impl in
  let module Inner_curve = Step_main_inputs.Inner_curve in
  let module M =
    Group_map.Bw19.Make (Field.Constant) (Field)
      (struct
        let params =
          Group_map.Bw19.Params.create
            (module Field.Constant)
            { b = Inner_curve.Params.b }
      end)
  in
  let group_map =
    Snarky_group_map.Checked.wrap
      (module Impl)
      ~potential_xs:M.potential_xs
      ~y_squared:(fun ~x ->
        Field.(
          (x * x * x)
          + (constant Inner_curve.Params.a * x)
          + constant Inner_curve.Params.b) )
    |> unstage
  in
  let _x, _y = group_map inputs.(0) in
  ()

(* ft_comm on Step field (Pallas inner curve).
   Input layout (17 fields):
     0-13: t_comm (7 points × 2 coords)
     14:   perm (Type2 shifted value, cross-field)
     15:   zeta_to_srs_length (Type2 shifted value)
     16:   zeta_to_domain_size (Type2 shifted value)

   Note: Step IVP uses Type2 shifted values (cross-field Fp→Fq). *)
let ftcomm_step_circuit (inputs : Impl.Field.t array) () =
  let open Impl in
  let open Pickles_types in
  let module Inner_curve = Step_main_inputs.Inner_curve in
  let read_pt i : Inner_curve.t = (inputs.(i), inputs.(i + 1)) in
  let t_comm = Array.init 7 ~f:(fun j -> read_pt (2 * j)) in
  let read_other_field i : Impls.Step.Other_field.t =
    (inputs.(i), Boolean.Unsafe.of_cvar inputs.(i + 1))
  in
  let plonk =
    { Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.
      alpha = { Kimchi_types.inner = Field.zero }
    ; beta = Field.zero
    ; gamma = Field.zero
    ; zeta = { Kimchi_types.inner = Field.zero }
    ; perm = Shifted_value.Type2.Shifted_value (read_other_field 14)
    ; zeta_to_srs_length = Shifted_value.Type2.Shifted_value (read_other_field 16)
    ; zeta_to_domain_size = Shifted_value.Type2.Shifted_value (read_other_field 18)
    ; feature_flags =
        Kimchi_backend_common.Plonk_types.Features.map
          Kimchi_backend_common.Plonk_types.Features.none_bool
          ~f:(fun _ -> Boolean.false_)
    ; joint_combiner = Opt.Nothing
    }
  in
  let scale_fast2 p (s : Impls.Step.Other_field.t Shifted_value.Type2.t) =
    with_label __LOC__ (fun () ->
        Ops.scale_fast2 p s ~num_bits:Field.size_in_bits )
  in
  let dummy_pt = Inner_curve.Params.one in
  let sigma_comm_last = Inner_curve.constant dummy_pt in
  let dummy_comm = [| sigma_comm_last |] in
  let verification_key =
    { Plonk_verification_key_evals.
      sigma_comm = Vector.init Nat.N7.n ~f:(fun _ -> dummy_comm)
    ; coefficients_comm = Vector.init Nat.N15.n ~f:(fun _ -> dummy_comm)
    ; generic_comm = dummy_comm
    ; psm_comm = dummy_comm
    ; complete_add_comm = dummy_comm
    ; mul_comm = dummy_comm
    ; emul_comm = dummy_comm
    ; endomul_scalar_comm = dummy_comm
    }
  in
  let _ft_comm =
    Common.ft_comm
      ~add:(Ops.add_fast ?check_finite:None)
      ~scale:scale_fast2 ~negate:Inner_curve.negate
      ~verification_key
      ~plonk ~t_comm
  in
  ()

(* ---- Entry point ---- *)

let run ~output_dir =
  let dump_step name circuit ~input_typ ~return_typ =
    dump_tick_with_labels output_dir name circuit ~input_typ ~return_typ
  in
  let dump_wrap name circuit ~input_typ ~return_typ =
    dump_tock_with_labels output_dir name circuit ~input_typ ~return_typ
  in
  (* Basic Step circuits *)
  dump_step "mul_step_circuit" mul_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  dump_step "inv_step_circuit" inv_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  dump_step "div_step_circuit" div_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  dump_step "equals_step_circuit" equals_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Boolean.typ ;
  dump_step "if_step_circuit" if_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  dump_step "assert_equal_step_circuit" assert_equal_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Typ.unit ;
  dump_step "assert_square_step_circuit" assert_square_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Typ.unit ;
  dump_step "pow2_pow_step_circuit" pow2_pow_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Typ.unit ;
  dump_step "assert_non_zero_step_circuit" assert_non_zero_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Typ.unit ;
  dump_step "assert_not_equal_step_circuit" assert_not_equal_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Typ.unit ;
  dump_step "unpack_step_circuit" unpack_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Typ.unit ;
  dump_step "bool_and_step_circuit" bool_and_circuit
    ~input_typ:Impl.Boolean.typ ~return_typ:Impl.Boolean.typ ;
  dump_step "bool_or_step_circuit" bool_or_circuit
    ~input_typ:Impl.Boolean.typ ~return_typ:Impl.Boolean.typ ;
  dump_step "bool_xor_step_circuit" bool_xor_circuit
    ~input_typ:Impl.Boolean.typ ~return_typ:Impl.Boolean.typ ;
  dump_step "bool_all_step_circuit" bool_all_circuit
    ~input_typ:Impl.Boolean.typ ~return_typ:Impl.Boolean.typ ;
  dump_step "bool_any_step_circuit" bool_any_circuit
    ~input_typ:Impl.Boolean.typ ~return_typ:Impl.Boolean.typ ;
  dump_step "bool_assert_step_circuit" bool_assert_circuit
    ~input_typ:Impl.Boolean.typ ~return_typ:Impl.Typ.unit ;
  let point_typ = Impl.Typ.(Impl.Field.typ * Impl.Field.typ) in
  let two_point_typ = Impl.Typ.(point_typ * point_typ) in
  dump_step "add_complete_step_circuit" add_complete_circuit
    ~input_typ:two_point_typ ~return_typ:point_typ ;
  dump_step "endo_scalar_step_circuit" endo_scalar_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  dump_step "endo_mul_step_circuit" endo_mul_circuit
    ~input_typ:Impl.Typ.(point_typ * Impl.Field.typ) ~return_typ:point_typ ;
  dump_step "var_base_mul_step_circuit" var_base_mul_circuit
    ~input_typ:Impl.Typ.(point_typ * Impl.Field.typ) ~return_typ:point_typ ;
  dump_step "scale_fast2_128_step_circuit" scale_fast2_128_circuit
    ~input_typ:Impl.Typ.(point_typ * Impl.Field.typ) ~return_typ:point_typ ;
  let array3_field = Impl.Typ.array ~length:3 Impl.Field.typ in
  dump_step "poseidon_step_circuit" poseidon_circuit
    ~input_typ:array3_field ~return_typ:array3_field ;
  dump_step "pow7_step_circuit" pow7_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  dump_step "pow8_step_circuit" pow8_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  let array90_field = Impl.Typ.array ~length:90 Impl.Field.typ in
  dump_step "linearization_step_circuit" linearization_tick_circuit
    ~input_typ:array90_field ~return_typ:Impl.Field.typ ;
  let array90_wrap = WrapImpl.Typ.array ~length:90 WrapImpl.Field.typ in
  dump_wrap "linearization_wrap_circuit" linearization_tock_circuit
    ~input_typ:array90_wrap ~return_typ:WrapImpl.Field.typ ;
  let array91_field = Impl.Typ.array ~length:91 Impl.Field.typ in
  dump_step "ft_eval0_step_circuit" ft_eval0_circuit
    ~input_typ:array91_field ~return_typ:Impl.Field.typ ;
  (* Phase 1 sub-circuits *)
  let array4_field = Impl.Typ.array ~length:4 Impl.Field.typ in
  dump_step "expand_plonk_step_circuit" expand_plonk_circuit
    ~input_typ:array4_field ~return_typ:Impl.Typ.unit ;
  let array34_field = Impl.Typ.array ~length:34 Impl.Field.typ in
  dump_step "challenge_digest_step_circuit" challenge_digest_circuit
    ~input_typ:array34_field ~return_typ:Impl.Typ.unit ;
  let array20_field = Impl.Typ.array ~length:20 Impl.Field.typ in
  dump_step "b_correct_step_circuit" b_correct_circuit
    ~input_typ:array20_field ~return_typ:Impl.Typ.unit ;
  let array18_field = Impl.Typ.array ~length:18 Impl.Field.typ in
  dump_step "plonk_checks_passed_step_circuit" plonk_checks_passed_circuit
    ~input_typ:array18_field ~return_typ:Impl.Typ.unit ;
  let array124_field = Impl.Typ.array ~length:124 Impl.Field.typ in
  dump_step "sponge_and_challenges_step_circuit" sponge_and_challenges_circuit
    ~input_typ:array124_field ~return_typ:Impl.Typ.unit ;
  let array129_field = Impl.Typ.array ~length:129 Impl.Field.typ in
  dump_step "cip_step_circuit" cip_circuit
    ~input_typ:array129_field ~return_typ:Impl.Typ.unit ;
  (* Pickles sub-circuits *)
  let array151_field = Impl.Typ.array ~length:151 Impl.Field.typ in
  dump_step "finalize_other_proof_step_circuit" finalize_other_proof_circuit
    ~input_typ:array151_field ~return_typ:Impl.Typ.unit ;
  let array148_wrap = Impls.Wrap.Typ.array ~length:148 Impls.Wrap.Field.typ in
  dump_wrap "finalize_other_proof_wrap_circuit" finalize_other_proof_wrap_circuit
    ~input_typ:array148_wrap ~return_typ:Impls.Wrap.Typ.unit ;
  (* IVP needs the Tick URS for Generators.h (blinding generator) *)
  Backend.Tick.Keypair.set_urs_info [] ;
  let array34_wrap = Impls.Wrap.Typ.array ~length:34 Impls.Wrap.Field.typ in
  dump_wrap "xhat_wrap_circuit" xhat_circuit
    ~input_typ:array34_wrap ~return_typ:Impls.Wrap.Typ.unit ;
  let array177_wrap = Impls.Wrap.Typ.array ~length:177 Impls.Wrap.Field.typ in
  dump_wrap "ivp_wrap_circuit" ivp_wrap_circuit
    ~input_typ:array177_wrap ~return_typ:Impls.Wrap.Typ.unit ;
  let array196_wrap = Impls.Wrap.Typ.array ~length:196 Impls.Wrap.Field.typ in
  dump_wrap "wrap_verify_circuit" wrap_verify_circuit
    ~input_typ:array196_wrap ~return_typ:Impls.Wrap.Typ.unit ;
  let array212_wrap = Impls.Wrap.Typ.array ~length:212 Impls.Wrap.Field.typ in
  dump_wrap "wrap_verify_n2_circuit" wrap_verify_n2_circuit
    ~input_typ:array212_wrap ~return_typ:Impls.Wrap.Typ.unit ;
  (* Full wrap_main circuit: compute input size from Typ sizes *)
  let wrap_main_input_size =
    let open Pickles_types in
    let typ_size : type v c. (v, c) Impls.Wrap.Typ.t -> int =
      fun (Typ r) -> r.size_in_field_elements
    in
    let feature_flags = Kimchi_backend_common.Plonk_types.Features.Full.none in
    let wrap_stmt_size = 30 in  (* manually parsed: plonk(7) + xi + cip + b + branch_data + bp_chals(16) + sponge + msg_wrap + msg_step *)
    let which_branch_size = 1 in
    let prev_proof_state_size = typ_size
      (Import.Types.Step.Proof_state.wrap_typ
         ~assert_16_bits:(Wrap_verifier.assert_n_bits ~n:16)
         (Vector.init Nat.N2.n ~f:(fun _ -> Plonk_types.Features.none))
         (Shifted_value.Type2.wrap_typ Impls.Wrap.Field.typ)) in
    let prev_step_accs_size = typ_size
      (Vector.wrap_typ Wrap_main_inputs.Inner_curve.typ Nat.N2.n) in
    let old_bp_chals_size = Nat.to_int Backend.Tock.Rounds.n in  (* N1 slot0: 1×15, slot1: 0×15 *)
    let evals_size = typ_size
      (Vector.wrap_typ
         (Plonk_types.All_evals.wrap_typ ~num_chunks:1 feature_flags)
         Nat.N2.n) in
    let wrap_domain_indices_size = typ_size
      (Vector.wrap_typ Impls.Wrap.Field.typ Nat.N2.n) in
    let openings_proof_size = typ_size
      (Plonk_types.Openings.Bulletproof.wrap_typ
         ( Impls.Wrap.Typ.transport Wrap_verifier.Other_field.Packed.typ
             ~there:(fun x ->
               match Shifted_value.Type1.of_field (module Backend.Tick.Field)
                       ~shift:Common.Shifts.tick1 x with
               | Shifted_value x -> x)
             ~back:(fun x ->
               Shifted_value.Type1.to_field (module Backend.Tick.Field)
                 ~shift:Common.Shifts.tick1 (Shifted_value x))
           |> Impls.Wrap.Typ.transport_var
                ~there:(fun (Shifted_value.Type1.Shifted_value x) -> x)
                ~back:(fun x -> Shifted_value x) )
         Wrap_main_inputs.Inner_curve.typ
         ~length:(Nat.to_int Backend.Tick.Rounds.n)) in
    let messages_size = typ_size
      (Plonk_types.Messages.wrap_typ Wrap_main_inputs.Inner_curve.typ
         feature_flags
         ~dummy:Wrap_main_inputs.Inner_curve.Params.one
         ~commitment_lengths:(Commitment_lengths.default ~num_chunks:1)) in
    let total = wrap_stmt_size + which_branch_size + prev_proof_state_size
      + prev_step_accs_size + old_bp_chals_size + evals_size
      + wrap_domain_indices_size + openings_proof_size + messages_size in
    Printf.printf "wrap_main_circuit input sizes: stmt=%d which=%d pps=%d accs=%d bpc=%d evals=%d wdi=%d op=%d msg=%d total=%d\n"
      wrap_stmt_size which_branch_size prev_proof_state_size
      prev_step_accs_size old_bp_chals_size evals_size
      wrap_domain_indices_size openings_proof_size messages_size total ;
    total
  in
  let wrap_main_input_typ =
    Impls.Wrap.Typ.array ~length:wrap_main_input_size Impls.Wrap.Field.typ
  in
  dump_wrap "wrap_main_circuit" wrap_main_circuit
    ~input_typ:wrap_main_input_typ ~return_typ:Impls.Wrap.Typ.unit ;
  (* ---- Pseudo module sub-circuits ---- *)
  let array1_field_ps = Impl.Typ.array ~length:1 Impl.Field.typ in
  let array1_wrap_ps = Impls.Wrap.Typ.array ~length:1 Impls.Wrap.Field.typ in
  let array2_field_ps = Impl.Typ.array ~length:2 Impl.Field.typ in
  let array2_wrap_ps = Impls.Wrap.Typ.array ~length:2 Impls.Wrap.Field.typ in
  let array4_field_ps = Impl.Typ.array ~length:4 Impl.Field.typ in
  let array4_wrap_ps = Impls.Wrap.Typ.array ~length:4 Impls.Wrap.Field.typ in
  dump_step "one_hot_n1_step_circuit" one_hot_n1_step_circuit
    ~input_typ:array1_field_ps ~return_typ:Impl.Typ.unit ;
  dump_wrap "one_hot_n1_wrap_circuit" one_hot_n1_wrap_circuit
    ~input_typ:array1_wrap_ps ~return_typ:Impls.Wrap.Typ.unit ;
  dump_step "one_hot_n3_step_circuit" one_hot_n3_step_circuit
    ~input_typ:array1_field_ps ~return_typ:Impl.Typ.unit ;
  dump_wrap "one_hot_n3_wrap_circuit" one_hot_n3_wrap_circuit
    ~input_typ:array1_wrap_ps ~return_typ:Impls.Wrap.Typ.unit ;
  dump_step "pseudo_mask_n1_step_circuit" pseudo_mask_n1_step_circuit
    ~input_typ:array2_field_ps ~return_typ:Impl.Typ.unit ;
  dump_wrap "pseudo_mask_n1_wrap_circuit" pseudo_mask_n1_wrap_circuit
    ~input_typ:array2_wrap_ps ~return_typ:Impls.Wrap.Typ.unit ;
  dump_step "pseudo_mask_n3_step_circuit" pseudo_mask_n3_step_circuit
    ~input_typ:array4_field_ps ~return_typ:Impl.Typ.unit ;
  dump_wrap "pseudo_mask_n3_wrap_circuit" pseudo_mask_n3_wrap_circuit
    ~input_typ:array4_wrap_ps ~return_typ:Impls.Wrap.Typ.unit ;
  dump_step "pseudo_choose_n1_step_circuit" pseudo_choose_n1_step_circuit
    ~input_typ:array1_field_ps ~return_typ:Impl.Typ.unit ;
  dump_wrap "pseudo_choose_n1_wrap_circuit" pseudo_choose_n1_wrap_circuit
    ~input_typ:array1_wrap_ps ~return_typ:Impls.Wrap.Typ.unit ;
  dump_step "pseudo_choose_n3_step_circuit" pseudo_choose_n3_step_circuit
    ~input_typ:array1_field_ps ~return_typ:Impl.Typ.unit ;
  dump_wrap "pseudo_choose_n3_wrap_circuit" pseudo_choose_n3_wrap_circuit
    ~input_typ:array1_wrap_ps ~return_typ:Impls.Wrap.Typ.unit ;
  dump_wrap "choose_key_n1_wrap_circuit" choose_key_n1_wrap_circuit
    ~input_typ:array1_wrap_ps ~return_typ:Impls.Wrap.Typ.unit ;
  (* Step IVP needs the Tock URS for Step_main_inputs.Generators.h *)
  Backend.Tock.Keypair.set_urs_info [] ;
  let array175_field = Impl.Typ.array ~length:175 Impl.Field.typ in
  dump_step "ivp_step_circuit" ivp_step_circuit
    ~input_typ:array175_field ~return_typ:Impl.Typ.unit ;
  let array91_field = Impl.Typ.array ~length:91 Impl.Field.typ in
  dump_step "hash_messages_for_next_step_proof_circuit"
    hash_messages_for_next_step_proof_circuit
    ~input_typ:array91_field ~return_typ:Impl.Typ.unit ;
  let array33_wrap = Impls.Wrap.Typ.array ~length:33 Impls.Wrap.Field.typ in
  dump_wrap "hash_messages_for_next_wrap_proof_circuit"
    hash_messages_for_next_wrap_proof_circuit
    ~input_typ:array33_wrap ~return_typ:Impls.Wrap.Typ.unit ;
  (* Wrap sub-circuits *)
  let array80_wrap = Impls.Wrap.Typ.array ~length:80 Impls.Wrap.Field.typ in
  dump_wrap "bullet_reduce_wrap_circuit" bullet_reduce_circuit
    ~input_typ:array80_wrap ~return_typ:Impls.Wrap.Typ.unit ;
  let array5_wrap = Impls.Wrap.Typ.array ~length:5 Impls.Wrap.Field.typ in
  dump_wrap "bullet_reduce_one_wrap_circuit" bullet_reduce_one_circuit
    ~input_typ:array5_wrap ~return_typ:Impls.Wrap.Typ.unit ;
  let array17_wrap = Impls.Wrap.Typ.array ~length:17 Impls.Wrap.Field.typ in
  dump_wrap "ftcomm_wrap_circuit" ftcomm_circuit
    ~input_typ:array17_wrap ~return_typ:Impls.Wrap.Typ.unit ;
  let array37_wrap = Impls.Wrap.Typ.array ~length:37 Impls.Wrap.Field.typ in
  dump_wrap "combine_poly_wrap_circuit" combine_poly_circuit
    ~input_typ:array37_wrap ~return_typ:Impls.Wrap.Typ.unit ;
  let array1_wrap = Impls.Wrap.Typ.array ~length:1 Impls.Wrap.Field.typ in
  dump_wrap "group_map_wrap_circuit" group_map_circuit
    ~input_typ:array1_wrap ~return_typ:Impls.Wrap.Typ.unit ;
  (* Step sub-circuits *)
  let array5_field = Impl.Typ.array ~length:5 Impl.Field.typ in
  dump_step "bullet_reduce_one_step_circuit" bullet_reduce_one_step_circuit
    ~input_typ:array5_field ~return_typ:Impl.Typ.unit ;
  let array75_field = Impl.Typ.array ~length:75 Impl.Field.typ in
  dump_step "bullet_reduce_step_circuit" bullet_reduce_step_circuit
    ~input_typ:array75_field ~return_typ:Impl.Typ.unit ;
  let array1_field = Impl.Typ.array ~length:1 Impl.Field.typ in
  dump_step "group_map_step_circuit" group_map_step_circuit
    ~input_typ:array1_field ~return_typ:Impl.Typ.unit ;
  let array20_field_ftcomm = Impl.Typ.array ~length:20 Impl.Field.typ in
  dump_step "ftcomm_step_circuit" ftcomm_step_circuit
    ~input_typ:array20_field_ftcomm ~return_typ:Impl.Typ.unit ;
  let array30_field = Impl.Typ.array ~length:30 Impl.Field.typ in
  dump_step "xhat_step_circuit" xhat_step_circuit
    ~input_typ:array30_field ~return_typ:Impl.Typ.unit ;
  (* Step verify circuit — last to avoid shifting other circuits' variable IDs *)
  let step_verify_input_size =
    let feature_flags =
      Kimchi_backend_common.Plonk_types.Features.Full.none
    in
    let (Impl.Typ.Typ ppw_r) =
      Per_proof_witness.typ Impl.Typ.unit Pickles_types.Nat.N0.n ~feature_flags ~num_chunks:1
    in
    let (Impl.Typ.Typ unf_r) =
      Unfinalized.typ ~wrap_rounds:Backend.Tock.Rounds.n
    in
    ppw_r.size_in_field_elements + unf_r.size_in_field_elements + 3
    (* +3 for: is_base_case, messages_for_next_wrap_proof, messages_for_next_step_proof *)
  in
  let step_verify_input_typ =
    Impl.Typ.array ~length:step_verify_input_size Impl.Field.typ
  in
  dump_step "step_verify_circuit" step_verify_circuit
    ~input_typ:step_verify_input_typ ~return_typ:Impl.Typ.unit ;
  (* Full step verify_one circuit: FOP + message hash + IVP + assertions *)
  let full_step_verify_one_input_size =
    let feature_flags =
      Kimchi_backend_common.Plonk_types.Features.Full.none
    in
    let (Impl.Typ.Typ ppw_r) =
      Per_proof_witness.typ Impl.Field.typ Pickles_types.Nat.N1.n ~feature_flags ~num_chunks:1
    in
    let (Impl.Typ.Typ unf_r) =
      Unfinalized.typ ~wrap_rounds:Backend.Tock.Rounds.n
    in
    ppw_r.size_in_field_elements + unf_r.size_in_field_elements + 2
    (* +2 for: messages_for_next_wrap_proof, must_verify *)
  in
  let full_step_verify_one_input_typ =
    Impl.Typ.array ~length:full_step_verify_one_input_size Impl.Field.typ
  in
  dump_step "full_step_verify_one_circuit" full_step_verify_one_circuit
    ~input_typ:full_step_verify_one_input_typ ~return_typ:Impl.Typ.unit ;
  (* Step verify N2 circuit *)
  let step_verify_n2_input_size =
    let feature_flags =
      Kimchi_backend_common.Plonk_types.Features.Full.none
    in
    let (Impl.Typ.Typ ppw_r) =
      Per_proof_witness.typ Impl.Typ.unit Pickles_types.Nat.N2.n ~feature_flags ~num_chunks:1
    in
    let (Impl.Typ.Typ unf_r) =
      Unfinalized.typ ~wrap_rounds:Backend.Tock.Rounds.n
    in
    ppw_r.size_in_field_elements + unf_r.size_in_field_elements + 3
  in
  let step_verify_n2_input_typ =
    Impl.Typ.array ~length:step_verify_n2_input_size Impl.Field.typ
  in
  dump_step "step_verify_n2_circuit" step_verify_n2_circuit
    ~input_typ:step_verify_n2_input_typ ~return_typ:Impl.Typ.unit ;
  (* Full step verify_one N2 circuit *)
  let full_step_verify_one_n2_input_size =
    let feature_flags =
      Kimchi_backend_common.Plonk_types.Features.Full.none
    in
    let (Impl.Typ.Typ ppw_r) =
      Per_proof_witness.typ Impl.Field.typ Pickles_types.Nat.N2.n ~feature_flags ~num_chunks:1
    in
    let (Impl.Typ.Typ unf_r) =
      Unfinalized.typ ~wrap_rounds:Backend.Tock.Rounds.n
    in
    ppw_r.size_in_field_elements + unf_r.size_in_field_elements + 2
  in
  let full_step_verify_one_n2_input_typ =
    Impl.Typ.array ~length:full_step_verify_one_n2_input_size Impl.Field.typ
  in
  dump_step "full_step_verify_one_n2_circuit" full_step_verify_one_n2_circuit
    ~input_typ:full_step_verify_one_n2_input_typ ~return_typ:Impl.Typ.unit
