module D = Digest
module SC = Scalar_challenge
open Core
open Pickles_types
module Digest = D
open Common

let verify (type a n) (module Max_branching : Nat.Intf with type n = n)
    (module A_value : Intf.Statement_value with type t = a)
    (key : Verification_key.t) (ts : (A_value.t * (n, n) Proof.t) list) =
  let module Marlin = Types.Dlog_based.Proof_state.Deferred_values.Marlin in
  let module Max_local_max_branching = Max_branching in
  let module Max_branching_vec = Vector.With_length (Max_branching) in
  let module MLMB_vec = Vector.With_length (Max_local_max_branching) in
  let module Fp = Impls.Pairing_based.Field.Constant in
  let fp : _ Marlin_checks.field = (module Fp) in
  let check, result =
    let r = ref [] in
    let result () =
      if List.for_all !r ~f:(fun (_lab, b) -> b) then Ok ()
      else
        Error
          (String.concat ~sep:"\n"
             (List.map !r ~f:(fun (lab, b) -> sprintf "%s: %b" lab b)))
    in
    ((fun x -> r := x :: !r), result)
  in
  let _finalized =
    List.iter ts
      ~f:(fun ( app_state
              , { statement
                ; index
                ; prev_x_hat_beta_1= x_hat_beta_1
                ; prev_evals= evals } )
         ->
        Timer.start __LOC__ ;
        let statement =
          {statement with pass_through= {statement.pass_through with app_state}}
        in
        let open Pairing_marlin_types in
        let open Types.Dlog_based.Proof_state in
        let sc = SC.to_field_constant (module Fp) ~endo:Endo.Pairing.scalar in
        Timer.clock __LOC__ ;
        let {Deferred_values.xi; r; marlin; r_xi_sum} =
          Deferred_values.map_challenges ~f:Challenge.Constant.to_fp ~scalar:sc
            statement.proof_state.deferred_values
        in
        let marlin_checks =
          let domains = key.step_domains.(index) in
          let open Marlin_checks in
          checks fp marlin evals ~x_hat_beta_1
            ~input_domain:(domain fp domains.x) ~domain_h:(domain fp domains.h)
            ~domain_k:(domain fp domains.k)
        in
        Timer.clock __LOC__ ;
        let absorb, squeeze =
          let open Fp_sponge.Bits in
          let sponge =
            let s = create Fp_sponge.params in
            absorb s
              (Digest.Constant.to_fp
                 statement.proof_state.sponge_digest_before_evaluations) ;
            s
          in
          let squeeze () =
            sc
              (Scalar_challenge
                 (Challenge.Constant.of_bits
                    (squeeze sponge ~length:Challenge.Constant.length)))
          in
          (absorb sponge, squeeze)
        in
        absorb x_hat_beta_1 ;
        Vector.iter ~f:absorb (Evals.to_vector evals) ;
        let xi_actual = squeeze () in
        let r_actual = squeeze () in
        Timer.clock __LOC__ ;
        let e1, e2, e3 = Evals.to_combined_vectors ~x_hat:x_hat_beta_1 evals in
        Timer.clock __LOC__ ;
        let r_xi_sum_actual =
          let open Fp in
          let combine batch pt without_bound =
            Pcs_batch.combine_evaluations batch ~crs_max_degree ~mul ~add ~one
              ~evaluation_point:pt ~xi without_bound []
          in
          let {Marlin.beta_1= b1; beta_2= b2; beta_3= b3; _} = marlin in
          List.fold ~init:zero
            ~f:(fun acc x -> r * (x + acc))
            [ combine Common.Pairing_pcs_batch.beta_3 b3 e3
            ; combine Common.Pairing_pcs_batch.beta_2 b2 e2
            ; combine Common.Pairing_pcs_batch.beta_1 b1 e1 ]
        in
        Timer.clock __LOC__ ;
        List.iteri marlin_checks ~f:(fun i (x, y) ->
            check (sprintf "marlin %d" i, Fp.equal x y) ) ;
        Timer.clock __LOC__ ;
        List.iter
          ~f:(fun (s, x, y) -> check (s, Fp.equal x y))
          [ ("xi", xi, xi_actual)
          ; ("r", r, r_actual)
          ; ("r_xi_sum", r_xi_sum, r_xi_sum_actual) ] )
  in
  let open Zexe_backend.Dlog_based_proof in
  Common.time "pairing_check" (fun () ->
      check
        ( "pairing_check"
        , Pairing_acc.batch_check
            (List.map ts ~f:(fun (_, t) ->
                 t.statement.proof_state.me_only.pairing_marlin_acc )) ) ) ;
  Common.time "dlog_check" (fun () ->
      check
        ( "dlog_check"
        , batch_verify
            (List.map ts ~f:(fun (app_state, t) ->
                 let prepared_statement : _ Types.Dlog_based.Statement.t =
                   { pass_through=
                       Common.hash_pairing_me_only
                         ~app_state:A_value.to_field_elements
                         (Reduced_me_only.Pairing_based.prepare
                            ~dlog_marlin_index:key.commitments
                            {t.statement.pass_through with app_state})
                   ; proof_state=
                       { t.statement.proof_state with
                         me_only=
                           Common.hash_dlog_me_only
                             (Reduced_me_only.Dlog_based.prepare
                                t.statement.proof_state.me_only) } }
                 in
                 let input =
                   fq_unpadded_public_input_of_statement prepared_statement
                 in
                 ( t.proof
                 , input
                 , Some
                     (Vector.to_list
                        (Vector.map2
                           ~f:(fun g cs ->
                             { Challenge_polynomial.challenges=
                                 Vector.to_array (compute_challenges cs)
                             ; commitment= g } )
                           t.statement.pass_through.sg
                           t.statement.proof_state.me_only
                             .old_bulletproof_challenges)) ) ))
            key.index ) ) ;
  match result () with Ok () -> true | Error _e -> false
