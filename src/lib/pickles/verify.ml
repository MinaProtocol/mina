module SC = Scalar_challenge
open Core_kernel
open Async_kernel
open Pickles_types
open Common
open Import
open Backend
open Tuple_lib

module Instance = struct
  type t =
    | T :
        (module Nat.Intf with type n = 'n)
        * (module Intf.Statement_value with type t = 'a)
        * Verification_key.t
        * 'a
        * ('n, 'n) Proof.t
        -> t
end

(* TODO: Just stick this in plonk_checks.ml *)
module Plonk_checks = struct
  include Plonk_checks
  module Type1 =
    Plonk_checks.Make (Shifted_value.Type1) (Plonk_checks.Scalars.Tick)
  module Type2 =
    Plonk_checks.Make (Shifted_value.Type2) (Plonk_checks.Scalars.Tock)
end

let verify_heterogenous (ts : Instance.t list) =
  let module Plonk = Types.Wrap.Proof_state.Deferred_values.Plonk in
  let module Tick_field = Backend.Tick.Field in
  let tick_field : _ Plonk_checks.field = (module Tick_field) in
  let check, result =
    let r = ref [] in
    let result () =
      match !r with
      | [] ->
          Ok ()
      | _ ->
          Error
            (String.concat ~sep:"\n"
               (List.map !r ~f:(fun lab -> Lazy.force lab)) )
    in
    ((fun (lab, b) -> if not b then r := lab :: !r), result)
  in
  let in_circuit_plonks, computed_bp_chals =
    List.map ts
      ~f:(fun
           (T
             ( _max_proofs_verified
             , _statement
             , key
             , app_state
             , T
                 { statement
                   (* TODO
                      ; prev_x_hat = (x_hat1, _) as prev_x_hat
                   *)
                 ; prev_evals = evals
                 } ) )
         ->
        Timer.start __LOC__ ;
        let statement =
          { statement with
            pass_through = { statement.pass_through with app_state }
          }
        in
        let open Types.Wrap.Proof_state in
        let sc =
          SC.to_field_constant tick_field ~endo:Endo.Wrap_inner_curve.scalar
        in
        Timer.clock __LOC__ ;
        let { Deferred_values.xi
            ; plonk = plonk0
            ; combined_inner_product
            ; branch_data
            ; bulletproof_challenges
            ; b
            } =
          Deferred_values.map_challenges ~f:Challenge.Constant.to_tick_field
            ~scalar:sc statement.proof_state.deferred_values
        in
        let zeta = sc plonk0.zeta in
        let alpha = sc plonk0.alpha in
        let step_domain = Branch_data.domain branch_data in
        let w =
          Tick.Field.domain_generator ~log2_size:(Domain.log2_size step_domain)
        in
        let zetaw = Tick.Field.mul zeta w in
        let tick_plonk_minimal :
            _ Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t
            =
          let chal = Challenge.Constant.to_tick_field in
          { zeta
          ; alpha
          ; beta = chal plonk0.beta
          ; gamma = chal plonk0.gamma
          ; joint_combiner = Option.map ~f:sc plonk0.joint_combiner
          }
        in
        let tick_combined_evals =
          Plonk_checks.evals_of_split_evals
            (module Tick.Field)
            evals.evals.evals ~rounds:(Nat.to_int Tick.Rounds.n) ~zeta ~zetaw
          |> Plonk_types.Evals.to_in_circuit
        in
        let tick_domain =
          Plonk_checks.domain
            (module Tick.Field)
            step_domain ~shifts:Common.tick_shifts
            ~domain_generator:Backend.Tick.Field.domain_generator
        in
        let tick_env =
          Plonk_checks.scalars_env
            (module Tick.Field)
            ~endo:Endo.Step_inner_curve.base ~mds:Tick_field_sponge.params.mds
            ~srs_length_log2:Common.Max_degree.step_log2
            ~field_of_hex:(fun s ->
              Kimchi_pasta.Pasta.Bigint256.of_hex_string s
              |> Kimchi_pasta.Pasta.Fp.of_bigint )
            ~domain:tick_domain tick_plonk_minimal tick_combined_evals
        in
        let plonk =
          let p =
            Plonk_checks.Type1.derive_plonk
              (module Tick.Field)
              ~shift:Shifts.tick1 ~env:tick_env tick_plonk_minimal
              tick_combined_evals
          in
          { p with
            zeta = plonk0.zeta
          ; alpha = plonk0.alpha
          ; beta = plonk0.beta
          ; gamma = plonk0.gamma
          ; lookup =
              Option.map (Plonk_types.Opt.to_option p.lookup) ~f:(fun l ->
                  { Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit
                    .Lookup
                    .lookup_gate = l.lookup_gate
                  ; joint_combiner = Option.value_exn plonk0.joint_combiner
                  } )
          }
        in
        Timer.clock __LOC__ ;
        let absorb, squeeze =
          let open Tick_field_sponge.Bits in
          let sponge =
            let s = create Tick_field_sponge.params in
            absorb s
              (Digest.Constant.to_tick_field
                 statement.proof_state.sponge_digest_before_evaluations ) ;
            s
          in
          let squeeze () =
            let underlying =
              Challenge.Constant.of_bits
                (squeeze sponge ~length:Challenge.Constant.length)
            in
            sc (Scalar_challenge.create underlying)
          in
          (absorb sponge, squeeze)
        in
        let old_bulletproof_challenges =
          Vector.map ~f:Ipa.Step.compute_challenges
            statement.pass_through.old_bulletproof_challenges
        in
        (let challenges_digest =
           let open Tick_field_sponge.Field in
           let sponge = create Tick_field_sponge.params in
           Vector.iter old_bulletproof_challenges
             ~f:(Vector.iter ~f:(absorb sponge)) ;
           squeeze sponge
         in
         absorb challenges_digest ;
         absorb evals.ft_eval1 ;
         let xs = Plonk_types.Evals.to_absorption_sequence evals.evals.evals in
         let x1, x2 = evals.evals.public_input in
         absorb x1 ;
         absorb x2 ;
         List.iter xs ~f:(fun (x1, x2) ->
             Array.iter ~f:absorb x1 ; Array.iter ~f:absorb x2 ) ) ;
        let xi_actual = squeeze () in
        let r_actual = squeeze () in
        Timer.clock __LOC__ ;
        (* TODO: The deferred values "bulletproof_challenges" should get routed
           into a "batch dlog Tick acc verifier" *)
        let actual_proofs_verified = Vector.length old_bulletproof_challenges in
        Timer.clock __LOC__ ;
        let combined_inner_product_actual =
          Wrap.combined_inner_product ~env:tick_env ~plonk:tick_plonk_minimal
            ~domain:tick_domain ~ft_eval1:evals.ft_eval1
            ~actual_proofs_verified:(Nat.Add.create actual_proofs_verified)
            evals.evals ~old_bulletproof_challenges ~r:r_actual ~xi ~zeta ~zetaw
        in
        let check_eq lab x y =
          check
            ( lazy
                (sprintf
                   !"%s: %{sexp:Tick_field.t} != %{sexp:Tick_field.t}"
                   lab x y )
            , Tick_field.equal x y )
        in
        Timer.clock __LOC__ ;
        let bulletproof_challenges =
          Ipa.Step.compute_challenges bulletproof_challenges
        in
        Timer.clock __LOC__ ;
        let shifted_value =
          Shifted_value.Type1.to_field (module Tick.Field) ~shift:Shifts.tick1
        in
        let b_actual =
          let challenge_poly =
            unstage
              (Wrap.challenge_polynomial
                 (Vector.to_array bulletproof_challenges) )
          in
          Tick.Field.(challenge_poly zeta + (r_actual * challenge_poly zetaw))
        in
        List.iter
          ~f:(fun (s, x, y) -> check_eq s x y)
          (* Both these values can actually be omitted from the proof on the wire since we recompute them
             anyway. *)
          [ ("xi", xi, xi_actual)
          ; ( "combined_inner_product"
            , shifted_value combined_inner_product
            , combined_inner_product_actual )
          ; ("b", shifted_value b, b_actual)
          ] ;
        (plonk, bulletproof_challenges) )
    |> List.unzip
  in
  let open Backend.Tock.Proof in
  let open Promise.Let_syntax in
  let%bind accumulator_check =
    Ipa.Step.accumulator_check
      (List.map ts ~f:(fun (T (_, _, _, _, T t)) ->
           ( t.statement.proof_state.me_only.challenge_polynomial_commitment
           , Ipa.Step.compute_challenges
               t.statement.proof_state.deferred_values.bulletproof_challenges ) )
      )
  in
  Common.time "batch_step_dlog_check" (fun () ->
      check (lazy "batch_step_dlog_check", accumulator_check) ) ;
  let%map dlog_check =
    batch_verify
      (List.map2_exn ts in_circuit_plonks
         ~f:(fun
              (T
                ( (module Max_proofs_verified)
                , (module A_value)
                , key
                , app_state
                , T t ) )
              plonk
            ->
           let prepared_statement : _ Types.Wrap.Statement.In_circuit.t =
             { pass_through =
                 Common.hash_messages_for_next_step_proof
                   ~app_state:A_value.to_field_elements
                   (Reduced_me_only.Step.prepare
                      ~dlog_plonk_index:key.commitments
                      { t.statement.pass_through with app_state } )
             ; proof_state =
                 { t.statement.proof_state with
                   deferred_values =
                     { t.statement.proof_state.deferred_values with plonk }
                 ; me_only =
                     Wrap_hack.hash_messages_for_next_wrap_proof
                       Max_proofs_verified.n
                       (Reduced_me_only.Wrap.prepare
                          t.statement.proof_state.me_only )
                 }
             }
           in
           let input =
             tock_unpadded_public_input_of_statement prepared_statement
           in
           ( key.index
           , t.proof
           , input
           , Some
               (Wrap_hack.pad_accumulator
                  (Vector.map2
                     ~f:(fun g cs ->
                       { Challenge_polynomial.challenges =
                           Vector.to_array (Ipa.Wrap.compute_challenges cs)
                       ; commitment = g
                       } )
                     (Vector.extend_exn
                        t.statement.pass_through
                          .challenge_polynomial_commitments
                        Max_proofs_verified.n
                        (Lazy.force Dummy.Ipa.Wrap.sg) )
                     t.statement.proof_state.me_only.old_bulletproof_challenges ) )
           ) ) )
  in
  Common.time "dlog_check" (fun () -> check (lazy "dlog_check", dlog_check)) ;
  match result () with
  | Ok () ->
      true
  | Error e ->
      eprintf !"bad verify: %s\n%!" e ;
      false

let verify (type a return_typ n)
    (max_proofs_verified : (module Nat.Intf with type n = n))
    (a_value : (module Intf.Statement_value with type t = a))
    (key : Verification_key.t) (ts : (a * (n, n) Proof.t) list) =
  verify_heterogenous
    (List.map ts ~f:(fun (x, p) ->
         Instance.T (max_proofs_verified, a_value, key, x, p) ) )
