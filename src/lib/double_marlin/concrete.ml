module I = Intf
open Types
open Pickles_types
module D = Digest
open Core_kernel
module Digest = D
open Tuple_lib
open Snarky_bn382_backend

let () = Snarky.Snark0.set_eval_constraints true

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

module type App_state_intf = 
  I.App_state_intf with module Impl := Impls.Pairing_based

let compute_challenge ~is_square x =
  let nonresidue = Fq.of_int 7 in
  Fq.sqrt (if is_square then x else Fq.(nonresidue * x))

let compute_challenges chals =
  Array.map chals ~f:(fun {Bulletproof_challenge.prechallenge; is_square} ->
      let prechallenge =
        Fq.of_bits (Challenge.Constant.to_bits prechallenge)
      in
      assert (is_square = Fq.is_square prechallenge) ;
      compute_challenge ~is_square prechallenge )

let compute_sg chals =
  Snarky_bn382.Fq_urs.b_poly_commitment
    (Lazy.force Snarky_bn382_backend.Dlog_based.Keypair.urs)
    (Fq.Vector.of_array
          (compute_challenges chals) )
  |> G.Affine.of_backend

module Pairing_based_reduced_me_only = struct
  type 's t = {app_state: 's; sg: Snarky_bn382_backend.G.Affine.t}
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

type 's pairing_based_proof =
  { statement:
      ( Challenge.Constant.t
      , Fq.t
      , bool
      , (Challenge.Constant.t, bool) Bulletproof_challenge.t
      , 's Pairing_based_reduced_me_only.t
      , Dlog_based_reduced_me_only.t
      , Digest.Constant.t )
      Statement.Pairing_based.t
  ; prev_evals: Fq.t Dlog_marlin_types.Evals.t Triple.t
  ; prev_x_hat: Fq.t Triple.t
  ; proof: Pairing_based.Proof.t }
[@@deriving bin_io]

type 's dlog_based_proof =
  { statement:
      ( Challenge.Constant.t
      , Fp.t
      , bool
      , Challenge.Constant.t
      , Fq.t
      , Dlog_based_reduced_me_only.t
      , Digest.Constant.t
      , 's Pairing_based_reduced_me_only.t )
      Statement.Dlog_based.t
  ; prev_evals: Fp.t Pairing_marlin_types.Evals.t
  ; prev_x_hat_beta_1 : Fp.t
  ; proof: Dlog_based.Proof.t }
[@@deriving bin_io]

module Dlog_based_proof = struct
  type 's t = 's dlog_based_proof [@@deriving bin_io]

  module M = Pairing_main.Main (Pairing_main_inputs)

  let bulletproof_challenges sponge lr =
    let absorb_g (x, y) =
      Fp_sponge.Bits.absorb sponge x;
      Fp_sponge.Bits.absorb sponge y
    in
    Array.map lr ~f:(fun (l, r) ->
        absorb_g l;
        absorb_g r;
        let open Challenge.Constant in
        let chal = Fp_sponge.Bits.squeeze sponge ~length:length in
        { Bulletproof_challenge.prechallenge= of_bits chal
        ; is_square = Fq.is_square (Fq.of_bits chal)
        } )

  (* TODO: Don't hardcode *)
  let domain_h =
    let num_constraints = 99312 in
    let num_vars = 72640 in
    Domain.Pow_2_roots_of_unity
      (Int.ceil_log2 (Int.max num_constraints num_vars))

  let domain_k =
    let nonzero_entries = 135457 in
    Domain.Pow_2_roots_of_unity (Int.ceil_log2 nonzero_entries)

  let dlog_crs_max_degree = Dlog_main_inputs.crs_max_degree

  let public_input_of_statement prev_statement =
    let input =
      Impls.Dlog_based.generate_public_input
        [Impls.Dlog_based.input]
        (Statement.Dlog_based.to_data prev_statement)
    in
    Fq.one :: List.init (Fq.Vector.length input) ~f:(Fq.Vector.get input)

  let b_poly chals =
    let open Fq in
    let chal_invs = Array.map chals ~f:inv in
    fun x -> Dlog_main.sg_polynomial ~add ~mul chals chal_invs x

  let print_fq lab x = 
    printf "%s: %!" lab; Fq.print x ; printf "%!"

  let step
    (type state)
    ((module State) : (module App_state_intf with type Constant.t = state))
      ~dlog_marlin_index
      ~pairing_marlin_index
      pk
      dlog_vk
      (next_app_state: state)
      ( { proof=prev_proof
        ; statement=prev_statement
        ; prev_evals
        ; prev_x_hat_beta_1
        }
        : state dlog_based_proof)
      : state pairing_based_proof
    =
    let prev_challenges =
      (* TODO: This is redone in the call to Dlog_based_reduced_me_only.prepare *)
      compute_challenges
        prev_statement.proof_state.me_only.old_bulletproof_challenges
    in
    let prev_me_only : _ Me_only.Pairing_based.t =
      Pairing_based_reduced_me_only.prepare ~dlog_marlin_index
        prev_statement.pass_through
    in
    let prev_statement_with_hashes : _ Statement.Dlog_based.t =
      { pass_through=
          Common.hash_pairing_me_only prev_me_only
            ~app_state:State.Constant.to_field_elements
      ; proof_state=
          { prev_statement.proof_state with
            me_only=
              Common.hash_dlog_me_only
                { pairing_marlin_index
                ; old_bulletproof_challenges= prev_challenges
                ; pairing_marlin_acc= prev_statement.proof_state.me_only.pairing_marlin_acc
                }
          }
      }
    in
    let module O = Snarky_bn382_backend.Dlog_based.Oracles in
    let o = 
      let public_input = public_input_of_statement prev_statement_with_hashes in
      O.create
        dlog_vk
        { commitment= prev_statement.pass_through.sg
        ; challenges= prev_challenges }
        public_input
        prev_proof
    in
    let was_base_case = State.Constant.is_base_case next_app_state in
    let (x_hat_1, x_hat_2, x_hat_3) as x_hat = O.x_hat o in
    let beta_1 = O.beta1 o in
    let beta_2 = O.beta2 o in
    let beta_3 = O.beta3 o in
    let alpha = O.alpha o in
    let eta_a = O.eta_a o in
    let eta_b = O.eta_b o in
    let eta_c = O.eta_c o in
    let xi = O.polys o in
    let r = O.evals o in
    let sponge_digest_before_evaluations = O.digest_before_evaluations o in
    (* TODO Just have these generated by calling into rust. *)
    let new_bulletproof_challenges, b =
      let prechals =
        Array.map (O.opening_prechallenges o) ~f:(fun x ->
          (x, Fq.is_square x))
      in
      let chals =
          Array.map prechals ~f:(fun (x, is_square) ->
            compute_challenge ~is_square x )
      in
      let b_poly = b_poly chals in
      let b =
        let open Fq in
        b_poly beta_1 + r * (b_poly beta_2 + r * (b_poly beta_3))
      in
      let prechals = Array.map prechals ~f:(fun (x, is_square) ->
          { Bulletproof_challenge.prechallenge=
              Challenge.Constant.of_fq x; is_square })
      in
      (prechals, b)
    in
    let proof =
      { prev_proof with
        openings=
          { prev_proof.openings with
            proof=
              { prev_proof.openings.proof with
                sg =
                  if was_base_case
                  then compute_sg new_bulletproof_challenges
                  else prev_proof.openings.proof.sg
              }
          }
      }
    in
    let next_statement : _ Statement.Pairing_based.t =
      let combined_inner_product =
        let e1, e2, e3 = proof.openings.evals in
        let open Fq in
        let b_poly = b_poly prev_challenges in
        let combine x_hat pt e =
          let a, b = Dlog_marlin_types.Evals.to_vectors e in
          Pcs_batch.combine_evaluations
            (Common.dlog_pcs_batch ~domain_h ~domain_k)
            ~crs_max_degree:dlog_crs_max_degree
            ~xi
            ~mul ~add ~one
            ~evaluation_point:pt
            (b_poly pt :: x_hat :: a)
            b
        in
        combine x_hat_1 beta_1 e1 + r * (combine x_hat_2 beta_2 e2 + r * combine x_hat_3 beta_3 e3)
      in
      let chal = Challenge.Constant.of_fq in
      let me_only : state Pairing_based_reduced_me_only.t =
        (* Have the sg be available in the opening proof and verify it. *)
        { app_state= next_app_state
        ; sg=
            (* If it "is base case" we should recompute this based on
               the new_bulletproof_challenges
            *)
            if was_base_case
            then compute_sg new_bulletproof_challenges
            else proof.openings.proof.sg
        }
      in
      { proof_state=
          { deferred_values=
              { marlin=
                  { sigma_2=fst proof.messages.sigma_gh_2
                  ; sigma_3=fst proof.messages.sigma_gh_3
                  ; alpha= chal alpha
                  ; eta_a=chal eta_a
                  ; eta_b=chal eta_b
                  ; eta_c=chal eta_c
                  ; beta_1= chal beta_1
                  ; beta_2= chal beta_2
                  ; beta_3= chal beta_3
                  }
              ; combined_inner_product
              ; xi= chal xi
              ; r= chal r
              ; bulletproof_challenges=new_bulletproof_challenges
              ; b
              }
          ; was_base_case
          ; sponge_digest_before_evaluations=
              Digest.Constant.of_fq sponge_digest_before_evaluations
          ; me_only
          }
      ; pass_through= prev_statement.proof_state.me_only
      }
    in
    let next_me_only_prepared =
                     (Pairing_based_reduced_me_only.prepare
                        ~dlog_marlin_index
                        next_statement.proof_state.me_only)
                     in
    let handler (Snarky.Request.With {request; respond}) =
      let open M.Requests in
      let k x = respond (Provide x) in
      match request with
      | Prev_evals -> k prev_evals
      | Prev_messages -> k proof.messages
      | Prev_openings_proof -> k proof.openings.proof
      | Prev_app_state State.Tag -> k prev_statement.pass_through.app_state
      | Prev_sg -> k prev_statement.pass_through.sg
      | Prev_x_hat_beta_1 -> k prev_x_hat_beta_1
      | Me_only State.Tag -> k next_me_only_prepared
      | Prev_proof_state -> k prev_statement_with_hashes.proof_state
      | Compute.Fq_is_square x ->
        k Fq.(is_square (of_bits x))
    in
    let (next_proof : Pairing_based.Proof.t) = 
      Impls.Pairing_based.prove pk
        [ Impls.Pairing_based.input 
            ~bulletproof_log2:(Array.length proof.openings.proof.lr)
        ]
        (fun x () ->
          Impls.Pairing_based.handle
            (fun () ->
                M.main (module State)
                  x )
            handler
        )
        ()
        (Statement.Pairing_based.to_data
           { proof_state=
               { next_statement.proof_state with
                 me_only=
                   Common.hash_pairing_me_only
                     ~app_state:State.Constant.to_field_elements
                     next_me_only_prepared
               }
           ; pass_through=
               prev_statement_with_hashes.proof_state.me_only
           })
    in
    { proof=next_proof
    ; statement=next_statement
    ; prev_evals= proof.openings.evals
    ; prev_x_hat=x_hat
    }
end

module Pairing_based_proof = struct
  module M = Dlog_main.Make (Dlog_main_inputs)

  type 's t = 's pairing_based_proof [@@deriving bin_io]

  (* TODO: Perform finalization as well *)
  let verify  (type s) (module App : App_state_intf with type Constant.t = s)
      ~dlog_marlin_index ~pairing_marlin_index vk :
      s pairing_based_proof -> bool =
   fun {statement; prev_evals; proof} ->
    Impls.Pairing_based.verify proof vk
      [ Impls.Pairing_based.input
          ~bulletproof_log2:(
            Array.length statement.pass_through.old_bulletproof_challenges)
      ]
      (Statement.Pairing_based.to_data
         { proof_state=
             { statement.proof_state with
               me_only=
                 Common.hash_pairing_me_only
                   ~app_state:App.Constant.to_field_elements
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

  let public_input_of_statement (prev_statement : _ Statement.Pairing_based.t) =
    let input =
      Impls.Pairing_based.generate_public_input
        [ Impls.Pairing_based.input
            ~bulletproof_log2:(
              Array.length
                 prev_statement.proof_state.deferred_values.bulletproof_challenges
              )
        ]
        (Statement.Pairing_based.to_data prev_statement)
    in
    Fp.one :: List.init (Fp.Vector.length input) ~f:(Fp.Vector.get input)

  let wrap (type s)
      (module App : App_state_intf with type Constant.t = s)
      ~dlog_marlin_index ~pairing_marlin_index pairing_vk pk
      ({statement= prev_statement; prev_x_hat; prev_evals; proof} :
        s pairing_based_proof) =
    let prev_me_only : _ Me_only.Dlog_based.t =
      Dlog_based_reduced_me_only.prepare ~pairing_marlin_index
        prev_statement.pass_through
    in
    let prev_statement_with_hashes : _ Statement.Pairing_based.t =
      { proof_state=
          { prev_statement.proof_state with
            me_only=
              Common.hash_pairing_me_only
                ~app_state:App.Constant.to_field_elements
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
      | Prev_x_hat ->
          k prev_x_hat
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
    let module O = Snarky_bn382_backend.Pairing_based.Oracles in
    let public_input =
      public_input_of_statement prev_statement_with_hashes
    in
    let o = O.create pairing_vk public_input proof in
    let x_hat_beta_1 = O.x_hat_beta1 o in
    let next_statement : _ Statement.Dlog_based.t =
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
        combined_evaluation ~x_hat_beta_1 ~r ~xi ~beta_1
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
          ; was_base_case= prev_statement.proof_state.was_base_case
          ; sponge_digest_before_evaluations=
              D.Constant.of_fp sponge_digest_before_evaluations
          ; me_only }
      ; pass_through= prev_statement.proof_state.me_only }
    in
    let me_only_prepared =Dlog_based_reduced_me_only.prepare ~pairing_marlin_index
                        next_statement.proof_state.me_only
    in
    let bulletproof_log2=
      Array.length prev_statement.proof_state.deferred_values.bulletproof_challenges
    in
    let next_proof =
      Impls.Dlog_based.prove pk 
        ~message:{
          commitment= prev_statement.proof_state.me_only.sg
        ; challenges= me_only_prepared.old_bulletproof_challenges
        }
        [Impls.Dlog_based.input]
        (fun x () -> Impls.Dlog_based.handle (fun () -> M.main ~bulletproof_log2 x) handler)
        ()
        (Statement.Dlog_based.to_data
           { pass_through= 
               prev_statement_with_hashes.proof_state.me_only
           ; proof_state=
               { next_statement.proof_state with
                 me_only=
                   Common.hash_dlog_me_only
                     me_only_prepared } })
    in
    ( { proof= next_proof
      ; statement= next_statement
      ; prev_evals= proof.openings.evals 
      ; prev_x_hat_beta_1= x_hat_beta_1
      }
      : s dlog_based_proof )
end

module Make (State : App_state_intf) : sig
  val negative_one : State.Constant.t Dlog_based_proof.t

  val step : State.Constant.t Dlog_based_proof.t -> State.Constant.t -> State.Constant.t Pairing_based_proof.t
  val wrap : State.Constant.t Pairing_based_proof.t -> State.Constant.t  Dlog_based_proof.t
end = struct

  let bulletproof_log2 = 20

  let wrap_kp =
    Impls.Dlog_based.generate_keypair
      ~exposing:[Impls.Dlog_based.input]
      (fun x () -> 
         let () = Pairing_based_proof.M.main ~bulletproof_log2 x in ())

  let step_kp =
    Impls.Pairing_based.generate_keypair
      ~exposing:[Impls.Pairing_based.input ~bulletproof_log2]
      (fun x () ->
         let () =
           Dlog_based_proof.M.main
             (module State) x
         in
         ())

  let step_pk = Impls.Pairing_based.Keypair.pk step_kp

  let pairing_marlin_index =
    Snarky_bn382_backend.Pairing_based.Keypair.vk_commitments
      step_pk

  let wrap_pk = Impls.Dlog_based.Keypair.pk wrap_kp

  let dlog_marlin_index =
    Snarky_bn382_backend.Dlog_based.Keypair.vk_commitments
      wrap_pk

  let wrap_vk = Impls.Dlog_based.Keypair.vk wrap_kp
  let step_vk = Impls.Pairing_based.Keypair.vk step_kp

  let negative_one : State.Constant.t dlog_based_proof =
    let ro lab length f =
      let r = ref 0 in
      fun () ->
        incr r ;
        f (Common.bits_random_oracle ~length (sprintf "%s_%d" lab !r))
    in
    let chal =
      ro "chal" Challenge.Constant.length Challenge.Constant.of_bits
    in
    let fp =
      ro "fp" Digest.Constant.length Fp.of_bits
    in
    let fq =
      ro "fq" Digest.Constant.length Fq.of_bits
    in
    let old_bulletproof_challenges =
      let f = ro "bpchal" Challenge.Constant.length Challenge.Constant.of_bits in
      Array.init bulletproof_log2 ~f:(fun _ ->
          let prechallenge = f () in
          { Bulletproof_challenge.prechallenge
          ; is_square = Fq.is_square (Fq.of_bits (Challenge.Constant.to_bits prechallenge)) } )
    in
    let old_sg = compute_sg old_bulletproof_challenges in
    let opening_check : _ Pairing_marlin_types.Accumulator.Opening_check.t =
      (* TODO: Leaky *)
      let t = Snarky_bn382.Fp_urs.dummy_opening_check
          (Lazy.force Snarky_bn382_backend.Pairing_based.Keypair.urs)
      in
      { r_f_minus_r_v_plus_rz_pi=
          Snarky_bn382.G1.Affine.Pair.f0 t
          |> G1.Affine.of_backend
      ; r_pi= 
          Snarky_bn382.G1.Affine.Pair.f1 t
          |> G1.Affine.of_backend
      }
    in
    let degree_bound_checks : _ Pairing_marlin_types.Accumulator.Degree_bound_checks.t =
      let h =
        Unsigned.Size_t.to_int (Snarky_bn382.Fp_index.domain_h_size step_pk)
      in
      let k =
        Unsigned.Size_t.to_int (Snarky_bn382.Fp_index.domain_k_size step_pk)
      in
      (* TODO: Leaky *)
      let t =
        Snarky_bn382.Fp_urs.dummy_degree_bound_checks
          (Lazy.force Snarky_bn382_backend.Pairing_based.Keypair.urs)
          (Unsigned.Size_t.of_int (h - 1))
          (Unsigned.Size_t.of_int (k - 1))
      in
      { shifted_accumulator=
          Snarky_bn382.G1.Affine.Vector.get t 0
          |> G1.Affine.of_backend
      ; unshifted_accumulators= 
          Vector.init Nat.N2.n ~f:(fun i ->
          G1.Affine.of_backend (Snarky_bn382.G1.Affine.Vector.get t i))
      }
    in
    let g= G.(to_affine_exn one)in
    let opening_proof_lr =Array.init bulletproof_log2 ~f:(fun _ ->
        (g,g))
    in
    let opening_proof_challenges =
      (* This has to be the sponge state at the end of the inner marlin
         protocol *)
      Dlog_based_proof.bulletproof_challenges
        (Fp_sponge.Bits.create Fp_sponge.params)
        opening_proof_lr
    in
    { proof=
        { messages=
            { w_hat=g
            ; z_hat_a=g
            ; z_hat_b=g
            ; gh_1=((g,g), g)
            ; sigma_gh_2=(fq (), ((g,g),g))
            ; sigma_gh_3=(fq (), ((g,g),g))
            }
        ; openings=
            { proof=
                { lr=opening_proof_lr
                ; z_1= fq ()
                ; z_2= fq ()
                ; delta = g
                ; sg= compute_sg opening_proof_challenges
                }
            ; evals=(
                let e : _ Dlog_marlin_types.Evals.t =
                  let abc ()= { Abc.a=fq();b=fq(); c=fq() } in
                  { w_hat=fq ()
                  ; z_hat_a= fq()
                  ; z_hat_b= fq()
                  ; g_1= fq()
                  ; h_1= fq()
                  ; g_2= fq()
                  ; h_2= fq()
                  ; g_3= fq()
                  ; h_3= fq()
                  ; row= abc()
                  ; col= abc()
                  ; value= abc()
                  ; rc= abc()
                  }
                in
                (e , e, e)
              )
            }
        }
    ; statement=
        { proof_state=
          { deferred_values=
              { xi=chal ()
              ; r= chal ()
              ; r_xi_sum= fp ()
              ; marlin=
                  { sigma_2= fp ()
                  ; sigma_3= fp ()
                  ; alpha= chal ()
                  ; eta_a= chal ()
                  ; eta_b= chal ()
                  ; eta_c= chal ()
                  ; beta_1= chal ()
                  ; beta_2= chal ()
                  ; beta_3= chal ()
                  }
              }
          ; sponge_digest_before_evaluations=
              Digest.Constant.of_fq Fq.zero
          ; was_base_case= true
          ; me_only=
              (* TODO: Gotta make this stuff real *)
              { pairing_marlin_acc=
                  { opening_check
                  ; degree_bound_checks
                  }
              ; old_bulletproof_challenges
              }
          }
        ; pass_through=
            { app_state= State.Constant.dummy
            ; sg=old_sg
            }
        }
    ; prev_x_hat_beta_1 = fp ()
    ; prev_evals=
        (
           let abc ()= { Abc.a=fp();b=fp(); c=fp() } in
           { w_hat= fp ()
            ; z_hat_a= fp()
            ; z_hat_b= fp()
            ; g_1= fp()
            ; h_1= fp()
            ; g_2= fp()
            ; h_2= fp()
            ; g_3= fp()
            ; h_3= fp()
            ; row= abc()
            ; col= abc()
            ; value= abc()
            ; rc= abc()
           }
         )
    }

  let step dlog_proof next_state =
    Dlog_based_proof.step
      (module State)
      ~dlog_marlin_index
      ~pairing_marlin_index
      step_pk
      wrap_vk
      next_state
      dlog_proof

  let wrap proof =
    Pairing_based_proof.wrap
      (module State)
      ~dlog_marlin_index
      ~pairing_marlin_index
      step_vk
      wrap_pk
      proof
end

let%test_unit "concrete" =
  let module State = struct
    open Impls.Pairing_based

    type t = Field.t

    type _ Tag.t += Tag : Field.Constant.t Tag.t

    module Constant = struct
      include Field.Constant

      let is_base_case = Field.Constant.(equal zero)

      let to_field_elements x = [|x|]

      let dummy = Field.Constant.zero
    end

    let to_field_elements x = [|x|]

    let typ = Typ.field

    let check_update x0 x1 = Field.(equal x1 (x0 + one))

    let is_base_case x = Field.(equal x zero)
  end
  in
  let module M = Make(State) in
  let open Common in
  let proof =
    time "first step" (fun () ->
      M.step M.negative_one Fp.zero )
  in
  let proof =
    time "first wrap" (fun () ->
        M.wrap proof ) 
  in
  let proof =
    time "second step" (fun () ->
      M.step proof Fp.one ) in
  let proof =
    time "second wrap" (fun () ->
        M.wrap proof )
  in
  ()
