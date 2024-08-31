module SC = Scalar_challenge
module P = Proof
open Pickles_types
open Hlist
open Common
open Import
open Types
open Backend

(* This contains the "wrap" prover *)

let challenge_polynomial =
  Wrap_verifier.challenge_polynomial (module Backend.Tick.Field)

module Type1 =
  Plonk_checks.Make
    (Shifted_value.Type1)
    (struct
      let constant_term = Plonk_checks.Scalars.Tick.constant_term

      let index_terms = Plonk_checks.Scalars.Tick.index_terms
    end)

let _vector_of_list (type a t)
    (module V : Snarky_intf.Vector.S with type elt = a and type t = t)
    (xs : a list) : t =
  let r = V.create () in
  List.iter xs ~f:(V.emplace_back r) ;
  r

let tick_rounds = Nat.to_int Tick.Rounds.n

let combined_inner_product (type actual_proofs_verified) ~env ~domain ~ft_eval1
    ~actual_proofs_verified:
      (module AB : Nat.Add.Intf with type n = actual_proofs_verified)
    (e : (_ array * _ array, _) Plonk_types.All_evals.With_public_input.t)
    ~(old_bulletproof_challenges : (_, actual_proofs_verified) Vector.t) ~r
    ~plonk ~xi ~zeta ~zetaw =
  let combined_evals =
    Plonk_checks.evals_of_split_evals ~zeta ~zetaw
      (module Tick.Field)
      ~rounds:tick_rounds e.evals
  in
  let ft_eval0 : Tick.Field.t =
    Type1.ft_eval0
      (module Tick.Field)
      plonk ~env ~domain
      (Plonk_types.Evals.to_in_circuit combined_evals)
      (fst e.public_input)
  in
  let T = AB.eq in
  let challenge_polys =
    Vector.map
      ~f:(fun chals -> unstage (challenge_polynomial (Vector.to_array chals)))
      old_bulletproof_challenges
  in
  let a = Plonk_types.Evals.to_list e.evals in
  let combine ~which_eval ~ft pt =
    let f (x, y) = match which_eval with `Fst -> x | `Snd -> y in
    let a = List.map ~f a in
    let v : Tick.Field.t array list =
      List.append
        (List.map (Vector.to_list challenge_polys) ~f:(fun f -> [| f pt |]))
        (f e.public_input :: [| ft |] :: a)
    in
    let open Tick.Field in
    Pcs_batch.combine_split_evaluations ~xi ~init:Fn.id
      ~mul_and_add:(fun ~acc ~xi fx -> fx + (xi * acc))
      v
  in
  let open Tick.Field in
  combine ~which_eval:`Fst ~ft:ft_eval0 zeta
  + (r * combine ~which_eval:`Snd ~ft:ft_eval1 zetaw)

module For_tests_only = struct
  type shifted_tick_field =
    Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t

  type scalar_challenge_constant =
    Import.Challenge.Constant.t Import.Scalar_challenge.t

  type deferred_values_and_hints =
    { x_hat_evals : Backend.Tick.Field.t array * Backend.Tick.Field.t array
    ; sponge_digest_before_evaluations : Backend.Tick.Field.t
    ; deferred_values :
        ( ( Import.Challenge.Constant.t
          , scalar_challenge_constant
          , shifted_tick_field
          , (shifted_tick_field, bool) Opt.t
          , (scalar_challenge_constant, bool) Opt.t
          , bool )
          Import.Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t
        , scalar_challenge_constant
        , shifted_tick_field
        , scalar_challenge_constant Import.Bulletproof_challenge.t
          Import.Types.Step_bp_vec.t
        , Import.Branch_data.t )
        Import.Types.Wrap.Proof_state.Deferred_values.t
    }

  let deferred_values (type n)
      ~(sgs : (Backend.Tick.Curve.Affine.t, n) Vector.t) ~actual_feature_flags
      ~(prev_challenges : ((Backend.Tick.Field.t, _) Vector.t, n) Vector.t)
      ~(step_vk : Kimchi_bindings.Protocol.VerifierIndex.Fp.t)
      ~(public_input : Backend.Tick.Field.t list)
      ~(proof : Backend.Tick.Proof.with_public_evals)
      ~(actual_proofs_verified : n Nat.t) : deferred_values_and_hints =
    let module O = Tick.Oracles in
    let o =
      O.create_with_public_evals step_vk
        Vector.(
          map2 sgs prev_challenges ~f:(fun commitment cs ->
              { Tick.Proof.Challenge_polynomial.commitment
              ; challenges = Vector.to_array cs
              } )
          |> to_list)
        public_input proof
    in
    let x_hat =
      match proof.public_evals with
      | Some x ->
          x
      | None ->
          O.([| p_eval_1 o |], [| p_eval_2 o |])
    in
    let scalar_chal f =
      Scalar_challenge.map ~f:Challenge.Constant.of_tick_field (f o)
    in
    let plonk0 =
      { Types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.alpha =
          scalar_chal O.alpha
      ; beta = O.beta o
      ; gamma = O.gamma o
      ; zeta = scalar_chal O.zeta
      ; joint_combiner =
          (* TODO: Needs to be changed when lookups are fully implemented *)
          Option.map (O.joint_combiner_chal o)
            ~f:(Scalar_challenge.map ~f:Challenge.Constant.of_tick_field)
      ; feature_flags = actual_feature_flags
      }
    in
    let r = scalar_chal O.u in
    let xi = scalar_chal O.v in
    let module As_field = struct
      let to_field =
        SC.to_field_constant
          (module Tick.Field)
          ~endo:Endo.Wrap_inner_curve.scalar

      let r = to_field r

      let xi = to_field xi

      let zeta = to_field plonk0.zeta

      let alpha = to_field plonk0.alpha

      let joint_combiner = Option.map ~f:to_field plonk0.joint_combiner
    end in
    let domain = Domain.Pow_2_roots_of_unity step_vk.domain.log_size_of_group in
    let zetaw = Tick.Field.mul As_field.zeta step_vk.domain.group_gen in
    let tick_plonk_minimal =
      { plonk0 with
        zeta = As_field.zeta
      ; alpha = As_field.alpha
      ; joint_combiner = As_field.joint_combiner
      }
    in
    let tick_combined_evals =
      Plonk_checks.evals_of_split_evals
        (module Tick.Field)
        proof.proof.openings.evals ~rounds:(Nat.to_int Tick.Rounds.n)
        ~zeta:As_field.zeta ~zetaw
      |> Plonk_types.Evals.to_in_circuit
    in
    let tick_domain =
      Plonk_checks.domain
        (module Tick.Field)
        domain ~shifts:Common.tick_shifts
        ~domain_generator:Backend.Tick.Field.domain_generator
    in
    let tick_env =
      let module Env_bool = struct
        type t = bool

        let true_ = true

        let false_ = false

        let ( &&& ) = ( && )

        let ( ||| ) = ( || )

        let any = List.exists ~f:Fn.id
      end in
      let module Env_field = struct
        include Tick.Field

        type bool = Env_bool.t

        let if_ (b : bool) ~then_ ~else_ = if b then then_ () else else_ ()
      end in
      Plonk_checks.scalars_env
        (module Env_bool)
        (module Env_field)
        ~endo:Endo.Step_inner_curve.base ~mds:Tick_field_sponge.params.mds
        ~zk_rows:step_vk.zk_rows ~srs_length_log2:Common.Max_degree.step_log2
        ~field_of_hex:(fun s ->
          Kimchi_pasta.Pasta.Bigint256.of_hex_string s
          |> Kimchi_pasta.Pasta.Fp.of_bigint )
        ~domain:tick_domain tick_plonk_minimal tick_combined_evals
    in
    let plonk =
      let module Field = struct
        include Tick.Field
      end in
      Type1.derive_plonk
        (module Field)
        ~shift:Shifts.tick1 ~env:tick_env tick_plonk_minimal tick_combined_evals
    and new_bulletproof_challenges, b =
      let prechals =
        Array.map (O.opening_prechallenges o) ~f:(fun x ->
            Scalar_challenge.map ~f:Challenge.Constant.of_tick_field x )
      in
      let chals =
        Array.map prechals ~f:(fun x -> Ipa.Step.compute_challenge x)
      in
      let challenge_poly = unstage (challenge_polynomial chals) in
      let open As_field in
      let b =
        let open Tick.Field in
        challenge_poly zeta + (r * challenge_poly zetaw)
      in
      let prechals = Array.map prechals ~f:Bulletproof_challenge.unpack in
      (prechals, b)
    in
    let shift_value =
      Shifted_value.Type1.of_field (module Tick.Field) ~shift:Shifts.tick1
    and chal = Challenge.Constant.of_tick_field in
    { deferred_values =
        { Types.Wrap.Proof_state.Deferred_values.xi
        ; b = shift_value b
        ; bulletproof_challenges =
            Vector.of_array_and_length_exn new_bulletproof_challenges
              Tick.Rounds.n
        ; combined_inner_product =
            shift_value
              As_field.(
                combined_inner_product (* Note: We do not pad here. *)
                  ~actual_proofs_verified:
                    (Nat.Add.create actual_proofs_verified)
                  { evals = proof.proof.openings.evals; public_input = x_hat }
                  ~r ~xi ~zeta ~zetaw
                  ~old_bulletproof_challenges:prev_challenges ~env:tick_env
                  ~domain:tick_domain ~ft_eval1:proof.proof.openings.ft_eval1
                  ~plonk:tick_plonk_minimal)
        ; branch_data =
            { proofs_verified =
                ( match actual_proofs_verified with
                | Z ->
                    Branch_data.Proofs_verified.N0
                | S Z ->
                    N1
                | S (S Z) ->
                    N2
                | S _ ->
                    assert false )
            ; domain_log2 =
                Branch_data.Domain_log2.of_int_exn
                  step_vk.domain.log_size_of_group
            }
        ; plonk =
            { plonk with
              zeta = plonk0.zeta
            ; alpha = plonk0.alpha
            ; beta = chal plonk0.beta
            ; gamma = chal plonk0.gamma
            ; joint_combiner = Opt.of_option plonk0.joint_combiner
            }
        }
    ; x_hat_evals = x_hat
    ; sponge_digest_before_evaluations = O.digest_before_evaluations o
    }
end

include For_tests_only
module Step_acc = Tock.Inner_curve.Affine

(* The prover for wrapping a proof *)
let wrap
    (type actual_proofs_verified max_proofs_verified
    max_local_max_proofs_verifieds ) ~proof_cache
    ~(max_proofs_verified : max_proofs_verified Nat.t)
    (module Max_local_max_proof_verifieds : Hlist.Maxes.S
      with type ns = max_local_max_proofs_verifieds
       and type length = max_proofs_verified )
    (( module
      Req ) :
      (max_proofs_verified, max_local_max_proofs_verifieds) Requests.Wrap.t )
    ~dlog_plonk_index wrap_main ~(typ : _ Impls.Step.Typ.t) ~step_vk
    ~actual_wrap_domains ~step_plonk_indices:_ ~feature_flags
    ~actual_feature_flags ?tweak_statement pk
    ({ statement = prev_statement; prev_evals; proof; index = which_index } :
      ( _
      , _
      , (_, actual_proofs_verified) Vector.t
      , (_, actual_proofs_verified) Vector.t
      , max_local_max_proofs_verifieds
        H1.T(P.Base.Messages_for_next_proof_over_same_field.Wrap).t
      , ( (Tock.Field.t, Tock.Field.t array) Plonk_types.All_evals.t
        , max_proofs_verified )
        Vector.t )
      P.Base.Step.t ) =
  let logger = Context_logger.get () in
  [%log internal] "Pickles_wrap_proof" ;
  let messages_for_next_wrap_proof =
    let module M =
      H1.Map
        (P.Base.Messages_for_next_proof_over_same_field.Wrap)
        (P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared)
        (struct
          let f = P.Base.Messages_for_next_proof_over_same_field.Wrap.prepare
        end)
    in
    M.f prev_statement.messages_for_next_wrap_proof
  in
  let prev_statement_with_hashes : _ Types.Step.Statement.t =
    { proof_state =
        { prev_statement.proof_state with
          messages_for_next_step_proof =
            (let to_field_elements =
               let (Typ typ) = typ in
               fun x -> fst (typ.value_to_fields x)
             in
             (* TODO: Careful here... the length of
                old_buletproof_challenges inside the messages_for_next_step_proof
                might not be correct *)
             Common.hash_messages_for_next_step_proof
               ~app_state:to_field_elements
               (P.Base.Messages_for_next_proof_over_same_field.Step.prepare
                  ~dlog_plonk_index
                  prev_statement.proof_state.messages_for_next_step_proof ) )
        }
    ; messages_for_next_wrap_proof =
        (let module M =
           H1.Map
             (P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared)
             (E01 (Digest.Constant))
             (struct
               let f (type n)
                   (m :
                     n
                     P.Base.Messages_for_next_proof_over_same_field.Wrap
                     .Prepared
                     .t ) =
                 Wrap_hack.hash_messages_for_next_wrap_proof
                   (Vector.length m.old_bulletproof_challenges)
                   m
             end)
         in
        let module V = H1.To_vector (Digest.Constant) in
        V.f Max_local_max_proof_verifieds.length
          (M.f messages_for_next_wrap_proof) )
    }
  in
  let handler (Snarky_backendless.Request.With { request; respond }) =
    let open Req in
    let k x = respond (Provide x) in
    match request with
    | Evals ->
        k prev_evals
    | Step_accs ->
        let module M =
          H1.Map
            (P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared)
            (E01 (Step_acc))
            (struct
              let f :
                  type a.
                     a
                     P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared
                     .t
                  -> Step_acc.t =
               fun t -> t.challenge_polynomial_commitment
            end)
        in
        let module V = H1.To_vector (Step_acc) in
        k
          (V.f Max_local_max_proof_verifieds.length
             (M.f messages_for_next_wrap_proof) )
    | Old_bulletproof_challenges ->
        let module M =
          H1.Map
            (P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared)
            (Challenges_vector.Constant)
            (struct
              let f
                  (t :
                    _
                    P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared
                    .t ) =
                t.old_bulletproof_challenges
            end)
        in
        k (M.f messages_for_next_wrap_proof)
    | Messages ->
        k proof.proof.messages
    | Openings_proof ->
        k proof.proof.openings.proof
    | Proof_state ->
        k prev_statement_with_hashes.proof_state
    | Which_branch ->
        k which_index
    | Wrap_domain_indices ->
        let all_possible_domains = Wrap_verifier.all_possible_domains () in
        let wrap_domain_indices =
          Vector.map actual_wrap_domains ~f:(fun domain_size ->
              let domain_index =
                Vector.foldi ~init:0 all_possible_domains
                  ~f:(fun j acc (Pow_2_roots_of_unity domain) ->
                    if Int.equal domain domain_size then j else acc )
              in
              Tock.Field.of_int domain_index )
        in
        k
          (Vector.extend_front_exn wrap_domain_indices max_proofs_verified
             Tock.Field.one )
    | _ ->
        Snarky_backendless.Request.unhandled
  in

  let public_input =
    tick_public_input_of_statement ~max_proofs_verified
      prev_statement_with_hashes
  in
  let prev_challenges =
    Vector.map ~f:Ipa.Step.compute_challenges
      prev_statement.proof_state.messages_for_next_step_proof
        .old_bulletproof_challenges
  in
  let actual_proofs_verified = Vector.length prev_challenges in
  let lte =
    Nat.lte_exn actual_proofs_verified
      (Length.to_nat Max_local_max_proof_verifieds.length)
  in
  let sgs =
    let module M =
      H1.Map
        (P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared)
        (E01 (Tick.Curve.Affine))
        (struct
          let f :
              type n.
                 n P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared.t
              -> _ =
           fun t -> t.challenge_polynomial_commitment
        end)
    in
    let module V = H1.To_vector (Tick.Curve.Affine) in
    Vector.trim_front
      (V.f Max_local_max_proof_verifieds.length
         (M.f messages_for_next_wrap_proof) )
      lte
  in
  [%log internal] "Wrap_compute_deferred_values" ;
  let { deferred_values; x_hat_evals; sponge_digest_before_evaluations } =
    deferred_values ~sgs ~prev_challenges ~step_vk ~public_input ~proof
      ~actual_proofs_verified ~actual_feature_flags
  in
  [%log internal] "Wrap_compute_deferred_values_done" ;
  let next_statement : _ Types.Wrap.Statement.In_circuit.t =
    let messages_for_next_wrap_proof :
        _ P.Base.Messages_for_next_proof_over_same_field.Wrap.t =
      { challenge_polynomial_commitment =
          proof.proof.openings.proof.challenge_polynomial_commitment
      ; old_bulletproof_challenges =
          Vector.map prev_statement.proof_state.unfinalized_proofs ~f:(fun t ->
              t.deferred_values.bulletproof_challenges )
      }
    in
    { proof_state =
        { deferred_values
        ; sponge_digest_before_evaluations =
            Digest.Constant.of_tick_field sponge_digest_before_evaluations
        ; messages_for_next_wrap_proof
        }
    ; messages_for_next_step_proof =
        prev_statement.proof_state.messages_for_next_step_proof
    }
  in
  let next_statement =
    match tweak_statement with
    | None ->
        next_statement
    | Some f ->
        (* For adversarial tests, we want to simulate an adversary creating a
           proof that doesn't match the pickles protocol.
           In order to do this, we pass a function [tweak_statement] that takes
           the valid statement that we computed above and 'tweaks' it so that
           the statement is no longer valid. This modified statement is then
           propagated as part of any later recursion.
        *)
        f next_statement
  in
  let messages_for_next_wrap_proof_prepared =
    P.Base.Messages_for_next_proof_over_same_field.Wrap.prepare
      next_statement.proof_state.messages_for_next_wrap_proof
  in
  let next_accumulator =
    Vector.map2
      (Vector.extend_front_exn
         prev_statement.proof_state.messages_for_next_step_proof
           .challenge_polynomial_commitments max_proofs_verified
         (Lazy.force Dummy.Ipa.Wrap.sg) )
      messages_for_next_wrap_proof_prepared.old_bulletproof_challenges
      ~f:(fun sg chals ->
        { Tock.Proof.Challenge_polynomial.commitment = sg
        ; challenges = Vector.to_array chals
        } )
    |> Wrap_hack.pad_accumulator
  in
  let%map.Promise next_proof =
    let (T (input, conv, _conv_inv)) = Impls.Wrap.input ~feature_flags () in
    Common.time "wrap proof" (fun () ->
        [%log internal] "Wrap_generate_witness_conv" ;
        Impls.Wrap.generate_witness_conv
          ~f:(fun { Impls.Wrap.Proof_inputs.auxiliary_inputs; public_inputs } () ->
            [%log internal] "Backend_tock_proof_create_async" ;
            let create_proof () =
              Backend.Tock.Proof.create_async ~primary:public_inputs
                ~auxiliary:auxiliary_inputs pk ~message:next_accumulator
            in
            let%map.Promise proof =
              match proof_cache with
              | None ->
                  create_proof ()
              | Some proof_cache -> (
                  match
                    Proof_cache.get_wrap_proof proof_cache ~keypair:pk
                      ~public_input:public_inputs
                  with
                  | None ->
                      if
                        Proof_cache.is_env_var_set_requesting_error_for_proofs
                          ()
                      then failwith "Regenerated proof" ;
                      let%map.Promise proof = create_proof () in
                      Proof_cache.set_wrap_proof proof_cache ~keypair:pk
                        ~public_input:public_inputs proof.proof ;
                      proof
                  | Some proof ->
                      Promise.return
                        ( { proof; public_evals = None }
                          : Tock.Proof.with_public_evals ) )
            in
            [%log internal] "Backend_tock_proof_create_async_done" ;
            proof )
          ~input_typ:input
          ~return_typ:(Snarky_backendless.Typ.unit ())
          (fun x () : unit ->
            Impls.Wrap.handle (fun () : unit -> wrap_main (conv x)) handler )
          { messages_for_next_step_proof =
              prev_statement_with_hashes.proof_state
                .messages_for_next_step_proof
          ; proof_state =
              { next_statement.proof_state with
                messages_for_next_wrap_proof =
                  Wrap_hack.hash_messages_for_next_wrap_proof
                    max_proofs_verified messages_for_next_wrap_proof_prepared
              ; deferred_values =
                  { next_statement.proof_state.deferred_values with
                    plonk =
                      { next_statement.proof_state.deferred_values.plonk with
                        joint_combiner =
                          Opt.to_option
                            next_statement.proof_state.deferred_values.plonk
                              .joint_combiner
                      }
                  }
              }
          } )
  in
  [%log internal] "Pickles_wrap_proof_done" ;
  ( { proof = Wrap_wire_proof.of_kimchi_proof next_proof.proof
    ; statement =
        Types.Wrap.Statement.to_minimal next_statement
          ~to_option:Opt.to_option_unsafe
    ; prev_evals =
        { Plonk_types.All_evals.evals =
            { public_input = x_hat_evals; evals = proof.proof.openings.evals }
        ; ft_eval1 = proof.proof.openings.ft_eval1
        }
    }
    : _ P.Base.Wrap.t )
