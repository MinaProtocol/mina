open Pickles_types
open Hlist
open Import
open Impls.Step

(* Converts from the one hot vector representation of a number
   0 <= i < n

     0  1  ... i-1  i  i+1       n-1
   [ 0; 0; ... 0;   1; 0;   ...; 0 ]

   to the numeric representation i. *)

module Make (Inductive_rule : Inductive_rule.Intf) = struct
  module B = Inductive_rule.B

  let verify_one ~srs
      ({ app_state
       ; wrap_proof
       ; proof_state
       ; prev_proof_evals
       ; prev_challenges
       ; prev_challenge_polynomial_commitments
       } :
        _ Per_proof_witness.t ) (d : _ Types_map.For_step.t)
      (messages_for_next_wrap_proof : Digest.t) (unfinalized : Unfinalized.t)
      (must_verify : B.t) : _ Vector.t * B.t =
    Boolean.Assert.( = ) unfinalized.should_finalize must_verify ;
    let deferred_values = proof_state.deferred_values in
    let finalized, chals =
      with_label __LOC__ (fun () ->
          let sponge_digest = proof_state.sponge_digest_before_evaluations in
          let sponge =
            let open Step_main_inputs in
            let sponge = Sponge.create sponge_params in
            Sponge.absorb sponge (`Field sponge_digest) ;
            sponge
          in
          (* TODO: Refactor args into an "unfinalized proof" struct *)
          Step_verifier.finalize_other_proof d.max_proofs_verified
            ~step_domains:d.step_domains ~zk_rows:d.zk_rows ~sponge
            ~prev_challenges deferred_values prev_proof_evals )
    in
    let branch_data = deferred_values.branch_data in
    let sponge_after_index, hash_messages_for_next_step_proof =
      let to_field_elements =
        let (Typ typ) = d.public_input in
        fun x -> fst (typ.var_to_fields x)
      in
      let sponge_after_index, hash_messages_for_next_step_proof =
        (* TODO: Don't rehash when it's not necessary *)
        Step_verifier.hash_messages_for_next_step_proof_opt ~index:d.wrap_key
          to_field_elements
      in
      (sponge_after_index, unstage hash_messages_for_next_step_proof)
    in
    (* prepare the statement to be verified below *)
    let statement =
      let prev_messages_for_next_step_proof =
        with_label __LOC__ (fun () ->
            hash_messages_for_next_step_proof
              ~proofs_verified_mask:
                (Vector.trim_front branch_data.proofs_verified_mask
                   (Nat.lte_exn
                      (Vector.length prev_challenge_polynomial_commitments)
                      Nat.N2.n ) )
              (* Use opt sponge for cutting off the bulletproof challenges early *)
              { app_state
              ; dlog_plonk_index = d.wrap_key
              ; challenge_polynomial_commitments =
                  prev_challenge_polynomial_commitments
              ; old_bulletproof_challenges = prev_challenges
              } )
      in
      (* Returns messages for the next step proof and messages for the next
         wrap proof *)
      { Types.Wrap.Statement.messages_for_next_step_proof =
          prev_messages_for_next_step_proof
      ; proof_state = { proof_state with messages_for_next_wrap_proof }
      }
    in
    (* and when the statement is prepared, we call the step verifier with this
       statement *)
    let verified =
      with_label __LOC__ (fun () ->
          Step_verifier.verify ~srs
            ~feature_flags:(Plonk_types.Features.of_full d.feature_flags)
            ~lookup_parameters:
              { use = d.feature_flags.uses_lookups
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
            ~proofs_verified:d.max_proofs_verified ~wrap_domain:d.wrap_domain
            ~is_base_case:(Boolean.not must_verify) ~sponge_after_index
            ~sg_old:prev_challenge_polynomial_commitments ~proof:wrap_proof
            ~wrap_verification_key:d.wrap_key statement unfinalized )
    in
    if debug then
      as_prover
        As_prover.(
          fun () ->
            let finalized = read Boolean.typ finalized in
            let verified = read Boolean.typ verified in
            let must_verify = read Boolean.typ must_verify in
            printf "finalized: %b\n%!" finalized ;
            printf "verified: %b\n%!" verified ;
            printf "must_verify: %b\n\n%!" must_verify) ;
    (chals, Boolean.(verified &&& finalized ||| not must_verify))

  (* The SNARK function corresponding to the input inductive rule. *)
  let step_main :
      type proofs_verified self_branches prev_vars prev_values var value a_var a_value ret_var ret_value auxiliary_var auxiliary_value max_proofs_verified local_branches local_signature.
         (module Requests.Step(Inductive_rule).S
            with type local_signature = local_signature
             and type local_branches = local_branches
             and type statement = a_value
             and type prev_values = prev_values
             and type max_proofs_verified = max_proofs_verified
             and type proofs_verified = proofs_verified
             and type return_value = ret_value
             and type auxiliary_value = auxiliary_value )
      -> (module Nat.Add.Intf with type n = max_proofs_verified)
      -> self_branches:self_branches Nat.t
           (* How many branches does this proof system have *)
      -> prev_requests:local_signature H1.T(Requests.Prev_request_packed).t
           (* One request module per predecessor, carrying the data fixing that
              predecessor's witness layout (width, feature flags, chunk count)
              together with its own fresh request constructors. *)
      -> local_signature_length:
           (local_signature, proofs_verified) Hlist.Length.t
      -> proofs_verified:(prev_vars, proofs_verified) Hlist.Length.t
      -> lte:(proofs_verified, max_proofs_verified) Nat.Lte.t
      -> public_input:
           ( var
           , value
           , a_var
           , a_value
           , ret_var
           , ret_value )
           Inductive_rule.public_input
      -> auxiliary_typ:(auxiliary_var, auxiliary_value) Typ.t
      -> basic:
           ( var
           , value
           , max_proofs_verified
           , self_branches )
           Types_map.Compiled.basic
      -> known_wrap_keys:
           local_branches H1.T(Types_map.For_step.Optional_wrap_key).t
      -> self:(var, value, max_proofs_verified, self_branches) Tag.t
      -> ( prev_vars
         , prev_values
         , local_signature
         , local_branches
         , a_var
         , a_value
         , ret_var
         , ret_value
         , auxiliary_var
         , auxiliary_value )
         Inductive_rule.Promise.t
      -> (   unit
          -> ( (Unfinalized.t, max_proofs_verified) Vector.t
             , Field.t
             , (Field.t, max_proofs_verified) Vector.t )
             Types.Step.Statement.t
             Promise.t )
         Staged.t =
   fun (module Req) max_proofs_verified ~self_branches ~prev_requests
       ~local_signature_length ~proofs_verified ~lte ~public_input
       ~auxiliary_typ ~basic ~known_wrap_keys ~self rule ->
    let (input_typ, output_typ)
          : (a_var, a_value) Typ.t * (ret_var, ret_value) Typ.t =
      match public_input with
      | Input typ ->
          (typ, Typ.unit)
      | Output typ ->
          (Typ.unit, typ)
      | Input_and_output (input_typ, output_typ) ->
          (input_typ, output_typ)
    in
    let main () : _ Types.Step.Statement.t Promise.t =
      let open Impls.Step in
      let logger = Context_logger.get () in
      let module Max_proofs_verified = ( val max_proofs_verified : Nat.Add.Intf
                                           with type n = max_proofs_verified )
      in
      let T = Max_proofs_verified.eq in
      let app_state = exists input_typ ~request:(fun () -> Req.App_state) in
      let%bind.Promise { Inductive_rule.previous_proof_statements
                       ; public_output = ret_var
                       ; auxiliary_output = auxiliary_var
                       } =
        (* Run the application logic of the rule on the predecessor statements *)
        with_label "rule_main" (fun () ->
            rule.main { public_input = app_state } )
      in
      with_label "step_main" (fun () ->
          let () =
            exists Typ.unit ~request:(fun () ->
                let ret_value = As_prover.read output_typ ret_var in
                Req.Return_value ret_value )
          in
          let () =
            exists Typ.unit ~request:(fun () ->
                let auxiliary_value =
                  As_prover.read auxiliary_typ auxiliary_var
                in
                Req.Auxiliary_value auxiliary_value )
          in
          (* Compute proof parts outside of the prover before requesting values.
        *)
          let%map.Promise () =
            Async_promise.unit_request (fun () ->
                let previous_proof_statements =
                  let rec go :
                      type prev_vars prev_values ns1 ns2.
                         ( prev_vars
                         , ns1 )
                         H2.T(Inductive_rule.Previous_proof_statement).t
                      -> (prev_vars, prev_values, ns1, ns2) H4.T(Tag).t
                      -> ( prev_values
                         , ns1 )
                         H2.T(Inductive_rule.Previous_proof_statement.Constant)
                         .t =
                   fun previous_proof_statement tags ->
                    match (previous_proof_statement, tags) with
                    | [], [] ->
                        []
                    | ( { public_input; proof; proof_must_verify } :: stmts
                      , tag :: tags ) ->
                        let public_input =
                          (fun (type var value n m)
                               (tag : (var, value, n, m) Tag.t) (var : var) :
                               value ->
                            let typ : (var, value) Typ.t =
                              match
                                Type_equal.Id.same_witness self.id tag.id
                              with
                              | Some T ->
                                  basic.public_input
                              | None ->
                                  Types_map.public_input tag
                            in
                            As_prover.read typ var )
                            tag public_input
                        in
                        { public_input
                        ; proof = As_prover.read (Typ.prover_value ()) proof
                        ; proof_must_verify =
                            As_prover.read Boolean.typ proof_must_verify
                        }
                        :: go stmts tags
                  in
                  go previous_proof_statements rule.prevs
                in
                Req.Compute_prev_proof_parts previous_proof_statements )
          in
          let dlog_plonk_index =
            let num_chunks = (* TODO *) Plonk_checks.num_chunks_by_default in
            exists
              ~request:(fun () -> Req.Wrap_index)
              (Plonk_verification_key_evals.typ
                 (Typ.array ~length:num_chunks Step_verifier.Inner_curve.typ) )
          and prevs =
            (* Allocate each predecessor's witness with its own [Witness]
               request, taken from the per-predecessor request hlist. Each
               [Prev_request] is pinned to its predecessor's width, so its
               request fires (and is later answered) directly, with no index or
               width comparison. Co-walks the predecessors' [Tag]s only to
               recover the per-proof type indices; the witness [Typ] itself
               comes from each [Prev_request]. *)
            let rec exists_prevs :
                type pvars pvals ns1 ns2.
                   (pvars, pvals, ns1, ns2) H4.T(Tag).t
                -> ns1 H1.T(Requests.Prev_request_packed).t
                -> (pvars, ns1, ns2) H3.T(Per_proof_witness.No_app_state).t =
             fun tags reqs ->
              match[@warning "-4"] (tags, reqs) with
              | [], [] ->
                  []
              | _tag :: tags, req :: reqs ->
                  let (module M) = req in
                  let v = exists (M.typ ()) ~request:(fun () -> M.Witness) in
                  v :: exists_prevs tags reqs
              | _ ->
                  .
            in
            exists_prevs rule.prevs prev_requests
          and unfinalized_proofs_unextended =
            (* One [Unfinalized.typ] per predecessor, fired from each
               predecessor's own [Unfinalized] request — a fold over
               [prev_requests]. *)
            let rec exists_unfinalized :
                type ws n.
                   ws H1.T(Requests.Prev_request_packed).t
                -> (ws, n) Hlist.Length.t
                -> (Unfinalized.t, n) Vector.t =
             fun reqs len ->
              match (reqs, len) with
              | [], Z ->
                  []
              | req :: reqs, S len ->
                  let (module M) = req in
                  let v =
                    exists (Unfinalized.typ ~wrap_rounds:Backend.Tock.Rounds.n)
                      ~request:(fun () -> M.Unfinalized)
                  in
                  v :: exists_unfinalized reqs len
            in
            exists_unfinalized prev_requests local_signature_length
          and messages_for_next_wrap_proof =
            (* Fill the max-proofs-verified-length messages layout front to
               back: the front [gap = max - proofs_verified] padding slots from
               a single dummy request, then one slot per predecessor from its
               own [Messages_for_next_wrap_proof] request. *)
            let (Nat.Lte.Complement (_gap, gap_adds)) =
              Nat.Lte.complement lte Max_proofs_verified.n
            in
            let rec exists_messages :
                type gap ws n total.
                   (gap, n, total) Nat.Adds.t
                -> (ws, n) Hlist.Length.t
                -> ws H1.T(Requests.Prev_request_packed).t
                -> (Digest.t, total) Vector.t =
             fun adds width reqs ->
              match (adds, width, reqs) with
              | S adds, _, _ ->
                  let v =
                    exists Digest.typ ~request:(fun () ->
                        Req.Dummy_messages_for_next_wrap_proof )
                  in
                  v :: exists_messages adds width reqs
              | Z, S width, req :: reqs ->
                  let (module R) = req in
                  let v =
                    exists Digest.typ ~request:(fun () ->
                        R.Messages_for_next_wrap_proof )
                  in
                  v :: exists_messages Nat.Adds.Z width reqs
              | Z, Z, [] ->
                  []
            in
            exists_messages gap_adds local_signature_length prev_requests
          in
          let srs = Backend.Tock.Keypair.load_urs () in
          [%log internal] "Step_compute_bulletproof_challenges" ;
          let bulletproof_challenges =
            with_label "prevs_verified" (fun () ->
                let rec go :
                    type vars vals ns1 ns2 n.
                       (vars, ns1, ns2) H3.T(Per_proof_witness.No_app_state).t
                    -> (vars, vals, ns1, ns2) H4.T(Types_map.For_step).t
                    -> vars H1.T(E01(Digest)).t
                    -> vars H1.T(E01(Unfinalized)).t
                    -> ( vars
                       , ns1 )
                       H2.T(Inductive_rule.Previous_proof_statement).t
                    -> (vars, n) Length.t
                    -> (_, n) Vector.t * B.t list =
                 fun prevs datas messages_for_next_wrap_proofs unfinalizeds
                     stmts pi ->
                  match
                    ( prevs
                    , datas
                    , messages_for_next_wrap_proofs
                    , unfinalizeds
                    , stmts
                    , pi )
                  with
                  | [], [], [], [], [], Z ->
                      ([], [])
                  | ( prev :: prevs
                    , d :: datas
                    , messages_for_next_wrap_proof
                      :: messages_for_next_wrap_proofs
                    , unfinalized :: unfinalizeds
                    , { public_input; proof_must_verify = must_verify; _ }
                      :: stmts
                    , S pi ) ->
                      let chals, v =
                        (* Reattach this predecessor's app-state to its witness
                           for verification. *)
                        verify_one ~srs
                          { prev with app_state = public_input }
                          d messages_for_next_wrap_proof unfinalized must_verify
                      in
                      let chalss, vs =
                        go prevs datas messages_for_next_wrap_proofs
                          unfinalizeds stmts pi
                      in
                      (chals :: chalss, v :: vs)
                in
                let chalss, vs =
                  let messages_for_next_wrap_proofs =
                    with_label "messages_for_next_wrap_proofs" (fun () ->
                        let module V = H1.Of_vector (Digest) in
                        V.f proofs_verified
                          (Vector.trim_front messages_for_next_wrap_proof lte) )
                  and unfinalized_proofs =
                    let module H = H1.Of_vector (Unfinalized) in
                    H.f proofs_verified unfinalized_proofs_unextended
                  and datas =
                    let self_data :
                        ( var
                        , value
                        , max_proofs_verified
                        , self_branches )
                        Types_map.For_step.t =
                      { max_proofs_verified
                      ; public_input = basic.public_input
                      ; wrap_domain = `Known basic.wrap_domains.h
                      ; step_domains = `Known basic.step_domains
                      ; wrap_key = dlog_plonk_index
                      ; feature_flags = basic.feature_flags
                      ; num_chunks = basic.num_chunks
                      ; zk_rows = basic.zk_rows
                      }
                    in
                    let rec go :
                        type a1 a2 n m.
                           (a1, a2, n, m) H4.T(Tag).t
                        -> m H1.T(Types_map.For_step.Optional_wrap_key).t
                        -> (a1, a2, n, m) H4.T(Types_map.For_step).t =
                     fun tags optional_wrap_keys ->
                      match (tags, optional_wrap_keys) with
                      | [], [] ->
                          []
                      | tag :: tags, optional_wrap_key :: optional_wrap_keys ->
                          let data =
                            match Type_equal.Id.same_witness self.id tag.id with
                            | None -> (
                                match tag.kind with
                                | Compiled ->
                                    Types_map.For_step
                                    .of_compiled_with_known_wrap_key
                                      (Option.value_exn optional_wrap_key)
                                      (Types_map.lookup_compiled tag.id)
                                | Side_loaded ->
                                    Types_map.For_step.of_side_loaded
                                      (Types_map.lookup_side_loaded tag.id) )
                            | Some T ->
                                self_data
                          in
                          data :: go tags optional_wrap_keys
                    in
                    go rule.prevs known_wrap_keys
                  in
                  go prevs datas messages_for_next_wrap_proofs
                    unfinalized_proofs previous_proof_statements proofs_verified
                in
                Boolean.Assert.all vs ; chalss )
          in
          [%log internal] "Step_compute_bulletproof_challenges_done" ;
          let messages_for_next_step_proof =
            let challenge_polynomial_commitments =
              let module M =
                H3.Map
                  (Per_proof_witness.No_app_state)
                  (E03 (Step_verifier.Inner_curve))
                  (struct
                    let f :
                        type a b c.
                           (a, b, c) Per_proof_witness.No_app_state.t
                        -> Step_verifier.Inner_curve.t =
                     fun acc ->
                      acc.wrap_proof.opening.challenge_polynomial_commitment
                  end)
              in
              let module V = H3.To_vector (Step_verifier.Inner_curve) in
              V.f proofs_verified (M.f prevs)
            in
            with_label "hash_messages_for_next_step_proof" (fun () ->
                let hash_messages_for_next_step_proof =
                  let to_field_elements =
                    let (Typ typ) = basic.public_input in
                    fun x -> fst (typ.var_to_fields x)
                  in
                  unstage
                    (Step_verifier.hash_messages_for_next_step_proof
                       ~index:dlog_plonk_index to_field_elements )
                in
                let (app_state : var) =
                  match public_input with
                  | Input _ ->
                      app_state
                  | Output _ ->
                      ret_var
                  | Input_and_output _ ->
                      (app_state, ret_var)
                in
                hash_messages_for_next_step_proof
                  { app_state
                  ; dlog_plonk_index
                  ; challenge_polynomial_commitments
                  ; old_bulletproof_challenges =
                      (* Note: the bulletproof_challenges here are unpadded! *)
                      bulletproof_challenges
                  } )
          in
          let unfinalized_proofs =
            Vector.extend_front unfinalized_proofs_unextended lte
              Max_proofs_verified.n (Unfinalized.dummy ())
          in
          ( { Types.Step.Statement.proof_state =
                { unfinalized_proofs; messages_for_next_step_proof }
            ; messages_for_next_wrap_proof
            }
            : ( (Unfinalized.t, max_proofs_verified) Vector.t
              , Field.t
              , (Field.t, max_proofs_verified) Vector.t )
              Types.Step.Statement.t ) )
    in
    stage main
end
