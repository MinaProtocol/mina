(* TODO:
   Start writing pairing_main so I can get a sense of how the x_hat
   commitment and challenge is going to work. *)
open Core_kernel
module B = Bigint
module H_list = Snarky.H_list

module Evals = struct
  open Vector

  module Make (N : Nat_intf) = struct
    include N

    type 'a t = ('a, n) Vector.t

    include Binable (N)

    let typ elt = Vector.typ elt n
  end

  module Beta1 = Make (struct
    type n = z s s s s s s

    let n = S (S (S (S (S (S Z)))))

    let () = assert (6 = nat_to_int n)
  end)

  module Beta2 = Make (struct
    type n = z s s

    let n = S (S Z)

    let () = assert (2 = nat_to_int n)
  end)

  module Beta3 = Make (struct
    type n = z s s s s s s s s s s s

    let n = S (S (S (S (S (S (S (S (S (S (S Z))))))))))

    let () = assert (11 = nat_to_int n)
  end)
end

type 'a abc = {a: 'a; b: 'a; c: 'a}

type 'a matrix_evals = {row: 'a; col: 'a; value: 'a}

module Pairing_marlin_accumulator = struct
  type 'g t = {r_f: 'g; r_pi: 'g; zr_pi: 'g} [@@deriving fields]

  open Snarky
  open H_list

  let to_hlist {r_f; r_pi; zr_pi} = [r_f; r_pi; zr_pi]

  let of_hlist ([r_f; r_pi; zr_pi] : (unit, _) H_list.t) = {r_f; r_pi; zr_pi}

  let typ g =
    Typ.of_hlistable [g; g; g] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let assert_equal g t1 t2 =
    List.iter ~f:(fun x -> g (x t1) (x t2)) [r_f; r_pi; zr_pi]
end

module Dlog_marlin_statement = struct
  open H_list

  (* About 10000 bits altogether *)
  module Deferred_values = struct
    module Kate_acc_input = struct
      type ('fp, 'values) t =
        { zr: 'fp
        ; z: 'fp (* Evaluation point *)
                 (* 128 bits *)
        ; v: 'values (* Evaluation values *) }

      let to_hlist {zr; z; v} = [zr; z; v]

      let of_hlist ([zr; z; v] : (unit, _) H_list.t) = {zr; z; v}

      let typ fp values =
        Snarky.Typ.of_hlistable [fp; fp; values] ~var_to_hlist:to_hlist
          ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist

      let assert_equal fp t1 t2 =
        let mk t : _ list = t.zr :: t.z :: Vector.to_list t.v in
        List.iter2_exn ~f:fp (mk t1) (mk t2)
    end

    type 'fp t =
      { xi: 'fp (* 128 bits *)
      ; beta_1: ('fp, 'fp Evals.Beta1.t) Kate_acc_input.t
      ; beta_2: ('fp, 'fp Evals.Beta2.t) Kate_acc_input.t
      ; beta_3: ('fp, 'fp Evals.Beta3.t) Kate_acc_input.t
      ; sigma_2: 'fp
      ; sigma_3: 'fp
      ; alpha: 'fp (* 128 bits *)
      ; eta_A: 'fp (* 128 bits *)
      ; eta_B: 'fp (* 128 bits *)
      ; eta_C: 'fp (* 128 bits *) }
    [@@deriving fields]

    let assert_equal fp t1 t2 =
      let acc x = Kate_acc_input.assert_equal fp x in
      let check c p = c (p t1) (p t2) in
      check acc beta_1 ;
      check acc beta_2 ;
      check acc beta_3 ;
      List.iter ~f:(check fp) [xi; sigma_2; sigma_3; alpha; eta_A; eta_B; eta_C]

    let to_hlist
        { xi
        ; beta_1
        ; beta_2
        ; beta_3
        ; sigma_2
        ; sigma_3
        ; alpha
        ; eta_A
        ; eta_B
        ; eta_C } =
      [xi; beta_1; beta_2; beta_3; sigma_2; sigma_3; alpha; eta_A; eta_B; eta_C]

    let of_hlist
        ([ xi
         ; beta_1
         ; beta_2
         ; beta_3
         ; sigma_2
         ; sigma_3
         ; alpha
         ; eta_A
         ; eta_B
         ; eta_C ] :
          (unit, _) H_list.t) =
      {xi; beta_1; beta_2; beta_3; sigma_2; sigma_3; alpha; eta_A; eta_B; eta_C}

    let typ fp =
      let acc v = Kate_acc_input.typ fp (v fp) in
      let open Evals in
      Snarky.Typ.of_hlistable
        [ fp
        ; acc Beta1.typ
        ; acc Beta2.typ
        ; acc Beta3.typ
        ; fp
        ; fp
        ; fp
        ; fp
        ; fp
        ; fp ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  type ('fp, 'fq, 'g1, 'kpc, 'bppc, 'digest, 's) t =
    { deferred_values: 'fp Deferred_values.t
    ; pairing_marlin_index: 'kpc abc matrix_evals
    ; sponge_digest: 'digest
    ; bp_challenges_old: 'fq array (* Bullet proof challenges *)
    ; b_challenge_old: 'fq
    ; b_u_x_old: 'fq
    ; pairing_marlin_acc: 'g1 Pairing_marlin_accumulator.t
          (* Purportedly b_{bp_challenges_old}(b_challenge_old) *)
          (* All this could be a hash which we unhash *)
    ; app_state: 's
    ; g_old: 'fp * 'fp
    ; dlog_marlin_index: 'bppc abc matrix_evals }
end

module Pairing_marlin_proof = struct
  module Precomputation = struct
    type ('pc, 'fp) t =
      { y0: 'fp
      ; a0: 'fp
      ; g0: 'pc
      ; x'_hat: 'pc (* This is the commitment to the LDE of the "real input" *)
      }
    [@@deriving fields, bin_io]

    open H_list

    let to_hlist {y0; a0; g0; x'_hat} = [y0; a0; g0; x'_hat]

    let of_hlist ([y0; a0; g0; x'_hat] : (unit, _) H_list.t) =
      {y0; a0; g0; x'_hat}

    let typ pc fp =
      Snarky.Typ.of_hlistable [fp; fp; pc; pc] ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  module Wire = struct
    module Opening = struct
      type ('proof, 'values) t = {proof: 'proof; values: 'values}
      [@@deriving fields, bin_io]

      open H_list

      let to_hlist {proof; values} = [proof; values]

      let of_hlist ([proof; values] : (unit, _) H_list.t) = {proof; values}

      let typ proof values =
        Snarky.Typ.of_hlistable [proof; values] ~var_to_hlist:to_hlist
          ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist
    end

    module Messages = struct
      type ('pc, 'fp) t =
        { w_hat: 'pc
        ; s: 'pc
        ; z_hat_A: 'pc
        ; z_hat_B: 'pc
        ; gh_1: 'pc * 'pc
        ; sigma_gh_2: 'fp * ('pc * 'pc)
        ; sigma_gh_3: 'fp * ('pc * 'pc) }
      [@@deriving fields, bin_io]

      open H_list

      let to_hlist {w_hat; s; z_hat_A; z_hat_B; gh_1; sigma_gh_2; sigma_gh_3} =
        [w_hat; s; z_hat_A; z_hat_B; gh_1; sigma_gh_2; sigma_gh_3]

      let of_hlist
          ([w_hat; s; z_hat_A; z_hat_B; gh_1; sigma_gh_2; sigma_gh_3] :
            (unit, _) H_list.t) =
        {w_hat; s; z_hat_A; z_hat_B; gh_1; sigma_gh_2; sigma_gh_3}

      let typ pc fp =
        let open Snarky.Typ in
        of_hlistable
          [pc; pc; pc; pc; pc * pc; fp * (pc * pc); fp * (pc * pc)]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
          ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
    end

    module Openings = struct
      open Evals

      type ('proof, 'fp) t =
        { beta_1: ('proof, 'fp Beta1.t) Opening.t
        ; beta_2: ('proof, 'fp Beta2.t) Opening.t
        ; beta_3: ('proof, 'fp Beta3.t) Opening.t }
      [@@deriving fields, bin_io]

      open H_list

      let to_hlist {beta_1; beta_2; beta_3} = [beta_1; beta_2; beta_3]

      let of_hlist ([beta_1; beta_2; beta_3] : (unit, _) H_list.t) =
        {beta_1; beta_2; beta_3}

      let typ proof fp =
        let op vals = Opening.typ proof (vals fp) in
        let open Snarky.Typ in
        of_hlistable
          [op Beta1.typ; op Beta2.typ; op Beta3.typ]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
          ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
    end

    type ('proof, 'pc, 'fp) t =
      {messages: ('pc, 'fp) Messages.t; openings: ('proof, 'fp) Openings.t}
    [@@deriving fields, bin_io]

    open H_list

    let to_hlist {messages; openings} = [messages; openings]

    let of_hlist ([messages; openings] : (unit, _) H_list.t) =
      {messages; openings}

    let typ proof pc fp =
      Snarky.Typ.of_hlistable
        [Messages.typ pc fp; Openings.typ proof fp]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end
end

module Intf = struct
  module Group (Impl : Snarky.Snark_intf.Run) = struct
    open Impl

    module type S = sig
      type t

      module Constant : sig
        type t
      end

      val typ : (t, Constant.t) Typ.t

      val ( + ) : t -> t -> t

      val scale : t -> Boolean.var list -> t

      val negate : t -> t

      val to_field_elements : t -> Field.t list
    end
  end

  module Sponge (Impl : Snarky.Snark_intf.Run) = struct
    open Impl

    module type S =
      Sponge.Intf.Sponge
      with module Field := Field
       and module State := Sponge.State
       and type input := Field.t
       and type digest := length:int -> Boolean.var list

    (*
      type t

      val create : unit -> t

      val absorb_field : t -> Field.t -> unit

      val absorb_bits : t -> Boolean.var list -> unit

      val squeeze_field : t -> Field.t

      val squeeze_bits : t -> length:int -> Boolean.var list
    end
*)
  end

  module Precomputation (G : sig
    type t
  end) =
  struct
    module type S = sig
      type t

      val create : G.t -> t
    end
  end
end

(*

  module G2 : Intf.Group(Impl).S

  module GT : Intf.Group(Impl).S

  module G1_precomputation : Intf.Precomputation(G1).S
  module G2_precomputation : Intf.Precomputation(G2).S

  module Sponge : Intf.Sponge(Impl).S

  val batch_miller_loop :
       (Sgn_type.Sgn.t * G1_precomputation.t * G2_precomputation.t) list
    -> GT.t *)

module type Dlog_main_inputs_intf = sig
  module Impl : Snarky.Snark_intf.Run with type prover_state = unit

  module Fp_params : sig
    val p : Bigint.t

    val size_in_bits : int
  end

  module G1 : Intf.Group(Impl).S

  val sponge_params : Impl.Field.t Sponge.Params.t

  module Sponge : Intf.Sponge(Impl).S
end

module type Pairing_main_inputs_intf = sig
  module Impl : Snarky.Snark_intf.Run with type prover_state = unit

  module Fq_params : sig
    val q : Bigint.t

    val size_in_bits : int
  end

  module G : Intf.Group(Impl).S

  val sponge_params : Impl.Field.t Sponge.Params.t

  module Sponge : Intf.Sponge(Impl).S
end

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
end

module Dlog_main (Inputs : Dlog_main_inputs_intf) = struct
  open Inputs
  open Impl

  type fq = Field.t

  let n = 1 lsl 15

  let k = Int.ceil_log2 n

  let product m f = List.reduce_exn (List.init m ~f) ~f:Field.( * )

  let b (u : fq array) (x : fq) : fq =
    let x_to_pow2s =
      let res = Array.create ~len:k x in
      for i = 1 to k - 1 do
        res.(i) <- Field.square res.(i - 1)
      done ;
      res
    in
    let open Field in
    product k (fun i -> u.(i) + (inv u.(i) * x_to_pow2s.(i)))

  module PC = G1

  module Fp = struct
    (* For us, q > p, so one Field.t = fq can represent an fp *)
    module Packed = Field

    module Unpacked = struct
      type t = Boolean.var list

      type constant = bool list

      let typ : (t, constant) Typ.t =
        let typ = Typ.list ~length:Fp_params.size_in_bits Boolean.typ in
        let p_msb =
          let test_bit x i = B.(shift_right x i land one = one) in
          List.init Fp_params.size_in_bits ~f:(test_bit Fp_params.p)
          |> List.rev
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

      let assert_equal t1 t2 = Field.(Assert.equal (pack t1) (pack t2))
    end

    let pack : Unpacked.t -> Packed.t = Packed.pack
  end

  module Type = struct
    type _ t =
      | PC : G1.t t
      | Fp : Fp.Unpacked.t t
      | ( :: ) : 'a t * 'b t -> ('a * 'b) t
  end

  let rec absorb : type a. Sponge.t -> a Type.t -> a -> unit =
   fun sponge ty t ->
    let absorb_field = Sponge.absorb sponge in
    match ty with
    | PC ->
        List.iter ~f:absorb_field (G1.to_field_elements t)
    | Fp ->
        absorb_field (Fp.Packed.project t)
    | ty1 :: ty2 ->
        let t1, t2 = t in
        absorb sponge ty1 t1 ; absorb sponge ty2 t2

  module Opening_proof = G1

  module Opening = struct
    type 'n t =
      ( Opening_proof.t
      , (Fp.Unpacked.t, 'n) Vector.t )
      Pairing_marlin_proof.Wire.Opening.t
  end

  module Marlin_proof = struct
    type t = (Opening_proof.t, PC.t, Fp.Unpacked.t) Pairing_marlin_proof.Wire.t
  end

  let combined_commitment ~xi (polys : _ Vector.t) =
    let (p0 :: ps) = polys in
    List.fold_left (Vector.to_list ps) ~init:p0 ~f:(fun acc p ->
        G1.(p + scale acc xi) )

  let accumuluate_pairing_state r_i zr_i pi_i f_i
      {Pairing_marlin_accumulator.r_f; r_pi; zr_pi} :
      _ Pairing_marlin_accumulator.t =
    let open G1 in
    let ( * ) s p = scale p s in
    { r_f= r_f + (r_i * f_i)
    ; r_pi= r_pi + (r_i * pi_i)
    ; zr_pi= zr_pi + (zr_i * pi_i) }

  let pack_fp = Field.project

  let accumulate_and_defer
      ~(defer : [`Mul of Fp.Unpacked.t * Fp.Unpacked.t] -> Boolean.var list)
      r_i f_i z_i ({values; proof} : _ Pairing_marlin_proof.Wire.Opening.t) acc
      =
    let zr_i = defer (`Mul (z_i, r_i)) in
    let acc = accumuluate_pairing_state r_i zr_i proof f_i acc in
    ( acc
    , { Dlog_marlin_statement.Deferred_values.Kate_acc_input.zr= zr_i
      ; z= z_i
      ; v= values } )

  type scalar = Boolean.var list

  module Requests = struct
    open Snarky.Request

    module Prev = struct
      type _ t +=
        | Pairing_marlin_accumulator :
            G1.Constant.t Pairing_marlin_accumulator.t t
        | Pairing_marlin_proof :
            ( Opening_proof.Constant.t
            , PC.Constant.t
            , Fp.Unpacked.constant )
            Pairing_marlin_proof.Wire.t
            t
        | Sponge_digest : Fp.Unpacked.constant t
    end

    type _ t +=
      | Fp_mul : bool list * bool list -> bool list t
      | Mul_scalars : bool list * bool list -> bool list t

    module Precomputation = struct
      type _ t +=
        | X'_hat : G1.Constant.t t
        | G0 : (field * field) t
        | Y0 : Fp.Unpacked.constant t
        | A0 : Fp.Unpacked.constant t
    end
  end

  module Challenge = struct
    let length = 256

    type t = Boolean.var list

    let typ = Typ.list ~length Boolean.typ
  end

  let incrementally_verify_pairings ~verification_key:m ~sponge ~public_input
      ~pairing_acc:pacc ~proof:({messages; openings= ops} : Marlin_proof.t) =
    let receive ty f =
      let x = f messages in
      absorb sponge ty x ; x
    in
    let sample () = Sponge.squeeze sponge ~length:Challenge.length in
    let open Pairing_marlin_proof.Wire.Messages in
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
    let sigma_2, (g_2, h_2) = receive (Fp :: PC :: PC) sigma_gh_2 in
    let beta_2 = sample () in
    let sigma_3, (g_3, h_3) = receive (Fp :: PC :: PC) sigma_gh_3 in
    let beta_3 = sample () in
    let x_hat_beta_3 =
      ()
      (*
      check_g0_on_a0_equals_y0;
      let x'_hat_beta3 = get_g0_eval_on_beta_3 and check =  correctness in
      let res =
        defer arithmetic of x'_hat_beta_3
                            + Lagrange_{input_size + 1} g0_x
                            + Lagrange_{input_size + 2} g0_y
                            + Lagrange_{input_size + 3} a0
                            + Lagrange_{input_size + 4} y0
      in
      res
      (* 
      *)
      () *)
    in
    (* We can use the same random scalar xi for all of these opening proofs. *)
    let xi = sample () in
    let open Vector in
    let combined_commitment (type n) (_ : n s Opening.t)
        (ps : (_, n s) Vector.t) =
      combined_commitment ~xi ps
    in
    let f_1 =
      combined_commitment ops.beta_1 [g_1; h_1; z_hat_A; z_hat_B; w_hat; s]
    in
    let f_2 = combined_commitment ops.beta_2 [g_2; h_2] in
    let f_3 =
      combined_commitment ops.beta_3
        [ g_3
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
    let r = sample () in
    let defer (`Mul (x, y)) =
      exists Fp.Unpacked.typ
        ~request:
          As_prover.(
            fun () ->
              Requests.Fp_mul (read Fp.Unpacked.typ x, read Fp.Unpacked.typ y))
    in
    let r2 =
      exists Fp.Unpacked.typ
        ~request:
          As_prover.(
            fun () ->
              let r = read Fp.Unpacked.typ r in
              Requests.Mul_scalars (r, r))
    in
    let r3 =
      exists Fp.Unpacked.typ
        ~request:
          As_prover.(
            fun () ->
              let r2 = read Fp.Unpacked.typ r2 in
              let r = read Fp.Unpacked.typ r in
              Requests.Mul_scalars (r, r2))
    in
    let accum x = accumulate_and_defer ~defer x in
    let pacc, beta_1 = accum r f_1 beta_1 ops.beta_1 pacc in
    let pacc, beta_2 = accum r2 f_2 beta_2 ops.beta_2 pacc in
    let pacc, beta_3 = accum r3 f_3 beta_3 ops.beta_3 pacc in
    ( pacc
    , { Dlog_marlin_statement.Deferred_values.xi
      ; beta_1
      ; beta_2
      ; beta_3
      ; sigma_2
      ; sigma_3
      ; alpha
      ; eta_A
      ; eta_B
      ; eta_C } )

  (* Inside here we have F_q arithmetic, so we can incrementally check
   the polynomial commitments from the pairing-based Marlin *)
  let dlog_main
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
      ; dlog_marlin_index } =
    let open Requests in
    let exists typ r = exists typ ~request:(fun () -> r) in
    let prev_deferred_fq_arithmetic =
      (* TODO *)
      []
    in
    List.iter prev_deferred_fq_arithmetic ~f:perform ;
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
          (Pairing_marlin_proof.Wire.typ Opening_proof.typ PC.typ
             Fp.Unpacked.typ)
          Prev.Pairing_marlin_proof
      and prev_pairing_marlin_acc =
        exists
          (Pairing_marlin_accumulator.typ G1.typ)
          Requests.Prev.Pairing_marlin_accumulator
      in
      incrementally_verify_pairings ~verification_key:pairing_marlin_index
        ~sponge ~proof:prev_marlin_proof ~pairing_acc:prev_pairing_marlin_acc
        ~public_input:[]
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
      Field.pack (Sponge.squeeze sponge ~length:128)
    in
    Field.Assert.equal sponge_digest actual_sponge_digest ;
    Pairing_marlin_accumulator.assert_equal
      (fun x y ->
        List.iter2_exn ~f:Field.Assert.equal (G1.to_field_elements x)
          (G1.to_field_elements y) )
      updated_pairing_marlin_acc pairing_marlin_acc ;
    Dlog_marlin_statement.Deferred_values.assert_equal Fp.Unpacked.assert_equal
      deferred_values deferred_fp_arithmetic
end
