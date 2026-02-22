(* Dump Kimchi circuit gate data to JSON for each DSL operation.

   This module lives inside the pickles library so it has access to
   internal modules like Plonk_curve_ops.

   Usage: dune exec src/lib/pickles/dump_circuit/dump_circuit.exe *)

module Impl = Kimchi_pasta_snarky_backend.Step_impl

module Add = Plonk_curve_ops.Make_add(Impl)

module Step_SC = Scalar_challenge.Make
  (Impl)
  (Step_main_inputs.Inner_curve)
  (Import.Challenge.Make(Impl))
  (Endo.Step_inner_curve)

let dump output_dir name circuit ~input_typ ~return_typ =
  let cs =
    Impl.constraint_system ~input_typ ~return_typ circuit
  in
  let json =
    Kimchi_pasta_constraint_system.Vesta_constraint_system.to_json cs
  in
  let path = output_dir ^ "/" ^ name ^ ".json" in
  Out_channel.write_all path ~data:(json ^ "\n") ;
  Printf.printf "Wrote %s\n" path

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
        Kimchi_pasta.Pasta.Bigint256.of_hex_string s
        |> Kimchi_pasta.Pasta.Fp.of_bigint
        |> Impl.Field.constant)
      ~domain
      plonk_minimal combined_evals
  in
  Plonk_checks.Scalars_tokens_interpreter.Tick.constant_term env

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
  Printf.printf "Wrote %s\n" path

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
        Kimchi_pasta.Pasta.Bigint256.of_hex_string s
        |> Kimchi_pasta.Pasta.Fq.of_bigint
        |> Field.constant)
      ~domain
      plonk_minimal combined_evals
  in
  Plonk_checks.Scalars_tokens_interpreter.Tock.constant_term env

(* ---- Entry point ---- *)

let run ~output_dir =
  let dump name circuit ~input_typ ~return_typ =
    dump output_dir name circuit ~input_typ ~return_typ
  in
  dump "mul_circuit" mul_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  dump "inv_circuit" inv_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  dump "div_circuit" div_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  dump "equals_circuit" equals_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Boolean.typ ;
  dump "if_circuit" if_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  dump "assert_equal_circuit" assert_equal_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Typ.unit ;
  dump "assert_square_circuit" assert_square_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Typ.unit ;
  dump "assert_non_zero_circuit" assert_non_zero_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Typ.unit ;
  dump "assert_not_equal_circuit" assert_not_equal_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Typ.unit ;
  dump "unpack_circuit" unpack_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Typ.unit ;
  dump "bool_and_circuit" bool_and_circuit
    ~input_typ:Impl.Boolean.typ ~return_typ:Impl.Boolean.typ ;
  dump "bool_or_circuit" bool_or_circuit
    ~input_typ:Impl.Boolean.typ ~return_typ:Impl.Boolean.typ ;
  dump "bool_xor_circuit" bool_xor_circuit
    ~input_typ:Impl.Boolean.typ ~return_typ:Impl.Boolean.typ ;
  dump "bool_all_circuit" bool_all_circuit
    ~input_typ:Impl.Boolean.typ ~return_typ:Impl.Boolean.typ ;
  dump "bool_any_circuit" bool_any_circuit
    ~input_typ:Impl.Boolean.typ ~return_typ:Impl.Boolean.typ ;
  dump "bool_assert_circuit" bool_assert_circuit
    ~input_typ:Impl.Boolean.typ ~return_typ:Impl.Typ.unit ;
  let point_typ = Impl.Typ.(Impl.Field.typ * Impl.Field.typ) in
  let two_point_typ = Impl.Typ.(point_typ * point_typ) in
  dump "add_complete_circuit" add_complete_circuit
    ~input_typ:two_point_typ ~return_typ:point_typ ;
  dump "endo_scalar_circuit" endo_scalar_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  dump "endo_mul_circuit" endo_mul_circuit
    ~input_typ:Impl.Typ.(point_typ * Impl.Field.typ) ~return_typ:point_typ ;
  dump "var_base_mul_circuit" var_base_mul_circuit
    ~input_typ:Impl.Typ.(point_typ * Impl.Field.typ) ~return_typ:point_typ ;
  dump "scale_fast2_128_circuit" scale_fast2_128_circuit
    ~input_typ:Impl.Typ.(point_typ * Impl.Field.typ) ~return_typ:point_typ ;
  let array3_field = Impl.Typ.array ~length:3 Impl.Field.typ in
  dump "poseidon_circuit" poseidon_circuit
    ~input_typ:array3_field ~return_typ:array3_field ;
  dump "pow7_circuit" pow7_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  dump "pow8_circuit" pow8_circuit
    ~input_typ:Impl.Field.typ ~return_typ:Impl.Field.typ ;
  let array90_field = Impl.Typ.array ~length:90 Impl.Field.typ in
  dump "linearization_tick_circuit" linearization_tick_circuit
    ~input_typ:array90_field ~return_typ:Impl.Field.typ ;
  let dump_tock' name circuit ~input_typ ~return_typ =
    dump_tock output_dir name circuit ~input_typ ~return_typ
  in
  let array90_wrap = WrapImpl.Typ.array ~length:90 WrapImpl.Field.typ in
  dump_tock' "linearization_tock_circuit" linearization_tock_circuit
    ~input_typ:array90_wrap ~return_typ:WrapImpl.Field.typ
