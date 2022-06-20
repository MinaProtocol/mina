module S = Sponge
open Core_kernel
open Pickles_types
open Common
open Poly_types
open Hlist
open Import
open Impls.Step
open Step_main_inputs
open Step_verifier
module B = Inductive_rule.B

(* Converts from the one hot vector representation of a number
   0 <= i < n

     0  1  ... i-1  i  i+1       n-1
   [ 0; 0; ... 0;   1; 0;   ...; 0 ]

   to the numeric representation i. *)

let one_hot_vector_to_num (type n) (v : n Per_proof_witness.One_hot_vector.t) :
    Field.t =
  let n = Vector.length (v :> (Boolean.var, n) Vector.t) in
  Pseudo.choose (v, Vector.init n ~f:Field.of_int) ~f:Fn.id

let verify_one
    ({ app_state
     ; wrap_proof
     ; proof_state
     ; prev_proof_evals
     ; prev_challenges
     ; prev_challenge_polynomial_commitments
     } :
      _ Per_proof_witness.t ) (d : _ Types_map.For_step.t)
    (pass_through : Digest.t) (unfinalized : Unfinalized.t) (should_verify : B.t)
    : _ Vector.t * B.t =
  Boolean.Assert.( = ) unfinalized.should_finalize should_verify ;
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
        finalize_other_proof d.max_proofs_verified ~step_domains:d.step_domains
          ~sponge ~prev_challenges proof_state.deferred_values prev_proof_evals )
  in
  let branch_data = proof_state.deferred_values.branch_data in
  let statement =
    let prev_me_only =
      with_label __LOC__ (fun () ->
          let hash =
            let to_field_elements =
              let (Typ typ) = d.public_input in
              fun x -> fst (typ.var_to_fields x)
            in
            (* TODO: Don't rehash when it's not necessary *)
            unstage (hash_me_only_opt ~index:d.wrap_key to_field_elements)
          in
          hash ~widths:d.proofs_verifieds
            ~max_width:(Nat.Add.n d.max_proofs_verified)
            ~proofs_verified_mask:
              (Vector.trim branch_data.proofs_verified_mask
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
    { Types.Wrap.Statement.pass_through = prev_me_only
    ; proof_state = { proof_state with me_only = pass_through }
    }
  in
  let verified =
    with_label __LOC__ (fun () ->
        verify ~proofs_verified:d.max_proofs_verified ~wrap_domain:d.wrap_domain
          ~is_base_case:(Boolean.not should_verify)
          ~sg_old:prev_challenge_polynomial_commitments ~proof:wrap_proof
          ~wrap_verification_key:d.wrap_key statement unfinalized )
  in
  if debug then
    as_prover
      As_prover.(
        fun () ->
          let finalized = read Boolean.typ finalized in
          let verified = read Boolean.typ verified in
          let should_verify = read Boolean.typ should_verify in
          printf "finalized: %b\n%!" finalized ;
          printf "verified: %b\n%!" verified ;
          printf "should_verify: %b\n\n%!" should_verify) ;
  (chals, Boolean.(verified &&& finalized ||| not should_verify))

let finalize_previous_and_verify = ()

(* The SNARK function corresponding to the input inductive rule. *)
let step_main :
    type proofs_verified self_branches prev_vars prev_values prev_ret_vars var value a_var a_value ret_var ret_value max_proofs_verified local_branches local_signature.
       (module Requests.Step.S
          with type local_signature = local_signature
           and type local_branches = local_branches
           and type statement = a_value
           and type prev_values = prev_values
           and type max_proofs_verified = max_proofs_verified
           and type return_value = ret_value )
    -> (module Nat.Add.Intf with type n = max_proofs_verified)
    -> self_branches:self_branches Nat.t
         (* How many branches does this proof system have *)
    -> local_signature:local_signature H1.T(Nat).t
         (* The specification, for each proof that this step circuit verifies, of the maximum width used
            by that proof system. *)
    -> local_signature_length:(local_signature, proofs_verified) Hlist.Length.t
    -> local_branches:
         (* For each inner proof of type T , the number of branches that type T has. *)
         local_branches H1.T(Nat).t
    -> local_branches_length:(local_branches, proofs_verified) Hlist.Length.t
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
    -> basic:
         ( var
         , value
         , max_proofs_verified
         , self_branches )
         Types_map.Compiled.basic
    -> self:(var, value, max_proofs_verified, self_branches) Tag.t
    -> ( prev_vars
       , prev_values
       , local_signature
       , local_branches
       , a_var
       , a_value
       , ret_var
       , ret_value )
       Inductive_rule.t
    -> (   unit
        -> ( (Unfinalized.t, max_proofs_verified) Vector.t
           , Field.t
           , (Field.t, max_proofs_verified) Vector.t )
           Types.Step.Statement.t )
       Staged.t =
 fun (module Req) max_proofs_verified ~self_branches ~local_signature
     ~local_signature_length ~local_branches ~local_branches_length
     ~proofs_verified ~lte ~public_input ~basic ~self rule ->
  let module T (F : T4) = struct
    type ('a, 'b, 'n, 'm) t =
      | Other of ('a, 'b, 'n, 'm) F.t
      | Self : (a_var, a_value, max_proofs_verified, self_branches) t
  end in
  let module Typ_with_max_proofs_verified = struct
    type ('var, 'value, 'local_max_proofs_verified, 'local_branches) t =
      ( ( 'var
        , 'local_max_proofs_verified
        , 'local_branches )
        Per_proof_witness.No_app_state.t
      , ( 'value
        , 'local_max_proofs_verified
        , 'local_branches )
        Per_proof_witness.Constant.No_app_state.t )
      Typ.t
  end in
  let prev_values_typs =
    let rec join :
        type pvars pvals ns1 ns2.
        (pvars, pvals, ns1, ns2) H4.T(Tag).t -> (pvars, pvals) H2.T(Typ).t =
      function
      | [] ->
          []
      | d :: ds ->
          let typ =
            (fun (type var value n m) (d : (var, value, n, m) Tag.t) ->
              let typ : (var, value) Typ.t =
                match Type_equal.Id.same_witness self.id d.id with
                | Some T ->
                    basic.public_input
                | None ->
                    Types_map.public_input d
              in
              typ )
              d
          in
          let typs_tl = join ds in
          typ :: typs_tl
    in
    let module Mk_typ = H2.Typ (Impls.Step) in
    let typs = join rule.prevs in
    Mk_typ.f typs
  in
  let prev_proof_typs =
    let rec join :
        type e pvars pvals ns1 ns2 br.
           (pvars, pvals, ns1, ns2) H4.T(Tag).t
        -> ns1 H1.T(Nat).t
        -> ns2 H1.T(Nat).t
        -> (pvars, br) Length.t
        -> (ns1, br) Length.t
        -> (ns2, br) Length.t
        -> (pvars, pvals, ns1, ns2) H4.T(Typ_with_max_proofs_verified).t =
     fun ds ns1 ns2 ld ln1 ln2 ->
      match (ds, ns1, ns2, ld, ln1, ln2) with
      | [], [], [], Z, Z, Z ->
          []
      | d :: ds, n1 :: ns1, n2 :: ns2, S ld, S ln1, S ln2 ->
          let t = Per_proof_witness.typ Typ.unit n1 n2 in
          t :: join ds ns1 ns2 ld ln1 ln2
      | [], _, _, _, _, _ ->
          .
      | _ :: _, _, _, _, _, _ ->
          .
    in
    join rule.prevs local_signature local_branches proofs_verified
      local_signature_length local_branches_length
  in
  let module Prev_typ =
    H4.Typ (Impls.Step) (Typ_with_max_proofs_verified)
      (Per_proof_witness.No_app_state)
      (Per_proof_witness.Constant.No_app_state)
      (struct
        let f = Fn.id
      end)
  in
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
  let main () : _ Types.Step.Statement.t =
    let open Requests.Step in
    let open Impls.Step in
    with_label "step_main" (fun () ->
        let module Max_proofs_verified = ( val max_proofs_verified : Nat.Add.Intf
                                             with type n = max_proofs_verified
                                         )
        in
        let T = Max_proofs_verified.eq in
        let prev_statements =
          exists prev_values_typs ~request:(fun () -> Req.Prev_inputs)
        in
        let app_state = exists input_typ ~request:(fun () -> Req.App_state) in
        let proofs_should_verify, ret_var =
          (* Run the application logic of the rule on the predecessor statements *)
          with_label "rule_main" (fun () ->
              rule.main prev_statements app_state )
        in
        let () =
          exists Typ.unit ~request:(fun () ->
              let ret_value = As_prover.read output_typ ret_var in
              Req.Return_value ret_value )
        in
        (* Compute proof parts outside of the prover before requesting values.
        *)
        exists Typ.unit ~request:(fun () ->
            let inners_must_verify =
              let rec go :
                  type prev_vars prev_values ns1 ns2.
                     prev_vars H1.T(E01(B)).t
                  -> (prev_vars, prev_values, ns1, ns2) H4.T(Tag).t
                  -> prev_values H1.T(E01(Bool)).t =
               fun bs tags ->
                match (bs, tags) with
                | [], [] ->
                    []
                | b :: bs, _tag :: tags ->
                    As_prover.read Boolean.typ b :: go bs tags
              in
              go proofs_should_verify rule.prevs
            in
            Req.Compute_prev_proof_parts inners_must_verify ) ;
        let dlog_plonk_index =
          exists
            ~request:(fun () -> Req.Wrap_index)
            (Plonk_verification_key_evals.typ Inner_curve.typ)
        and prevs =
          exists (Prev_typ.f prev_proof_typs) ~request:(fun () ->
              Req.Proof_with_datas )
        and unfinalized_proofs =
          exists
            (Vector.typ
               (Unfinalized.typ ~wrap_rounds:Backend.Tock.Rounds.n)
               Max_proofs_verified.n )
            ~request:(fun () -> Req.Unfinalized_proofs)
        and pass_through =
          exists (Vector.typ Digest.typ Max_proofs_verified.n)
            ~request:(fun () -> Req.Pass_through)
        in
        let prevs =
          (* Inject the app-state values into the per-proof witnesses. *)
          let rec go :
              type vars ns1 ns2.
                 (vars, ns1, ns2) H3.T(Per_proof_witness.No_app_state).t
              -> vars H1.T(Id).t
              -> (vars, ns1, ns2) H3.T(Per_proof_witness).t =
           fun proofs app_states ->
            match (proofs, app_states) with
            | [], [] ->
                []
            | proof :: proofs, app_state :: app_states ->
                { proof with app_state } :: go proofs app_states
          in
          go prevs prev_statements
        in
        let bulletproof_challenges =
          with_label "prevs_verified" (fun () ->
              let rec go :
                  type vars vals prev_vals ns1 ns2 n.
                     (vars, ns1, ns2) H3.T(Per_proof_witness).t
                  -> (vars, vals, ns1, ns2) H4.T(Types_map.For_step).t
                  -> vars H1.T(E01(Digest)).t
                  -> vars H1.T(E01(Unfinalized)).t
                  -> vars H1.T(E01(B)).t
                  -> (vars, n) Length.t
                  -> (_, n) Vector.t * B.t list =
               fun proofs datas pass_throughs unfinalizeds should_verifys pi ->
                match
                  ( proofs
                  , datas
                  , pass_throughs
                  , unfinalizeds
                  , should_verifys
                  , pi )
                with
                | [], [], [], [], [], Z ->
                    ([], [])
                | ( p :: proofs
                  , d :: datas
                  , pass_through :: pass_throughs
                  , unfinalized :: unfinalizeds
                  , should_verify :: should_verifys
                  , S pi ) ->
                    let chals, v =
                      verify_one p d pass_through unfinalized should_verify
                    in
                    let chalss, vs =
                      go proofs datas pass_throughs unfinalizeds should_verifys
                        pi
                    in
                    (chals :: chalss, v :: vs)
              in
              let chalss, vs =
                let pass_throughs =
                  with_label "pass_throughs" (fun () ->
                      let module V = H1.Of_vector (Digest) in
                      V.f proofs_verified (Vector.trim pass_through lte) )
                and unfinalized_proofs =
                  let module H = H1.Of_vector (Unfinalized) in
                  H.f proofs_verified (Vector.trim unfinalized_proofs lte)
                and datas =
                  let self_data :
                      ( var
                      , value
                      , max_proofs_verified
                      , self_branches )
                      Types_map.For_step.t =
                    { branches = self_branches
                    ; proofs_verifieds =
                        `Known
                          (Vector.map basic.proofs_verifieds ~f:Field.of_int)
                    ; max_proofs_verified
                    ; public_input = basic.public_input
                    ; wrap_domain = `Known basic.wrap_domains.h
                    ; step_domains = `Known basic.step_domains
                    ; wrap_key = dlog_plonk_index
                    }
                  in
                  let module M =
                    H4.Map (Tag) (Types_map.For_step)
                      (struct
                        let f :
                            type a1 a2 n m.
                               (a1, a2, n, m) Tag.t
                            -> (a1, a2, n, m) Types_map.For_step.t =
                         fun tag ->
                          match Type_equal.Id.same_witness self.id tag.id with
                          | Some T ->
                              self_data
                          | None -> (
                              match tag.kind with
                              | Compiled ->
                                  Types_map.For_step.of_compiled
                                    (Types_map.lookup_compiled tag.id)
                              | Side_loaded ->
                                  Types_map.For_step.of_side_loaded
                                    (Types_map.lookup_side_loaded tag.id) )
                      end)
                  in
                  M.f rule.prevs
                in
                go prevs datas pass_throughs unfinalized_proofs
                  proofs_should_verify proofs_verified
              in
              Boolean.Assert.all vs ; chalss )
        in
        let me_only =
          let challenge_polynomial_commitments =
            let module M =
              H3.Map (Per_proof_witness) (E03 (Inner_curve))
                (struct
                  let f :
                      type a b c. (a, b, c) Per_proof_witness.t -> Inner_curve.t
                      =
                   fun acc ->
                    acc.wrap_proof.opening.challenge_polynomial_commitment
                end)
            in
            let module V = H3.To_vector (Inner_curve) in
            V.f proofs_verified (M.f prevs)
          in
          with_label "hash_me_only" (fun () ->
              let hash_me_only =
                let to_field_elements =
                  let (Typ typ) = basic.public_input in
                  fun x -> fst (typ.var_to_fields x)
                in
                unstage (hash_me_only ~index:dlog_plonk_index to_field_elements)
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
              hash_me_only
                { app_state
                ; dlog_plonk_index
                ; challenge_polynomial_commitments
                ; old_bulletproof_challenges =
                    (* Note: the bulletproof_challenges here are unpadded! *)
                    bulletproof_challenges
                } )
        in
        ( { Types.Step.Statement.proof_state = { unfinalized_proofs; me_only }
          ; pass_through
          }
          : ( (Unfinalized.t, max_proofs_verified) Vector.t
            , Field.t
            , (Field.t, max_proofs_verified) Vector.t )
            Types.Step.Statement.t ) )
  in
  stage main
