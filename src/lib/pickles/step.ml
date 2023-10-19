module SC = Scalar_challenge
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
    end)
    (Max_proofs_verified : Nat.Add.Intf_transparent) =
struct
  let _double_zip = Double.map2 ~f:Core_kernel.Tuple2.create

  module E = struct
    type t = Tock.Field.t array Double.t Plonk_types.Evals.t * Tock.Field.t
  end

  module Plonk_checks = struct
    include Plonk_checks
    module Type1 = Plonk_checks.Make (Shifted_value.Type1) (Scalars.Tick)
    module Type1_override_ffadd =
      Plonk_checks.Make (Shifted_value.Type1) (Scalars.Tick_with_override)
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
      local_widths local_heights prevs_length var value ret_var ret_value
      auxiliary_var auxiliary_value ) ?handler ~proof_cache
      (T branch_data :
        ( A.t
        , A_value.t
        , ret_var
        , ret_value
        , auxiliary_var
        , auxiliary_value
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
      ~feature_flags ~self_dlog_plonk_index
      ~(public_input :
         ( var
         , value
         , A.t
         , A_value.t
         , ret_var
         , ret_value )
         Inductive_rule.public_input )
      ~(auxiliary_typ : (auxiliary_var, auxiliary_value) Impls.Step.Typ.t) pk
      self_dlog_vk :
      ( ( value
        , (_, Max_proofs_verified.n) Vector.t
        , (_, prevs_length) Vector.t
        , (_, prevs_length) Vector.t
        , _
        , (_, Max_proofs_verified.n) Vector.t )
        Proof.Base.Step.t
      * ret_value
      * auxiliary_value
      * (int, prevs_length) Vector.t )
      Promise.t =
    let logger = Internal_tracing_context_logger.get () in
    [%log internal] "Pickles_step_proof" ;
    let _ = auxiliary_typ in
    (* unused *)
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
        , Tick.Field.t Shifted_value.Type1.t option
        , Challenge.Constant.t Scalar_challenge.t option
        , bool
        , Digest.Constant.t
        , Digest.Constant.t
        , Digest.Constant.t
        , Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
          Step_bp_vec.t
        , Branch_data.t )
        Wrap.Statement.In_circuit.t
    end in
    let challenge_polynomial =
      Wrap_verifier.challenge_polynomial (module Backend.Tock.Field)
    in
    let expand_proof :
        type var value local_max_proofs_verified m.
           Impls.Wrap.Verification_key.t
        -> _ array Plonk_verification_key_evals.t
        -> value
        -> (local_max_proofs_verified, local_max_proofs_verified) Proof.t
        -> (var, value, local_max_proofs_verified, m) Tag.t
        -> must_verify:bool
        -> [ `Sg of Tock.Curve.Affine.t ]
           * Unfinalized.Constant.t
           * Statement_with_hashes.t
           * X_hat.t
           * ( value
             , local_max_proofs_verified
             , m )
             Per_proof_witness.Constant.No_app_state.t
           * [ `Actual_wrap_domain of int ] =
     fun dlog_vk dlog_index app_state (T t) tag ~must_verify ->
      let t =
        { t with
          statement =
            { t.statement with
              messages_for_next_step_proof =
                { t.statement.messages_for_next_step_proof with app_state }
            }
        }
      in
      let proof = Wrap_wire_proof.to_kimchi_proof t.proof in
      let data = Types_map.lookup_basic tag in
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
            t.prev_evals.evals.evals ~rounds:(Nat.to_int Tick.Rounds.n) ~zeta
            ~zetaw
          |> Plonk_types.Evals.to_in_circuit
        in
        let plonk_minimal =
          { Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal
            .zeta
          ; alpha
          ; beta = Challenge.Constant.to_tick_field plonk0.beta
          ; gamma = Challenge.Constant.to_tick_field plonk0.gamma
          ; joint_combiner = Option.map ~f:to_field plonk0.joint_combiner
          ; feature_flags = plonk0.feature_flags
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
            include Tick.Field

            type bool = Env_bool.t

            let if_ (b : bool) ~then_ ~else_ = if b then then_ () else else_ ()
          end in
          Plonk_checks.scalars_env
            (module Env_bool)
            (module Env_field)
            ~srs_length_log2:Common.Max_degree.step_log2 ~zk_rows:data.zk_rows
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
            let module Field = struct
              include Tick.Field
            end in
            ( if data.override_ffadd then
              Plonk_checks.Type1_override_ffadd.derive_plonk
            else Plonk_checks.Type1.derive_plonk )
              (module Field)
              ~env ~shift:Shifts.tick1 plonk_minimal combined_evals )
      in
      let (module Local_max_proofs_verified) = data.max_proofs_verified in
      let T = Local_max_proofs_verified.eq in
      let statement = t.statement in
      let prev_challenges =
        (* TODO: This is redone in the call to Reduced_messages_for_next_proof_over_same_field.Wrap.prepare *)
        Vector.map ~f:Ipa.Wrap.compute_challenges
          statement.proof_state.messages_for_next_wrap_proof
            .old_bulletproof_challenges
      in
      let deferred_values_computed =
        Wrap_deferred_values.expand_deferred ~evals:t.prev_evals
          ~override_ffadd:data.override_ffadd
          ~old_bulletproof_challenges:
            statement.messages_for_next_step_proof.old_bulletproof_challenges
          ~zk_rows:data.zk_rows ~proof_state:statement.proof_state
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
          , _
          , _
          , _ )
          Wrap.Statement.In_circuit.t =
        { messages_for_next_step_proof =
            (let to_field_elements =
               let (Typ typ) = data.public_input in
               fun x -> fst (typ.value_to_fields x)
             in
             (* TODO: Only do this hashing when necessary *)
             Common.hash_messages_for_next_step_proof
               (Reduced_messages_for_next_proof_over_same_field.Step.prepare
                  ~dlog_plonk_index:dlog_index
                  statement.messages_for_next_step_proof )
               ~app_state:to_field_elements )
        ; proof_state =
            { deferred_values =
                (let deferred_values = deferred_values_computed in
                 { plonk =
                     { plonk with
                       zeta = plonk0.zeta
                     ; alpha = plonk0.alpha
                     ; beta = plonk0.beta
                     ; gamma = plonk0.gamma
                     ; joint_combiner = plonk0.joint_combiner
                     }
                 ; combined_inner_product =
                     deferred_values.combined_inner_product
                 ; b = deferred_values.b
                 ; xi = deferred_values.xi
                 ; bulletproof_challenges =
                     statement.proof_state.deferred_values
                       .bulletproof_challenges
                 ; branch_data = deferred_values.branch_data
                 } )
            ; sponge_digest_before_evaluations =
                statement.proof_state.sponge_digest_before_evaluations
            ; messages_for_next_wrap_proof =
                Wrap_hack.hash_messages_for_next_wrap_proof
                  Local_max_proofs_verified.n
                  { old_bulletproof_challenges = prev_challenges
                  ; challenge_polynomial_commitment =
                      statement.proof_state.messages_for_next_wrap_proof
                        .challenge_polynomial_commitment
                  }
            }
        }
      in
      let module O = Tock.Oracles in
      let o =
        let public_input =
          tock_public_input_of_statement ~feature_flags
            prev_statement_with_hashes
        in
        O.create dlog_vk
          ( Vector.map2
              (Vector.extend_front_exn
                 statement.messages_for_next_step_proof
                   .challenge_polynomial_commitments Local_max_proofs_verified.n
                 (Lazy.force Dummy.Ipa.Wrap.sg) )
              (* This should indeed have length Max_proofs_verified... No! It should have type Max_proofs_verified_a. That is, the max_proofs_verified specific to a proof of this type...*)
              prev_challenges
              ~f:(fun commitment chals ->
                { Tock.Proof.Challenge_polynomial.commitment
                ; challenges = Vector.to_array chals
                } )
          |> Wrap_hack.pad_accumulator )
          public_input proof
      in
      let ((x_hat_1, _x_hat_2) as x_hat) = O.(p_eval_1 o, p_eval_2 o) in
      let scalar_chal f =
        Scalar_challenge.map ~f:Challenge.Constant.of_tock_field (f o)
      in
      let plonk0 =
        { Types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.alpha =
            scalar_chal O.alpha
        ; beta = O.beta o
        ; gamma = O.gamma o
        ; zeta = scalar_chal O.zeta
        ; joint_combiner =
            Option.map
              ~f:(Scalar_challenge.map ~f:Challenge.Constant.of_tock_field)
              (O.joint_combiner_chal o)
        ; feature_flags =
            t.statement.proof_state.deferred_values.plonk.feature_flags
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

        let joint_combiner = O.joint_combiner o
      end in
      let w =
        Tock.Field.domain_generator ~log2_size:dlog_vk.domain.log_size_of_group
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
            (Array.map prechals ~f:Bulletproof_challenge.unpack |> Array.to_list)
            Tock.Rounds.n
        in
        (prechals, b)
      in
      let challenge_polynomial_commitment =
        if not must_verify then Ipa.Wrap.compute_sg new_bulletproof_challenges
        else proof.openings.proof.challenge_polynomial_commitment
      in
      let witness : _ Per_proof_witness.Constant.No_app_state.t =
        { app_state = ()
        ; proof_state =
            { prev_statement_with_hashes.proof_state with
              messages_for_next_wrap_proof = ()
            }
        ; prev_proof_evals = t.prev_evals
        ; prev_challenge_polynomial_commitments =
            Vector.extend_front_exn
              t.statement.messages_for_next_step_proof
                .challenge_polynomial_commitments Local_max_proofs_verified.n
              (Lazy.force Dummy.Ipa.Wrap.sg)
            (* TODO: This computation is also redone elsewhere. *)
        ; prev_challenges =
            Vector.extend_front_exn
              (Vector.map
                 t.statement.messages_for_next_step_proof
                   .old_bulletproof_challenges ~f:Ipa.Step.compute_challenges )
              Local_max_proofs_verified.n
              (Lazy.force Dummy.Ipa.Step.challenges_computed)
        ; wrap_proof =
            { opening =
                { proof.openings.proof with challenge_polynomial_commitment }
            ; messages = proof.messages
            }
        }
      in
      let tock_domain =
        Plonk_checks.domain
          (module Tock.Field)
          (Pow_2_roots_of_unity dlog_vk.domain.log_size_of_group)
          ~shifts:Common.tock_shifts
          ~domain_generator:Backend.Tock.Field.domain_generator
      in
      let tock_combined_evals =
        Plonk_checks.evals_of_split_evals
          (module Tock.Field)
          proof.openings.evals ~rounds:(Nat.to_int Tock.Rounds.n)
          ~zeta:As_field.zeta ~zetaw
        |> Plonk_types.Evals.to_in_circuit
      in
      let tock_plonk_minimal =
        { plonk0 with
          zeta = As_field.zeta
        ; alpha = As_field.alpha
        ; joint_combiner = As_field.joint_combiner
        }
      in
      let tock_env =
        let module Env_bool = struct
          type t = bool

          let true_ = true

          let false_ = false

          let ( &&& ) = ( && )

          let ( ||| ) = ( || )

          let any = List.exists ~f:Fn.id
        end in
        let module Env_field = struct
          include Tock.Field

          type bool = Env_bool.t

          let if_ (b : bool) ~then_ ~else_ = if b then then_ () else else_ ()
        end in
        Plonk_checks.scalars_env
          (module Env_bool)
          (module Env_field)
          ~domain:tock_domain ~srs_length_log2:Common.Max_degree.wrap_log2
          ~zk_rows:3
          ~field_of_hex:(fun s ->
            Kimchi_pasta.Pasta.Bigint256.of_hex_string s
            |> Kimchi_pasta.Pasta.Fq.of_bigint )
          ~endo:Endo.Wrap_inner_curve.base ~mds:Tock_field_sponge.params.mds
          tock_plonk_minimal tock_combined_evals
      in
      let combined_inner_product =
        let e = proof.openings.evals in
        let b_polys =
          Vector.map
            ~f:(fun chals ->
              unstage (challenge_polynomial (Vector.to_array chals)) )
            (Wrap_hack.pad_challenges prev_challenges)
        in
        let a = Plonk_types.Evals.to_list e in
        let open As_field in
        let combine ~which_eval ~ft_eval pt =
          let f (x, y) = match which_eval with `Fst -> x | `Snd -> y in
          let v : Tock.Field.t array list =
            let a = List.map ~f a in
            List.append
              (Vector.to_list (Vector.map b_polys ~f:(fun f -> [| f pt |])))
              ([| f x_hat |] :: [| ft_eval |] :: a)
          in
          let open Tock.Field in
          Pcs_batch.combine_split_evaluations ~xi ~init:Fn.id
            ~mul_and_add:(fun ~acc ~xi fx -> fx + (xi * acc))
            v
        in
        let ft_eval0 =
          Plonk_checks.Type2.ft_eval0
            (module Tock.Field)
            ~domain:tock_domain ~env:tock_env tock_plonk_minimal
            tock_combined_evals [| x_hat_1 |]
        in
        let open Tock.Field in
        combine ~which_eval:`Fst ~ft_eval:ft_eval0 As_field.zeta
        + (r * combine ~which_eval:`Snd ~ft_eval:proof.openings.ft_eval1 zetaw)
      in
      let chal = Challenge.Constant.of_tock_field in
      let plonk =
        let module Field = struct
          include Tock.Field
        end in
        (* Wrap proof, no features *)
        Plonk_checks.Type2.derive_plonk
          (module Field)
          ~env:tock_env ~shift:Shifts.tock2 tock_plonk_minimal
          tock_combined_evals
        |> Composition_types.Step.Proof_state.Deferred_values.Plonk.In_circuit
           .of_wrap
             ~assert_none:(fun x -> assert (Option.is_none (Opt.to_option x)))
             ~assert_false:(fun x -> assert (not x))
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
      , witness
      , `Actual_wrap_domain dlog_vk.domain.log_size_of_group )
    in
    let challenge_polynomial_commitments = ref None in
    let unfinalized_proofs = ref None in
    let statements_with_hashes = ref None in
    let x_hats = ref None in
    let witnesses = ref None in
    let prev_proofs = ref None in
    let return_value = ref None in
    let auxiliary_value = ref None in
    let actual_wrap_domains = ref None in
    let compute_prev_proof_parts prev_proof_requests =
      let ( challenge_polynomial_commitments'
          , unfinalized_proofs'
          , statements_with_hashes'
          , x_hats'
          , witnesses'
          , prev_proofs'
          , actual_wrap_domains' ) =
        let[@warning "-4"] rec go :
            type vars values ns ms k.
               (vars, values, ns, ms) H4.T(Tag).t
            -> ( values
               , ns )
               H2.T(Inductive_rule.Previous_proof_statement.Constant).t
            -> (vars, k) Length.t
            -> (Tock.Curve.Affine.t, k) Vector.t
               * (Unfinalized.Constant.t, k) Vector.t
               * (Statement_with_hashes.t, k) Vector.t
               * (X_hat.t, k) Vector.t
               * ( values
                 , ns
                 , ms )
                 H3.T(Per_proof_witness.Constant.No_app_state).t
               * (ns, ns) H2.T(Proof).t
               * (int, k) Vector.t =
         fun ts prev_proof_stmts l ->
          match (ts, prev_proof_stmts, l) with
          | [], [], Z ->
              ([], [], [], [], [], [], [])
          | ( t :: ts
            , { public_input = app_state
              ; proof = p
              ; proof_must_verify = must_verify
              }
              :: prev_proof_stmts
            , S l ) ->
              let dlog_vk, dlog_index =
                if Type_equal.Id.same self.Tag.id t.id then
                  (self_dlog_vk, self_dlog_plonk_index)
                else
                  let d = Types_map.lookup_basic t in
                  (d.wrap_vk, d.wrap_key)
              in
              let `Sg sg, u, s, x, w, `Actual_wrap_domain domain =
                expand_proof dlog_vk dlog_index app_state p t ~must_verify
              and sgs, us, ss, xs, ws, ps, domains = go ts prev_proof_stmts l in
              ( sg :: sgs
              , u :: us
              , s :: ss
              , x :: xs
              , w :: ws
              , p :: ps
              , domain :: domains )
          | _, _ :: _, _ ->
              .
          | _, [], _ ->
              .
        in
        go branch_data.rule.prevs prev_proof_requests prev_vars_length
      in
      challenge_polynomial_commitments := Some challenge_polynomial_commitments' ;
      unfinalized_proofs := Some unfinalized_proofs' ;
      statements_with_hashes := Some statements_with_hashes' ;
      x_hats := Some x_hats' ;
      witnesses := Some witnesses' ;
      prev_proofs := Some prev_proofs' ;
      actual_wrap_domains := Some actual_wrap_domains'
    in
    let unfinalized_proofs = lazy (Option.value_exn !unfinalized_proofs) in
    let unfinalized_proofs_extended =
      lazy
        (Vector.extend_front
           (Lazy.force unfinalized_proofs)
           lte Max_proofs_verified.n
           (Lazy.force Unfinalized.Constant.dummy) )
    in
    let module Extract = struct
      module type S = sig
        type res

        val f : _ Proof.t -> res
      end
    end in
    let extract_from_proofs (type res)
        (module Extract : Extract.S with type res = res) =
      let rec go :
          type vars values ns ms len.
             (ns, ns) H2.T(Proof).t
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
      go
        (Option.value_exn !prev_proofs)
        branch_data.rule.prevs prev_values_length
    in
    let messages_for_next_step_proof :
        _ Reduced_messages_for_next_proof_over_same_field.Step.t Lazy.t =
      lazy
        (let old_bulletproof_challenges =
           extract_from_proofs
             ( module struct
               type res =
                 Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
                 Step_bp_vec.t

               let f (T t : _ Proof.t) =
                 t.statement.proof_state.deferred_values.bulletproof_challenges
             end )
         in
         let (return_value : ret_value) = Option.value_exn !return_value in
         let (app_state : value) =
           match public_input with
           | Input _ ->
               next_state
           | Output _ ->
               return_value
           | Input_and_output _ ->
               (next_state, return_value)
         in
         (* Have the sg be available in the opening proof and verify it. *)
         { app_state
         ; challenge_polynomial_commitments =
             Option.value_exn !challenge_polynomial_commitments
         ; old_bulletproof_challenges
         } )
    in
    let messages_for_next_step_proof_prepared =
      lazy
        (Reduced_messages_for_next_proof_over_same_field.Step.prepare
           ~dlog_plonk_index:self_dlog_plonk_index
           (Lazy.force messages_for_next_step_proof) )
    in
    let messages_for_next_wrap_proof_padded =
      let rec pad :
          type n k maxes.
             (Digest.Constant.t, k) Vector.t
          -> maxes H1.T(Nat).t
          -> (maxes, n) Hlist.Length.t
          -> (Digest.Constant.t, n) Vector.t =
       fun xs maxes l ->
        match (xs, maxes, l) with
        | [], [], Z ->
            []
        | _x :: _xs, [], Z ->
            assert false
        | x :: xs, _ :: ms, S n ->
            x :: pad xs ms n
        | [], _m :: ms, S n ->
            let t : _ Types.Wrap.Proof_state.Messages_for_next_wrap_proof.t =
              { challenge_polynomial_commitment = Lazy.force Dummy.Ipa.Step.sg
              ; old_bulletproof_challenges =
                  Vector.init Max_proofs_verified.n ~f:(fun _ ->
                      Lazy.force Dummy.Ipa.Wrap.challenges_computed )
              }
            in
            Wrap_hack.hash_messages_for_next_wrap_proof Max_proofs_verified.n t
            :: pad [] ms n
      in
      lazy
        (Vector.rev
           (pad
              (Vector.map
                 (Vector.rev (Option.value_exn !statements_with_hashes))
                 ~f:(fun s -> s.proof_state.messages_for_next_wrap_proof) )
              Maxes.maxes Maxes.length ) )
    in
    let handler (Snarky_backendless.Request.With { request; respond } as r) =
      let k x = respond (Provide x) in
      match request with
      | Req.Compute_prev_proof_parts prev_proof_requests ->
          [%log internal] "Step_compute_prev_proof_parts" ;
          compute_prev_proof_parts prev_proof_requests ;
          [%log internal] "Step_compute_prev_proof_parts_done" ;
          k ()
      | Req.Proof_with_datas ->
          k (Option.value_exn !witnesses)
      | Req.Wrap_index ->
          k self_dlog_plonk_index
      | Req.App_state ->
          k next_state
      | Req.Return_value res ->
          return_value := Some res ;
          k ()
      | Req.Auxiliary_value res ->
          auxiliary_value := Some res ;
          k ()
      | Req.Unfinalized_proofs ->
          k (Lazy.force unfinalized_proofs)
      | Req.Messages_for_next_wrap_proof ->
          k (Lazy.force messages_for_next_wrap_proof_padded)
      | Req.Wrap_domain_indices ->
          let all_possible_domains = Wrap_verifier.all_possible_domains () in
          let wrap_domain_indices =
            Vector.map (Option.value_exn !actual_wrap_domains)
              ~f:(fun domain_size ->
                let domain_index =
                  Vector.foldi ~init:0 all_possible_domains
                    ~f:(fun j acc (Pow_2_roots_of_unity domain) ->
                      if Int.equal domain domain_size then j else acc )
                in
                Pickles_base.Proofs_verified.of_int domain_index )
          in
          k wrap_domain_indices
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

               let f (T t : _ Proof.t) =
                 t.statement.proof_state.messages_for_next_wrap_proof
                   .challenge_polynomial_commitment
             end )
         in
         (* emphatically NOT padded with dummies *)
         Vector.(
           map2 to_fold_in
             (Lazy.force messages_for_next_step_proof_prepared)
               .old_bulletproof_challenges ~f:(fun commitment chals ->
               { Tick.Proof.Challenge_polynomial.commitment
               ; challenges = Vector.to_array chals
               } )
           |> to_list) )
    in
    let%map.Promise ( (next_proof : Tick.Proof.with_public_evals)
                    , _next_statement_hashed ) =
      let (T (input, _conv, conv_inv)) =
        Impls.Step.input ~proofs_verified:Max_proofs_verified.n
          ~wrap_rounds:Tock.Rounds.n
      in
      let { Domains.h } = Vector.nth_exn step_domains branch_data.index in
      ksprintf Common.time "step-prover %d (%d)" branch_data.index
        (Domain.size h)
        (fun () ->
          let promise_or_error =
            (* Use a try_with to give an informative backtrace.
               If we don't do this, the backtrace will be obfuscated by the
               Promise, and it's significantly harder to track down errors.
               This only applies to errors in the 'witness generation' stage;
               proving errors are emitted inside the promise, and are therefore
               unaffected.
            *)
            Or_error.try_with ~backtrace:true (fun () ->
                [%log internal] "Step_generate_witness_conv" ;
                Impls.Step.generate_witness_conv
                  ~f:(fun { Impls.Step.Proof_inputs.auxiliary_inputs
                          ; public_inputs
                          } next_statement_hashed ->
                    [%log internal] "Backend_tick_proof_create_async" ;
                    let create_proof () =
                      Backend.Tick.Proof.create_async ~primary:public_inputs
                        ~auxiliary:auxiliary_inputs
                        ~message:
                          (Lazy.force prev_challenge_polynomial_commitments)
                        pk
                    in
                    let%map.Promise proof =
                      match proof_cache with
                      | None ->
                          create_proof ()
                      | Some proof_cache -> (
                          match
                            Proof_cache.get_step_proof proof_cache ~keypair:pk
                              ~public_input:public_inputs
                          with
                          | None ->
                              if
                                Proof_cache
                                .is_env_var_set_requesting_error_for_proofs ()
                              then failwith "Regenerated proof" ;
                              let%map.Promise proof = create_proof () in
                              Proof_cache.set_step_proof proof_cache ~keypair:pk
                                ~public_input:public_inputs proof.proof ;
                              proof
                          | Some proof ->
                              Promise.return
                                ( { proof; public_evals = None }
                                  : Tick.Proof.with_public_evals ) )
                    in
                    [%log internal] "Backend_tick_proof_create_async_done" ;
                    (proof, next_statement_hashed) )
                  ~input_typ:Impls.Step.Typ.unit ~return_typ:input
                  (fun () () ->
                    Impls.Step.handle
                      (fun () -> conv_inv (branch_data.main ~step_domains ()))
                      handler ) )
          in
          (* Re-raise any captured errors, complete with their backtrace. *)
          Or_error.ok_exn promise_or_error )
        ()
    in
    let prev_evals =
      extract_from_proofs
        ( module struct
          type res = E.t

          let f (T t : _ Proof.t) =
            let proof = Wrap_wire_proof.to_kimchi_proof t.proof in
            (proof.openings.evals, proof.openings.ft_eval1)
        end )
    in
    let messages_for_next_wrap_proof =
      let rec go :
          type a.
             (a, a) H2.T(Proof).t
          -> a H1.T(Proof.Base.Messages_for_next_proof_over_same_field.Wrap).t =
        function
        | [] ->
            []
        | T t :: tl ->
            t.statement.proof_state.messages_for_next_wrap_proof :: go tl
      in
      go (Option.value_exn !prev_proofs)
    in
    let next_statement : _ Types.Step.Statement.t =
      { proof_state =
          { unfinalized_proofs = Lazy.force unfinalized_proofs_extended
          ; messages_for_next_step_proof =
              Lazy.force messages_for_next_step_proof
          }
      ; messages_for_next_wrap_proof
      }
    in
    [%log internal] "Pickles_step_proof_done" ;
    ( { Proof.Base.Step.proof = next_proof
      ; statement = next_statement
      ; index = branch_data.index
      ; prev_evals =
          Vector.extend_front
            (Vector.map2 prev_evals (Option.value_exn !x_hats)
               ~f:(fun (es, ft_eval1) x_hat ->
                 Plonk_types.All_evals.
                   { ft_eval1
                   ; evals =
                       { With_public_input.evals = es
                       ; public_input =
                           (let x1, x2 = x_hat in
                            ([| x1 |], [| x2 |]) )
                       }
                   } ) )
            lte Max_proofs_verified.n (Lazy.force Dummy.evals)
      }
    , Option.value_exn !return_value
    , Option.value_exn !auxiliary_value
    , Option.value_exn !actual_wrap_domains )
end
