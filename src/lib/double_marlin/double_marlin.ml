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

  type ('fp, 'fq, 'kpc, 'bppc, 'digest, 's) t =
    { deferred_values: 'fp Deferred_values.t
    ; pairing_marlin_index: 'kpc abc matrix_evals
    ; sponge_digest: 'digest
    ; bp_challenges_old: 'fq array (* Bullet proof challenges *)
    ; b_challenge_old: 'fq
    ; b_u_x_old: 'fq
          (* Purportedly b_{bp_challenges_old}(b_challenge_old) *)
          (* All this could be a hash which we unhash *)
    ; app_state: 's
    ; g_old: 'fp * 'fp
    ; dlog_marlin_index: 'bppc abc matrix_evals }
end

module Pairing_marlin_accumulator = struct
  type 'g t = {r_f: 'g; r_pi: 'g; zr_pi: 'g}

  open Snarky
  open H_list

  let to_hlist {r_f; r_pi; zr_pi} = [r_f; r_pi; zr_pi]

  let of_hlist ([r_f; r_pi; zr_pi] : (unit, _) H_list.t) = {r_f; r_pi; zr_pi}

  let typ g =
    Typ.of_hlistable [g; g; g] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
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

  module Sponge : Intf.Sponge(Impl).S
end

module type Pairing_main_inputs_intf = sig
  module Impl : Snarky.Snark_intf.Run with type prover_state = unit

  module Fq_params : sig
    val q : Bigint.t

    val size_in_bits : int
  end

  module G1 : Intf.Group(Impl).S

  module Sponge : Intf.Sponge(Impl).S
end

module Pairing_main (Inputs : Pairing_main_inputs_intf) = struct
  open Inputs
  open Impl
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

  (* Approach 1:
     compute lagrange polynomial commitment directly
     that is, hardcode lagrange polynomials and do O(num inputs) scalar muls
     and get an opening proof at beta_3. the additional opening proof costs
     1 additional scalar mul and adds one deferred fp value.

     Approach 2:
     Get a commitment to the lagrange interpolated polynomial,
     add a public inputs to the pairing marlin R1CS
     - alpha = Hash(real public inputs)
     - x_hat(alpha) 
     and do an opening proof to check the commitment at alpha, AND get an opening
     proof at beta_3

     Approach 3:
     compute it directly.
     This involves 2*n non-native multiplies

     Approach 2':
     Approach 2 does not make sense as stated. Here is how it would actually work.

     The pairing-marlin proof will have

     public_input: (I, g0, a0, y0)
     absorb I.hash_state;
     g <- receive commitment from prover { LDE(I) }
     absorb g;
     a <- squeeze ();
     y := eval (LDE(I)) a;
     assert (y0 == y);
     assert (a0 == a);
     assert (g0 == g)

     You could also write it as
     public_input: (I, g0, a0, y0)
     absorb I.hash_state;
     absorb g;
     a <- squeeze ();
     assert (a0 == a);
     assert (y0 = eval (LDE(I)) a);

     And then in the dlog_marlin main, when verifying this previous paring marlin proof,
     you would check that
     - g0 opens to y0 at a
     - g0 opens to x_hat_beta_3 at beta_3

     and pass off x_hat_beta_3 to the next guy
   *)

  (* Approach 3

   \ell_i(x) =
    { 1 if x == i
    ; 0 if x != i and x in I }

   \ell_i(x)
   = (v_I(x) / (x - i)) / \prod_{j in I, j != i} (i - j)
   = (v_I(x) / (x - i)) * C_i

   \sum_i a_i \ell_i(x)
   = \sum_i a_i C_i v_I(x) / (x - i)
   = v_I(x) \sum_i a_i C_i / (x - i)

   = v_I(x) * (\sum_i a_i C_i \prod_{j != i} (x - j) ) / v_I(x)
*)

  (*

     To compute for all i (C_i / (x - i)):

     Guess a result d_i. Compute the formal product r_i := (x - i) d_i.

     Let s_i be a random hash.

     Compute 
      Cs_i := \sum_i s_i C_i 
      rs_i := \sum_i s_i r_i.

     Expose these two as public inputs and check they are equal the next time.
  *)

  (* Montgomery *)

  (* A = (a0 + T a1)
     B = (b0 + T b1)

     Say I = 2^e. (e will be like 5)

     Say q is N+1 bits. So we need all limbs to stay less than 2^N

     a0 b0 + T (a1 b0 + b0 a1) + T^2 a1 b1
     a0 b0 + T (a1 b0 + b0 a1) + T^2 a1 b1

     Say the weight of a limbed-number is the bitsize of its largest limb.

     t_i := a_i C_i / (x - i)
     if each limb of t_i < 2^k
     then each limb of \sum_i t_I < I 2^k = 2^{k + e}

     Need k+e <= N. So need k <= N - e.

     Can arrange for
     - weightB
    *)

  (*
     t_i := a_i C_i / (x - i)

     t_i must have term bound <= N - e.

     Say a_i has term bound A, C_i has term bound C.
     (a_i 
  *)

  (* Computing division.
     A / B = C
     A = C * B

     Consider A = a0 + a1 T + a2 T^2.

     Can check A = C * B as polynomials in T.

     For inversion, how many representations does 1 have as a polynomial in T?

     1 = a0 + a1 T + a2 T^2

     So can compute

  *)

  (* Trick for inversion

     T := 2^t

     Let's say we need to compute 1 / b_i for i < n.

     Pick representations r_i of 1 and then batch verify them.
     How to batch verify? Pick random scalars s_i,

     compute \sum_i s_i and \sum_i s_i r_i
     and expose them as public inputs.

     Ok so to compute 1/b.

     Let b = b0 + b1 T
     guess c = c0 + c1 T

     defer the check of "b c is a representation of 1".
     That is, compute O = b0 c0 + T (b0 c1 + b1 c0) + T^2 b1 c1.

     Compute such O_i for all the inversions one must perform.
     Select random scalars s_i = . Compute

     s_sum := \sum_i s_i
     os_sum := \sum_i O_i s_i
     = (bi_0 ci_0 
     
  *)

  (* Might not even need this.
   Suppose inverting b = b0 + 
  *)

  module PC = G1

  module Fp = struct
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
    end

    (* For us, q > p, so one Field.t = fq can represent an fp *)
    module Packed = Field
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

  (* TODO: Gonna do 
   "(acc, new) -> r * acc + new" instead of 
   "(acc, new) -> acc + r * new" *)

  (*
     Say we want to verify a bunch of Kate proofs
     
     π_i proves f_i(z_i) = v_i.

     Say we sample for each a random scalar r_i.

     We can check (using additive notation)

     0
     = sum_i r_i [ e(f_i - v_i G, H) - e(π_i, betaH - z_i H) ]
     = sum_i [ e(r_i (f_i - v_i G), H) - e(r_i π_i, betaH - z_i H) ]
     = e(sum_i r_i (f_i - v_i G), H) - sum_i e(r_i π_i, betaH - z_i H)
     = e((sum_i r_i f_i) - (sum_i r_i v_i) G, H) - sum_i e(r_i π_i, betaH - z_i H)
     = e((sum_i r_i f_i) - (sum_i r_i v_i) G, H) - sum_i e(r_i π_i, betaH - z_i H)

     Now note that 
     sum_i e(r_i π_i, betaH - z_i H)
     = sum_i e(r_i π_i, betaH) - e(r_i π_i, z_i H)
     = sum_i e(r_i π_i, betaH) - e((z_i r_i) π_i, H)
     = e(sum_i r_i π_i, betaH) - e(sum_i (z_i r_i) π_i, H)

     Which means overall we need to check
     0
     = e((sum_i r_i f_i) - (sum_i r_i v_i) G, H) - e(sum_i r_i π_i, betaH) - e(sum_i (z_i r_i) π_i, H)

     So, we never have to do any miller loops and per incremental update we only have to do
     - G1 scalar multiplciation: r_i f_i
     - deferred Fp multiplication: r_i v_i
     - G1 scalar multiplciation: r_i π_i
     - deferred Fp multiplication: z_i r_i
     - G1 scalar multiplciation: (z_i_r_i) π_i
  *)
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
    (acc, {Dlog_marlin_statement.Deferred_values.zr= zr_i; z= z_i; v= values})

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
      (*
    pairing_marlin_vk (* F_q based *)
    next_pairing_marlin_acc (* F_q based *)

    app_state (* F_p based (passed through) *)
    dlog_marlin_vk (* F_p based (passed through) *)
    g_old (* F_p based (passed through) *)

    x_old (* F_q based *)
    u_old (* F_q based *)
    b_u_x_old (* F_q based *)

    prev_dlog_marlin_acc (* F_p based *)
    prev_deferred_fp_arithmetic (* F_p based *) *)
      { Dlog_marlin_statement.deferred_values
      ; pairing_marlin_index
      ; sponge_digest
      ; bp_challenges_old
      ; b_challenge_old
      ; b_u_x_old (* All this could be a hash which we unhash *)
      ; app_state
      ; g_old
      ; dlog_marlin_index } =
    let prev_deferred_fq_arithmetic =
      (* TODO
    exists Deferred_fq_arithmetic *)
      []
    in
    List.iter prev_deferred_fq_arithmetic ~f:perform ;
    (* This is kind of a special case of deferred fq arithmetic. *)
    Field.Assert.equal (b bp_challenges_old b_challenge_old) b_u_x_old ;
    let updated_pairing_marlin_acc, deferred_fp_arithmetic =
      let exists typ r = exists typ ~request:(fun () -> r) in
      let open Requests in
      let sponge =
        let prev_sponge_digest = exists Fp.Unpacked.typ Prev.Sponge_digest in
        failwith "TODO"
      in
      let prev_marlin_proof =
        exists
          (Pairing_marlin_proof.Wire.typ Opening_proof.typ PC.typ
             Fp.Unpacked.typ)
          Prev.Pairing_marlin_proof
      in
      (* This performs the marlin verifier, does the incremental update of
       the polynomial commitment verification but does not perform all the
       F_p arithmetic equality checks. *)
      let prev_pairing_marlin_acc =
        exists
          (Pairing_marlin_accumulator.typ G1.typ)
          Requests.Prev.Pairing_marlin_accumulator
      in
      incrementally_verify_pairings ~verification_key:pairing_marlin_index
        ~sponge ~proof:prev_marlin_proof ~pairing_acc:prev_pairing_marlin_acc
        ~public_input:[]
      (* TODO *)
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
    assert (updated_pairing_marlin_macc = next_pairing_marlin_acc) ;
    assert (prev_deferred_fp_arithmetic = deferred_fp_arithmetic)
end

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
