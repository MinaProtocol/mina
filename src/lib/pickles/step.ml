module SC = Scalar_challenge
open Core_kernel
open Async_kernel
module P = Proof
open Pickles_types
open Poly_types
open Hlist
open Backend
open Tuple_lib
open Import
open Types
open Common

(* This contains the "step" prover *)

module Make
    (A : T0) (A_value : sig
      type t

      val to_field_elements : t -> Tick.Field.t array
    end)
    (Max_proofs_verified : Nat.Add.Intf_transparent) =
struct
  let double_zip = Double.map2 ~f:Core_kernel.Tuple2.create

  module E = struct
    type t = Tock.Field.t array Plonk_types.Evals.t Double.t * Tock.Field.t
  end

  module Plonk_checks = struct
    include Plonk_checks
    module Type1 = Plonk_checks.Make (Shifted_value.Type1) (Scalars.Tick)
    module Type2 = Plonk_checks.Make (Shifted_value.Type2) (Scalars.Tock)
  end

  (* The prover corresponding to the given inductive rule. *)
  let f
      (type (* The maximum number of proofs verified by one of the proof systems verified by this rule :)

               In other words: each of the proofs verified by this rule comes from some pickles proof system.

               The ith one of those proof systems has a maximum number of proofs N_i that is verified by
               a rule in proof system i. max_local_max_proof_verifieds is the max of the N_i.
            *)
      max_local_max_proof_verifieds self_branches prev_vars prev_values
      local_widths local_heights prevs_length ) ?handler
      (T branch_data :
        ( A.t
        , A_value.t
        , Max_proofs_verified.n
        , self_branches
        , prev_vars
        , prev_values
        , local_widths
        , local_heights )
        Step_branch_data.t ) (next_state : A_value.t)
      ~maxes:
        (module Maxes : Pickles_types.Hlist.Maxes.S
          with type length = Max_proofs_verified.n
           and type ns = max_local_max_proof_verifieds )
      ~(prevs_length : (prev_vars, prevs_length) Length.t) ~self ~step_domains
      ~self_dlog_plonk_index pk self_dlog_vk
      (prev_values : prev_values H1.T(Id).t)
      (prev_proofs : (local_widths, local_widths) H2.T(P).t) :
      ( A_value.t
      , (_, Max_proofs_verified.n) Vector.t
      , (_, prevs_length) Vector.t
      , (_, prevs_length) Vector.t
      , _
      , (_, Max_proofs_verified.n) Vector.t )
      P.Base.Step.t
      Promise.t =
    let _, prev_vars_length = branch_data.proofs_verified in
    let T = Length.contr prev_vars_length prevs_length in
    let (module Req) = branch_data.requests in
    let T =
      Hlist.Length.contr (snd branch_data.proofs_verified) prev_vars_length
    in
    let prev_values_length =
      let module L12 = H4.Length_1_to_2 (Tag) in
      L12.f branch_data.rule.prevs prev_vars_length
    in
    let lte = branch_data.lte in
    let module X_hat = struct
      type t = Tock.Field.t Double.t
    end in
    let module Statement_with_hashes = struct
      type t =
        ( Challenge.Constant.t
        , Challenge.Constant.t Scalar_challenge.t
        , Tick.Field.t Shifted_value.Type1.t
        , Tock.Field.t
        , Digest.Constant.t
        , Digest.Constant.t
        , Digest.Constant.t
        , Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
          Step_bp_vec.t
        , Branch_data.t )
        Wrap.Statement.In_circuit.t
    end in
    let challenge_polynomial =
      Tock.Field.(Wrap_verifier.challenge_polynomial ~add ~mul ~one)
    in
    let expand_proof :
        type var value local_max_proofs_verified m.
           Impls.Wrap.Verification_key.t
        -> 'a
        -> value
        -> (local_max_proofs_verified, local_max_proofs_verified) P.t
        -> (var, value, local_max_proofs_verified, m) Tag.t
        -> must_verify:bool
        -> [ `Sg of Tock.Curve.Affine.t ]
           * Unfinalized.Constant.t
           * Statement_with_hashes.t
           * X_hat.t
           * ( value
             , local_max_proofs_verified
             , m )
             Per_proof_witness.Constant.No_app_state.t =
     fun dlog_vk dlog_index app_state (T t) tag ~must_verify ->
      let t =
        { t with
          statement =
            { t.statement with
              pass_through = { t.statement.pass_through with app_state }
            }
        }
      in
      let plonk0 = t.statement.proof_state.deferred_values.plonk in
      let plonk =
        let domain =
          Branch_data.domain t.statement.proof_state.deferred_values.branch_data
        in
        let to_field =
          SC.to_field_constant
            (module Tick.Field)
            ~endo:Endo.Wrap_inner_curve.scalar
        in
        let alpha = to_field plonk0.alpha in
        let zeta = to_field plonk0.zeta in
        let zetaw =
          Tick.Field.(
            zeta * domain_generator ~log2_size:(Domain.log2_size domain))
        in
        let combined_evals =
          Plonk_checks.evals_of_split_evals
            (module Tick.Field)
            (Double.map t.prev_evals.evals ~f:(fun e -> e.evals))
            ~rounds:(Nat.to_int Tick.Rounds.n) ~zeta ~zetaw
        in
        let plonk_minimal =
          { Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal
            .zeta
          ; alpha
          ; beta = Challenge.Constant.to_tick_field plonk0.beta
          ; gamma = Challenge.Constant.to_tick_field plonk0.gamma
          }
        in
        let env =
          Plonk_checks.scalars_env
            (module Tick.Field)
            ~srs_length_log2:Common.Max_degree.step_log2
            ~endo:Endo.Step_inner_curve.base ~mds:Tick_field_sponge.params.mds
            ~field_of_hex:(fun s ->
              Kimchi_pasta.Pasta.Bigint256.of_hex_string s
              |> Kimchi_pasta.Pasta.Fp.of_bigint )
            ~domain:
              (Plonk_checks.domain
                 (module Tick.Field)
                 domain ~shifts:Common.tick_shifts
                 ~domain_generator:Backend.Tick.Field.domain_generator )
            plonk_minimal combined_evals
        in
        time "plonk_checks" (fun () ->
            Plonk_checks.Type1.derive_plonk
              (module Tick.Field)
              ~env ~shift:Shifts.tick1 plonk_minimal combined_evals )
      in
      let data = Types_map.lookup_basic tag in
      let (module Local_max_proofs_verified) = data.max_proofs_verified in
      let T = Local_max_proofs_verified.eq in
      let statement = t.statement in
      let prev_challenges =
        (* TODO: This is redone in the call to Wrap_reduced_me_only.prepare *)
        Vector.map ~f:Ipa.Wrap.compute_challenges
          statement.proof_state.me_only.old_bulletproof_challenges
      in
      let prev_statement_with_hashes :
          ( _
          , _
          , _ Shifted_value.Type1.t
          , _
          , _
          , _
          , _
          , _
          , _ )
          Wrap.Statement.In_circuit.t =
        { pass_through =
            (* TODO: Only do this hashing when necessary *)
            Common.hash_step_me_only
              (Reduced_me_only.Step.prepare ~dlog_plonk_index:dlog_index
                 statement.pass_through )
              ~app_state:data.value_to_field_elements
        ; proof_state =
            { statement.proof_state with
              deferred_values =
                { statement.proof_state.deferred_values with
                  plonk =
                    { plonk with
                      zeta = plonk0.zeta
                    ; alpha = plonk0.alpha
                    ; beta = plonk0.beta
                    ; gamma = plonk0.gamma
                    }
                }
            ; me_only =
                Wrap_hack.hash_dlog_me_only Local_max_proofs_verified.n
                  { old_bulletproof_challenges = prev_challenges
                  ; challenge_polynomial_commitment =
                      statement.proof_state.me_only
                        .challenge_polynomial_commitment
                  }
            }
        }
      in
      let module O = Tock.Oracles in
      let o =
        let public_input =
          tock_public_input_of_statement prev_statement_with_hashes
        in
        O.create dlog_vk
          ( Vector.map2
              (Vector.extend_exn
                 statement.pass_through.challenge_polynomial_commitments
                 Local_max_proofs_verified.n
                 (Lazy.force Dummy.Ipa.Wrap.sg) )
              (* This should indeed have length Max_proofs_verified... No! It should have type Max_proofs_verified_a. That is, the max_proofs_verified specific to a proof of this type...*)
              prev_challenges
              ~f:(fun commitment chals ->
                { Tock.Proof.Challenge_polynomial.commitment
                ; challenges = Vector.to_array chals
                } )
          |> Wrap_hack.pad_accumulator )
          public_input t.proof
      in
      let ((x_hat_1, x_hat_2) as x_hat) = O.(p_eval_1 o, p_eval_2 o) in
      let scalar_chal f =
        Scalar_challenge.map ~f:Challenge.Constant.of_tock_field (f o)
      in
      let plonk0 =
        { Types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.alpha =
            scalar_chal O.alpha
        ; beta = O.beta o
        ; gamma = O.gamma o
        ; zeta = scalar_chal O.zeta
        }
      in
      let xi = scalar_chal O.v in
      let r = scalar_chal O.u in
      let sponge_digest_before_evaluations = O.digest_before_evaluations o in
      let to_field =
        SC.to_field_constant
          (module Tock.Field)
          ~endo:Endo.Step_inner_curve.scalar
      in
      let module As_field = struct
        let r = to_field r

        let xi = to_field xi

        let zeta = to_field plonk0.zeta

        let alpha = to_field plonk0.alpha
      end in
      let w =
        Tock.Field.domain_generator
          ~log2_size:(Domain.log2_size data.wrap_domains.h)
      in
      let zetaw = Tock.Field.mul As_field.zeta w in
      let new_bulletproof_challenges, b =
        let prechals =
          Array.map (O.opening_prechallenges o) ~f:(fun x ->
              Scalar_challenge.map ~f:Challenge.Constant.of_tock_field x )
        in
        let chals =
          Array.map prechals ~f:(fun x -> Ipa.Wrap.compute_challenge x)
        in
        let challenge_polynomial = unstage (challenge_polynomial chals) in
        let open As_field in
        let b =
          let open Tock.Field in
          challenge_polynomial zeta + (r * challenge_polynomial zetaw)
        in
        let prechals =
          Vector.of_list_and_length_exn
            ( Array.map prechals ~f:(fun x ->
                  { Bulletproof_challenge.prechallenge = x } )
            |> Array.to_list )
            Tock.Rounds.n
        in
        (prechals, b)
      in
      let challenge_polynomial_commitment =
        if not must_verify then Ipa.Wrap.compute_sg new_bulletproof_challenges
        else t.proof.openings.proof.challenge_polynomial_commitment
      in
      let witness : _ Per_proof_witness.Constant.No_app_state.t =
        { app_state = ()
        ; proof_state =
            { prev_statement_with_hashes.proof_state with me_only = () }
        ; prev_proof_evals = t.prev_evals
        ; prev_challenge_polynomial_commitments =
            Vector.extend_exn
              t.statement.pass_through.challenge_polynomial_commitments
              Local_max_proofs_verified.n
              (Lazy.force Dummy.Ipa.Wrap.sg)
            (* TODO: This computation is also redone elsewhere. *)
        ; prev_challenges =
            Vector.extend_exn
              (Vector.map t.statement.pass_through.old_bulletproof_challenges
                 ~f:Ipa.Step.compute_challenges )
              Local_max_proofs_verified.n Dummy.Ipa.Step.challenges_computed
        ; wrap_proof =
            { opening =
                { t.proof.openings.proof with challenge_polynomial_commitment }
            ; messages = t.proof.messages
            }
        }
      in
      let tock_domain =
        Plonk_checks.domain
          (module Tock.Field)
          data.wrap_domains.h ~shifts:Common.tock_shifts
          ~domain_generator:Backend.Tock.Field.domain_generator
      in
      let tock_combined_evals =
        Plonk_checks.evals_of_split_evals
          (module Tock.Field)
          t.proof.openings.evals ~rounds:(Nat.to_int Tock.Rounds.n)
          ~zeta:As_field.zeta ~zetaw
      in
      let tock_plonk_minimal =
        { plonk0 with zeta = As_field.zeta; alpha = As_field.alpha }
      in
      let tock_env =
        Plonk_checks.scalars_env
          (module Tock.Field)
          ~domain:tock_domain ~srs_length_log2:Common.Max_degree.wrap_log2
          ~field_of_hex:(fun s ->
            Kimchi_pasta.Pasta.Bigint256.of_hex_string s
            |> Kimchi_pasta.Pasta.Fq.of_bigint )
          ~endo:Endo.Wrap_inner_curve.base ~mds:Tock_field_sponge.params.mds
          tock_plonk_minimal tock_combined_evals
      in
      let combined_inner_product =
        let e1, e2 = t.proof.openings.evals in
        let b_polys =
          Vector.map
            ~f:(fun chals ->
              unstage (challenge_polynomial (Vector.to_array chals)) )
            (Wrap_hack.pad_challenges prev_challenges)
        in
        let open As_field in
        let combine ~ft_eval (x_hat : Tock.Field.t) pt e =
          let a, b = Plonk_types.Evals.(to_vectors (e : _ array t)) in
          let v : (Tock.Field.t array, _) Vector.t =
            Vector.append
              (Vector.map b_polys ~f:(fun f -> [| f pt |]))
              ([| x_hat |] :: [| ft_eval |] :: a)
              (snd (Wrap_hack.Padded_length.add Nat.N26.n))
          in
          let open Tock.Field in
          Pcs_batch.combine_split_evaluations
            (Common.dlog_pcs_batch (Wrap_hack.Padded_length.add Nat.N26.n))
            ~xi ~init:Fn.id ~mul ~last:Array.last
            ~mul_and_add:(fun ~acc ~xi fx -> fx + (xi * acc))
            ~evaluation_point:pt
            ~shifted_pow:(fun deg x ->
              Pcs_batch.pow ~one ~mul x
                Int.(Max_degree.wrap - (deg mod Max_degree.wrap)) )
            v b
        in
        let ft_eval0 =
          Plonk_checks.Type2.ft_eval0
            (module Tock.Field)
            ~domain:tock_domain ~env:tock_env tock_plonk_minimal
            tock_combined_evals x_hat_1
        in
        let open Tock.Field in
        combine ~ft_eval:ft_eval0 x_hat_1 As_field.zeta e1
        + (r * combine ~ft_eval:t.proof.openings.ft_eval1 x_hat_2 zetaw e2)
      in
      let chal = Challenge.Constant.of_tock_field in
      let plonk =
        Plonk_checks.Type2.derive_plonk
          (module Tock.Field)
          ~env:tock_env ~shift:Shifts.tock2 tock_plonk_minimal
          tock_combined_evals
      in
      let shifted_value =
        Shifted_value.Type2.of_field (module Tock.Field) ~shift:Shifts.tock2
      in
      ( `Sg challenge_polynomial_commitment
      , { Types.Step.Proof_state.Per_proof.deferred_values =
            { plonk =
                { plonk with
                  zeta = plonk0.zeta
                ; alpha = plonk0.alpha
                ; beta = chal plonk0.beta
                ; gamma = chal plonk0.gamma
                }
            ; combined_inner_product = shifted_value combined_inner_product
            ; xi
            ; bulletproof_challenges = new_bulletproof_challenges
            ; b = shifted_value b
            }
        ; should_finalize = must_verify
        ; sponge_digest_before_evaluations =
            Digest.Constant.of_tock_field sponge_digest_before_evaluations
        }
      , prev_statement_with_hashes
      , x_hat
      , witness )
    in
    let challenge_polynomial_commitments = ref None in
    let unfinalized_proofs = ref None in
    let statements_with_hashes = ref None in
    let x_hats = ref None in
    let witnesses = ref None in
    let compute_prev_proof_parts inners_must_verify =
      let ( challenge_polynomial_commitments'
          , unfinalized_proofs'
          , statements_with_hashes'
          , x_hats'
          , witnesses' ) =
        let rec go :
            type vars values ns ms k.
               values H1.T(Id).t
            -> (ns, ns) H2.T(Proof).t
            -> (vars, values, ns, ms) H4.T(Tag).t
            -> values H1.T(E01(Bool)).t
            -> (vars, k) Length.t
            -> (Tock.Curve.Affine.t, k) Vector.t
               * (Unfinalized.Constant.t, k) Vector.t
               * (Statement_with_hashes.t, k) Vector.t
               * (X_hat.t, k) Vector.t
               * ( values
                 , ns
                 , ms )
                 H3.T(Per_proof_witness.Constant.No_app_state).t =
         fun app_states ps ts must_verifys l ->
          match (app_states, ps, ts, must_verifys, l) with
          | [], [], [], [], Z ->
              ([], [], [], [], [])
          | ( app_state :: app_states
            , p :: ps
            , t :: ts
            , must_verify :: must_verifys
            , S l ) ->
              let dlog_vk, dlog_index =
                if Type_equal.Id.same self.Tag.id t.id then
                  (self_dlog_vk, self_dlog_plonk_index)
                else
                  let d = Types_map.lookup_basic t in
                  (d.wrap_vk, d.wrap_key)
              in
              let `Sg sg, u, s, x, w =
                expand_proof dlog_vk dlog_index app_state p t ~must_verify
              and sgs, us, ss, xs, ws = go app_states ps ts must_verifys l in
              (sg :: sgs, u :: us, s :: ss, x :: xs, w :: ws)
          | _ :: _, [], _, _, _ ->
              .
          | [], _ :: _, _, _, _ ->
              .
        in
        go prev_values prev_proofs branch_data.rule.prevs inners_must_verify
          prev_vars_length
      in
      challenge_polynomial_commitments := Some challenge_polynomial_commitments' ;
      unfinalized_proofs := Some unfinalized_proofs' ;
      statements_with_hashes := Some statements_with_hashes' ;
      x_hats := Some x_hats' ;
      witnesses := Some witnesses'
    in
    let unfinalized_proofs_extended =
      lazy
        (Vector.extend
           (Option.value_exn !unfinalized_proofs)
           lte Max_proofs_verified.n
           (Unfinalized.Constant.dummy ()) )
    in
    let module Extract = struct
      module type S = sig
        type res

        val f : _ P.t -> res
      end
    end in
    let extract_from_proofs (type res)
        (module Extract : Extract.S with type res = res) =
      let rec go :
          type vars values ns ms len.
             (ns, ns) H2.T(P).t
          -> (values, vars, ns, ms) H4.T(Tag).t
          -> (vars, len) Length.t
          -> (res, len) Vector.t =
       fun prevs tags len ->
        match (prevs, tags, len) with
        | [], [], Z ->
            []
        | t :: prevs, _ :: tags, S len ->
            Extract.f t :: go prevs tags len
      in
      go prev_proofs branch_data.rule.prevs prev_values_length
    in
    let next_statement_me_only : _ Reduced_me_only.Step.t Lazy.t =
      lazy
        (let old_bulletproof_challenges =
           extract_from_proofs
             ( module struct
               type res =
                 Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
                 Step_bp_vec.t

               let f (T t : _ P.t) =
                 t.statement.proof_state.deferred_values.bulletproof_challenges
             end )
         in
         (* Have the sg be available in the opening proof and verify it. *)
         { app_state = next_state
         ; challenge_polynomial_commitments =
             Option.value_exn !challenge_polynomial_commitments
         ; old_bulletproof_challenges
         } )
    in
    let next_me_only_prepared =
      lazy
        (Reduced_me_only.Step.prepare ~dlog_plonk_index:self_dlog_plonk_index
           (Lazy.force next_statement_me_only) )
    in
    let pass_through_padded =
      let rec pad :
          type n k maxes pvals lws lhs.
             (Digest.Constant.t, k) Vector.t
          -> maxes H1.T(Nat).t
          -> (maxes, n) Hlist.Length.t
          -> (Digest.Constant.t, n) Vector.t =
       fun xs maxes l ->
        match (xs, maxes, l) with
        | [], [], Z ->
            []
        | x :: xs, [], Z ->
            assert false
        | x :: xs, _ :: ms, S n ->
            x :: pad xs ms n
        | [], m :: ms, S n ->
            let t : _ Types.Wrap.Proof_state.Me_only.t =
              { challenge_polynomial_commitment = Lazy.force Dummy.Ipa.Step.sg
              ; old_bulletproof_challenges =
                  Vector.init Max_proofs_verified.n ~f:(fun _ ->
                      Dummy.Ipa.Wrap.challenges_computed )
              }
            in
            Wrap_hack.hash_dlog_me_only Max_proofs_verified.n t :: pad [] ms n
      in
      lazy
        (pad
           (Vector.map (Option.value_exn !statements_with_hashes) ~f:(fun s ->
                s.proof_state.me_only ) )
           Maxes.maxes Maxes.length )
    in
    let handler (Snarky_backendless.Request.With { request; respond } as r) =
      let k x = respond (Provide x) in
      match request with
      | Req.Compute_prev_proof_parts inners_must_verify ->
          compute_prev_proof_parts inners_must_verify ;
          k ()
      | Req.Prev_inputs ->
          k prev_values
      | Req.Proof_with_datas ->
          k (Option.value_exn !witnesses)
      | Req.Wrap_index ->
          k self_dlog_plonk_index
      | Req.App_state ->
          k next_state
      | Req.Unfinalized_proofs ->
          k (Lazy.force unfinalized_proofs_extended)
      | Req.Pass_through ->
          k (Lazy.force pass_through_padded)
      | _ -> (
          match handler with
          | Some f ->
              f r
          | None ->
              Snarky_backendless.Request.unhandled )
    in
    let prev_challenge_polynomial_commitments =
      lazy
        (let to_fold_in =
           extract_from_proofs
             ( module struct
               type res = Tick.Curve.Affine.t

               let f (T t : _ P.t) =
                 t.statement.proof_state.me_only.challenge_polynomial_commitment
             end )
         in
         (* emphatically NOT padded with dummies *)
         Vector.(
           map2 to_fold_in
             (Lazy.force next_me_only_prepared).old_bulletproof_challenges
             ~f:(fun commitment chals ->
               { Tick.Proof.Challenge_polynomial.commitment
               ; challenges = Vector.to_array chals
               } )
           |> to_list) )
    in
    let%map.Promise (next_proof : Tick.Proof.t), next_statement_hashed =
      let (T (input, _conv, conv_inv)) =
        Impls.Step.input ~proofs_verified:Max_proofs_verified.n
          ~wrap_rounds:Tock.Rounds.n
      in
      let { Domains.h } =
        List.nth_exn (Vector.to_list step_domains) branch_data.index
      in
      ksprintf Common.time "step-prover %d (%d)" branch_data.index
        (Domain.size h) (fun () ->
          Impls.Step.generate_witness_conv
            ~f:(fun { Impls.Step.Proof_inputs.auxiliary_inputs; public_inputs }
                    next_statement_hashed ->
              let%map.Promise proof =
                Backend.Tick.Proof.create_async ~primary:public_inputs
                  ~auxiliary:auxiliary_inputs
                  ~message:(Lazy.force prev_challenge_polynomial_commitments)
                  pk
              in
              (proof, next_statement_hashed) )
            [] ~return_typ:input
            (fun () ->
              Impls.Step.handle
                (fun () -> conv_inv (branch_data.main ~step_domains ()))
                handler ) )
    in
    let prev_evals =
      extract_from_proofs
        ( module struct
          type res = E.t

          let f (T t : _ P.t) =
            (t.proof.openings.evals, t.proof.openings.ft_eval1)
        end )
    in
    let pass_through =
      let rec go : type a a. (a, a) H2.T(P).t -> a H1.T(P.Base.Me_only.Wrap).t =
        function
        | [] ->
            []
        | T t :: tl ->
            t.statement.proof_state.me_only :: go tl
      in
      go prev_proofs
    in
    let next_statement : _ Types.Step.Statement.t =
      { proof_state =
          { unfinalized_proofs = Lazy.force unfinalized_proofs_extended
          ; me_only = Lazy.force next_statement_me_only
          }
      ; pass_through
      }
    in
    { P.Base.Step.proof = next_proof
    ; statement = next_statement
    ; index = branch_data.index
    ; prev_evals =
        Vector.extend
          (Vector.map2 prev_evals (Option.value_exn !x_hats)
             ~f:(fun (es, ft_eval1) x_hat ->
               Plonk_types.All_evals.
                 { ft_eval1
                 ; evals =
                     Double.map2 es x_hat ~f:(fun es x_hat ->
                         { With_public_input.evals = es; public_input = x_hat } )
                 } ) )
          lte Max_proofs_verified.n Dummy.evals
    }
end
