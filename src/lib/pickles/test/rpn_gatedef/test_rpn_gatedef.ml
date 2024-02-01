open Core_kernel
open Plonk_checks
open Pickles_types

(* open Base *)
(* open Composition_types *)
module Type1 = Plonk_checks.Make (Shifted_value.Type1) (Scalars.Tick)

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () =
  (* let domain = Domain.Pow_2_roots_of_unity 32 in
  let alpha = Backend.Tick.Field.of_int 1 in
  let beta = Backend.Tick.Field.of_int 1 in
  let gamma = Backend.Tick.Field.of_int 1 in
  let joint_combiner = Some (Backend.Tick.Field.of_int 1) in
  let zeta = Backend.Tick.Field.of_int 1 in
  let zetaw =
    Backend.Tick.Field.(
      zeta * domain_generator ~log2_size:(Domain.log2_size domain))
  in *)

  (* let to_field =
       Pickles.Scalar_challenge.to_field_constant
         (module Backend.Tick.Field)
         ~endo:Pickles.Endo.Wrap_inner_curve.scalar
     in
  *)

  (* let prev_evals =
       let e =
         Plonk_types.Evals.map Evaluation_lengths.default ~f:(fun n ->
             (tick_arr n, tick_arr n) )
       in
       let ex =
         { Plonk_types.All_evals.With_public_input.public_input = ([||], [||])
         ; evals = e
         }
       in
       { ft_eval1 = tick (); evals = ex }
     in
  *)

  (*
  let prev_evals =
    let tick_arr len = Array.init len ~f:(fun _ -> tick ()) in
    let e =
      Plonk_types.Evals.map Evaluation_lengths.default ~f:(fun n ->
          (tick_arr n, tick_arr n) )
    in
    let ex =
      { Plonk_types.All_evals.With_public_input.public_input = ([||], [||])
      ; evals = e
      }
    in
    { Plonk_types.All_evals.ft_eval1 = tick (); evals = ex }
  in

  let combined_evals =
    Plonk_checks.evals_of_split_evals
      (module Backend.Tick.Field)
      t.prev_evals.evals.evals
      ~rounds:(Nat.to_int Backend.Tick.Rounds.n)
      ~zeta ~zetaw
    |> Plonk_types.Evals.to_in_circuit
  in

  let plonk_minimal =
    { Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.zeta
    ; alpha
    ; beta
    ; gamma
    ; joint_combiner
    ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
    }
  in

  let env =
    let module Env_bool = struct
      type t = bool

      let true_ = true

      let false_ = false

      let ( &&& ) = ( && )

      let ( ||| ) = ( || )

      let any = List.exists ~f:Fn.id
    end in

    let module Env_field = struct
      include Backend.Tick.Field

      type bool = Env_bool.t

      let if_ (b : bool) ~then_ ~else_ = if b then then_ () else else_ ()
    end in

    Plonk_checks.scalars_env
      (module Env_bool)
      (module Env_field)
      ~srs_length_log2:Pickles.Common.Max_degree.step_log2
      ~zk_rows:3 (* JES: CHECK 3 OK for test? *)
      ~endo:Pickles.Endo.Step_inner_curve.base
      ~mds:Pickles.Tick_field_sponge.params.mds
      ~field_of_hex:(fun s ->
        Kimchi_pasta.Pasta.Bigint256.of_hex_string s
        |> Kimchi_pasta.Pasta.Fp.of_bigint )
      ~domain:
        (Plonk_checks.domain
           (module Backend.Tick.Field)
           ~shifts:Pickles.Common.tick_shifts domain
           ~domain_generator:Backend.Tick.Field.domain_generator )
      plonk_minimal combined_evals
  in *)
  let conditional_gate =
    Kimchi_types.
      [| Cell { col = Index ForeignFieldAdd; row = Curr }
       ; Cell { col = Witness 3; row = Curr }
       ; Dup
       ; Mul
       ; Cell { col = Witness 3; row = Curr }
       ; Sub
       ; Alpha
       ; Pow 1l
       ; Cell { col = Witness 0; row = Curr }
       ; Cell { col = Witness 3; row = Curr }
       ; Cell { col = Witness 1; row = Curr }
       ; Mul
       ; Literal (Pickles.Backend.Tick.Field.of_int 1)
       ; Cell { col = Witness 3; row = Curr }
       ; Sub
       ; Cell { col = Witness 2; row = Curr }
       ; Mul
       ; Add
       ; Sub
       ; Mul
       ; Add
       ; Mul
      |]
  in
  printf "Evaluating...\n" ;
  let _x =
    Type1.evaluate_rpn
      (module Pickles.Backend.Tick.Field)
      ~gate_rpn:conditional_gate
  in
  ()
