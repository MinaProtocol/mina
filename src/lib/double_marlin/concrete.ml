open Types
open Pickles_types
module D = Digest
open Core_kernel
module Digest = D
open Tuple_lib
open Snarky_bn382_backend

module Proof_state = struct
  module Dlog_based = Types.Dlog_based.Proof_state
  module Pairing_based = Types.Pairing_based.Proof_state
end

module Me_only = struct
  module Dlog_based = Types.Dlog_based.Proof_state.Me_only
  module Pairing_based = Types.Pairing_based.Proof_state.Me_only
end

module Statement = struct
  module Dlog_based = Types.Dlog_based.Statement
  module Pairing_based = Types.Pairing_based.Statement
end

let compute_challenges chals =
  let nonresidue = Fq.of_int 5 in
  Array.map chals ~f:(fun {Bulletproof_challenge.prechallenge; is_square} ->
      let prechallenge =
        Fq.of_bits (Challenge.Constant.to_bits prechallenge)
      in
      assert (is_square = Fq.is_square prechallenge) ;
      let sq =
        if is_square then prechallenge else Fq.(nonresidue * prechallenge)
      in
      Fq.sqrt sq )

module State = Impls.Pairing_based.Field

module Pairing_based_reduced_me_only = struct
  type t = {app_state: State.Constant.t; sg: Snarky_bn382_backend.G.Affine.t}
  [@@deriving bin_io]

  let prepare ~dlog_marlin_index {app_state; sg} =
    {Me_only.Pairing_based.app_state; sg; dlog_marlin_index}
end

module Dlog_based_reduced_me_only = struct
  type t =
    { pairing_marlin_acc:
        Snarky_bn382_backend.G1.Affine.t Pairing_marlin_types.Accumulator.t
    ; old_bulletproof_challenges:
        (Challenge.Constant.t, bool) Bulletproof_challenge.t array }
  [@@deriving bin_io]

  let prepare ~pairing_marlin_index
      {pairing_marlin_acc; old_bulletproof_challenges} =
    { Me_only.Dlog_based.pairing_marlin_index
    ; pairing_marlin_acc
    ; old_bulletproof_challenges= compute_challenges old_bulletproof_challenges
    }
end

type pairing_based_proof =
  { statement:
      ( Challenge.Constant.t
      , Fq.t
      , bool
      , (Challenge.Constant.t, bool) Bulletproof_challenge.t
      , Pairing_based_reduced_me_only.t
      , Dlog_based_reduced_me_only.t
      , Digest.Constant.t )
      Statement.Pairing_based.t
  ; prev_evals: Fq.t Dlog_marlin_types.Evals.t Triple.t
  ; prev_x_hat_beta_1: Fq.t
  ; proof: Pairing_based.Proof.t }
[@@deriving bin_io]

type dlog_based_proof =
  { statement:
      ( Challenge.Constant.t
      , Fp.t
      , Challenge.Constant.t
      , Fq.t
      , Dlog_based_reduced_me_only.t
      , Digest.Constant.t
      , Pairing_based_reduced_me_only.t )
      Statement.Dlog_based.t
  ; prev_evals: Fp.t Pairing_marlin_types.Evals.t
  ; proof: Dlog_based.Proof.t }
[@@deriving bin_io]

module Pairing_based_proof = struct
  module M = Dlog_main.Make (Dlog_main_inputs)

  type t = pairing_based_proof [@@deriving bin_io]

  let verify ~dlog_marlin_index ~pairing_marlin_index vk app_state :
      pairing_based_proof -> bool =
   fun {statement; prev_evals; proof} ->
    Impls.Pairing_based.verify proof vk
      [Impls.Pairing_based.input]
      (Statement.Pairing_based.to_data
         { proof_state=
             { statement.proof_state with
               me_only=
                 Common.hash_pairing_me_only
                   (Pairing_based_reduced_me_only.prepare ~dlog_marlin_index
                      statement.proof_state.me_only) }
         ; pass_through=
             Common.hash_dlog_me_only
               (Dlog_based_reduced_me_only.prepare ~pairing_marlin_index
                  statement.pass_through) })

  let combined_polynomials ~xi
      ~pairing_marlin_index:(index : _ Abc.t Matrix_evals.t) public_input
      (proof : Pairing_based.Proof.t) =
    let combine t v =
      let open G1 in
      Pickles_types.Pcs_batch.combine_commitments t ~scale ~add ~xi
        (Pickles_types.Vector.map v ~f:G1.of_affine)
    in
    let { Pickles_types.Pairing_marlin_types.Messages.w_hat
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
      Snarky_bn382.Fp_urs.commit_evaluations
        (Lazy.force Snarky_bn382_backend.Pairing_based.Keypair.urs)
        (Unsigned.Size_t.of_int 64)
        v
      |> Snarky_bn382_backend.G1.Affine.of_backend
    in
    ( combine Common.pairing_beta_1_pcs_batch
        [x_hat; w_hat; z_hat_a; z_hat_b; g1; h1]
        []
    , combine Common.pairing_beta_2_pcs_batch [g2; h2] []
    , combine Common.pairing_beta_3_pcs_batch
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
        ; index.value.c ]
        [] )

  let combined_evaluation (proof : Pairing_based.Proof.t) ~r ~xi ~beta_1
      ~beta_2 ~beta_3 ~x_hat_beta_1 =
    let { Pickles_types.Pairing_marlin_types.Evals.w_hat
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
        ; value= {a= val_0; b= val_1; c= val_2} } =
      proof.openings.evals
    in
    let combine t (pt : Fp.t) =
      let open Fp in
      Pickles_types.Pcs_batch.combine_evaluations
        ~crs_max_degree:Dlog_main_inputs.crs_max_degree ~mul ~add ~one
        ~evaluation_point:pt ~xi t
    in
    let f_1 =
      combine Common.pairing_beta_1_pcs_batch beta_1
        [x_hat_beta_1; w_hat; z_hat_a; z_hat_b; g_1; h_1]
        []
    in
    let f_2 = combine Common.pairing_beta_2_pcs_batch beta_2 [g_2; h_2] [] in
    let f_3 =
      combine Common.pairing_beta_3_pcs_batch beta_3
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
        ; val_2 ]
        []
    in
    Fp.(r * (f_1 + (r * (f_2 + (r * f_3)))))

  let accumulate_pairing_checks (proof : Pairing_based.Proof.t)
      (prev_acc : _ Pairing_marlin_types.Accumulator.t) ~r ~r_k ~r_xi_sum
      ~beta_1 ~beta_2 ~beta_3 (f_1, f_2, f_3) =
    let open G1 in
    let prev_acc =
      Pickles_types.Pairing_marlin_types.Accumulator.map ~f:of_affine prev_acc
    in
    let proof1, proof2, proof3 =
      Triple.map proof.openings.proofs ~f:of_affine
    in
    let conv = Double.map ~f:of_affine in
    let g1 = conv (fst proof.messages.gh_1) in
    let g2 = conv (fst (snd proof.messages.sigma_gh_2)) in
    let g3 = conv (fst (snd proof.messages.sigma_gh_3)) in
    Pickles_types.Pairing_marlin_types.Accumulator.map ~f:to_affine_exn
      { degree_bound_checks=
          Dlog_main.accumulate_degree_bound_checks prev_acc.degree_bound_checks
            ~add ~scale ~r_h:r ~r_k g1 g2 g3
      ; opening_check=
          Dlog_main.accumulate_opening_check ~add ~negate ~scale ~generator:one
            ~r ~r_xi_sum prev_acc.opening_check (f_1, beta_1, proof1)
            (f_2, beta_2, proof2) (f_3, beta_3, proof3) }

  let public_input_of_statement prev_statement =
    let input =
      Impls.Pairing_based.generate_public_input
        [Impls.Pairing_based.input]
        (Statement.Pairing_based.to_data prev_statement)
    in
    Fp.one :: List.init (Fp.Vector.length input) ~f:(Fp.Vector.get input)

  let wrap ~dlog_marlin_index ~pairing_marlin_index pairing_vk pk
      ({statement= prev_statement; prev_x_hat_beta_1; prev_evals; proof} :
        pairing_based_proof) _ =
    let prev_me_only : _ Me_only.Dlog_based.t =
      Dlog_based_reduced_me_only.prepare ~pairing_marlin_index
        prev_statement.pass_through
    in
    let prev_statement_with_hashes : _ Statement.Pairing_based.t =
      { proof_state=
          { prev_statement.proof_state with
            me_only=
              Common.hash_pairing_me_only
                (Pairing_based_reduced_me_only.prepare ~dlog_marlin_index
                   prev_statement.proof_state.me_only) }
      ; pass_through= Common.hash_dlog_me_only prev_me_only }
    in
    let handler (Snarky.Request.With {request; respond}) =
      let open M.Requests in
      let k x = respond (Provide x) in
      match request with
      | Prev_evals ->
          k prev_evals
      | Prev_x_hat_beta_1 ->
          k prev_x_hat_beta_1
      | Prev_messages ->
          k proof.messages
      | Prev_openings_proof ->
          k proof.openings.proofs
      | Prev_proof_state ->
          k prev_statement_with_hashes.proof_state
      | Prev_me_only ->
          k prev_me_only
      | _ ->
          Snarky.Request.unhandled
    in
    let next_statement : _ Statement.Dlog_based.t =
      let public_input =
        public_input_of_statement prev_statement_with_hashes
      in
      let module O = Snarky_bn382_backend.Pairing_based.Oracles in
      let o = O.create pairing_vk public_input proof in
      let sponge_digest_before_evaluations = O.digest_before_evaluations o in
      let r = O.r o in
      let r_k = O.r_k o in
      let xi = O.batch o in
      let beta_1 = O.beta1 o in
      let beta_2 = O.beta2 o in
      let beta_3 = O.beta3 o in
      let alpha = O.alpha o in
      let eta_a = O.eta_a o in
      let eta_b = O.eta_b o in
      let eta_c = O.eta_c o in
      let r_xi_sum =
        combined_evaluation ~x_hat_beta_1:(O.x_hat_beta1 o) ~r ~xi ~beta_1
          ~beta_2 ~beta_3 proof
      in
      let me_only : Dlog_based_reduced_me_only.t =
        let combined_polys =
          combined_polynomials ~xi ~pairing_marlin_index public_input proof
        in
        { pairing_marlin_acc=
            accumulate_pairing_checks proof
              prev_statement.pass_through.pairing_marlin_acc ~r ~r_k ~r_xi_sum
              ~beta_1 ~beta_2 ~beta_3 combined_polys
        ; old_bulletproof_challenges=
            prev_statement.proof_state.deferred_values.bulletproof_challenges
        }
      in
      let chal = Challenge.Constant.of_fp in
      { proof_state=
          { deferred_values=
              { xi= chal xi
              ; r= chal r
              ; r_xi_sum
              ; marlin=
                  { sigma_2= fst proof.messages.sigma_gh_2
                  ; sigma_3= fst proof.messages.sigma_gh_3
                  ; alpha= chal alpha
                  ; eta_a= chal eta_a
                  ; eta_b= chal eta_b
                  ; eta_c= chal eta_c
                  ; beta_1= chal beta_1
                  ; beta_2= chal beta_2
                  ; beta_3= chal beta_3 } }
          ; sponge_digest_before_evaluations=
              D.Constant.of_fp sponge_digest_before_evaluations
          ; me_only }
      ; pass_through= prev_statement.proof_state.me_only }
    in
    let next_proof =
      Impls.Dlog_based.prove pk [Impls.Dlog_based.input]
        (fun x () -> Impls.Dlog_based.handle (fun () -> M.main x) handler)
        ()
        (Statement.Dlog_based.to_data
           { pass_through= prev_statement_with_hashes.pass_through
           ; proof_state=
               { next_statement.proof_state with
                 me_only=
                   Common.hash_dlog_me_only
                     (Dlog_based_reduced_me_only.prepare ~pairing_marlin_index
                        next_statement.proof_state.me_only) } })
    in
    ( { proof= next_proof
      ; statement= next_statement
      ; prev_evals= proof.openings.evals }
      : dlog_based_proof )
end

(*
module Dlog_based = struct
  module Proof = struct
    type 'state t = 'state dlog_based_proof [@@deriving bin_io]

    let step :
           'state dlog_based_proof
        -> new_state:'state
        -> 'state pairing_based_proof =
     fun _ -> failwith "TODO"
  end
end *)
