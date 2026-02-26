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
    ~input_typ:array90_wrap ~return_typ:WrapImpl.Field.typ ;
  (* Phase 1 sub-circuits *)
  let array4_field = Impl.Typ.array ~length:4 Impl.Field.typ in
  dump "expand_plonk_circuit" expand_plonk_circuit
    ~input_typ:array4_field ~return_typ:Impl.Typ.unit ;
  let array34_field = Impl.Typ.array ~length:34 Impl.Field.typ in
  dump "challenge_digest_circuit" challenge_digest_circuit
    ~input_typ:array34_field ~return_typ:Impl.Typ.unit ;
  let array20_field = Impl.Typ.array ~length:20 Impl.Field.typ in
  dump "b_correct_circuit" b_correct_circuit
    ~input_typ:array20_field ~return_typ:Impl.Typ.unit ;
  let array18_field = Impl.Typ.array ~length:18 Impl.Field.typ in
  dump "plonk_checks_passed_circuit" plonk_checks_passed_circuit
    ~input_typ:array18_field ~return_typ:Impl.Typ.unit ;
  (* Pickles sub-circuits *)
  let array151_field = Impl.Typ.array ~length:151 Impl.Field.typ in
  dump "finalize_other_proof_circuit" finalize_other_proof_circuit
    ~input_typ:array151_field ~return_typ:Impl.Typ.unit ;
  let array148_wrap = Impls.Wrap.Typ.array ~length:148 Impls.Wrap.Field.typ in
  dump_tock' "finalize_other_proof_wrap_circuit" finalize_other_proof_wrap_circuit
    ~input_typ:array148_wrap ~return_typ:Impls.Wrap.Typ.unit
