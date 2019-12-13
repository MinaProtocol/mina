open Core_kernel
open Import
open Util

(* Evaluations:

       | g_1 | h_1 | z_A | z_B | w   | s   | g_2 | h_2 | g_3 | h_3 | indexpolys
beta_1 |  *  |  *  |  *  |  *  |  *  |  *  |     |     |     |     |
beta_2 |     |     |     |     |     |     |  *  |  *  |     |     |
beta_3 |     |     |     |     |     |     |     |     |  *  |  *  |  *

* = proof element in vanilla marlin
*)

(* The ideal thing to do would be to sample

   two 382 / 2 bit numbers c, d such that

   (1) c * d = 1
   (2) c is a square (this implies d is a square)

   note that (1) implies int(c) * int(d) > p, so
   the combined bit size of c, d is at least 382 bits.

   d * c + e * p = 1

   C * D = 1 + k * p
*)

(* TODO: Compute the number of pieces that we should chop

   the h_3 polynomial up into. At a certain point, chopping it up doesn't help
   because we take a ceil_log2

   This should be done by setting iteratively making it higher.
*)

module Marlin_polys = Vector.Nat.N19

module Openings = struct
  module Evaluations = struct
    module By_point = struct
      type 'fq t = {beta_1: 'fq; beta_2: 'fq; beta_3: 'fq; g_challenge: 'fq}
    end

    type 'fq t = ('fq By_point.t, Marlin_polys.n Vector.s) Vector.t
  end

  module Bulletproof = struct
    type ('fq, 'g) t =
      {gammas: ('g * 'g) array; z_1: 'fq; z_2: 'fq; beta: 'g; delta: 'g}

    module Advice = struct
      (* This is data that can be computed in linear time from the above plus the statement.
      
         It doesn't need to be sent on the wire, but it does need to be provided to the verifier
      *)
      type ('fq, 'g) t = {sg: 'g; a_hat: 'fq}
    end
  end

  type ('fq, 'g) t =
    {evaluations: 'fq Evaluations.t; proof: ('fq, 'g) Bulletproof.t}
end

module Main (Inputs : Intf.Pairing_main_inputs.S) = struct
  open Inputs
  open Impl
  module PC = G
  module Fp = Impl.Field

  module Data = struct
    type t = Field.t list * Boolean.var list

    let bits bs = ([], bs)

    let append (x1, b1) (x2, b2) = (x1 @ x2, b1 @ b2)

    let concat : t list -> t = List.reduce_exn ~f:append

    let pack_bits bs =
      List.groupi bs ~break:(fun i _ _ -> i mod (Field.size_in_bits - 1) = 0)
      |> List.map ~f:Field.pack

    let pack (x, b) = x @ pack_bits b

    let assert_equal t1 t2 =
      List.iter2_exn (pack t1) (pack t2) ~f:Field.Assert.equal

    let ( @ ) = append
  end

  module Challenge = struct
    type t = Boolean.var list

    let length = 128
  end

  (* q > p *)
  module Fq = struct
    type t = (* Low bits, high bit *)
      Fp.t * Boolean.var

    let typ = Typ.tuple2 Fp.typ Boolean.typ

    let to_bits (x, b) = Field.unpack x ~length:(Field.size_in_bits - 1) @ [b]
  end

  let rec absorb : type a.
      Sponge.t -> (a, < scalar: Fq.t ; g1: G.t >) Type.t -> a -> unit =
   fun sponge ty t ->
    match ty with
    | PC ->
        List.iter (G.to_field_elements t) ~f:(fun x ->
            Sponge.absorb sponge (`Field x) )
    | Scalar ->
        let low_bits, high_bit = t in
        Sponge.absorb sponge (`Field low_bits) ;
        Sponge.absorb sponge (`Bits [high_bit])
    | ty1 :: ty2 ->
        let absorb t = absorb sponge t in
        let t1, t2 = t in
        absorb ty1 t1 ; absorb ty2 t2

  module Bulletproof_challenge = struct
    type ('challenge, 'bool) t = {prechallenge: 'challenge; is_square: 'bool}
  end

  let bullet_reduce sponge gammas =
    let absorb t = absorb sponge t in
    let prechallenges =
      Array.map gammas ~f:(fun gammas_i ->
          absorb (PC :: PC) gammas_i ;
          Sponge.squeeze sponge ~length:Challenge.length )
    in
    let term_and_challenge (gamma_neg_one, gamma_one) pre =
      let pre_inv = failwith "TODO" in
      let pre_is_square = failwith "TODO" in
      let left_term =
        let base =
          G.if_ pre_is_square ~then_:gamma_neg_one
            ~else_:(G.scale_by_quadratic_nonresidue gamma_neg_one)
        in
        G.scale base pre
      in
      let right_term =
        let base =
          G.if_ pre_is_square ~then_:gamma_one
            ~else_:(G.scale_by_quadratic_nonresidue_inv gamma_one)
        in
        G.scale base (Fq.to_bits pre_inv)
      in
      ( G.(left_term + right_term)
      , {Bulletproof_challenge.prechallenge= pre; is_square= pre_is_square} )
    in
    let terms, challenges =
      Array.map2_exn gammas prechallenges ~f:term_and_challenge |> Array.unzip
    in
    (Array.reduce_exn terms ~f:G.( + ), challenges)

  let assert_equal_g g1 g2 =
    List.iter2_exn ~f:Field.Assert.equal (G.to_field_elements g1)
      (G.to_field_elements g2)

  (* Confused about how verifier chooses c in 3. Looks like prover can use
    whatever c they like *)
  let check_bulletproof ~g ~h ~sponge ~xi ~r ~g_old ~combined_inner_product
      ~
      (* Corresponds to y in figure 7 of WTS *)
      (* sum_i r^i sum_j xi^j f_j(beta_i) *)
      (advice : _ Openings.Bulletproof.Advice.t)
      ~(polynomials : (PC.t, Marlin_polys.n) Vector.t)
      ~openings:
      (* Actually I don't think it's necessary to have the evaluations
   here. *)
      ({proof; evaluations} : (Fq.t, G.t) Openings.t) =
    (* a_hat should be equal to
       sum_i < t, r^i pows(beta_i) >
       = sum_i r^i < t, pows(beta_i) > *)
    let () =
      (* Absorb the statement ( combined_polynomial, combined_inner_product, combined_evaluation ) *)
      ()
    in
    (* TODO: Absorb (combined_polynomial, inner_product_result/tau *)
    let open G in
    let combined_polynomial (* Corresponds to xi in figure 7 of WTS *) =
      List.fold_left (Vector.to_list polynomials) ~init:g_old ~f:(fun acc p ->
          p + scale acc xi )
    in
    let gamma_prod, challenges = bullet_reduce sponge proof.gammas in
    let gamma0 =
      let tau = scale g (Fq.to_bits combined_inner_product) in
      combined_polynomial + tau
    in
    let a_hat = Fq.to_bits advice.a_hat in
    let lhs = scale (gamma0 + gamma_prod + proof.beta) a_hat + proof.delta in
    let rhs =
      scale (advice.sg + scale g a_hat) (Fq.to_bits proof.z_1)
      + scale h (Fq.to_bits proof.z_2)
    in
    assert_equal_g lhs rhs ; challenges

  module Proof_state = struct
    module Deferred_values = struct
      module Marlin = struct
        type ('challenge, 'fq) t =
          { sigma_2: 'fq
          ; sigma_3: 'fq
          ; alpha: 'challenge (* 128 bits *)
          ; eta_A: 'challenge (* 128 bits *)
          ; eta_B: 'challenge (* 128 bits *)
          ; eta_C: 'challenge (* 128 bits *)
          ; beta_1: 'challenge
          ; beta_2: 'challenge
          ; beta_3: 'challenge }
      end

      type ('challenge, 'fq, 'bool, 'g) t =
        { marlin: ('challenge, 'fq) Marlin.t
        ; combined_inner_product: 'fq
        ; xi: 'challenge (* 128 bits *)
        ; bulletproof_challenges:
            ('challenge, 'bool) Bulletproof_challenge.t array
        ; advice: ('fq, 'g) Openings.Bulletproof.Advice.t }
    end

    module Pass_through = struct
      type 'g1 t =
        { pairing_marlin_index: 'g1 Abc.t Matrix_evals.t
        ; pairing_marlin_acc: 'g1 Pairing_marlin_types.Accumulator.t }
    end

    type ('challenge, 'fq, 'bool, 'g, 'g1, 'digest) t =
      { deferred_values: ('challenge, 'fq, 'bool, 'g) Deferred_values.t
      ; sponge_digest: 'digest
      ; dlog_marlin_index: 'g Abc.t Matrix_evals.t
            (* Pass thru. TODO: Make this a hash as we don't touch it at all *)
      ; pass_through: 'g1 Pass_through.t }
  end

  module Statement = struct
    type ('challenge, 'fq, 'bool, 'g, 'g1, 'digest, 's) t =
      { proof_state: ('challenge, 'fq, 'bool, 'g, 'g1, 'digest) Proof_state.t
      ; app_state: 's }
  end

  (* How to advance the proof state in "dlog main"

   exists g_old challenges_old.
   Sample a challenge point for g_old. Compute b_challenges_old(g_old).
   Then compute the combined_inner_product using this. *)
  let incrementally_verify_proof ~verification_key:(m : _ Abc.t Matrix_evals.t)
      ~sponge ~public_input ~g_old ~combined_inner_product ~advice
      ~proof:({messages; openings} :
               ( PC.t
               , Fq.t
               , (Fq.t, G.t) Openings.t )
               Pairing_marlin_types.Proof.t) =
    let receive ty f =
      let x = f messages in
      absorb sponge ty x ; x
    in
    let sample () = Sponge.squeeze sponge ~length:Challenge.length in
    let open Pairing_marlin_types.Messages in
    (* No need to absorb the public input into the sponge as we've already
      absorbed x'_hat, a0, and y0 *)
    let w_hat = receive PC w_hat in
    let s = receive PC s in
    let z_hat_A = receive PC z_hat_A in
    let z_hat_B = receive PC z_hat_B in
    let alpha = sample () in
    let eta_A = sample () in
    let eta_B = sample () in
    let eta_C = sample () in
    let g_1, h_1 = receive (PC :: PC) gh_1 in
    let beta_1 = sample () in
    let sigma_2, (g_2, h_2) = receive (Scalar :: PC :: PC) sigma_gh_2 in
    let beta_2 = sample () in
    let sigma_3, (g_3, h_3) = receive (Scalar :: PC :: PC) sigma_gh_3 in
    let beta_3 = sample () in
    let x_hat_beta_3 =
      let input_size = Array.length public_input in
      L.tweaked_lagrange ~sponge
        (L.Precomputation.create
           ~domain_size:(L.Precomputation.domain_size input_size))
        public_input
        (L.Fp_repr.of_bits ~chunk_size:124 beta_3)
    in
    (* We can use the same random scalar xi for all of these opening proofs. *)
    let xi = sample () in
    let r = sample () in
    (* No need to expose the polynomial evaluations as deferred values as they're
       not needed here for the incremental verification. All we need is a_hat and
       "combined_inner_product".

       Then, in the other proof, we can witness the evaluations and check their correctness
       against "combined_inner_product" *)
    let bulletproof_challenges =
      check_bulletproof ~g:Generators.g ~h:Generators.h ~sponge ~xi ~r ~g_old
        ~combined_inner_product ~advice ~openings
        ~polynomials:
          [ w_hat
          ; s
          ; z_hat_A
          ; z_hat_B
          ; g_1
          ; h_1
          ; g_2
          ; h_2
          ; g_3
          ; h_3
          ; m.row.a
          ; m.row.b
          ; m.row.c
          ; m.col.a
          ; m.col.b
          ; m.col.c
          ; m.value.a
          ; m.value.b
          ; m.value.c ]
    in
    ( xi
    , bulletproof_challenges
    , { Proof_state.Deferred_values.Marlin.sigma_2
      ; sigma_3
      ; alpha
      ; eta_A
      ; eta_B
      ; eta_C
      ; beta_1
      ; beta_2
      ; beta_3 } )

  let marlin_data
      { Proof_state.Deferred_values.Marlin.sigma_2
      ; sigma_3
      ; alpha
      ; eta_A
      ; eta_B
      ; eta_C
      ; beta_1
      ; beta_2
      ; beta_3 } =
    let fq_data ((x, b) : Fq.t) = ([x], [b]) in
    Data.concat
      ( fq_data sigma_2 :: fq_data sigma_3
      :: List.map ~f:Data.bits
           [alpha; eta_A; eta_B; eta_C; beta_1; beta_2; beta_3] )

  let chals_data chals =
    Array.map chals ~f:(fun {Bulletproof_challenge.prechallenge; is_square} ->
        Data.bits (is_square :: prechallenge) )
    |> Array.reduce_exn ~f:Data.append

  (* The problem is having inputs which are used non opaquely.
     Maybe we can do that with the x_hat evaluation?
  *)

  let combined_evaluation ~xi Vector.(eval0 :: evals) =
    List.fold_left (Vector.to_list evals) ~init:eval0 ~f:(fun acc eval ->
        Fp.((xi * acc) + eval) )

  (* x^{2 ^ k} - 1 *)
  let vanishing_polynomial domain x =
    let k = Domain.log2_size domain in
    let rec pow acc i = if i = 0 then acc else pow (Fp.square acc) (i - 1) in
    Fp.(pow x k - one)

  let sum' xs f = List.reduce_exn (List.map xs ~f) ~f:Fp.( + )

  let prod xs f = List.reduce_exn (List.map xs ~f) ~f:Fp.( * )

  type m = A | B | C

  let ms = [A; B; C]

  let abc a b c = function A -> a | B -> b | C -> c

  let all_but m = List.filter ms ~f:(( <> ) m)

  let finalize_checks ~domain_k ~domain_h
      ({ xi
       ; marlin=
           { sigma_2
           ; sigma_3
           ; alpha
           ; eta_a
           ; eta_b
           ; eta_c
           ; beta_1
           ; beta_2
           ; beta_3
           ; beta_1_xi_sum
           ; beta_2_xi_sum
           ; beta_3_xi_sum } } :
        _ Types.Dlog_based.Proof_state.Deferred_values.t) =
    let open Vector in
    let ([g_1; h_1; z_hat_A; z_hat_B; w_hat; s] as beta_1_evals
          : _ Pairing_marlin_types.Evals.Beta1.t) =
      exists (failwith "TODO")
    and ([g_2; h_2] as beta_2_evals : _ Pairing_marlin_types.Evals.Beta2.t) =
      exists (failwith "TODO")
    and ([ g_3
         ; h_3
         ; row_a
         ; row_b
         ; row_c
         ; col_a
         ; col_b
         ; col_c
         ; value_a
         ; value_b
         ; value_c ] as beta_3_evals
          : _ Pairing_marlin_types.Evals.Beta3.t) =
      exists (failwith "TODO")
    in
    let open Fp in
    Assert.equal beta_1_xi_sum (combined_evaluation ~xi beta_1_evals) ;
    Assert.equal beta_2_xi_sum (combined_evaluation ~xi beta_2_evals) ;
    Assert.equal beta_3_xi_sum (combined_evaluation ~xi beta_3_evals) ;
    let v_h_beta_1 = vanishing_polynomial domain_h beta_1 in
    let v_h_beta_2 = vanishing_polynomial domain_h beta_2 in
    let a_beta_3, b_beta_3 =
      let open Abc in
      let row = abc row_a row_b row_c
      and col = abc col_a col_b col_c
      and value = abc value_a value_b value_c
      and eta = abc eta_a eta_b eta_c in
      let a =
        v_h_beta_1 * v_h_beta_2
        * sum' ms (fun m ->
              eta m * value m
              * prod (all_but m) (fun n -> (beta_2 - row n) * (beta_1 - col n))
          )
      in
      let b = prod ms (fun m -> (beta_2 - row m) * (beta_1 - col m)) in
      (a, b)
    in
    Assert.equal
      (h_3 * vanishing_polynomial domain_k beta_3)
      ( a_beta_3
      - b_beta_3
        * ((beta_3 * g_3) + (sigma_3 / of_int (Domain.size domain_k))) )

  let main
      ({ proof_state=
           { deferred_values=
               { marlin
               ; combined_inner_product
               ; xi
               ; bulletproof_challenges
               ; advice }
           ; sponge_digest
           ; dlog_marlin_index
           ; pass_through }
       ; app_state } :
        _ Statement.t) =
    let prev_statement : _ Types.Dlog_based.Statement.t =
      exists (failwith "TODO")
    in
    App_state.check_update prev_statement.app_state app_state ;
    let sponge =
      let s = Sponge.create sponge_params in
      Sponge.absorb s prev_statement.proof_state.sponge_digest ;
      s
    in
    let xi_actual, bulletproof_challenges_actual, marlin_actual =
      let proof = exists (failwith "TODO") in
      incrementally_verify_proof ~verification_key:dlog_marlin_index ~sponge
        ~public_input:(failwith "TODO") ~g_old:(failwith "TODO")
        ~combined_inner_product ~advice ~proof
    in
    Data.(
      assert_equal
        (bits xi @ chals_data bulletproof_challenges @ marlin_data marlin)
        ( bits xi_actual
        @ chals_data bulletproof_challenges_actual
        @ marlin_data marlin_actual ))
end
