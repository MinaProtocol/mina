module SC = Scalar_challenge
open Core
module P = Proof
open Pickles_types
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
    (Max_branching : Nat.Add.Intf_transparent) =
struct
  let triple_zip (a1, a2, a3) (b1, b2, b3) = ((a1, b1), (a2, b2), (a3, b3))

  module E = struct
    type t = Tock.Field.t array Dlog_marlin_types.Evals.t Triple.t
  end

  (* The prover corresponding to the given inductive rule. *)
  let f
      (type max_local_max_branchings self_branches prev_vars prev_values
      local_widths local_heights prevs_length) ?handler
      (T branch_data :
        ( A.t
        , A_value.t
        , Max_branching.n
        , self_branches
        , prev_vars
        , prev_values
        , local_widths
        , local_heights )
        Step_branch_data.t) (next_state : A_value.t)
      ~maxes:(module Maxes : Pickles_types.Hlist.Maxes.S
        with type length = Max_branching.n
         and type ns = max_local_max_branchings)
      ~(prevs_length : (prev_vars, prevs_length) Length.t) ~self ~step_domains
      ~self_dlog_marlin_index pk self_dlog_vk
      (prev_with_proofs :
        (prev_values, local_widths, local_heights) H3.T(P.With_data).t) :
      ( A_value.t
      , (_, Max_branching.n) Vector.t
      , (_, prevs_length) Vector.t
      , (_, prevs_length) Vector.t
      , _
      , (_, Max_branching.n) Vector.t )
      P.Base.Pairing_based.t =
    let _, prev_vars_length = branch_data.branching in
    let T = Length.contr prev_vars_length prevs_length in
    let (module Req) = branch_data.requests in
    let T = Hlist.Length.contr (snd branch_data.branching) prev_vars_length in
    let prev_values_length =
      let module L12 = H4.Length_1_to_2 (Tag) in
      L12.f branch_data.rule.prevs prev_vars_length
    in
    let lte = branch_data.lte in
    let inners_must_verify =
      let prevs =
        let module M =
          H3.Map1_to_H1 (P.With_data) (Id)
            (struct
              let f : type a. (a, _, _) P.With_data.t -> a =
               fun (T t) -> t.statement.pass_through.app_state
            end)
        in
        M.f prev_with_proofs
      in
      branch_data.rule.main_value prevs next_state
    in
    (*
    let prev_with_proofs =
      let rec go
        : type a b c.
          (a, b, c) H3.T(P.With_data).t
          -> (a, b, c) H3.T(E03(Bool)).t
          -> (a, b, c) H3.T(P.With_data).t
        =
        fun ps must_verifys ->
          match ps, must_verifys with
          | [], [] -> []
          | T p :: ps, must_verify :: must_verifys ->
            let sg =
              if not must_verify then
                Ipa.Wrap.compute_sg u.deferred_values.bulletproof_challenges
              else sg 
            in
      in
      go
    in
*)
    let module X_hat = struct
      type t = Tock.Field.t Triple.t
    end in
    let module Statement_with_hashes = struct
      type t =
        ( Challenge.Constant.t
        , Challenge.Constant.t Scalar_challenge.t
        , Tick.Field.t
        , bool
        , Tock.Field.t
        , Digest.Constant.t
        , Digest.Constant.t
        , Digest.Constant.t
        , ( Challenge.Constant.t Scalar_challenge.t
          , bool )
          Bulletproof_challenge.t
          Bp_vec.t
        , Index.t )
        Dlog_based.Statement.t
    end in
    let b_poly = Tock.Field.(Dlog_main.b_poly ~add ~mul ~inv) in
    let sgs, unfinalized_proofs, statements_with_hashes, x_hats, witnesses =
      let f : type var value max local_max_branching m.
             max Nat.t
          -> Impls.Wrap.Verification_key.t
          -> 'a
          -> (value, local_max_branching, m) P.With_data.t
          -> (var, value, local_max_branching, m) Tag.t
          -> must_verify:bool
          -> [`Sg of Tock.Curve.Affine.t]
             * Unfinalized.Constant.t
             * Statement_with_hashes.t
             * X_hat.t
             * (value, local_max_branching, m) Per_proof_witness.Constant.t =
       fun max dlog_vk dlog_index (T t) tag ~must_verify ->
        let data = Types_map.lookup tag in
        let (module Local_max_branching) = data.max_branching in
        let T = Local_max_branching.eq in
        let statement = t.statement in
        let prev_challenges =
          (* TODO: This is redone in the call to Dlog_based_reduced_me_only.prepare *)
          Vector.map ~f:Ipa.Wrap.compute_challenges
            statement.proof_state.me_only.old_bulletproof_challenges
        in
        let prev_statement_with_hashes : _ Dlog_based.Statement.t =
          { pass_through=
              Common.hash_pairing_me_only
                (Reduced_me_only.Pairing_based.prepare
                   ~dlog_marlin_index:dlog_index statement.pass_through)
                ~app_state:data.a_value_to_field_elements
          ; proof_state=
              { statement.proof_state with
                me_only=
                  Common.hash_dlog_me_only Max_branching.n
                    { old_bulletproof_challenges=
                        (* TODO: Get rid of this padding *)
                        Vector.extend_exn prev_challenges Max_branching.n
                          Dummy.Ipa.Wrap.challenges_computed
                    ; sg= statement.proof_state.me_only.sg } } }
        in
        let module O = Tock.Oracles in
        let o =
          let public_input =
            tock_public_input_of_statement prev_statement_with_hashes
          in
          O.create dlog_vk
            Vector.(
              map2
                (Vector.extend_exn statement.pass_through.sg
                   Local_max_branching.n
                   (Lazy.force Dummy.Ipa.Wrap.sg))
                (* This should indeed have length max_branching... No! It should have type max_branching_a. That is, the max_branching specific to a proof of this type...*)
                prev_challenges
                ~f:(fun commitment chals ->
                  { Tock.Proof.Challenge_polynomial.commitment
                  ; challenges= Vector.to_array chals } )
              |> to_list)
            public_input t.proof
        in
        let ((x_hat_1, x_hat_2, x_hat_3) as x_hat) = O.x_hat o in
        let scalar_chal f =
          Scalar_challenge.map ~f:Challenge.Constant.of_tock_field (f o)
        in
        let beta_1 = scalar_chal O.beta1 in
        let beta_2 = scalar_chal O.beta2 in
        let beta_3 = scalar_chal O.beta3 in
        let alpha = O.alpha o in
        let eta_a = O.eta_a o in
        let eta_b = O.eta_b o in
        let eta_c = O.eta_c o in
        let xi = scalar_chal O.polys in
        let r = scalar_chal O.evals in
        let sponge_digest_before_evaluations = O.digest_before_evaluations o in
        let to_field =
          SC.to_field_constant (module Tock.Field) ~endo:Endo.Dee.scalar
        in
        let module As_field = struct
          let r = to_field r

          let xi = to_field xi

          let beta_1 = to_field beta_1

          let beta_2 = to_field beta_2

          let beta_3 = to_field beta_3
        end in
        let new_bulletproof_challenges, b =
          let prechals =
            Array.map (O.opening_prechallenges o) ~f:(fun x ->
                let x =
                  Scalar_challenge.map ~f:Challenge.Constant.of_tock_field x
                in
                (x, Tock.Field.is_square (to_field x)) )
          in
          let chals =
            Array.map prechals ~f:(fun (x, is_square) ->
                Ipa.Wrap.compute_challenge ~is_square x )
          in
          let b_poly = unstage (b_poly chals) in
          let open As_field in
          let b =
            let open Tock.Field in
            b_poly beta_1 + (r * (b_poly beta_2 + (r * b_poly beta_3)))
          in
          let prechals =
            Vector.of_list_and_length_exn
              ( Array.map prechals ~f:(fun (x, is_square) ->
                    {Bulletproof_challenge.prechallenge= x; is_square} )
              |> Array.to_list )
              Rounds.n
          in
          (prechals, b)
        in
        let sg =
          if not must_verify then
            Ipa.Wrap.compute_sg new_bulletproof_challenges
          else t.proof.openings.proof.sg
        in
        let witness : _ Per_proof_witness.Constant.t =
          ( t.P.Base.Dlog_based.statement.pass_through.app_state
          , {prev_statement_with_hashes.proof_state with me_only= ()}
          , Triple.map2 t.prev_evals t.prev_x_hat ~f:Tuple.T2.create
          , Vector.extend_exn t.statement.pass_through.sg Local_max_branching.n
              (Lazy.force Dummy.Ipa.Wrap.sg)
            (* TODO: This computation is also redone elsewhere. *)
          , Vector.extend_exn
              (Vector.map t.statement.pass_through.old_bulletproof_challenges
                 ~f:Ipa.Step.compute_challenges)
              Local_max_branching.n Dummy.Ipa.Step.challenges_computed
          , ({t.proof.openings.proof with sg}, t.proof.messages) )
        in
        let combined_inner_product =
          let e1, e2, e3 = t.proof.openings.evals in
          let b_polys =
            Vector.map
              ~f:(fun chals -> unstage (b_poly (Vector.to_array chals)))
              prev_challenges
          in
          let open As_field in
          let combine (x_hat : Tock.Field.t) pt e =
            let a, b = Dlog_marlin_types.Evals.(to_vectors (e : _ array t)) in
            let v : (Tock.Field.t array, _) Vector.t =
              Vector.append
                (Vector.map b_polys ~f:(fun f -> [|f pt|]))
                ([|x_hat|] :: a)
                (snd (Local_max_branching.add Nat.N19.n))
            in
            let open Tock.Field in
            let domains = data.wrap_domains in
            Pcs_batch.combine_split_evaluations
              (Common.dlog_pcs_batch
                 (Local_max_branching.add Nat.N19.n)
                 ~h_minus_1:Int.(Domain.size domains.h - 1)
                 ~k_minus_1:Int.(Domain.size domains.k - 1))
              ~xi ~init:Fn.id ~mul ~last:Array.last
              ~mul_and_add:(fun ~acc ~xi fx -> fx + (xi * acc))
              ~evaluation_point:pt
              ~shifted_pow:(fun deg x ->
                Pcs_batch.pow ~one ~mul x
                  Int.(crs_max_degree - (deg mod crs_max_degree)) )
              v b
          in
          let open Tock.Field in
          combine x_hat_1 beta_1 e1
          + (r * (combine x_hat_2 beta_2 e2 + (r * combine x_hat_3 beta_3 e3)))
        in
        let chal = Challenge.Constant.of_tock_field in
        ( `Sg sg
        , { Types.Pairing_based.Proof_state.Per_proof.deferred_values=
              { marlin=
                  { sigma_2= fst t.proof.messages.sigma_gh_2
                  ; sigma_3= fst t.proof.messages.sigma_gh_3
                  ; alpha= chal alpha
                  ; eta_a= chal eta_a
                  ; eta_b= chal eta_b
                  ; eta_c= chal eta_c
                  ; beta_1
                  ; beta_2
                  ; beta_3 }
              ; combined_inner_product
              ; xi
              ; bulletproof_challenges= new_bulletproof_challenges
              ; b }
          ; sponge_digest_before_evaluations=
              Digest.Constant.of_tock_field sponge_digest_before_evaluations }
        , prev_statement_with_hashes
        , x_hat
        , witness )
      in
      let rec go : type vars values ns ms maxes k.
             (values, ns, ms) H3.T(P.With_data).t
          -> maxes H1.T(Nat).t
          -> (vars, values, ns, ms) H4.T(Tag).t
          -> vars H1.T(E01(Bool)).t
          -> (vars, k) Length.t
          -> (Tock.Curve.Affine.t, k) Vector.t
             * (Unfinalized.Constant.t, k) Vector.t
             * (Statement_with_hashes.t, k) Vector.t
             * (X_hat.t, k) Vector.t
             * (values, ns, ms) H3.T(Per_proof_witness.Constant).t =
       fun ps maxes ts must_verifys l ->
        match (ps, maxes, ts, must_verifys, l) with
        | [], _, [], [], Z ->
            ([], [], [], [], [])
        | p :: ps, max :: maxes, t :: ts, must_verify :: must_verifys, S l ->
            let dlog_vk, dlog_index =
              if Type_equal.Id.same self t then
                (self_dlog_vk, self_dlog_marlin_index)
              else
                let d = Types_map.lookup t in
                (Lazy.force d.wrap_vk, Lazy.force d.wrap_key)
            in
            let `Sg sg, u, s, x, w = f max dlog_vk dlog_index p t ~must_verify
            and sgs, us, ss, xs, ws = go ps maxes ts must_verifys l in
            (sg :: sgs, u :: us, s :: ss, x :: xs, w :: ws)
        | _ :: _, [], _, _, _ ->
            assert false
      in
      go prev_with_proofs Maxes.maxes branch_data.rule.prevs inners_must_verify
        prev_vars_length
    in
    let inners_must_verify =
      let module V = H1.To_vector (Bool) in
      V.f prev_vars_length inners_must_verify
    in
    let next_statement : _ Types.Pairing_based.Statement.t =
      let unfinalized_proofs =
        Vector.zip unfinalized_proofs inners_must_verify
      in
      let unfinalized_proofs_extended =
        Vector.extend unfinalized_proofs lte Max_branching.n
          (Unfinalized.Constant.dummy, false)
      in
      let pass_through =
        let module M =
          H3.Map2_to_H1 (P.With_data) (P.Base.Me_only.Dlog_based)
            (struct
              let f : type a b c.
                  (a, b, c) P.With_data.t -> b P.Base.Me_only.Dlog_based.t =
               fun (T t) -> t.statement.proof_state.me_only
            end)
        in
        M.f prev_with_proofs
      in
      let old_bulletproof_challenges =
        let module VV = struct
          type t =
            ( Challenge.Constant.t Scalar_challenge.t
            , bool )
            Bulletproof_challenge.t
            Bp_vec.t
        end in
        let module M =
          H3.Map
            (P.With_data)
            (E03 (VV))
            (struct
              let f (T t : _ P.With_data.t) : VV.t =
                t.statement.proof_state.deferred_values.bulletproof_challenges
            end)
        in
        let module V = H3.To_vector (VV) in
        V.f prev_values_length (M.f prev_with_proofs)
      in
      let me_only : _ Reduced_me_only.Pairing_based.t =
        (* Have the sg be available in the opening proof and verify it. *)
        {app_state= next_state; sg= sgs; old_bulletproof_challenges}
      in
      { proof_state= {unfinalized_proofs= unfinalized_proofs_extended; me_only}
      ; pass_through }
    in
    let next_me_only_prepared =
      Reduced_me_only.Pairing_based.prepare
        ~dlog_marlin_index:self_dlog_marlin_index
        next_statement.proof_state.me_only
    in
    let handler (Snarky_backendless.Request.With {request; respond} as r) =
      let k x = respond (Provide x) in
      match request with
      | Req.Proof_with_datas ->
          k witnesses
      | Req.Wrap_index ->
          k self_dlog_marlin_index
      | Req.App_state ->
          k next_me_only_prepared.app_state
      | _ -> (
        match handler with
        | Some f ->
            f r
        | None ->
            Snarky_backendless.Request.unhandled )
    in
    let (next_proof : Tick.Proof.t) =
      let (T (input, conv)) =
        Impls.Step.input ~branching:Max_branching.n ~bulletproof_log2:Rounds.n
      in
      let rec pad : type n k maxes pvals lws lhs.
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
            let t : _ Types.Dlog_based.Proof_state.Me_only.t =
              { sg= Lazy.force Dummy.Ipa.Step.sg
              ; old_bulletproof_challenges=
                  Vector.init Max_branching.n ~f:(fun _ ->
                      Dummy.Ipa.Wrap.challenges_computed ) }
            in
            Common.hash_dlog_me_only Max_branching.n t :: pad [] ms n
      in
      let {Domains.h; k; x} =
        List.nth_exn
          (Vector.to_list step_domains)
          (Index.to_int branch_data.index)
      in
      let to_fold_in =
        let module M =
          H3.Map
            (P.With_data)
            (E03 (Tick.Curve.Affine))
            (struct
              let f (T t : _ P.With_data.t) =
                t.statement.proof_state.me_only.sg
            end)
        in
        let module V = H3.To_vector (Tick.Curve.Affine) in
        V.f prev_values_length (M.f prev_with_proofs)
      in
      ksprintf Common.time "step-prover %d (%d, %d, %d)"
        (Index.to_int branch_data.index)
        (Domain.size h) (Domain.size k) (Domain.size x) (fun () ->
          Impls.Step.prove pk [input]
            ~message:
              (* emphatically NOT padded with dummies *)
              Vector.(
                map2 to_fold_in
                  next_me_only_prepared.old_bulletproof_challenges
                  ~f:(fun commitment chals ->
                    { Tick.Proof.Challenge_polynomial.commitment
                    ; challenges= Vector.to_array chals } )
                |> to_list)
            (fun x () ->
              ( Impls.Step.handle
                  (fun () -> (branch_data.main ~step_domains (conv x) : unit))
                  handler
                : unit ) )
            ()
            { proof_state=
                { next_statement.proof_state with
                  me_only=
                    Common.hash_pairing_me_only
                      ~app_state:A_value.to_field_elements
                      next_me_only_prepared }
            ; pass_through=
                (* TODO: Use the same pad_pass_through function as in wrap *)
                pad
                  (Vector.map statements_with_hashes ~f:(fun s ->
                       s.proof_state.me_only ))
                  Maxes.maxes Maxes.length } )
    in
    let prev_evals =
      let module M =
        H3.Map
          (P.With_data)
          (E03 (E))
          (struct
            let f (T t : _ P.With_data.t) = t.proof.openings.evals
          end)
      in
      let module V = H3.To_vector (E) in
      V.f prev_values_length (M.f prev_with_proofs)
    in
    { proof= next_proof
    ; statement= next_statement
    ; index= branch_data.index
    ; prev_evals=
        Vector.extend
          (Vector.map2 prev_evals x_hats ~f:(fun es x_hat ->
               triple_zip es x_hat ))
          lte Max_branching.n Dummy.evals }
end
