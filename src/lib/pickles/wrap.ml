module SC = Scalar_challenge
module P = Proof
open Pickles_types
open Hlist
open Tuple_lib
open Zexe_backend
open Common
open Core
open Import
open Types

(* This contains the "wrap" prover *)

let vector_of_list (type a t)
    (module V : Snarky.Vector.S with type elt = a and type t = t) (xs : a list)
    : t =
  let r = V.create () in
  List.iter xs ~f:(V.emplace_back r) ;
  r

let combined_evaluation (proof : Zexe_backend.Pairing_based.Proof.t) ~r ~xi
    ~beta_1 ~beta_2 ~beta_3 ~x_hat_beta_1 =
  let { Pairing_marlin_types.Evals.w_hat
      ; z_hat_a
      ; z_hat_b
      ; h_1
      ; h_2
      ; h_3
      ; g_1
      ; g_2
      ; g_3
      ; row= {a= row_0; b= row_1; c= row_2}
      ; col= {a= col_0; b= col_1; c= col_2}
      ; value= {a= val_0; b= val_1; c= val_2}
      ; rc= {a= rc_0; b= rc_1; c= rc_2} } =
    proof.Pairing_marlin_types.Proof.openings.evals
  in
  let combine t (pt : Fp.t) =
    let open Fp in
    Pcs_batch.combine_evaluations ~crs_max_degree ~mul ~add ~one
      ~evaluation_point:pt ~xi t
  in
  let f_1 =
    combine Common.Pairing_pcs_batch.beta_1 beta_1
      [x_hat_beta_1; w_hat; z_hat_a; z_hat_b; g_1; h_1]
      []
  in
  let f_2 = combine Common.Pairing_pcs_batch.beta_2 beta_2 [g_2; h_2] [] in
  let f_3 =
    combine Common.Pairing_pcs_batch.beta_3 beta_3
      [ g_3
      ; h_3
      ; row_0
      ; row_1
      ; row_2
      ; col_0
      ; col_1
      ; col_2
      ; val_0
      ; val_1
      ; val_2
      ; rc_0
      ; rc_1
      ; rc_2 ]
      []
  in
  Fp.(r * (f_1 + (r * (f_2 + (r * f_3)))))

let combined_polynomials ~xi
    ~pairing_marlin_index:(index : _ Abc.t Matrix_evals.t) public_input
    (proof : Zexe_backend.Pairing_based.Proof.t) =
  let combine t v =
    let open G1 in
    let open Pickles_types in
    Pcs_batch.combine_commitments t ~scale ~add ~xi
      (Vector.map v ~f:G1.of_affine)
  in
  let { Pairing_marlin_types.Messages.w_hat
      ; z_hat_a
      ; z_hat_b
      ; gh_1= (g1, _), h1
      ; sigma_gh_2= _, ((g2, _), h2)
      ; sigma_gh_3= _, ((g3, _), h3) } =
    proof.messages
  in
  let x_hat =
    let v = Fp.Vector.create () in
    List.iter public_input ~f:(Fp.Vector.emplace_back v) ;
    let domain_size = Int.ceil_pow2 (List.length public_input) in
    Snarky_bn382.Fp_urs.commit_evaluations
      (Zexe_backend.Pairing_based.Keypair.load_urs ())
      (Unsigned.Size_t.of_int domain_size)
      v
    |> Zexe_backend.G1.Affine.of_backend
  in
  ( combine Common.Pairing_pcs_batch.beta_1
      [x_hat; w_hat; z_hat_a; z_hat_b; g1; h1]
      []
  , combine Common.Pairing_pcs_batch.beta_2 [g2; h2] []
  , combine Common.Pairing_pcs_batch.beta_3
      [ g3
      ; h3
      ; index.row.a
      ; index.row.b
      ; index.row.c
      ; index.col.a
      ; index.col.b
      ; index.col.c
      ; index.value.a
      ; index.value.b
      ; index.value.c
      ; index.rc.a
      ; index.rc.b
      ; index.rc.c ]
      [] )

(* The prover for wrapping a proof *)
let wrap (type max_branching max_local_max_branchings) max_branching
    (module Max_local_max_branchings : Hlist.Maxes.S
      with type ns = max_local_max_branchings
       and type length = max_branching)
    ((module Req) : (max_branching, max_local_max_branchings) Requests.Wrap.t)
    ~dlog_marlin_index wrap_main to_field_elements ~pairing_vk ~step_domains
    ~wrap_domains ~pairing_marlin_indices pk
    ({statement= prev_statement; prev_evals; proof; index= which_index} :
      ( _
      , _
      , _
      , max_local_max_branchings H1.T(P.Base.Me_only.Dlog_based).t
      , ( (Fq.t array Dlog_marlin_types.Evals.t * Fq.t) Triple.t
        , max_branching )
        Vector.t )
      P.Base.Pairing_based.t) =
  let pairing_marlin_index =
    (Vector.to_array pairing_marlin_indices).(which_index)
  in
  let prev_me_only =
    let module M =
      H1.Map (P.Base.Me_only.Dlog_based) (P.Base.Me_only.Dlog_based.Prepared)
        (struct
          let f = P.Base.Me_only.Dlog_based.prepare
        end)
    in
    M.f prev_statement.pass_through
  in
  let prev_statement_with_hashes : _ Types.Pairing_based.Statement.t =
    { proof_state=
        { prev_statement.proof_state with
          me_only=
            Common.hash_pairing_me_only ~app_state:to_field_elements
              (P.Base.Me_only.Pairing_based.prepare ~dlog_marlin_index
                 prev_statement.proof_state.me_only) }
    ; pass_through=
        (let module M =
           H1.Map
             (P.Base.Me_only.Dlog_based.Prepared)
             (E01 (Digest.Constant))
             (struct
               let f (type n) (m : n P.Base.Me_only.Dlog_based.Prepared.t) =
                 let T =
                   Nat.eq_exn Nat.N2.n
                     (Vector.length m.old_bulletproof_challenges)
                 in
                 Common.hash_dlog_me_only m
             end)
         in
        let module V = H1.To_vector (Digest.Constant) in
        V.f Max_local_max_branchings.length (M.f prev_me_only)) }
  in
  let handler (Snarky.Request.With {request; respond}) =
    let open Req in
    let k x = respond (Provide x) in
    match request with
    | Evals ->
        k prev_evals
    | Index ->
        k which_index
    | Pairing_accs ->
        let module M =
          H1.Map
            (P.Base.Me_only.Dlog_based.Prepared)
            (E01 (Pairing_acc))
            (struct
              let f : type a.
                  a P.Base.Me_only.Dlog_based.Prepared.t -> Pairing_acc.t =
               fun t -> t.pairing_marlin_acc
            end)
        in
        let module V = H1.To_vector (Pairing_acc) in
        k (V.f Max_local_max_branchings.length (M.f prev_me_only))
    | Old_bulletproof_challenges ->
        let module M =
          H1.Map
            (P.Base.Me_only.Dlog_based.Prepared)
            (Challenges_vector.Constant)
            (struct
              let f (t : _ P.Base.Me_only.Dlog_based.Prepared.t) =
                t.old_bulletproof_challenges
            end)
        in
        k (M.f prev_me_only)
    | Messages ->
        k proof.messages
    | Openings_proof ->
        k proof.openings.proofs
    | Proof_state ->
        k prev_statement_with_hashes.proof_state
    | _ ->
        Snarky.Request.unhandled
  in
  let module O = Zexe_backend.Pairing_based.Oracles in
  let public_input =
    fp_public_input_of_statement ~max_branching prev_statement_with_hashes
  in
  let o =
    O.create pairing_vk (vector_of_list (module Fp.Vector) public_input) proof
  in
  let x_hat_beta_1 = O.x_hat_beta1 o in
  let next_statement : _ Types.Dlog_based.Statement.t =
    let scalar_chal f =
      Scalar_challenge.map ~f:Challenge.Constant.of_fp (f o)
    in
    let sponge_digest_before_evaluations = O.digest_before_evaluations o in
    let r = scalar_chal O.r in
    let r_k = scalar_chal O.r_k in
    let xi = scalar_chal O.batch in
    let beta_1 = scalar_chal O.beta1 in
    let beta_2 = scalar_chal O.beta2 in
    let beta_3 = scalar_chal O.beta3 in
    let alpha = O.alpha o in
    let eta_a = O.eta_a o in
    let eta_b = O.eta_b o in
    let eta_c = O.eta_c o in
    let module As_field = struct
      let to_field = SC.to_field_constant (module Fp) ~endo:Endo.Pairing.scalar

      let r = to_field r

      let r_k = to_field r_k

      let xi = to_field xi

      let beta_1 = to_field beta_1

      let beta_2 = to_field beta_2

      let beta_3 = to_field beta_3
    end in
    let r_xi_sum =
      let open As_field in
      combined_evaluation ~x_hat_beta_1 ~r ~xi ~beta_1 ~beta_2 ~beta_3 proof
    in
    let me_only : _ Types.Dlog_based.Proof_state.Me_only.t =
      let combined_polys =
        combined_polynomials ~xi:As_field.xi ~pairing_marlin_index public_input
          proof
      in
      let prev_pairing_acc =
        let module G1 = Zexe_backend.G1 in
        let open Pairing_marlin_types.Accumulator in
        let module M =
          H1.Map_reduce (P.Base.Me_only.Dlog_based) (Pairing_acc.Projective)
            (struct
              let reduce into t = accumulate t G1.( + ) ~into

              let map (t : _ P.Base.Me_only.Dlog_based.t) =
                map ~f:G1.of_affine t.pairing_marlin_acc
            end)
        in
        map ~f:G1.to_affine_exn (M.f prev_statement.pass_through)
      in
      { pairing_marlin_acc=
          (let {Domains.h; k} = step_domains in
           let open As_field in
           Pairing_acc.accumulate prev_pairing_acc proof ~domain_h:h
             ~domain_k:k ~r ~r_k ~r_xi_sum ~beta_1 ~beta_2 ~beta_3
             combined_polys)
      ; old_bulletproof_challenges=
          Vector.map prev_statement.proof_state.unfinalized_proofs
            ~f:(fun (t, _) -> t.deferred_values.bulletproof_challenges) }
    in
    let chal = Challenge.Constant.of_fp in
    { proof_state=
        { deferred_values=
            { xi
            ; r
            ; r_xi_sum
            ; marlin=
                { sigma_2= fst proof.messages.sigma_gh_2
                ; sigma_3= fst proof.messages.sigma_gh_3
                ; alpha= chal alpha
                ; eta_a= chal eta_a
                ; eta_b= chal eta_b
                ; eta_c= chal eta_c
                ; beta_1
                ; beta_2
                ; beta_3 } }
        ; was_base_case=
            List.for_all
              ~f:(fun (_, should_verify) -> not should_verify)
              (Vector.to_list prev_statement.proof_state.unfinalized_proofs)
        ; sponge_digest_before_evaluations=
            Digest.Constant.of_fp sponge_digest_before_evaluations
        ; me_only }
    ; pass_through= prev_statement.proof_state.me_only }
  in
  let me_only_prepared =
    P.Base.Me_only.Dlog_based.prepare next_statement.proof_state.me_only
  in
  let next_proof =
    let (T (input, conv)) = Impls.Dlog_based.input () in
    Common.time "wrap proof" (fun () ->
        Impls.Dlog_based.prove pk
          ~message:
            ( Vector.map2 prev_statement.proof_state.me_only.sg
                me_only_prepared.old_bulletproof_challenges ~f:(fun sg chals ->
                  { Zexe_backend.Dlog_based_proof.Challenge_polynomial
                    .commitment= sg
                  ; challenges= Vector.to_array chals } )
            |> Vector.to_list )
          [input]
          (fun x () ->
            ( Impls.Dlog_based.handle
                (fun () -> (wrap_main (conv x) : unit))
                handler
              : unit ) )
          ()
          { pass_through= prev_statement_with_hashes.proof_state.me_only
          ; proof_state=
              { next_statement.proof_state with
                me_only= Common.hash_dlog_me_only me_only_prepared } } )
  in
  ( { proof= next_proof
    ; index= which_index
    ; statement= next_statement
    ; prev_evals= proof.openings.evals
    ; prev_x_hat_beta_1= x_hat_beta_1 }
    : _ P.Base.Dlog_based.t )
