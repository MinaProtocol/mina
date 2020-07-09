module SC = Scalar_challenge
open Core
open Pickles_types
open Common
open Import
open Types
open Backend
open Tuple_lib

let verify (type a n) (module Max_branching : Nat.Intf with type n = n)
    (module A_value : Intf.Statement_value with type t = a)
    (key : Verification_key.t) (ts : (A_value.t * (n, n) Proof.t) list) =
  let module Marlin = Types.Dlog_based.Proof_state.Deferred_values.Marlin in
  let module Max_local_max_branching = Max_branching in
  let module Max_branching_vec = Vector.With_length (Max_branching) in
  let module MLMB_vec = Vector.With_length (Max_local_max_branching) in
  let module Tick_field = Backend.Tick.Field in
  let tick_field : _ Marlin_checks.field = (module Tick_field) in
  let check, result =
    let r = ref [] in
    let result () =
      match !r with
      | [] ->
          Ok ()
      | _ ->
          Error
            (String.concat ~sep:"\n"
               (List.map !r ~f:(fun lab -> Lazy.force lab)))
    in
    ((fun (lab, b) -> if not b then r := lab :: !r), result)
  in
  let _finalized =
    List.iter ts
      ~f:(fun ( app_state
              , T
                  { statement
                  ; prev_x_hat= (x_hat_beta_1, _, _) as prev_x_hat
                  ; prev_evals= evals } )
         ->
        Timer.start __LOC__ ;
        let statement =
          {statement with pass_through= {statement.pass_through with app_state}}
        in
        let open Pairing_marlin_types in
        let open Types.Dlog_based.Proof_state in
        let sc = SC.to_field_constant tick_field ~endo:Endo.Dum.scalar in
        Timer.clock __LOC__ ;
        let { Deferred_values.xi
            ; marlin
            ; combined_inner_product
            ; which_branch
            ; bulletproof_challenges } =
          Deferred_values.map_challenges ~f:Challenge.Constant.to_tick_field
            ~scalar:sc statement.proof_state.deferred_values
        in
        let step_domains = key.step_domains.(Index.to_int which_branch) in
        let marlin_checks =
          let open Marlin_checks in
          checks tick_field marlin
            (evals_of_split_evals ~rounds:(Nat.to_int Tick.Rounds.n)
               (module Tick.Field)
               (marlin.beta_1, marlin.beta_2, marlin.beta_3)
               evals)
            ~x_hat_beta_1
            ~input_domain:(domain tick_field step_domains.x)
            ~domain_h:(domain tick_field step_domains.h)
            ~domain_k:(domain tick_field step_domains.k)
        in
        Timer.clock __LOC__ ;
        let absorb, squeeze =
          let open Tick_field_sponge.Bits in
          let sponge =
            let s = create Tick_field_sponge.params in
            absorb s
              (Digest.Constant.to_tick_field
                 statement.proof_state.sponge_digest_before_evaluations) ;
            s
          in
          let squeeze () =
            let underlying =
              Challenge.Constant.of_bits
                (squeeze sponge ~length:Challenge.Constant.length)
            in
            sc (Scalar_challenge underlying)
          in
          (absorb sponge, squeeze)
        in
        let absorb_evals (x_hat, e) =
          let xs, ys = Dlog_marlin_types.Evals.to_vectors e in
          List.iter
            Vector.([|x_hat|] :: (to_list xs @ to_list ys))
            ~f:(Array.iter ~f:absorb)
        in
        Triple.(iter ~f:absorb_evals (map2 prev_x_hat evals ~f:Tuple2.create)) ;
        let xi_actual = squeeze () in
        let r_actual = squeeze () in
        Timer.clock __LOC__ ;
        (* TODO: The deferred values "bulletproof_challenges" should get routed
           into a "batch dlog Tick acc verifier" *)
        let actual_branching =
          Vector.length statement.pass_through.old_bulletproof_challenges
        in
        Timer.clock __LOC__ ;
        let combined_inner_product_actual =
          Wrap.combined_inner_product
            ~actual_branching:(Nat.Add.create actual_branching)
            evals ~x_hat:prev_x_hat
            ~old_bulletproof_challenges:
              (Vector.map ~f:Ipa.Step.compute_challenges
                 statement.pass_through.old_bulletproof_challenges)
            ~r:r_actual ~xi ~beta_1:marlin.beta_1 ~beta_2:marlin.beta_2
            ~beta_3:marlin.beta_3 ~step_branch_domains:step_domains
        in
        let check_eq lab x y =
          check
            ( lazy
                (sprintf
                   !"%s: %{sexp:Tick_field.t} != %{sexp:Tick_field.t}"
                   lab x y)
            , Tick_field.equal x y )
        in
        Timer.clock __LOC__ ;
        List.iteri marlin_checks ~f:(fun i (x, y) ->
            ksprintf check_eq "marlin %d" i x y ) ;
        Timer.clock __LOC__ ;
        List.iter
          ~f:(fun (s, x, y) -> check_eq s x y)
          (* Both these values can actually be omitted from the proof on the wire since we recompute them
   anyway. *)
          [ ("xi", xi, xi_actual)
          ; ( "combined_inner_product"
            , combined_inner_product
            , combined_inner_product_actual ) ] )
  in
  let open Backend.Tock.Proof in
  Common.time "batch_step_dlog_check" (fun () ->
      check
        ( lazy "batch_step_dlog_check"
        , Ipa.Step.accumulator_check
            (List.map ts ~f:(fun (_, T t) ->
                 ( t.statement.proof_state.me_only.sg
                 , Ipa.Step.compute_challenges
                     t.statement.proof_state.deferred_values
                       .bulletproof_challenges ) )) ) ) ;
  Common.time "dlog_check" (fun () ->
      check
        ( lazy "dlog_check"
        , batch_verify
            (List.map ts ~f:(fun (app_state, T t) ->
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
                           Common.hash_dlog_me_only Max_branching.n
                             (Reduced_me_only.Dlog_based.prepare
                                t.statement.proof_state.me_only) } }
                 in
                 let input =
                   tock_unpadded_public_input_of_statement prepared_statement
                 in
                 ( t.proof
                 , input
                 , Some
                     (Vector.to_list
                        (Vector.map2
                           ~f:(fun g cs ->
                             { Challenge_polynomial.challenges=
                                 Vector.to_array
                                   (Ipa.Wrap.compute_challenges cs)
                             ; commitment= g } )
                           (Vector.extend_exn t.statement.pass_through.sg
                              Max_branching.n
                              (Lazy.force Dummy.Ipa.Wrap.sg))
                           t.statement.proof_state.me_only
                             .old_bulletproof_challenges)) ) ))
            key.index ) ) ;
  match result () with
  | Ok () ->
      true
  | Error e ->
      eprintf !"bad verify: %s\n%!" e ;
      false
