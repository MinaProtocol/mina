module I = Intf
open Types
open Rugelach_types
module D = Digest
open Core_kernel
module Digest = D
open Tuple_lib
open Snarky_bn382_backend

let compute_challenge ~is_square x =
  let nonresidue = Fq.of_int 7 in
  Fq.sqrt (if is_square then x else Fq.(nonresidue * x))

let compute_challenges chals =
  Vector.map chals ~f:(fun {Bulletproof_challenge.prechallenge; is_square} ->
      let prechallenge =
        Fq.of_bits (Challenge.Constant.to_bits prechallenge)
      in
      assert (is_square = Fq.is_square prechallenge) ;
      compute_challenge ~is_square prechallenge )

let compute_sg chals =
  Snarky_bn382.Fq_urs.b_poly_commitment
    (Snarky_bn382_backend.Dlog_based.Keypair.load_urs ())
    (Fq.Vector.of_array (Vector.to_array (compute_challenges chals)))
  |> G.Affine.of_backend

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

module Nvector (N : Nat.Intf) = struct
  type 'a t = ('a, N.n) Vector.t

  include Vector.Binable (N)
  include Vector.Sexpable (N)
end

module Inputs
    (Branching_pred : Nat.Add.Intf_transparent)
    (Bp_rounds : Nat.Add.Intf_transparent) =
struct
  module Pairing = struct
    module Branching_pred = Branching_pred
    include Pairing_main_inputs
  end

  module Dlog = struct
    module Branching_pred = Branching_pred
    module Bulletproof_rounds = Bp_rounds

    let crs_max_degree = 1 lsl Rugelach_types.Nat.to_int Bulletproof_rounds.n

    include Dlog_main_inputs
  end
end

module Make
    (Branching_pred : Nat.Add.Intf_transparent)
    (Bp_rounds : Nat.Add.Intf_transparent) =
struct
  module Branching = Nat.S (Branching_pred)
  module Inputs = Inputs (Branching_pred) (Bp_rounds)
  module Bp_vector = Nvector (Bp_rounds)
  module Branching_vector = Nvector (Branching)

  module Pairing_based_reduced_me_only = struct
    type 's t =
      {app_state: 's; sg: Snarky_bn382_backend.G.Affine.t Branching_vector.t}
    [@@deriving bin_io]

    let prepare ~dlog_marlin_index {app_state; sg} =
      {Me_only.Pairing_based.app_state; sg; dlog_marlin_index}
  end

  module Dlog_based_reduced_me_only = struct
    type g1 =
      Impls.Dlog_based.Field.Constant.t * Impls.Dlog_based.Field.Constant.t
    [@@deriving sexp, bin_io]

    type t =
      { pairing_marlin_acc: g1 Pairing_marlin_types.Accumulator.t
      ; old_bulletproof_challenges:
          (Challenge.Constant.t, bool) Bulletproof_challenge.t Bp_vector.t
          Branching_vector.t }
    [@@deriving bin_io, sexp_of]

    let prepare ~pairing_marlin_index
        {pairing_marlin_acc; old_bulletproof_challenges} =
      { Me_only.Dlog_based.pairing_marlin_index
      ; pairing_marlin_acc
      ; old_bulletproof_challenges=
          Vector.map ~f:compute_challenges old_bulletproof_challenges }
  end

  type 's pairing_based_proof =
    { statement:
        ( ( Challenge.Constant.t
          , Fq.t
          , (Challenge.Constant.t, bool) Bulletproof_challenge.t Bp_vector.t
          , Digest.Constant.t )
          Types.Pairing_based.Proof_state.Per_proof.t
          Branching_vector.t
        , 's Pairing_based_reduced_me_only.t
        , bool
        , Dlog_based_reduced_me_only.t Branching_vector.t )
        Statement.Pairing_based.t
    ; prev_evals:
        (Fq.t Dlog_marlin_types.Evals.t * Fq.t) Triple.t Branching_vector.t
    ; proof: Pairing_based.Proof.t }
  [@@deriving bin_io]

  type 's dlog_based_proof =
    { statement:
        ( Challenge.Constant.t
        , Fp.t
        , bool
        , Fq.t
        , Dlog_based_reduced_me_only.t
        , Digest.Constant.t
        , 's Pairing_based_reduced_me_only.t )
        Statement.Dlog_based.t
    ; prev_evals: Fp.t Pairing_marlin_types.Evals.t
    ; prev_x_hat_beta_1: Fp.t
    ; proof: Dlog_based.Proof.t }
  [@@deriving bin_io]

  module Dlog_based_proof = struct
    type 's t = 's dlog_based_proof [@@deriving bin_io]

    module M = Pairing_main.Main (Inputs.Pairing)

    let bulletproof_challenges sponge lr =
      let absorb_g (x, y) =
        Fp_sponge.Bits.absorb sponge x ;
        Fp_sponge.Bits.absorb sponge y
      in
      Array.map lr ~f:(fun (l, r) ->
          absorb_g l ;
          absorb_g r ;
          let open Challenge.Constant in
          let chal = Fp_sponge.Bits.squeeze sponge ~length in
          { Bulletproof_challenge.prechallenge= of_bits chal
          ; is_square= Fq.is_square (Fq.of_bits chal) } )

    let public_input_of_statement prev_statement =
      let input =
        let (T (typ, _conv)) = Impls.Dlog_based.input () in
        Impls.Dlog_based.generate_public_input [typ] prev_statement
      in
      Fq.one :: List.init (Fq.Vector.length input) ~f:(Fq.Vector.get input)

    let b_poly = Fq.(Dlog_main.b_poly ~add ~mul ~inv)

    let print_fq lab x = printf "%s: %!" lab ; Fq.print x ; printf "%!"

    let triple_zip (a1, a2, a3) (b1, b2, b3) = ((a1, b1), (a2, b2), (a3, b3))

    let step (type state)
        (module State : M.App_state_intf with type Constant.t = state)
        ~pairing_domains ~dlog_domains ~dlog_marlin_index ~pairing_marlin_index
        pk dlog_vk (next_app_state : state)
        (prev_proofs : state dlog_based_proof Branching_vector.t) :
        state pairing_based_proof =
      let was_base_case = State.Constant.is_base_case next_app_state in
      let unfinalized_proofs, prev_statements_with_hashes, x_hats =
        Vector.map prev_proofs
          ~f:(fun {statement; prev_evals; prev_x_hat_beta_1; proof} ->
            let prev_challenges =
              (* TODO: This is redone in the call to Dlog_based_reduced_me_only.prepare *)
              Vector.map ~f:compute_challenges
                statement.proof_state.me_only.old_bulletproof_challenges
            in
            let prev_statement_with_hashes : _ Statement.Dlog_based.t =
              { pass_through=
                  Common.hash_pairing_me_only
                    (Pairing_based_reduced_me_only.prepare ~dlog_marlin_index
                       statement.pass_through)
                    ~app_state:State.Constant.to_field_elements
              ; proof_state=
                  { statement.proof_state with
                    me_only=
                      Common.hash_dlog_me_only
                        { pairing_marlin_index
                        ; old_bulletproof_challenges= prev_challenges
                        ; pairing_marlin_acc=
                            statement.proof_state.me_only.pairing_marlin_acc }
                  } }
            in
            let module O = Snarky_bn382_backend.Dlog_based.Oracles in
            let o =
              let public_input =
                public_input_of_statement prev_statement_with_hashes
              in
              O.create dlog_vk
                Vector.(
                  map2 statement.pass_through.sg prev_challenges
                    ~f:(fun commitment chals ->
                      { Snarky_bn382_backend.Dlog_based_proof
                        .Challenge_polynomial
                        .commitment
                      ; challenges= Vector.to_array chals } )
                  |> to_list)
                public_input proof
            in
            let ((x_hat_1, x_hat_2, x_hat_3) as x_hat) = O.x_hat o in
            let beta_1 = O.beta1 o in
            let beta_2 = O.beta2 o in
            let beta_3 = O.beta3 o in
            let alpha = O.alpha o in
            let eta_a = O.eta_a o in
            let eta_b = O.eta_b o in
            let eta_c = O.eta_c o in
            let xi = O.polys o in
            let r = O.evals o in
            let sponge_digest_before_evaluations =
              O.digest_before_evaluations o
            in
            let combined_inner_product =
              let e1, e2, e3 = proof.openings.evals in
              let b_polys =
                Vector.map
                  ~f:(Fn.compose b_poly Vector.to_array)
                  prev_challenges
              in
              let combine x_hat pt e =
                let a, b = Dlog_marlin_types.Evals.to_vectors e in
                let v =
                  Vector.append
                    (Vector.map b_polys ~f:(fun f -> f pt))
                    (x_hat :: a)
                    (snd (Branching.add Nat.N19.n))
                in
                let open Fq in
                let domain_h, domain_k = dlog_domains in
                Pcs_batch.combine_evaluations
                  (Common.dlog_pcs_batch (Branching.add Nat.N19.n) ~domain_h
                     ~domain_k)
                  ~crs_max_degree:Inputs.Dlog.crs_max_degree ~xi ~mul ~add ~one
                  ~evaluation_point:pt v b
              in
              let open Fq in
              combine x_hat_1 beta_1 e1
              + r
                * (combine x_hat_2 beta_2 e2 + (r * combine x_hat_3 beta_3 e3))
            in
            let new_bulletproof_challenges, b =
              let prechals =
                Array.map (O.opening_prechallenges o) ~f:(fun x ->
                    (x, Fq.is_square x) )
              in
              let chals =
                Array.map prechals ~f:(fun (x, is_square) ->
                    compute_challenge ~is_square x )
              in
              let b_poly = b_poly chals in
              let b =
                let open Fq in
                b_poly beta_1 + (r * (b_poly beta_2 + (r * b_poly beta_3)))
              in
              let prechals =
                Array.map prechals ~f:(fun (x, is_square) ->
                    { Bulletproof_challenge.prechallenge=
                        Challenge.Constant.of_fq x
                    ; is_square } )
              in
              (prechals, b)
            in
            let chal = Challenge.Constant.of_fq in
            ( { Types.Pairing_based.Proof_state.Per_proof.deferred_values=
                  { marlin=
                      { sigma_2= fst proof.messages.sigma_gh_2
                      ; sigma_3= fst proof.messages.sigma_gh_3
                      ; alpha= chal alpha
                      ; eta_a= chal eta_a
                      ; eta_b= chal eta_b
                      ; eta_c= chal eta_c
                      ; beta_1= chal beta_1
                      ; beta_2= chal beta_2
                      ; beta_3= chal beta_3 }
                  ; combined_inner_product
                  ; xi= chal xi
                  ; r= chal r
                  ; bulletproof_challenges=
                      Vector.of_list_and_length_exn
                        (Array.to_list new_bulletproof_challenges)
                        Bp_rounds.n
                  ; b }
              ; sponge_digest_before_evaluations=
                  Digest.Constant.of_fq sponge_digest_before_evaluations }
            , prev_statement_with_hashes
            , x_hat ) )
        |> Vector.unzip3
      in
      let next_statement : _ Statement.Pairing_based.t =
        let me_only : state Pairing_based_reduced_me_only.t =
          (* Have the sg be available in the opening proof and verify it. *)
          { app_state= next_app_state
          ; sg=
              Vector.map2 unfinalized_proofs prev_proofs ~f:(fun u p ->
                  (* If it "is base case" we should recompute this based on
               the new_bulletproof_challenges
            *)
                  if was_base_case then
                    compute_sg u.deferred_values.bulletproof_challenges
                  else p.proof.openings.proof.sg ) }
        in
        { proof_state= {unfinalized_proofs; me_only; was_base_case}
        ; pass_through=
            Vector.map prev_proofs ~f:(fun {statement; _} ->
                statement.proof_state.me_only ) }
      in
      let next_me_only_prepared =
        Pairing_based_reduced_me_only.prepare ~dlog_marlin_index
          next_statement.proof_state.me_only
      in
      let handler (Snarky.Request.With {request; respond}) =
        let open M.Requests in
        let k x = respond (Provide x) in
        match request with
        | Prev_evals ->
            k
              (Vector.map prev_proofs
                 ~f:(fun {prev_evals; prev_x_hat_beta_1; _} ->
                   (prev_evals, prev_x_hat_beta_1) ))
        | Prev_messages ->
            k (Vector.map prev_proofs ~f:(fun {proof; _} -> proof.messages))
        | Prev_openings_proof ->
            k
              (Vector.map2 prev_proofs next_statement.proof_state.me_only.sg
                 ~f:(fun {proof; _} sg -> {proof.openings.proof with sg}))
        | Prev_states State.Tag ->
            k
              (Vector.map2 prev_proofs prev_statements_with_hashes
                 ~f:(fun prev s ->
                   (s.proof_state, prev.statement.pass_through.app_state) ))
        | Prev_sg ->
            k
              (Vector.map prev_proofs ~f:(fun prev ->
                   prev.statement.pass_through.sg ))
        | Me_only State.Tag ->
            k next_me_only_prepared
        | Compute.Fq_is_square x ->
            k Fq.(is_square (of_bits x))
        | _ ->
            Snarky.Request.unhandled
      in
      let (next_proof : Pairing_based.Proof.t) =
        let (T (input, conv)) =
          Impls.Pairing_based.input ~branching:Branching.n
            ~bulletproof_log2:Bp_rounds.n
        in
        let domain_h, domain_k = pairing_domains in
        Impls.Pairing_based.prove pk [input]
          (fun x () ->
            ( Impls.Pairing_based.handle
                (fun () ->
                  M.main ~bulletproof_log2:(Nat.to_int Bp_rounds.n) ~domain_h
                    ~domain_k
                    (module State)
                    (conv x) )
                handler
              : unit ) )
          ()
          { proof_state=
              { next_statement.proof_state with
                me_only=
                  Common.hash_pairing_me_only
                    ~app_state:State.Constant.to_field_elements
                    next_me_only_prepared }
          ; pass_through=
              Vector.map prev_statements_with_hashes ~f:(fun s ->
                  s.proof_state.me_only ) }
      in
      { proof= next_proof
      ; statement= next_statement
      ; prev_evals=
          Vector.map2 prev_proofs x_hats ~f:(fun p x_hat ->
              triple_zip p.proof.openings.evals x_hat ) }
  end

  module type App_state_intf =
    I.App_state_intf
    with module Impl := Impls.Pairing_based
     and module Branching := Branching

  module Pairing_based_proof = struct
    module M = Dlog_main.Make (Inputs.Dlog)

    type 's t = 's pairing_based_proof [@@deriving bin_io]

    (* TODO: Perform finalization as well *)
    let verify (type s) (module App : App_state_intf with type Constant.t = s)
        ~dlog_marlin_index ~pairing_marlin_index vk :
        s pairing_based_proof -> bool =
     fun {statement; prev_evals; proof} ->
      let (T (typ, conv)) =
        Impls.Pairing_based.input ~branching:Branching.n
          ~bulletproof_log2:Bp_rounds.n
      in
      Impls.Pairing_based.verify proof vk [typ]
        { proof_state=
            { statement.proof_state with
              me_only=
                Common.hash_pairing_me_only
                  ~app_state:App.Constant.to_field_elements
                  (Pairing_based_reduced_me_only.prepare ~dlog_marlin_index
                     statement.proof_state.me_only) }
        ; pass_through=
            Vector.map statement.pass_through ~f:(fun x ->
                Common.hash_dlog_me_only
                  (Dlog_based_reduced_me_only.prepare ~pairing_marlin_index x)
            ) }

    let combined_polynomials ~xi
        ~pairing_marlin_index:(index : _ Abc.t Matrix_evals.t) public_input
        (proof : Pairing_based.Proof.t) =
      let combine t v =
        let open G1 in
        let open Rugelach_types in
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
        Snarky_bn382.Fp_urs.commit_evaluations
          (Snarky_bn382_backend.Pairing_based.Keypair.load_urs ())
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
          ; value= {a= val_0; b= val_1; c= val_2} } =
        proof.openings.evals
      in
      let combine t (pt : Fp.t) =
        let open Fp in
        Pcs_batch.combine_evaluations
          ~crs_max_degree:Inputs.Dlog.crs_max_degree ~mul ~add ~one
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
        Pairing_marlin_types.Accumulator.map ~f:of_affine prev_acc
      in
      let proof1, proof2, proof3 =
        Triple.map proof.openings.proofs ~f:of_affine
      in
      let conv = Double.map ~f:of_affine in
      let g1 = conv (fst proof.messages.gh_1) in
      let g2 = conv (fst (snd proof.messages.sigma_gh_2)) in
      let g3 = conv (fst (snd proof.messages.sigma_gh_3)) in
      Pairing_marlin_types.Accumulator.map ~f:to_affine_exn
        { degree_bound_checks=
            Dlog_main.accumulate_degree_bound_checks
              prev_acc.degree_bound_checks ~add ~scale ~r_h:r ~r_k g1 g2 g3
        ; opening_check=
            Dlog_main.accumulate_opening_check ~add ~negate ~scale
              ~generator:one ~r ~r_xi_sum prev_acc.opening_check
              (f_1, beta_1, proof1) (f_2, beta_2, proof2) (f_3, beta_3, proof3)
        }

    let public_input_of_statement
        (prev_statement : _ Statement.Pairing_based.t) =
      let input =
        let (T (input, conv)) =
          Impls.Pairing_based.input ~branching:Branching.n
            ~bulletproof_log2:Bp_rounds.n
        in
        Impls.Pairing_based.generate_public_input [input] prev_statement
      in
      Fp.one :: List.init (Fp.Vector.length input) ~f:(Fp.Vector.get input)

    module Me_only = struct
      type t =
        ( Dlog_based_reduced_me_only.g1
        , Snarky_bn382_backend.Fq.t Bp_vector.t Branching_vector.t )
        Me_only.Dlog_based.t
      [@@deriving sexp_of]
    end

    let wrap (type s) (module App : App_state_intf with type Constant.t = s)
        ~domain_h ~domain_k ~dlog_marlin_index ~pairing_marlin_index pairing_vk
        pk
        ({statement= prev_statement; prev_evals; proof} :
          s pairing_based_proof) =
      let prev_me_only =
        Vector.map
          ~f:(Dlog_based_reduced_me_only.prepare ~pairing_marlin_index)
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
        ; pass_through= Vector.map ~f:Common.hash_dlog_me_only prev_me_only }
      in
      let handler (Snarky.Request.With {request; respond}) =
        let open M.Requests in
        let k x = respond (Provide x) in
        match request with
        | Prev_evals ->
            k prev_evals
        | Prev_messages ->
            k proof.messages
        | Prev_openings_proof ->
            k proof.openings.proofs
        | Prev_proof_state ->
            k prev_statement_with_hashes.proof_state
        | Prev_me_onlys ->
            k
              (Vector.map prev_me_only ~f:(fun t ->
                   (t.pairing_marlin_acc, t.old_bulletproof_challenges) ))
        | Pairing_marlin_index ->
            k pairing_marlin_index
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
          combined_evaluation ~x_hat_beta_1 ~r ~xi ~beta_1 ~beta_2 ~beta_3
            proof
        in
        let me_only : Dlog_based_reduced_me_only.t =
          let combined_polys =
            combined_polynomials ~xi ~pairing_marlin_index public_input proof
          in
          let prev_pairing_acc =
            let open Pairing_marlin_types.Accumulator in
            Vector.map prev_statement.pass_through ~f:(fun t ->
                map ~f:G1.of_affine t.pairing_marlin_acc )
            |> Vector.reduce ~f:(fun t1 t2 -> map2 t1 t2 ~f:G1.( + ))
            |> map ~f:G1.to_affine_exn
          in
          { pairing_marlin_acc=
              accumulate_pairing_checks proof prev_pairing_acc ~r ~r_k
                ~r_xi_sum ~beta_1 ~beta_2 ~beta_3 combined_polys
          ; old_bulletproof_challenges=
              Vector.map prev_statement.proof_state.unfinalized_proofs
                ~f:(fun t -> t.deferred_values.bulletproof_challenges) }
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
      let me_only_prepared =
        Dlog_based_reduced_me_only.prepare ~pairing_marlin_index
          next_statement.proof_state.me_only
      in
      let next_proof =
        let (T (input, conv)) = Impls.Dlog_based.input () in
        Impls.Dlog_based.prove pk
          ~message:
            ( Vector.map2 prev_statement.proof_state.me_only.sg
                me_only_prepared.old_bulletproof_challenges ~f:(fun sg chals ->
                  { Snarky_bn382_backend.Dlog_based_proof.Challenge_polynomial
                    .commitment= sg
                  ; challenges= Vector.to_array chals } )
            |> Vector.to_list )
          [input]
          (fun x () ->
            ( Impls.Dlog_based.handle
                (fun () -> M.main ~domain_h ~domain_k (conv x))
                handler
              : unit ) )
          ()
          { pass_through= prev_statement_with_hashes.proof_state.me_only
          ; proof_state=
              { next_statement.proof_state with
                me_only= Common.hash_dlog_me_only me_only_prepared } }
      in
      ( { proof= next_proof
        ; statement= next_statement
        ; prev_evals= proof.openings.evals
        ; prev_x_hat_beta_1= x_hat_beta_1 }
        : s dlog_based_proof )
  end

  module Make (State : App_state_intf) : sig
    val negative_one : State.Constant.t Dlog_based_proof.t

    val step :
         State.Constant.t Dlog_based_proof.t Branching_vector.t
      -> State.Constant.t
      -> State.Constant.t Pairing_based_proof.t

    val wrap :
         State.Constant.t Pairing_based_proof.t
      -> State.Constant.t Dlog_based_proof.t
  end = struct
    module Domains = struct
      let domains sys =
        let open Snarky_bn382_backend.R1cs_constraint_system in
        let open Domain in
        let weight = Weight.norm sys.weight in
        let witness_size =
          1 + sys.public_input_size + sys.auxiliary_input_size
        in
        let h =
          Pow_2_roots_of_unity
            Int.(ceil_log2 (max sys.constraints witness_size))
        in
        let k = Pow_2_roots_of_unity (Int.ceil_log2 weight) in
        (h, k)

      module Dlog = struct
        let t =
          let (T (typ, conv)) = Impls.Dlog_based.input () in
          let main x () : unit =
            Pairing_based_proof.M.main (conv x)
              ~domain_h:(Domain.Pow_2_roots_of_unity 17)
              ~domain_k:(Domain.Pow_2_roots_of_unity 17)
          in
          domains (Impls.Dlog_based.constraint_system ~exposing:[typ] main)

        let h, k = t
      end

      module Pairing = struct
        let t =
          let (T (typ, conv)) =
            Impls.Pairing_based.input ~branching:Branching.n
              ~bulletproof_log2:Bp_rounds.n
          in
          let main x () : unit =
            Dlog_based_proof.M.main
              (module State)
              (conv x) ~bulletproof_log2:(Nat.to_int Bp_rounds.n)
              ~domain_h:(Domain.Pow_2_roots_of_unity 17)
              ~domain_k:(Domain.Pow_2_roots_of_unity 17)
          in
          domains (Impls.Pairing_based.constraint_system ~exposing:[typ] main)

        let h, k = t
      end
    end

    let wrap_kp =
      let (T (typ, conv)) = Impls.Dlog_based.input () in
      let main x () : unit =
        Pairing_based_proof.M.main (conv x) ~domain_h:Domains.Dlog.h
          ~domain_k:Domains.Dlog.k
      in
      Impls.Dlog_based.generate_keypair ~exposing:[typ] main

    let step_kp =
      let (T (input, conv)) =
        Impls.Pairing_based.input ~branching:Branching.n
          ~bulletproof_log2:Bp_rounds.n
      in
      Impls.Pairing_based.generate_keypair ~exposing:[input] (fun x () ->
          let () =
            Dlog_based_proof.M.main
              (module State)
              (conv x) ~domain_h:Domains.Pairing.h ~domain_k:Domains.Pairing.k
              ~bulletproof_log2:(Nat.to_int Bp_rounds.n)
          in
          () )

    let step_pk = Impls.Pairing_based.Keypair.pk step_kp

    let pairing_marlin_index =
      Snarky_bn382_backend.Pairing_based.Keypair.vk_commitments step_pk

    let wrap_pk = Impls.Dlog_based.Keypair.pk wrap_kp

    let%test_unit "matching domain sizes" =
      let check (a, d) =
        [%test_eq: int] (Unsigned.Size_t.to_int a) (Domain.size d)
      in
      let open Snarky_bn382 in
      List.iter ~f:check
        [ (Fp_index.domain_h_size step_pk, Domains.Pairing.h)
        ; (Fp_index.domain_k_size step_pk, Domains.Pairing.k)
        ; (Fq_index.domain_h_size wrap_pk, Domains.Dlog.h)
        ; (Fq_index.domain_k_size wrap_pk, Domains.Dlog.k) ]

    let dlog_marlin_index =
      Snarky_bn382_backend.Dlog_based.Keypair.vk_commitments wrap_pk

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
      let fp = ro "fp" Digest.Constant.length Fp.of_bits in
      let fq = ro "fq" Digest.Constant.length Fq.of_bits in
      let old_bulletproof_challenges =
        let f =
          ro "bpchal" Challenge.Constant.length Challenge.Constant.of_bits
        in
        Vector.init Branching.n ~f:(fun _ ->
            Vector.init Bp_rounds.n ~f:(fun _ ->
                let prechallenge = f () in
                { Bulletproof_challenge.prechallenge
                ; is_square=
                    Fq.is_square
                      (Fq.of_bits (Challenge.Constant.to_bits prechallenge)) }
            ) )
      in
      let old_sg = Vector.map ~f:compute_sg old_bulletproof_challenges in
      let opening_check : _ Pairing_marlin_types.Accumulator.Opening_check.t =
        (* TODO: Leaky *)
        let t =
          Snarky_bn382.Fp_urs.dummy_opening_check
            (Snarky_bn382_backend.Pairing_based.Keypair.load_urs ())
        in
        { r_f_minus_r_v_plus_rz_pi=
            Snarky_bn382.G1.Affine.Pair.f0 t |> G1.Affine.of_backend
        ; r_pi= Snarky_bn382.G1.Affine.Pair.f1 t |> G1.Affine.of_backend }
      in
      let degree_bound_checks :
          _ Pairing_marlin_types.Accumulator.Degree_bound_checks.t =
        let h =
          Unsigned.Size_t.to_int (Snarky_bn382.Fp_index.domain_h_size step_pk)
        in
        let k =
          Unsigned.Size_t.to_int (Snarky_bn382.Fp_index.domain_k_size step_pk)
        in
        (* TODO: Leaky *)
        let t =
          Snarky_bn382.Fp_urs.dummy_degree_bound_checks
            (Snarky_bn382_backend.Pairing_based.Keypair.load_urs ())
            (Unsigned.Size_t.of_int (h - 1))
            (Unsigned.Size_t.of_int (k - 1))
        in
        { shifted_accumulator=
            Snarky_bn382.G1.Affine.Vector.get t 0 |> G1.Affine.of_backend
        ; unshifted_accumulators=
            Vector.init Nat.N2.n ~f:(fun i ->
                G1.Affine.of_backend (Snarky_bn382.G1.Affine.Vector.get t i) )
        }
      in
      let g = G.(to_affine_exn one) in
      let opening_proof_lr =
        Array.init (Nat.to_int Bp_rounds.n) ~f:(fun _ -> (g, g))
      in
      let opening_proof_challenges =
        (* This has to be the sponge state at the end of the inner marlin
         protocol *)
        Dlog_based_proof.bulletproof_challenges
          (Fp_sponge.Bits.create Fp_sponge.params)
          opening_proof_lr
        |> Array.to_list
        |> Fn.flip Vector.of_list_and_length_exn Bp_rounds.n
      in
      { proof=
          { messages=
              { w_hat= g
              ; z_hat_a= g
              ; z_hat_b= g
              ; gh_1= ((g, g), g)
              ; sigma_gh_2= (fq (), ((g, g), g))
              ; sigma_gh_3= (fq (), ((g, g), g)) }
          ; openings=
              { proof=
                  { lr= opening_proof_lr
                  ; z_1= fq ()
                  ; z_2= fq ()
                  ; delta= g
                  ; sg= compute_sg opening_proof_challenges }
              ; evals=
                  (let e : _ Dlog_marlin_types.Evals.t =
                     let abc () = {Abc.a= fq (); b= fq (); c= fq ()} in
                     { w_hat= fq ()
                     ; z_hat_a= fq ()
                     ; z_hat_b= fq ()
                     ; g_1= fq ()
                     ; h_1= fq ()
                     ; g_2= fq ()
                     ; h_2= fq ()
                     ; g_3= fq ()
                     ; h_3= fq ()
                     ; row= abc ()
                     ; col= abc ()
                     ; value= abc ()
                     ; rc= abc () }
                   in
                   (e, e, e)) } }
      ; statement=
          { proof_state=
              { deferred_values=
                  { xi= chal ()
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
                      ; beta_3= chal () } }
              ; sponge_digest_before_evaluations= Digest.Constant.of_fq Fq.zero
              ; was_base_case= true
              ; me_only=
                  { pairing_marlin_acc= {opening_check; degree_bound_checks}
                  ; old_bulletproof_challenges } }
          ; pass_through= {app_state= State.Constant.dummy; sg= old_sg} }
      ; prev_x_hat_beta_1= fp ()
      ; prev_evals=
          (let abc () = {Abc.a= fp (); b= fp (); c= fp ()} in
           { w_hat= fp ()
           ; z_hat_a= fp ()
           ; z_hat_b= fp ()
           ; g_1= fp ()
           ; h_1= fp ()
           ; g_2= fp ()
           ; h_2= fp ()
           ; g_3= fp ()
           ; h_3= fp ()
           ; row= abc ()
           ; col= abc ()
           ; value= abc ()
           ; rc= abc () }) }

    let step dlog_proof next_state =
      Dlog_based_proof.step
        (module State)
        ~pairing_domains:Domains.Pairing.t ~dlog_domains:Domains.Dlog.t
        ~dlog_marlin_index ~pairing_marlin_index step_pk wrap_vk next_state
        dlog_proof

    let wrap proof =
      Pairing_based_proof.wrap
        (module State)
        ~domain_h:Domains.Dlog.h ~domain_k:Domains.Dlog.k ~dlog_marlin_index
        ~pairing_marlin_index step_vk wrap_pk proof
  end
end

let%test_unit "concrete" =
  let module Branching_pred = Nat.N0 in
  let module Bp_rounds = Nat.N19 in
  let module State = struct
    open Impls.Pairing_based

    type t = Field.t

    type _ Tag.t += Tag : Field.Constant.t Tag.t

    let base = Field.Constant.one

    module Constant = struct
      include Field.Constant

      let is_base_case = Field.Constant.(equal base)

      let to_field_elements x = [|x|]

      let update prevs =
        Rugelach_types.Vector.fold ~init:Field.Constant.one
          ~f:Field.Constant.( + ) prevs

      let dummy = Field.Constant.zero
    end

    let to_field_elements x = [|x|]

    let typ = Typ.field

    let check_update prevs x =
      Field.equal x (Vector.fold prevs ~init:Field.one ~f:Field.( + ))

    let is_base_case x = Field.(equal x (constant base))
  end in
  let module M0 = Make (Branching_pred) (Bp_rounds) in
  let module M = M0.Make (State) in
  let open Common in
  let input = State.base in
  let branch t = Vector.init M0.Branching.n ~f:(fun _ -> t) in
  let proof =
    time "first step" (fun () -> M.step (branch M.negative_one) State.base)
  in
  let proof = time "first wrap" (fun () -> M.wrap proof) in
  let input = State.Constant.update (branch input) in
  let proof = time "second step" (fun () -> M.step (branch proof) input) in
  let proof = time "second wrap" (fun () -> M.wrap proof) in
  ignore proof ;
  failwithf "size %d"
    (M0.Dlog_based_proof.bin_size_t
       Impls.Pairing_based.Field.Constant.bin_size_t M.negative_one)
    ()
  |> ignore
