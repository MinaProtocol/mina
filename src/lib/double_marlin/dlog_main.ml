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

  module Opening_proof = G1
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

  let print_g1 lab (x, y) =
    as_prover
      As_prover.(
        fun () ->
          Core.printf "in-snark: %s (%s, %s)\n%!" lab
            (Field.Constant.to_string (read_var x))
            (Field.Constant.to_string (read_var y)))

  let print_chal lab x =
    as_prover
      As_prover.(
        fun () ->
          Core.printf "in-snark %s: %s\n%!" lab
            (Field.Constant.to_string
               (Field.Constant.project (List.map ~f:(read Boolean.typ) x))))

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
    Core.printf "Input size = %d\n%!" (Array.length public_input) ;
    let x_hat =
      assert (Int.ceil_pow2 (Array.length public_input) = Domain.size Input_domain.domain);
      let pairs =
        Array.mapi public_input ~f:(fun i x ->
            (x, Input_domain.lagrange_commitments.(i)) )
      in
      as_prover
        As_prover.(
          fun () ->
            Core.printf "in-snark xhat multiscale\n%!" ;
            Array.iter pairs ~f:(fun (a, p) ->
                let x, y = G1.Constant.to_affine_exn p in
                let bits = List.map a ~f:(read Boolean.typ) in
                let a =
                  List.foldi bits ~init:B.zero ~f:(fun i acc b ->
                      if not b then acc else B.(acc lor (one lsl i)) )
                in
                Core.printf "%s\n%!" (B.to_string a) )) ;
      (*
              (Field.Constant.to_string (x))
              (Field.Constant.to_string (y)) ));
*)
      (* Must handle 1 ! *)
      G1.multiscale_known
        (Array.mapi public_input ~f:(fun i x ->
             (x, lagrange_precomputations.(i)) ))
    in
    print_g1 "x_hat" x_hat ;
    absorb sponge PC x_hat ;
    let w_hat = receive PC w_hat in
    let z_hat_a = receive PC z_hat_a in
    let z_hat_b = receive PC z_hat_b in
    print_g1 "w" w_hat ;
    print_g1 "za" z_hat_a ;
    print_g1 "zb" z_hat_b ;
    let alpha = sample () in
    as_prover
      As_prover.(
        fun () ->
          Core.printf "Just computed alpha = %!" ;
          Snarky_bn382_backend.Fp.(
            print (of_bits (List.map alpha ~f:(read Boolean.typ)))) ;
          Core.printf "%!\n%!") ;
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
    List.iter
      [ ("alpha", alpha)
      ; ("eta_a", eta_a)
      ; ("eta_b", eta_b)
      ; ("eta_c", eta_c)
      ; ("r_k", r_k)
      ; ("beta_1", beta_1)
      ; ("beta_2", beta_2)
      ; ("beta_3", beta_3) ] ~f:(fun (lab, x) -> print_chal lab x) ;
    let digest_before_evaluations =
      Sponge.squeeze sponge ~length:Digest.length
    in
    (* xi, r should be sampled here in the prover/CPU verifier using

       let sponge = Fp_based_sponge.create () in
       Sponge.absorb sponge digest_before_evaluations;
       let xi = Sponge.squeeze sponge in
       let r = Sponge.squeeze sponge in
       ...
    *)
    let open Vector in
    let combine_commitments t =
      Core.printf "snark combine\n%!" ;
      let module Impl =
        Snarky.Snark.Run.Make (Snarky_bn382_backend.Pairing_based) (Unit)
      in
      let scale acc xi =
        let x, y = acc in
        as_prover
          As_prover.(
            fun () ->
              let xi =
                Snarky_bn382_backend.Fp.(
                  of_bits (List.map xi ~f:(read Boolean.typ)))
              in
              Core.printf "snark scale: acc=(%s, %s), xi=%s\n%!"
                (Inputs.Impl.Field.Constant.to_string (read_var x))
                (Inputs.Impl.Field.Constant.to_string (read_var y))
                (Impl.Field.Constant.to_string xi)) ;
        G1.scale acc xi
      in
      let add p scaled =
        let px, py = p in
        let sx, sy = scaled in
        as_prover
          As_prover.(
            fun () ->
              Core.printf "snark add: p=(%s, %s), scaled=(%s, %s)\n%!"
                (Inputs.Impl.Field.Constant.to_string (read_var px))
                (Inputs.Impl.Field.Constant.to_string (read_var py))
                (Inputs.Impl.Field.Constant.to_string (read_var sx))
                (Inputs.Impl.Field.Constant.to_string (read_var sy))) ;
        G1.( + ) p scaled
      in
      Pcs_batch.combine_commitments ~scale ~add ~xi t
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
      print_g1 "f_1" f_1 ;
      print_g1 "f_2" f_2 ;
      print_g1 "f_3" f_3 ;
      { Accumulator.degree_bound_checks=
          accumulate_degree_bound_checks degree_bound_checks ~r_h:r ~r_k g_1
            g_2 g_3
      ; opening_check=
          accumulate_opening_check opening_check ~r ~r_xi_sum
            (f_1, beta_1, pi_1) (f_2, beta_2, pi_2) (f_3, beta_3, pi_3) }
      (*
      accumulate_pairing_state ~r ~r_xi_sum
        pairing_acc
*)
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

  (*
    List.fold_left (Vector.to_list evals) ~init:eval0 ~f:(fun acc eval ->
        Fq.((xi * acc) + eval) ) *)

  (* x^{2 ^ k} - 1 *)
  let vanishing_polynomial domain x =
    let k = Domain.log2_size domain in
    let rec pow acc i = if i = 0 then acc else pow (Fq.square acc) (i - 1) in
    Fq.(pow x k - one)

  let sum' xs f = List.reduce_exn (List.map xs ~f) ~f:Fq.( + )

  let prod xs f = List.reduce_exn (List.map xs ~f) ~f:Fq.( * )

  (* TODO: Put this in the functor argument. *)
  let nonresidue = Fq.of_int 7

  let pow_two_pows x k =
    let res = Array.init k ~f:(fun _ -> x) in
    for i = 1 to k - 1 do
      res.(i) <- Fq.square res.(i - 1)
    done ;
    res

  (* TODO: Check a_hat! *)
  let compute_challenges chals =
    Array.map chals
      ~f:(fun {Types.Bulletproof_challenge.prechallenge; is_square} ->
        let sq =
          Fq.if_ is_square ~then_:prechallenge
            ~else_:Fq.(nonresidue * prechallenge)
        in
        Fq.sqrt sq )

  module Marlin_checks = Marlin_checks.Make (Impl)

  let print_bool lab x =
    as_prover (fun () ->
        printf "%s: %b\n%!" lab (As_prover.read Boolean.typ x))

  (* The sg challenge point should be hash(sg) (or some variant thereof)
     We have this in the form of the hashed pass_through!

     the bulletproof_challenges and the pass_through.sg correspond.
     So we compute f_{bulletproof_challenges}(pass_through.sg)
     and expose that when computing the next combined_inner_product.

     sg_evalution_point can be the pass_through hash
   *)
  let finalize_other_proof ~domain_k ~domain_h ~sponge
      ~(*
      ~old_sg_challenge_point
      ~old_sg_evaluation *)
      old_bulletproof_challenges
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
    (* Also have to get evals on old sg_challenge_goint. *)
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
    print_bool "xi_and_r_correct" xi_and_r_correct ;
    let combined_inner_product_correct =
      (* sum_i r^i sum_j xi^j f_j(beta_i) *)
      let actual_combined_inner_product =
        let sg_old =
          let old_bulletproof_challenges_inv =
            Array.map old_bulletproof_challenges ~f:Field.inv
          in
          sg_polynomial ~add:Field.add ~mul:Field.mul
            old_bulletproof_challenges old_bulletproof_challenges_inv
        in
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
    print_bool "combined_inner_product_correct" combined_inner_product_correct ;
    let marlin_checks_passed =
      Marlin_checks.check ~input_domain:Input_domain.domain ~domain_h ~domain_k
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
    print_bool "marlin_checks_passed" marlin_checks_passed ;
    ( Boolean.all
        [xi_and_r_correct; combined_inner_product_correct; marlin_checks_passed]
    , compute_challenges bulletproof_challenges )

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

  let split_last = Common.split_last

  (* TODO: The way this handles fq elts is wrong. Fix. *)
  let pack_data (bool, fq, digest, challenge, bulletproof_challenges) =
    Array.concat
      [ Array.map (Vector.to_array bool) ~f:List.return
      ; Array.concat_map (Vector.to_array fq) ~f:(fun x ->
            let low_bits, high_bit =
              split_last
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
    (* 
    Need the old sg_challenge_point and old sg_evaluation to correctly compute
       the combined_inner_product.

    Perhaps it should be in the prev me only?
    *)
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
    (* On the second wrap, if we start the process off with a bad sg,
       prev_proof_finalized will be false.
    *)
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
    (* TODO: Use unpack? *)
    let unpack length = Vector.map ~f:(Fq.choose_preimage_var ~length) in
    ( bool
    , unpack Fq.size_in_bits fp (*     , fq *)
    , unpack Challenge.length challenge (*     , fq_challenge *)
    , digest )
    |> Types.Dlog_based.Statement.of_data |> main

  (*

  (* Inside here we have F_q arithmetic, so we can incrementally check
   the polynomial commitments from the pairing-based Marlin *)
  let dlog_main statement
      (*
      { Dlog_marlin_statement.deferred_values
      ; pairing_marlin_index
      ; sponge_digest
          (* I don't think most of b stuff should be a public input for this proof,
   it should be a public input for the pairing proof.

   Specifically, the pairing proof should have as public inputs:

   bp_challenges_old
   g_old

   Then, we pick a random point b_challenge,
   evaluate b_u_x := b_{bp_challenges}(b_challenge) and
   
   expose in our public input: b_u_x, b_challenge, g_old. The
   next guy is responsible for checking this evaluation (it will actually
   need the old bp_challenges though to compute evaluations of
   g_old on all the other challenge points for the multi-polynomial,
   multi-point batched proof)
*)
      ; bp_challenges_old
      ; b_challenge_old
      ; b_u_x_old (* All this could be a hash which we unhash *)
      ; pairing_marlin_acc
      ; app_state
      ; g_old
      ; dlog_marlin_index } = *)
    =
    let 
      { Types.Dlog_based.Statement.proof_state
      ; pass_through
      }
      =
      Types.Dlog_based.Statement.of_data statement
    in
    let prev : _ Types.Pairing_based.Statement.t =
      exists (failwith "TIODO")
    in
    let open Requests in
    let exists typ r = exists typ ~request:(fun () -> r) in
    (* This is kind of a special case of deferred fq arithmetic. *)
    Field.Assert.equal (b bp_challenges_old b_challenge_old) b_u_x_old ;
    let prev_sponge_digest = exists Fp.Unpacked.typ Prev.Sponge_digest in
    let sponge =
      let sponge = Sponge.create sponge_params in
      Sponge.absorb sponge (Fp.pack prev_sponge_digest) ;
      sponge
    in
    let updated_pairing_marlin_acc, deferred_fp_arithmetic =
      let prev_marlin_proof =
        exists
          (Proof.typ PC.typ Fp.Unpacked.typ
             (Pairing_marlin_types.Openings.typ Opening_proof.typ
                Fp.Unpacked.typ))
          Prev.Pairing_marlin_proof
      and prev_pairing_marlin_acc =
        exists (Accumulator.typ G1.typ)
          Requests.Prev.Pairing_marlin_accumulator
      in
      let public_input =
        (* TODO *)
        Array.init 26 ~f:(fun _ ->
            L.Fp_repr.of_bits ~chunk_size:124
              (Impl.exists (Typ.list ~length:382 Boolean.typ)) )
      in
      incrementally_verify_pairings ~verification_key:pairing_marlin_index
        ~sponge ~proof:prev_marlin_proof ~pairing_acc:prev_pairing_marlin_acc
        ~public_input
      (*
      prev_marlin_proof
      ~public_input:[
        pairing_marlin_vk; (* This may need to be passed in using the hashing trick. It could be hashed together with prev_pairing_marlin_acc since they're both just passed through anyway.  *)
        prev_pairing_marlin_acc;
        dlog_marlin_vk;
        g_old;

        prev_dlog_marlin_acc;

        prev_deferred_fq_arithmetic;
      ] *)
    in
    (* TODO: Just squeeze a field element here *)
    let actual_sponge_digest =
      Field.pack (Sponge.squeeze sponge ~length:digest_length)
    in
    Field.Assert.equal sponge_digest actual_sponge_digest ;
    Accumulator.assert_equal
      (fun x y ->
        List.iter2_exn ~f:Field.Assert.equal (G1.to_field_elements x)
          (G1.to_field_elements y) )
      updated_pairing_marlin_acc pairing_marlin_acc ;
    Dlog_marlin_statement.Deferred_values.assert_equal Fp.Unpacked.assert_equal
      deferred_values deferred_fp_arithmetic
     *)
end

(*
let%test_unit "count-constraints" =
  let module Impl =
    Snarky.Snark.Run.Make (Snarky.Backends.Bn128.Default) (Unit)
  in
  let module Poseidon_inputs = struct
    module Field = struct
      open Impl

      (* The linear combinations involved in computing Poseidon do not involve very many
   variables, but if they are represented as arithmetic expressions (that is, "Cvars"
   which is what Field.t is under the hood) the expressions grow exponentially in
   in the number of rounds. Thus, we compute with Field elements represented by
   a "reduced" linear combination. That is, a coefficient for each variable and an
   constant term.
*)
      type t = Impl.field Int.Map.t * Impl.field

      let to_cvar ((m, c) : t) : Field.t =
        Map.fold m ~init:(Field.constant c) ~f:(fun ~key ~data acc ->
            let x =
              let v = Snarky.Cvar.Var key in
              if Field.Constant.equal data Field.Constant.one then v
              else Scale (data, v)
            in
            match acc with
            | Constant c when Field.Constant.equal Field.Constant.zero c ->
                x
            | _ ->
                Add (x, acc) )

      let constant c = (Int.Map.empty, c)

      let of_cvar (x : Field.t) =
        match x with
        | Constant c ->
            constant c
        | Var v ->
            (Int.Map.singleton v Field.Constant.one, Field.Constant.zero)
        | x ->
            let c, ts = Field.to_constant_and_terms x in
            ( Int.Map.of_alist_reduce
                (List.map ts ~f:(fun (f, v) -> (Impl.Var.index v, f)))
                ~f:Field.Constant.add
            , Option.value ~default:Field.Constant.zero c )

      let ( + ) (t1, c1) (t2, c2) =
        ( Map.merge t1 t2 ~f:(fun ~key:_ t ->
              match t with
              | `Left x ->
                  Some x
              | `Right y ->
                  Some y
              | `Both (x, y) ->
                  Some Field.Constant.(x + y) )
        , Field.Constant.add c1 c2 )

      let ( * ) (t1, c1) (t2, c2) =
        assert (Int.Map.is_empty t1) ;
        (Map.map t2 ~f:(Field.Constant.mul c1), Field.Constant.mul c1 c2)

      let zero : t = constant Field.Constant.zero
    end

    let rounds_full = 8

    let rounds_partial = 55

    let to_the_alpha x = Impl.Field.(square (square x) * x)

    let to_the_alpha x = Field.of_cvar (to_the_alpha (Field.to_cvar x))

    module Operations = Sponge.Make_operations (Field)
  end in
  let module S = Sponge.Make_sponge (Sponge.Poseidon (Poseidon_inputs)) in
  let module Inputs = struct
    module Impl = Impl

    let sponge_params =
      Sponge.Params.(
        map bn128 ~f:Impl.Field.(Fn.compose constant Constant.of_string))

    module Sponge = struct
      module S = struct
        type t = S.t

        let create ?init params =
          S.create
            ?init:
              (Option.map init
                 ~f:(Sponge.State.map ~f:Poseidon_inputs.Field.of_cvar))
            (Sponge.Params.map params ~f:Poseidon_inputs.Field.of_cvar)

        let absorb t input =
          ksprintf Impl.with_label "absorb: %s" __LOC__ (fun () ->
              S.absorb t (Poseidon_inputs.Field.of_cvar input) )

        let squeeze t =
          ksprintf Impl.with_label "squeeze: %s" __LOC__ (fun () ->
              Poseidon_inputs.Field.to_cvar (S.squeeze t) )
      end

      include Sponge.Make_bit_sponge (struct
                  type t = Impl.Boolean.var
                end)
                (struct
                  include Impl.Field

                  let to_bits t =
                    Bitstring_lib.Bitstring.Lsb_first.to_list
                      (Impl.Field.unpack_full t)
                end)
                (S)
    end

    module Fp_params = struct
      let size_in_bits = 382

      let p =
        Bigint.of_string
          "5543634365110765627805495722742127385843376434033820803590214255538854698464778703795540858859767700241957783601153"
    end

    module G1 = struct
      module Inputs = struct
        module Impl = Impl

        module F = struct
          include struct
            open Impl.Field

            type nonrec t = t

            let ( * ), ( + ), ( - ), inv_exn, square, scale, if_, typ, constant
                =
              (( * ), ( + ), ( - ), inv, square, scale, if_, typ, constant)

            let negate x = scale x Constant.(negate one)
          end

          module Constant = struct
            open Impl.Field.Constant

            type nonrec t = t

            let ( * ), ( + ), ( - ), inv_exn, square, negate =
              (( * ), ( + ), ( - ), inv, square, negate)
          end

          let assert_square x y = Impl.assert_square x y

          let assert_r1cs x y z = Impl.assert_r1cs x y z
        end

        module Params = struct
          open Impl.Field.Constant

          let a = zero

          let b = of_int 14

          let one =
            (* Fake *)
            (of_int 1, of_int 1)
        end

        module Constant = struct
          type t = F.Constant.t * F.Constant.t

          let to_affine_exn = Fn.id

          let of_affine = Fn.id

          let random () = Params.one
        end
      end

      module Constant = Inputs.Constant
      module T = Snarky_curve.Make_checked (Inputs)

      type t = T.t

      let typ = T.typ

      let ( + ) = T.add_exn

      let scale t bs =
        ksprintf Impl.with_label "scale %s" __LOC__ (fun () ->
            (* Dummy constraints *)
            let x, y = t in
            let constraints_per_bit = 6 in
            let num_bits = List.length bs in
            for _ = 1 to constraints_per_bit * num_bits do
              Impl.assert_r1cs x y x
            done ;
            t )

      (*         T.scale t (Bitstring_lib.Bitstring.Lsb_first.of_list bs) *)
      let to_field_elements (x, y) = [x; y]

      let negate = T.negate
    end
  end in
  let module M = Dlog_main (Inputs) in
  let typ =
    Dlog_marlin_statement.typ M.Challenge.typ M.Fp.Unpacked.typ Impl.Field.typ
      Inputs.G1.typ M.PC.typ
      (Snarky.Typ.tuple2 M.Fp.Unpacked.typ M.Fp.Unpacked.typ)
      Impl.Field.typ Impl.Field.typ
  in
  let c () =
    (* Writing down the input takes 39000 constriants *)
    let open Impl in
    M.dlog_main (exists typ)
  in
  printf "count = %d\n%!" (Impl.constraint_count c)
    *)

(*
  let module I = Snarky.Snark0.Make(Snarky.Backends.Bn128.Default) in
  let c () =
    let open I in
    let%bind stmt = exists typ in
    Impl.make_checked (fun () -> M.dlog_main stmt)
  in
  let module L = Snarky_log.Constraints(I) in
  Snarky_log.to_file "double_marlin.perf"
    (L.log (c ()));
  printf "logged"
     *)
(*
*)

(*
module Pairing_main (Inputs : Pairing_main_inputs_intf) = struct
  open Inputs
  open Impl

  (* Inside here we have F_p arithmetic so we can incrementally check the
    polynomial commitments from the DLog-based marlin *)
  let pairing_main app_state pairing_marlin_vk prev_pairing_marlin_acc
      dlog_marlin_vk g_new u_new x_new next_dlog_marlin_acc
      next_deferred_fq_arithmetic =
    (* The actual computation *)
    let prev_app_state = exists Prev_app_state in
    let transition = exists Transition in
    assert (transition_function prev_app_state transition = app_state) ;
    let prev_dlog_marlin_acc = exists Dlog_marlin_acc
    and prev_deferred_fp_arithmetic = exists Deferred_fp_arithmetic in
    List.iter prev_deferred_fp_arithmetic ~f:perform ;
    let (actual_g_new, actual_u_new), deferred_fq_arithmetic =
      let g_old, x_old, u_old, b_u_old = exists G_old in
      let ( updated_dlog_marlin_acc
          , deferred_fq_arithmetic
          , polynomial_evaluation_checks ) =
        let prev_dlog_marlin_proof = exists Prev_dlog_marlin_proof in
        Dlog_marlin.incrementally_execute_protocol dlog_marlin_vk
          prev_dlog_marlin_proof
          ~public_input:
            [ prev_app_state
            ; pairing_marlin_vk
            ; prev_pairing_marlin_acc
            ; dlog_marlin_vk
            ; g_old
            ; x_old
            ; u_old
            ; b_u_old_x
            ; prev_dlog_marlin_acc
            ; prev_deferred_fp_arithmetic ]
      in
      let g_new_u_new =
        batched_inner_product_argument
          ((g_old, x_old, b_u_old_x) :: polynomial_evaluation_checks)
      in
      (g_new_u_new, deferred_fq_arithmetic)
    in
    (* This should be sampled using the hash state at the end of 
          "Dlog_marlin.incrementally_execute_protocol" *)
    let x_new = sample () in
    assert (actual_g_new = g_new) ;
    assert (actual_u_new = u_new) ;
    assert (actual_x_new = x_new)
end *)
(*
  module Fp_constant = struct
    include Snarkette.Fields.Make_fp (struct
                include B

                let num_bits _ = 382

                let log_and = ( land )

                let log_or = ( lor )

                let test_bit x (i : int) = shift_right x i land one = one

                let to_yojson t = `String (to_string t)

                let of_yojson _ = failwith "todo"

                let ( // ) = ( / )
              end)
              (struct
                let order = Fp_params.p
              end)

    let of_bits bs = Option.value_exn (of_bits bs)

    let size_in_bits = 382
  end

  module L = Eval_lagrange.Eval_lagrange (Impl) (Sponge) (Fp_constant) *)

(* TODO: Could save 3 scalar muls at the cost of
     (I think) 3 more public inputs here by witnessing

     vr_i == value_i * randomness_i.

     Actually can avoid both!
  *)

(*
  module Accumulation_deferred_values = struct
    type t =
      {
      }
  end *)
(* I think we need to absorb the evaluations to sample r properly.

     OTOH -- the evaluations are completely determined subject to the proof verifying...
  *)

(* The xi sum scheme HAS to be

     say v_0 : Fq

     // let xi = witness() // == Fq_friendly_hash(sponge_digest_at_this_moment, v_0, ..., v_n)
     let c = witness(); // sum_i xi^i v_i

     expose c := sum_i 
  *)

(* Accumulate

     sum_{i=1}^3 r^i f_i
     = f_1 + r * (f_2 + r * f_3)

     sum_{i=1}^3 r^i v_i g

     Option 1:
      compute
      
      f_1 - v_1 * g + r * (f_2 - v_2 * g + r * (f_3 - v_3 g))

     cost:
      3 fixed base scalar muls
      3 variable base scalar muls

     public inputs:
      v_1, v_2, v_3

     Option 2:
     compute
      f_1 + r * (f_2 + r * f_3)
      and
      (sum_{i=1}^3 r^i v_i) g

     cost:
      1 fixed base scalar mul
      3 variable base

     public inputs:
        s := (sum_{i=1}^3 r^i v_i), digest_at_that_point

        in the other snark do:
          let evals = exists()
          sponge = sponge(digest_at_that_point);
          sponge.absorb(evals);
          let xi = squeeze();
          let r = squeeze();
          let v_j = sum_i xi^i evals.beta_j[i] 
          assert (s == sum_{j=1}^3 sum_i xi^i evals.beta_j[i])
  *)
(*
  module Requests = struct
    open Snarky.Request

    module Prev = struct
      type _ t +=
        | Pairing_marlin_accumulator : G1.Constant.t Accumulator.t t
        | Pairing_marlin_proof :
            ( PC.Constant.t
            , Fp.Unpacked.constant
            , ( Opening_proof.Constant.t
              , Fp.Unpacked.constant )
              Pairing_marlin_types.Openings.t )
            Proof.t
            t
        | Sponge_digest : Fp.Unpacked.constant t
    end

    type _ t +=
      | Fp_mul : bool list * bool list -> bool list t
      | Mul_scalars : bool list * bool list -> bool list t
  end *)
(*
  let accumulate_and_defer
      ~(defer : [`Mul of Fp.Unpacked.t * Fp.Unpacked.t] -> Boolean.var list)
      r_i f_i z_i ({values; proof} : _ Opening.t) acc
    =
    let zr_i = defer (`Mul (z_i, r_i)) in
    let acc = accumuluate_pairing_state r_i zr_i proof f_i acc in
    (acc, {Accumulator.Input.zr= zr_i; z= z_i; v= values})

*)
