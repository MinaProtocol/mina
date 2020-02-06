module D = Digest
open Core_kernel
open Import
open Util
open Pickles_types
open Dlog_marlin_types
module Accumulator = Pairing_marlin_types.Accumulator

let sg_polynomial ~add ~mul chals chal_invs pt =
  let ( + ) = add and ( * ) = mul in
  let k = Array.length chals in
  let pow_two_pows =
    let res = Array.init k ~f:(fun _ -> pt) in
    for i = 1 to k - 1 do
      let y = res.(i - 1) in
      res.(i) <- y * y
    done ;
    res
  in
  let prod f =
    let r = ref (f 0) in
    for i = 1 to k - 1 do
      r := f i * !r
    done ;
    !r
  in
  prod (fun i -> chal_invs.(i) + (chals.(i) * pow_two_pows.(k - 1 - i)))

let accumulate_degree_bound_checks ~add ~scale ~r_h ~r_k
    { Accumulator.Degree_bound_checks.shifted_accumulator
    ; unshifted_accumulators= [h; k] } (g1, g1_s) (g2, g2_s) (g3, g3_s) =
  let ( + ) = add in
  let ( * ) = Fn.flip scale in
  let shifted_accumulator =
    shifted_accumulator + (r_h * (g1 + (r_h * g2))) + (r_k * g3)
  in
  let unshifted_accumulators =
    let h = h + (r_h * (g1_s + (r_h * g2_s))) in
    let k = k + (r_k * g3_s) in
    Vector.[h; k]
  in
  {Accumulator.Degree_bound_checks.shifted_accumulator; unshifted_accumulators}

(*
   check that pi proves that U opens to v at z.

   pi =? commitmennt to (U - v * g ) / (beta*g - z)

   e(pi, beta*g - z*g) = e(U - v, g)

   e(pi, beta*g) - e(z*pi, g) - e(U - v, g) = 0
   e(pi, beta*g) - e(z*pi - (U - v * g), g) = 0

   sum_i r^i e(pi_i, beta_i*g) - e(z*pi - (U - v_i * g), g) = 0
*)

let accumulate_opening_check ~add ~negate ~scale ~generator ~r
    ~(* r should be exposed. *) r_xi_sum (* s should be exposed *)
    {Accumulator.Opening_check.r_f_minus_r_v_plus_rz_pi; r_pi}
    (f_1, beta_1, pi_1) (f_2, beta_2, pi_2) (f_3, beta_3, pi_3) =
  let ( + ) = add in
  let ( * ) s p = scale p s in
  let r_f_minus_r_v_plus_rz_pi =
    let rz_pi_term =
      let zpi_1 = beta_1 * pi_1 in
      let zpi_2 = beta_2 * pi_2 in
      let zpi_3 = beta_3 * pi_3 in
      r * (zpi_1 + (r * (zpi_2 + (r * zpi_3))))
      (* Could be more efficient at the cost of more public inputs. *)
      (* sum_{i=1}^3 r^i beta_i pi_i *)
    in
    let f_term = r * (f_1 + (r * (f_2 + (r * f_3)))) in
    let v_term = r_xi_sum * generator in
    r_f_minus_r_v_plus_rz_pi + f_term + negate v_term + rz_pi_term
  in
  let pi_term =
    (* sum_{i=1}^3 r^i pi_i *)
    r * (pi_1 + (r * (pi_2 + (r * pi_3))))
  in
  {Accumulator.Opening_check.r_f_minus_r_v_plus_rz_pi; r_pi= r_pi + pi_term}

module Make (Inputs : Intf.Dlog_main_inputs.S) = struct
  open Inputs
  open Impl

  module Fp = struct
    (* For us, q > p, so one Field.t = fq can represent an fp *)
    module Packed = struct
      module Constant = struct
        type t = Fp.t
      end

      type t = Field.t

      let typ =
        Typ.transport Field.typ
          ~there:(fun (x : Constant.t) -> Bigint.to_field (Fp.to_bigint x))
          ~back:(fun (x : Field.Constant.t) -> Fp.of_bigint (Bigint.of_field x))
    end

    module Unpacked = struct
      type t = Boolean.var list

      type constant = bool list

      let typ : (t, constant) Typ.t =
        let typ = Typ.list ~length:Fp.size_in_bits Boolean.typ in
        let p_msb =
          let test_bit x i = B.(shift_right x i land one = one) in
          List.init Fp.size_in_bits ~f:(test_bit Fp.order) |> List.rev
        in
        let check xs_lsb =
          let open Bitstring_lib.Bitstring in
          Snarky.Checked.all_unit
            [ typ.check xs_lsb
            ; make_checked (fun () ->
                  Bitstring_checked.lt_value
                    (Msb_first.of_list (List.rev xs_lsb))
                    (Msb_first.of_list p_msb)
                  |> Boolean.Assert.is_true ) ]
        in
        {typ with check}

      let assert_equal t1 t2 = Field.(Assert.equal (project t1) (project t2))
    end

    let pack : Unpacked.t -> Packed.t = Field.project
  end

  let debug = false

  let print_g1 lab (x, y) =
    if debug then as_prover
      As_prover.(
        fun () ->
          Core.printf "in-snark: %s (%s, %s)\n%!" lab
            (Field.Constant.to_string (read_var x))
            (Field.Constant.to_string (read_var y)))

  let print_chal lab x =
    if debug then as_prover
      As_prover.(
        fun () ->
          Core.printf "in-snark %s: %s\n%!" lab
            (Field.Constant.to_string
               (Field.Constant.project (List.map ~f:(read Boolean.typ) x))))

  let print_bool lab x =
    if debug then as_prover (fun () ->
        printf "%s: %b\n%!" lab (As_prover.read Boolean.typ x))

  module PC = G1
  module Fq = Field
  module Challenge = Challenge.Make (Impl)
  module Digest = D.Make (Impl)

  let product m f = List.reduce_exn (List.init m ~f) ~f:Field.( * )

  let b (u : Fq.t array) (x : Fq.t) : Fq.t =
    let bulletproof_challenges = Array.length u in
    let x_to_pow2s =
      let res = Array.create ~len:bulletproof_challenges x in
      for i = 1 to bulletproof_challenges - 1 do
        res.(i) <- Field.square res.(i - 1)
      done ;
      res
    in
    let open Field in
    product bulletproof_challenges (fun i ->
        u.(i) + (inv u.(i) * x_to_pow2s.(i)) )

  let absorb sponge ty t =
    absorb ~absorb_field:(Sponge.absorb sponge)
      ~g1_to_field_elements:G1.to_field_elements ~pack_scalar:Fn.id ty t

  let combined_commitment ~xi (polys : _ Vector.t) =
    let (p0 :: ps) = polys in
    List.fold_left (Vector.to_list ps) ~init:p0 ~f:(fun acc p ->
        G1.(p + scale acc xi) )

  let accumulate_degree_bound_checks =
    accumulate_degree_bound_checks ~add:G1.( + ) ~scale:G1.scale

  let accumulate_opening_check =
    let open G1 in
    accumulate_opening_check ~add:( + ) ~negate ~scale ~generator:Generators.g

  module Requests = struct
    open Snarky.Request

    type _ t +=
      | Prev_evals :
          Field.Constant.t Dlog_marlin_types.Evals.t Tuple_lib.Triple.t t
      | Prev_messages :
          (PC.Constant.t, Fp.Packed.Constant.t) Pairing_marlin_types.Messages.t
          t
      | Prev_openings_proof : G1.Constant.t Tuple_lib.Triple.t t
      | Prev_proof_state :
          ( Challenge.Constant.t
          , Fq.Constant.t
          , bool
          , (Challenge.Constant.t, bool) Types.Bulletproof_challenge.t
          , Digest.Constant.t
          , Digest.Constant.t )
          Types.Pairing_based.Proof_state.t
          t
      | Prev_me_only :
          ( G1.Constant.t
          , Field.Constant.t )
          Types.Dlog_based.Proof_state.Me_only.t
          t
      | Prev_x_hat : Field.Constant.t Tuple_lib.Triple.t t
  end

  let multiscale scalars elts = ()

  let lagrange_precomputations =
    Array.map Input_domain.lagrange_commitments
      ~f:G1.Scaling_precomputation.create

  let incrementally_verify_pairings
      ~verification_key:(m : _ Abc.t Matrix_evals.t) ~sponge ~public_input
      ~pairing_acc:{Accumulator.opening_check; degree_bound_checks}
      ~(messages : _ Pairing_marlin_types.Messages.t)
      ~opening_proofs:(pi_1, pi_2, pi_3) ~xi ~r ~r_xi_sum =
    let receive ty f =
      let x = f messages in
      absorb sponge ty x ; x
    in
    let sample () = Sponge.squeeze sponge ~length:Challenge.length in
    let open Pairing_marlin_types.Messages in
    let x_hat =
      assert (Int.ceil_pow2 (Array.length public_input) = Domain.size Input_domain.domain);
      G1.multiscale_known
        (Array.mapi public_input ~f:(fun i x ->
             (x, lagrange_precomputations.(i)) ))
    in
    absorb sponge PC x_hat ;
    let w_hat = receive PC w_hat in
    let z_hat_a = receive PC z_hat_a in
    let z_hat_b = receive PC z_hat_b in
    let alpha = sample () in
    let eta_a = sample () in
    let eta_b = sample () in
    let eta_c = sample () in
    let g_1, h_1 = receive (Type.degree_bounded_pc :: PC) gh_1 in
    let beta_1 = sample () in
    let sigma_2, (g_2, h_2) =
      receive (Scalar :: Type.degree_bounded_pc :: PC) sigma_gh_2
    in
    let beta_2 = sample () in
    let sigma_3, (g_3, h_3) =
      receive (Scalar :: Type.degree_bounded_pc :: PC) sigma_gh_3
    in
    let beta_3 = sample () in
    let r_k = sample () in
    begin
      print_g1 "x_hat" x_hat ;
      print_g1 "w" w_hat ;
      print_g1 "za" z_hat_a ;
      print_g1 "zb" z_hat_b ;
      List.iter
        [ ("alpha", alpha)
        ; ("eta_a", eta_a)
        ; ("eta_b", eta_b)
        ; ("eta_c", eta_c)
        ; ("r_k", r_k)
        ; ("beta_1", beta_1)
        ; ("beta_2", beta_2)
        ; ("beta_3", beta_3) ] ~f:(fun (lab, x) -> print_chal lab x) ;
    end;
    let digest_before_evaluations =
      Sponge.squeeze sponge ~length:Digest.length
    in
    let open Vector in
    let combine_commitments t =
      Pcs_batch.combine_commitments ~scale:G1.scale ~add:G1.(+) ~xi t
    in
    let pairing_acc =
      let (g1, g1_s), (g2, g2_s), (g3, g3_s) = (g_1, g_2, g_3) in
      let f_1 =
        combine_commitments Common.pairing_beta_1_pcs_batch
          [x_hat; w_hat; z_hat_a; z_hat_b; g1; h_1]
          []
      in
      let f_2 =
        combine_commitments Common.pairing_beta_2_pcs_batch [g2; h_2] []
      in
      let f_3 =
        combine_commitments Common.pairing_beta_3_pcs_batch
          [ g3
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
          []
      in
      { Accumulator.degree_bound_checks=
          accumulate_degree_bound_checks degree_bound_checks ~r_h:r ~r_k g_1
            g_2 g_3
      ; opening_check=
          accumulate_opening_check opening_check ~r ~r_xi_sum
            (f_1, beta_1, pi_1) (f_2, beta_2, pi_2) (f_3, beta_3, pi_3) }
    in
    let deferred =
      { Types.Dlog_based.Proof_state.Deferred_values.Marlin.sigma_2
      ; sigma_3
      ; alpha
      ; eta_a
      ; eta_b
      ; eta_c
      ; beta_1
      ; beta_2
      ; beta_3 }
    in
    (digest_before_evaluations, pairing_acc, deferred)

  let combined_evaluation ~xi ~evaluation_point
      (without_degree_bound, with_degree_bound) =
    Pcs_batch.combine_evaluations
      (Common.dlog_pcs_batch ~domain_h ~domain_k)
      ~crs_max_degree ~mul:Fq.mul ~add:Fq.add ~one:Fq.one ~evaluation_point ~xi
      without_degree_bound with_degree_bound

  (* x^{2 ^ k} - 1 *)
  let vanishing_polynomial domain x =
    let k = Domain.log2_size domain in
    let rec pow acc i = if i = 0 then acc else pow (Fq.square acc) (i - 1) in
    Fq.(pow x k - one)

  let sum' xs f = List.reduce_exn (List.map xs ~f) ~f:Fq.( + )

  let prod xs f = List.reduce_exn (List.map xs ~f) ~f:Fq.( * )

  let compute_challenges chals =
    (* TODO: Put this in the functor argument. *)
    let nonresidue = Fq.of_int 7 in
    Array.map chals
      ~f:(fun {Types.Bulletproof_challenge.prechallenge; is_square} ->
        let sq =
          Fq.if_ is_square ~then_:prechallenge
            ~else_:Fq.(nonresidue * prechallenge)
        in
        Fq.sqrt sq )

  module Marlin_checks = Marlin_checks.Make (Impl)

  let b_poly chals =
    let open Fq in
    let chal_invs = Array.map chals ~f:inv in
    fun x -> sg_polynomial ~add ~mul chals chal_invs x

  let finalize_other_proof ~domain_k ~domain_h ~sponge
      ~old_bulletproof_challenges
      ({xi; r; combined_inner_product; bulletproof_challenges; b; marlin} :
        _ Types.Pairing_based.Proof_state.Deferred_values.t) =
    let open Vector in
    (* You use the NEW bulletproof challenges to check b. Not the old ones. *)
    (* As a proof size optimization, we can probably rig each polynomial
       to vanish on the previous challenges.
    
       Like instead of the deg n polynomial f(x), the degree (n + 1) polynomial with 
       f_tilde(h) = f(h), for each h in h 
       f_tilde(beta_1) = 0
    *)
    let beta_1_evals, beta_2_evals, beta_3_evals =
      let ty = Evals.typ Fq.typ in
      exists (Typ.tuple3 ty ty ty) ~request:(fun () -> Requests.Prev_evals)
    in
    let (x_hat1, x_hat2, x_hat3) =
      exists (Typ.tuple3 Fq.typ Fq.typ Fq.typ) ~request:(fun () -> Requests.Prev_x_hat)
    in
    let open Fq in
    let absorb_evals x_hat e =
      let xs, ys = Evals.to_vectors e in
      List.iter Vector.(x_hat :: (to_list xs @ to_list ys)) ~f:(Sponge.absorb sponge)
    in
    (* A lot of hashing. *)
    absorb_evals x_hat1 beta_1_evals ;
    absorb_evals x_hat2 beta_2_evals ;
    absorb_evals x_hat3 beta_3_evals ;
    let xi_and_r_correct =
      let xi_actual = Sponge.squeeze sponge ~length:Challenge.length in
      let r_actual = Sponge.squeeze sponge ~length:Challenge.length in
      (* Sample new sg challenge point here *)
      Boolean.all [equal (pack xi_actual) xi; equal (pack r_actual) r]
    in
    let combined_inner_product_correct =
      (* sum_i r^i sum_j xi^j f_j(beta_i) *)
      let actual_combined_inner_product =
        let sg_old = b_poly old_bulletproof_challenges in
        let combine pt x_hat e =
          let a, b = Evals.to_vectors e in
          combined_evaluation ~xi ~evaluation_point:pt
            (sg_old pt :: x_hat :: a, b)
        in
        combine marlin.beta_1 x_hat1 beta_1_evals
        + r
          * ( combine marlin.beta_2 x_hat2 beta_2_evals
            + (r * combine marlin.beta_3 x_hat3 beta_3_evals) )
      in
      equal combined_inner_product actual_combined_inner_product
    in
    let bulletproof_challenges = compute_challenges bulletproof_challenges in
    let b_correct =
      let b_poly = b_poly bulletproof_challenges in
      let b_actual = b_poly marlin.beta_1 + r * (b_poly marlin.beta_2 + r * (b_poly marlin.beta_3)) in
      equal b b_actual
    in
    let marlin_checks_passed =
      Marlin_checks.check
        ~input_domain:Input_domain.self ~domain_h ~domain_k
        ~x_hat_beta_1:x_hat1
        marlin
        { w_hat= beta_1_evals.w_hat
        ; g_1= beta_1_evals.g_1
        ; h_1= beta_1_evals.h_1
        ; z_hat_a= beta_1_evals.z_hat_a
        ; z_hat_b= beta_1_evals.z_hat_b
        ; g_2= beta_2_evals.g_2
        ; h_2= beta_2_evals.h_2
        ; g_3= beta_3_evals.g_3
        ; h_3= beta_3_evals.h_3
        ; row= beta_3_evals.row
        ; col= beta_3_evals.col
        ; value=beta_3_evals.value
        ; rc= beta_3_evals.rc
        }
    in
    print_bool "combined_inner_product_correct" combined_inner_product_correct ;
    print_bool "marlin_checks_passed" marlin_checks_passed ;
    print_bool "b_correct" b_correct ;
    ( Boolean.all
        [xi_and_r_correct; b_correct; combined_inner_product_correct; marlin_checks_passed]
    , bulletproof_challenges )

  (* TODO: No need to hash the entire bulletproof challenges. Could
   just hash the segment of the public input LDE corresponding to them
   that we compute when verifying the previous proof. That is a commitment
   to them.
*)
  let hash_me_only t =
    let elts =
      Types.Dlog_based.Proof_state.Me_only.to_field_elements
        ~g1:G1.to_field_elements t
    in
    let sponge = Sponge.create sponge_params in
    Array.iter elts ~f:(fun x -> Sponge.absorb sponge x) ;
    Sponge.squeeze sponge ~length:Digest.length

  let map_challenges
      { Types.Pairing_based.Proof_state.Deferred_values.marlin
      ; combined_inner_product
      ; xi
      ; r
      ; bulletproof_challenges
      ; b } ~f =
    { Types.Pairing_based.Proof_state.Deferred_values.marlin=
        Types.Pairing_based.Proof_state.Deferred_values.Marlin.map_challenges
          marlin ~f
    ; combined_inner_product
    ; bulletproof_challenges=
        Array.map bulletproof_challenges
          ~f:(fun (r : _ Types.Bulletproof_challenge.t) ->
            {r with prechallenge= f r.prechallenge} )
    ; xi= f xi
    ; r= f r
    ; b }

  let pack_data (bool, fq, digest, challenge, bulletproof_challenges) =
    Array.concat
      [ Array.map (Vector.to_array bool) ~f:List.return
      ; Array.concat_map (Vector.to_array fq) ~f:(fun x ->
            let low_bits, high_bit =
              Common.split_last
                (Bitstring_lib.Bitstring.Lsb_first.to_list (Fq.unpack_full x))
            in
            [|low_bits; [high_bit]|] )
      ; Vector.to_array digest
      ; Vector.to_array challenge
      ; Array.map bulletproof_challenges
          ~f:(fun {Types.Bulletproof_challenge.prechallenge; is_square} ->
            is_square :: prechallenge ) ]

  let main
      ~bulletproof_log2
      ({ proof_state=
           { deferred_values= {marlin; xi; r; r_xi_sum}
           ; sponge_digest_before_evaluations
           ; me_only= me_only_digest 
           ; was_base_case
           }
       ; pass_through } :
        (Challenge.t, _, _, _, _, _, _, _) Types.Dlog_based.Statement.t) =
    let ( prev_deferred_values
        , prev_sponge_digest_before_evaluations
        , prev_proof_state ) =
      let state =
        exists
          (Types.Pairing_based.Proof_state.typ Challenge.typ Fq.typ Boolean.typ
             Digest.typ Digest.typ ~length:bulletproof_log2)
          ~request:(fun () -> Requests.Prev_proof_state)
      in
      ( map_challenges ~f:Fq.pack state.deferred_values
      , Fq.pack state.sponge_digest_before_evaluations
      , state )
    in
    let prev_me_only =
      exists
        (Types.Dlog_based.Proof_state.Me_only.typ G1.typ Fq.typ
           ~length:bulletproof_log2) ~request:(fun () ->
          Requests.Prev_me_only )
    in
    let pairing_marlin_index = prev_me_only.pairing_marlin_index in
    let prev_pairing_acc = prev_me_only.pairing_marlin_acc in
    let prev_statement =
      (* TODO: A lot of repeated hashing happening here on the dlog_marlin_index *)
      let prev_me_only = hash_me_only prev_me_only in
      { Types.Pairing_based.Statement.pass_through= prev_me_only
      ; proof_state= prev_proof_state }
    in
    let prev_proof_finalized, most_recent_bulletproof_challenges =
      let sponge =
        let s = Sponge.create sponge_params in
        Sponge.absorb s prev_sponge_digest_before_evaluations ;
        s
      in
      finalize_other_proof ~domain_k ~domain_h ~sponge prev_deferred_values
        ~old_bulletproof_challenges:prev_me_only.old_bulletproof_challenges
    in
    Boolean.Assert.(was_base_case = prev_statement.proof_state.was_base_case);
    print_bool "prev_proof_finalized" prev_proof_finalized ;
    print_bool "prev_statement.proof_state.was_base_case" prev_statement.proof_state.was_base_case ;
    Boolean.Assert.any
      [prev_proof_finalized; prev_statement.proof_state.was_base_case] ;
    let ( sponge_digest_before_evaluations_actual
        , pairing_marlin_acc
        , marlin_actual ) =
      let messages =
        exists (Pairing_marlin_types.Messages.typ PC.typ Fp.Packed.typ)
          ~request:(fun () -> Requests.Prev_messages)
      in
      let opening_proofs =
        exists (Typ.tuple3 G1.typ G1.typ G1.typ) ~request:(fun () ->
            Requests.Prev_openings_proof )
      in
      let sponge = Sponge.create sponge_params in
      incrementally_verify_pairings ~pairing_acc:prev_pairing_acc ~xi ~r
        ~r_xi_sum ~verification_key:pairing_marlin_index ~sponge
        ~public_input:
          (Array.append
             [|[Boolean.true_]|]
             (pack_data (Types.Pairing_based.Statement.to_data prev_statement)))
        ~messages ~opening_proofs
    in
    Field.Assert.equal me_only_digest
      (Field.pack
         (hash_me_only
            { Types.Dlog_based.Proof_state.Me_only.pairing_marlin_index
            ; pairing_marlin_acc
            ; old_bulletproof_challenges= most_recent_bulletproof_challenges })) ;
    Field.Assert.equal sponge_digest_before_evaluations
      (Field.pack sponge_digest_before_evaluations_actual)

  (* TODO
    Data.(
      assert_equal
        (marlin_data marlin)
        (marlin_data marlin_actual))
       *)

  let main (bool, fp, challenge, digest) =
    let unpack length = Vector.map ~f:(Fq.choose_preimage_var ~length) in
    ( bool
    , unpack Fq.size_in_bits fp
    , unpack Challenge.length challenge
    , digest )
    |> Types.Dlog_based.Statement.of_data |> main
end
