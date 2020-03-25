module D = Digest

module type Inputs = Intf.Dlog_main_inputs.S

open Core_kernel
open Import
open Util
open Pickles_types
open Dlog_marlin_types
module Accumulator = Pairing_marlin_types.Accumulator
open Tuple_lib

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

let b_poly ~add ~mul ~inv chals =
  let chal_invs = Array.map chals ~f:inv in
  fun x -> sg_polynomial ~add ~mul chals chal_invs x

let accumulate_degree_bound_checks ~update_unshifted ~add ~scale ~r_h ~r_k
    { Accumulator.Degree_bound_checks.shifted_accumulator
    ; unshifted_accumulators } (g1, g1_s) (g2, g2_s) (g3, g3_s) =
  let ( + ) = add in
  let ( * ) = Fn.flip scale in
  let shifted_accumulator =
    shifted_accumulator + (r_h * (g1 + (r_h * g2))) + (r_k * g3)
  in
  let h_update = r_h * (g1_s + (r_h * g2_s)) in
  let k_update = r_k * g3_s in
  let unshifted_accumulators =
    update_unshifted unshifted_accumulators (h_update, k_update)
    (*
    Map.update unshifted_accumulators (Domain.size domain_h)
      ~f:(fun x -> h_update + Option.value_exn x)
    |> Fn.flip Map.update (Domain.size domain_k)
        ~f:(fun x -> k_update + Option.value_exn x) *)
  in
  {Accumulator.Degree_bound_checks.shifted_accumulator; unshifted_accumulators}

let accumulate_degree_bound_checks' ~domain_h ~domain_k ~add =
  accumulate_degree_bound_checks ~add
    ~update_unshifted:(fun unsh (h_update, k_update) ->
      Map.update unsh
        (Domain.size domain_h - 1)
        ~f:(fun x -> add h_update (Option.value_exn x))
      |> Fn.flip Map.update
           (Domain.size domain_k - 1)
           ~f:(fun x -> add k_update (Option.value_exn x)) )

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

module Make (Inputs : Inputs) = struct
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
    if debug then
      as_prover
        As_prover.(
          fun () ->
            Core.printf "in-snark: %s (%s, %s)\n%!" lab
              (Field.Constant.to_string (read_var x))
              (Field.Constant.to_string (read_var y)))

  let print_chal lab x =
    if debug then
      as_prover
        As_prover.(
          fun () ->
            Core.printf "in-snark %s: %s\n%!" lab
              (Field.Constant.to_string
                 (Field.Constant.project (List.map ~f:(read Boolean.typ) x))))

  let print_bool lab x =
    if debug then
      as_prover (fun () ->
          printf "%s: %b\n%!" lab (As_prover.read Boolean.typ x) )

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

  module One_hot_vector = One_hot_vector.Make (Impl)

  type 'a index = 'a Abc.t Matrix_evals.t

  let seal x =
    match Field.to_constant x with
    | Some x ->
        Field.constant x
    | None ->
        let y = exists Field.typ ~compute:As_prover.(fun () -> read_var x) in
        Field.Assert.equal x y ; y

  let rec choose_key : type n.
      n Nat.s One_hot_vector.t -> (G1.t index, n Nat.s) Vector.t -> G1.t index
      =
    let open Tuple_lib in
    let map ~f = Matrix_evals.map ~f:(Abc.map ~f:(Double.map ~f)) in
    let map2 ~f =
      Matrix_evals.map2
        ~f:(Abc.map2 ~f:(fun (x1, y1) (x2, y2) -> (f x1 x2, f y1 y2)))
    in
    fun bs keys ->
      Vector.reduce
        (Vector.map2 bs keys ~f:(fun b -> map ~f:Field.(( * ) (b :> t))))
        ~f:(map2 ~f:Field.( + ))
      |> map ~f:seal

  let choose_key (type n) (i : n One_hot_vector.t) (vec : (_, n) Vector.t) =
    match vec with
    | [] ->
        failwith "choose_key: empty list"
    | _ :: _ ->
        choose_key i vec

  let input_domain = Set_once.create ()

  let print_pairing_acc domain_sizes lab t =
    let open Pickles_types.Pairing_marlin_types in
    if debug then
      as_prover
        As_prover.(
          fun () ->
            printf
              !"%s: %{sexp:((Field.Constant.t * Field.Constant.t), \
                (Field.Constant.t * Field.Constant.t) Int.Map.t) \
                Accumulator.t}\n\
                %!"
              lab
              (read
                 (Accumulator.typ domain_sizes
                    (Typ.transport G1.typ ~there:G1.Constant.of_affine
                       ~back:G1.Constant.to_affine_exn))
                 t))

  let lagrange_precomputations =
    let input_domain = ref None in
    let t =
      lazy
        (Array.map
           (Input_domain.lagrange_commitments (Option.value_exn !input_domain))
           ~f:(fun x -> lazy (G1.Scaling_precomputation.create x)))
    in
    fun ~input_size ->
      ( match !input_domain with
      | None ->
          let d = Domain.Pow_2_roots_of_unity (Int.ceil_log2 input_size) in
          input_domain := Some d
      | Some d ->
          [%test_eq: int] (Domain.size d) (Int.ceil_pow2 input_size) ) ;
      fun i -> Lazy.force (Lazy.force t).(i)

  let mask_gs bs gs =
    let open Field in
    List.map2_exn bs gs ~f:(fun (b : Boolean.var) (x, y) ->
        let b = (b :> t) in
        (b * x, b * y) )
    |> List.reduce_exn ~f:(fun (x1, y1) (x2, y2) -> (x1 + x2, y1 + y2))

  let incrementally_verify_pairings ~step_domains:(step_h, step_k)
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
    Set_once.set_if_none input_domain Stdlib.Lexing.dummy_pos
      (Domain.Pow_2_roots_of_unity (Int.ceil_log2 (Array.length public_input))) ;
    let x_hat =
      let input_size = Array.length public_input in
      G1.multiscale_known
        (Array.mapi public_input ~f:(fun i x ->
             (x, lagrange_precomputations ~input_size i) ))
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
    let digest_before_evaluations =
      Sponge.squeeze sponge ~length:Digest.length
    in
    let open Vector in
    let combine_commitments t =
      Pcs_batch.combine_commitments ~scale:G1.scale ~add:G1.( + ) ~xi t
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
      List.iteri [f_1; f_2; f_3] ~f:(ksprintf print_g1 "f_%d") ;
      { Accumulator.degree_bound_checks=
          accumulate_degree_bound_checks
            ~update_unshifted:(fun m (uh, uk) ->
              let m =
                Map.to_sequence ~order:`Increasing_key m |> Sequence.to_list
              in
              let keys = List.map m ~f:fst in
              (* TODO: Potential off by one. *)
              let add domain delta elts =
                let flags =
                  let domain_size = domain#size in
                  List.map keys ~f:(fun shift ->
                      Field.(equal (domain_size - one) (of_int shift)) )
                in
                let elt_plus_delta = G1.( + ) (mask_gs flags elts) delta in
                List.map2_exn flags elts ~f:(fun b g ->
                    G1.if_ b ~then_:elt_plus_delta ~else_:g )
              in
              add step_h uh (List.map m ~f:snd)
              |> add step_k uk |> List.zip_exn keys |> Int.Map.of_alist_exn )
            degree_bound_checks ~r_h:r ~r_k g_1 g_2 g_3
      ; opening_check=
          accumulate_opening_check opening_check ~r ~r_xi_sum
            (f_1, beta_1, pi_1) (f_2, beta_2, pi_2) (f_3, beta_3, pi_3) }
    in
    (*     print_pairing_acc "post acculmulattion" pairing_acc ; *)
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

  let combined_evaluation (type b b_plus_19) b_plus_19 ~shifted_pow ~xi
      ~evaluation_point
      ((without_degree_bound : (_, b_plus_19) Vector.t), with_degree_bound)
      ~h_minus_1 ~k_minus_1 =
    Pcs_batch.combine_evaluations'
      (Common.dlog_pcs_batch b_plus_19 ~h_minus_1 ~k_minus_1)
      ~shifted_pow ~mul:Fq.mul ~add:Fq.add ~one:Fq.one ~evaluation_point ~xi
      without_degree_bound with_degree_bound

  let sum' xs f = List.reduce_exn (List.map xs ~f) ~f:Fq.( + )

  let prod xs f = List.reduce_exn (List.map xs ~f) ~f:Fq.( * )

  let compute_challenges chals =
    (* TODO: Put this in the functor argument. *)
    let nonresidue = Fq.of_int 7 in
    Vector.map chals ~f:(fun {Bulletproof_challenge.prechallenge; is_square} ->
        let sq =
          Fq.if_ is_square ~then_:prechallenge
            ~else_:Fq.(nonresidue * prechallenge)
        in
        Fq.sqrt sq )

  module Marlin_checks = Marlin_checks.Make (Impl)

  let b_poly = Fq.(b_poly ~add ~mul ~inv)

  let ones_vector : type n.
      first_zero:Field.t -> n Nat.t -> (Boolean.var, n) Vector.t =
   fun ~first_zero n ->
    let rec go : type m.
        Boolean.var -> int -> m Nat.t -> (Boolean.var, m) Vector.t =
     fun value i m ->
      match m with
      | Z ->
          []
      | S m ->
          let value =
            Boolean.(
              value && Boolean.not (Field.equal first_zero (Field.of_int i)))
          in
          value :: go value (i + 1) m
    in
    go Boolean.true_ 0 n

  let finalize_other_proof (type b)
      (module Branching : Nat.Add.Intf with type n = b) ?actual_branching
      ~shifted_pow ~domain_h ~domain_k ~input_domain ~h_minus_1 ~k_minus_1
      ~sponge ~(old_bulletproof_challenges : (_, b) Vector.t)
      ({xi; r; combined_inner_product; bulletproof_challenges; b; marlin} :
        _ Types.Pairing_based.Proof_state.Deferred_values.t)
      ((beta_1_evals, x_hat1), (beta_2_evals, x_hat2), (beta_3_evals, x_hat3))
      =
    let T = Branching.eq in
    let open Vector in
    (* You use the NEW bulletproof challenges to check b. Not the old ones. *)
    (* As a proof size optimization, we can probably rig each polynomial
       to vanish on the previous challenges.
    
       Like instead of the deg n polynomial f(x), the degree (n + 1) polynomial with 
       f_tilde(h) = f(h), for each h in h 
       f_tilde(beta_1) = 0
    *)
    let open Fq in
    let absorb_evals x_hat e =
      let xs, ys = Evals.to_vectors e in
      List.iter
        Vector.(x_hat :: (to_list xs @ to_list ys))
        ~f:(Sponge.absorb sponge)
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
        let sg_olds =
          Vector.map old_bulletproof_challenges ~f:(fun chals ->
              b_poly (Vector.to_array chals) )
        in
        let combine pt x_hat e =
          let pi = Branching.add Nat.N19.n in
          let a, b = Evals.to_vectors e in
          let sg_evals =
            match actual_branching with
            | None ->
                Vector.map sg_olds ~f:(fun f -> f pt)
            | Some branching ->
                let mask =
                  ones_vector ~first_zero:branching (Vector.length sg_olds)
                in
                Vector.map2 mask sg_olds ~f:(fun b f -> (b :> Field.t) * f pt)
          in
          let v = Vector.append sg_evals (x_hat :: a) (snd pi) in
          combined_evaluation pi ~shifted_pow ~xi ~evaluation_point:pt (v, b)
            ~h_minus_1 ~k_minus_1
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
      let b_poly = b_poly (Vector.to_array bulletproof_challenges) in
      let b_actual =
        b_poly marlin.beta_1
        + (r * (b_poly marlin.beta_2 + (r * b_poly marlin.beta_3)))
      in
      equal b b_actual
    in
    let marlin_checks_passed =
      Marlin_checks.check ~input_domain ~domain_h ~domain_k
        ~x_hat_beta_1:x_hat1 marlin
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
        ; value= beta_3_evals.value
        ; rc= beta_3_evals.rc }
    in
    print_bool "xi_and_r_correct" xi_and_r_correct ;
    print_bool "combined_inner_product_correct" combined_inner_product_correct ;
    print_bool "marlin_checks_passed" marlin_checks_passed ;
    print_bool "b_correct" b_correct ;
    ( Boolean.all
        [ xi_and_r_correct
        ; b_correct
        ; combined_inner_product_correct
        ; marlin_checks_passed ]
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
        Vector.map bulletproof_challenges
          ~f:(fun (r : _ Bulletproof_challenge.t) ->
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
          ~f:(fun {Bulletproof_challenge.prechallenge; is_square} ->
            is_square :: prechallenge ) ]

  let hash_me_only t =
    let sponge = Sponge.create sponge_params in
    Array.iter ~f:(Sponge.absorb sponge)
      (Types.Dlog_based.Proof_state.Me_only.to_field_elements
         ~g1:G1.to_field_elements t) ;
    Sponge.squeeze sponge ~length:Digest.length

  let combine_pairing_accs : type n. (_, n) Vector.t -> _ = function
    | [] ->
        failwith "combine_pairing_accs: empty list"
    | [acc] ->
        acc
    | a :: accs ->
        let open Pairing_marlin_types.Accumulator in
        let (module Shifted) = G1.shifted () in
        Vector.fold accs
          ~init:(map a ~f:(fun x -> Shifted.(add zero x)))
          ~f:(fun acc t -> map2 acc t ~f:Shifted.add)
        |> map ~f:Shifted.unshift_nonzero

  module Branching = Nat.S (Branching_pred)

  type 'a vec = ('a, Branching.n) Vector.t

  module Requests = struct
    open Snarky.Request

    type 'a bp_vec = ('a, Bulletproof_rounds.n) Vector.t

    type _ t +=
      | Prev_evals :
          (Field.Constant.t Dlog_marlin_types.Evals.t * Field.Constant.t)
          Tuple_lib.Triple.t
          vec
          t
      | Prev_messages :
          (PC.Constant.t, Fp.Packed.Constant.t) Pairing_marlin_types.Messages.t
          t
      | Prev_openings_proof : G1.Constant.t Tuple_lib.Triple.t t
      | Prev_proof_state :
          ( ( ( Challenge.Constant.t
              , Fq.Constant.t
              , (Challenge.Constant.t, bool) Bulletproof_challenge.t bp_vec
              , Digest.Constant.t )
              Types.Pairing_based.Proof_state.Per_proof.t
            * bool )
            vec
          , Digest.Constant.t )
          Types.Pairing_based.Proof_state.t
          t
      | Prev_me_onlys :
          ( ( G1.Constant.t
            , G1.Constant.t
              Pairing_marlin_types.Accumulator.Degree_bound_checks
              .Unshifted_accumulators
              .t )
            Pairing_marlin_types.Accumulator.t
          * Field.Constant.t bp_vec vec )
          vec
          t
      | Pairing_marlin_index : One_hot_vector.Constant.t t

    (*       | Pairing_marlin_index : G1.Constant.t Abc.t Matrix_evals.t t *)
  end

  let assert_eq_marlin
      (m1: (Field.t, Field.t)  Types.Dlog_based.Proof_state.Deferred_values.Marlin.t)
      (m2: (Boolean.var list, Field.t)  Types.Dlog_based.Proof_state.Deferred_values.Marlin.t)
    =
    let open Types.Dlog_based.Proof_state.Deferred_values.Marlin in
    let fp x1 x2 =
      Field.(Assert.equal x1 x2)
    in
    let chal c1 c2 = Field.Assert.equal c1 (Field.project c2) in
    chal m1.alpha m2.alpha ;
    chal m1.eta_a m2.eta_a ;
    chal m1.eta_b m2.eta_b ;
    chal m1.eta_c m2.eta_c ;
    chal m1.beta_1 m2.beta_1 ;
    fp m1.sigma_2 m2.sigma_2 ;
    chal m1.beta_2 m2.beta_2 ;
    fp m1.sigma_3 m2.sigma_3 ;
    chal m1.beta_3 m2.beta_3
  ;;

  let main ~pairing_marlin_indices ~wrap_domains:(domain_h, domain_k)
      ~step_domains
      ({ proof_state=
           { deferred_values= {marlin; xi; r; r_xi_sum}
           ; sponge_digest_before_evaluations
           ; me_only= me_only_digest
           ; was_base_case }
       ; pass_through } :
        (Field.t, Field.t, _, _, _, _, _) Types.Dlog_based.Statement.t) =
    (* TODO: prev_proof_state has a fixed size so it should be possible to 
       just make this one of the public inputs.

       prev_me_onlys also has a fixed size (and in fact it is not even necessary to hash it)
    *)
    let prev_proof_state =
      let open Types.Pairing_based.Proof_state in
      let typ = typ (module Impl) Branching.n Bulletproof_rounds.n Fq.typ in
      exists typ ~request:(fun () -> Requests.Prev_proof_state)
    in
    let which_index =
      exists
        (One_hot_vector.typ (Vector.length pairing_marlin_indices))
        ~request:(fun () -> Requests.Pairing_marlin_index)
    in
    let pairing_marlin_index =
      choose_key which_index
        (Vector.map pairing_marlin_indices
           ~f:(Matrix_evals.map ~f:(Abc.map ~f:G1.constant)))
    in
    let prev_me_onlys =
      let h, k = step_domains in
      exists
        (Vector.typ
           (Typ.tuple2
              (Pairing_marlin_types.Accumulator.typ
                 (Int.Set.of_list [Domain.size h - 1; Domain.size k - 1])
                 G1.typ)
              (Vector.typ (Vector.typ Fq.typ Bulletproof_rounds.n) Branching.n))
           Branching.n)
        ~request:(fun () -> Requests.Prev_me_onlys)
    in
    let prev_pairing_accs, prev_old_bulletproof_challenges =
      Vector.unzip prev_me_onlys
    in
    let prev_pairing_acc = combine_pairing_accs prev_pairing_accs in
    (* print_pairing_acc "combined acc" prev_pairing_acc ; *)
    let new_bulletproof_challenges =
      let evals =
        let ty =
          let ty = Typ.tuple2 (Evals.typ Fq.typ) Fq.typ in
          Typ.tuple3 ty ty ty
        in
        exists (Vector.typ ty Branching.n) ~request:(fun () ->
            Requests.Prev_evals )
      in
      let chals =
        Vector.mapn
          [ prev_proof_state.unfinalized_proofs
          ; prev_old_bulletproof_challenges
          ; evals ]
          ~f:(fun [ ( {deferred_values; sponge_digest_before_evaluations}
                    , should_verify )
                  ; old_bulletproof_challenges
                  ; evals ]
             ->
            let sponge =
              let s = Sponge.create sponge_params in
              Sponge.absorb s (Fq.pack sponge_digest_before_evaluations) ;
              s
            in
            let verified, chals =
              finalize_other_proof
                ~input_domain:(Marlin_checks.domain Input_domain.self)
                (module Branching)
                ~shifted_pow:(fun deg x ->
                  Fq.(Pcs_batch.pow ~one ~mul ~add) x (crs_max_degree - deg) )
                ~domain_h:(Marlin_checks.domain domain_h)
                ~domain_k:(Marlin_checks.domain domain_k)
                ~h_minus_1:(Domain.size domain_h - 1)
                ~k_minus_1:(Domain.size domain_k - 1)
                ~sponge
                (map_challenges deferred_values ~f:Fq.pack)
                ~old_bulletproof_challenges evals
            in
            Boolean.(Assert.any [not should_verify; verified]) ;
            chals )
      in
      chals
    in
    Boolean.(
      Assert.( = ) was_base_case
        (all
           Vector.(
             to_list
               (map prev_proof_state.unfinalized_proofs
                  ~f:(fun (_, should_verify) -> not should_verify))))) ;
    (* What do we actually need from prev_statement? 

       1. The evaluations (or a commitment to the evaluations) used.
       This is provided by digest_before_evaluations

       2. The unfinalized challenge values
    *)
    let prev_statement =
      (* TODO: A lot of repeated hashing happening here on the dlog_marlin_index *)
      let prev_me_onlys =
        Vector.map prev_me_onlys ~f:(fun (pacc, chals) ->
            hash_me_only
              {pairing_marlin_acc= pacc; old_bulletproof_challenges= chals} )
      in
      { Types.Pairing_based.Statement.pass_through= prev_me_onlys
      ; proof_state= prev_proof_state }
    in
    (* 
    print_bool "prev_proof_finalized" prev_proofs_finalized ;
    print_bool "prev_statement.proof_state.was_base_case"
      prev_statement.proof_state.was_base_case ;
    Boolean.Assert.any
      [prev_proofs_finalized; prev_statement.proof_state.was_base_case] ;
      *)
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
      let pack =
        let pack_fq (x : Fq.t) =
          let low_bits, high_bit =
            Common.split_last
              (Bitstring_lib.Bitstring.Lsb_first.to_list (Fq.unpack_full x))
          in
          [|low_bits; [high_bit]|]
        in
        fun t ->
          Spec.pack
            (module Impl)
            pack_fq
            (Types.Pairing_based.Statement.spec Branching.n
               Bulletproof_rounds.n)
            (Types.Pairing_based.Statement.to_data t)
      in
      let xi = Field.unpack xi ~length:Challenge.length in
      let r = Field.unpack r ~length:Challenge.length in
      let r_xi_sum =
        Field.choose_preimage_var r_xi_sum ~length:Field.size_in_bits
      in
      incrementally_verify_pairings
        ~step_domains:(Double.map step_domains ~f:Marlin_checks.domain)
        ~pairing_acc:prev_pairing_acc ~xi ~r ~r_xi_sum
        ~verification_key:pairing_marlin_index ~sponge
        ~public_input:(Array.append [|[Boolean.true_]|] (pack prev_statement))
        ~messages ~opening_proofs
    in
    Field.Assert.equal me_only_digest
      (Field.pack
         (hash_me_only
            { Types.Dlog_based.Proof_state.Me_only.pairing_marlin_acc
            ; old_bulletproof_challenges= new_bulletproof_challenges })) ;
    Field.Assert.equal sponge_digest_before_evaluations
      (Field.pack sponge_digest_before_evaluations_actual)
end
