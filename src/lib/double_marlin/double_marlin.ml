open Core_kernel
module Intf = struct
  module Group (Impl :  Snarky.Snark_intf.Run) = struct
    open Impl
    module type S = sig

      type t

      val (+) : t -> t -> t

      val scale : t -> Boolean.var list -> t

      val negate : t -> t

      val to_field_elements : t -> Field.t list
    end
  end

  module Sponge (Impl : Snarky.Snark_intf.Run) = struct
    open Impl

    module type S = sig

    type t

    val create : unit -> t

    val absorb_field : t -> Field.t -> unit

    val absorb_bits : t -> Boolean.var list -> unit

    val squeeze : t -> Field.t
  end
  end

  module Precomputation (G : sig type t end) = struct
    module type S = sig
      type t

      val create : G.t -> t
    end
  end
end

module type Dlog_main_inputs_intf = sig
  module Impl : Snarky.Snark_intf.Run
  open Impl

  module G1 : Intf.Group(Impl).S

  module G2 : Intf.Group(Impl).S

  module GT : Intf.Group(Impl).S

  module G1_precomputation : Intf.Precomputation(G1).S
  module G2_precomputation : Intf.Precomputation(G2).S

  module Sponge : Intf.Sponge(Impl).S

  val batch_miller_loop :
       (Sgn_type.Sgn.t * G1_precomputation.t * G2_precomputation.t) list
    -> GT.t
end

module Dlog_main (Inputs : Dlog_main_inputs_intf) = struct
  open Inputs
  open Impl

  type fq = Field.t

  let n = failwith "TODO"
  let k = Int.ceil_log2 n

  let product m f =
    List.reduce_exn (List.init m ~f) ~f:Field.( * )

  let b (u : fq array) (x : fq) : fq =
    let x_to_pow2s =
      let res = Array.create ~len:k x in
      for i = 1 to k - 1 do
        res.(i) <- Field.square (res.(i - 1))
      done;
      res
    in
    let open Field in
    product k (fun i -> u.(i) + inv u.(i) * x_to_pow2s.(i))

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
   *)

  type polynomial = G1.t


  (* For us, q > p *)
  type fp = Field.t

  module Type = struct
    type _ t =
      | PC : polynomial t
      | Fp : fp t
      | (::) : 'a t * 'b t -> ('a * 'b) t
  end

  let rec absorb : type a. Sponge.t -> a Type.t -> a -> unit =
    fun sponge ty t ->
      let absorb_field = Sponge.absorb_field sponge in
      match ty with
      | PC ->
        List.iter ~f:absorb_field (G1.to_field_elements t)
      | Fp -> absorb_field t
      | (ty1 :: ty2) ->
        let t1, t2 = t in
        absorb sponge ty1 t1;
        absorb sponge ty2 t2

  module Opening = struct
      type t = 
        { value : fp
        ; proof : G1.t
        }
      [@@deriving fields]

  end


  module Marlin_proof = struct
    module Messages = struct
      type t =
      { w_hat : polynomial
      ; s : polynomial
      ; z_hat_A : polynomial
      ; z_hat_B : polynomial
      ; gh_1 : polynomial * polynomial
      ; sigma_gh_2 : fp * (polynomial * polynomial)
      ; sigma_gh_3 : fp * (polynomial * polynomial)
      }
      [@@deriving fields]
    end

    module Openings = struct
      type 'n openings = (Opening.t, 'n) Vector.t

      (*
      module Polynomials = struct
        type t =
          | H_1 
          | G_1 
          | Z_A 
          | Z_B 
          | W_hat 
          | S  
        [@@deriving enum]
      end

      let _ = Polynomials.

      type 'a beta1 =
        { h_1 : 'a
        ; g_1 : 'a
        ; z_A : 'a
        ; z_B : 'a
        ; w_hat : 'a
        ; s  : 'a
        }
      [@@deriving fields]

      type 'a beta2 =
        { h_2     : 'a
        ; g_2 : 'a
        }
      [@@deriving fields]

      type 'a beta3 =
        { h_3     : 'a
        ; row_A   : 'a
        ; row_B   : 'a
        ; row_C   : 'a
        ; col_A   : 'a
        ; col_B   : 'a
        ; col_C   : 'a
        ; value_A : 'a
        ; value_B : 'a
        ; value_C : 'a
        }
      [@@deriving fields] *)

      type ('n1, 'n2, 'n3) t =
        { beta_1 : 'n1 openings
        ; beta_2 : 'n2 openings
        ; beta_3 : 'n3 openings
        }
    end

    type ('n1, 'n2, 'n3) t =
      { messages : Messages.t
      ; openings: ('n1, 'n2, 'n3) Openings.t
      }
  end

  type 'a abc = { a : 'a; b : 'a; c : 'a }
  type 'a matrix_evals = { row : 'a ; col: 'a; value: 'a }

  let combined_commitment ~xi (polys : _ Vector.t) =
    let p0 :: ps = polys in
    List.fold_left (Vector.to_list ps) ~init:p0
      ~f:(fun acc p -> G1.(p + scale acc xi))

(*

  let combined_commitment ~xi ~sponge openings polys =
    let values = Vector.map openings ~f:Opening.value in
    let (o0, p0) :: ops = Vector.(zip openings polys) in
    let poly =
      List.fold_left (Vector.to_list polys) ~init:p0
        ~f:(fun acc p -> G1.(p + scale acc xi))
    in

    let compute_v = `Compute_v values in

    o0.proof
*)

(* Gonna do 
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
  let accumuluate_pairing_state
    ~defer
      r_i
      ((rf_acc, rpi_acc, zrpi_acc), (rv_acc, zr_acc))
      (pi_i, f_i, z_i, v_i)
    =
    let open G1 in
    let ( * ) s p = scale p s in
    let zr_i = defer (`Mul (z_i, r_i)) in
    ( rf_acc + r_i * f_i
    , rpi_acc + r_i * pi_i
    , zrpi_acc + zr_i * pi_i
    )

  let challenge_length = 256

(*
  type pairing_acc_deferred_computation =
    { compute_v : fp list
    ; check_zr : (fp * 
    }


*)
  type deferred_computations =
    { xi : fp
    ; beta_1 : pairing_acc_deferred_computation
    }

  let incrementally_verify_pairings
    m
      ~sponge ~verification_key ~public_input ~proof:{ Marlin_proof.messages; openings} =
    let receive ty f =
      let x = f messages in
      absorb sponge ty x ;
      x
    in
    let sample () = Sponge.squeeze sponge in
    let sample_fp_challenge () =
    List.take  
      (Field.unpack ~length:Field.size_in_bits
         (sample ()))
      256
    in
    let open Marlin_proof.Messages in
    let w_hat = receive PC w_hat in
    let s = receive PC s in
    let z_hat_A = receive PC z_hat_A in
    let z_hat_B = receive PC z_hat_B in
    let alpha = sample () in
    let eta_A = sample () in
    let eta_B = sample () in
    let eta_C = sample () in
    let (g_1, h_1) = receive (PC :: PC) gh_1 in
    let beta_1 = sample () in
    let (sigma_2, (g_2, h_2)) = receive (Fp :: PC :: PC) sigma_gh_2 in
    let beta_2 = sample () in
    let (sigma_3, (g_3, h_3)) = receive (Fp :: PC :: PC) sigma_gh_3 in
    let beta_3 = sample () in
    let open_ { Opening.proof; value } poly =
      failwith "TODO"
    in
    (* We can use the same random scalar xi for all of these opening proofs. *)
    let xi = sample_fp_challenge () in
    let f_1 =
      combined_commitment ~xi
        [ g_1; h_1; z_hat_A; z_hat_B; w_hat; s ] in
    let f_2 =
      combined_commitment ~xi
        [ g_2; h_2 ]
    in
    let f_3 =
      combined_commitment ~xi
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
        ; m.value.c  ]
    in
    
    let alpha = sample_fp_challenge () in
    G1.scale

    (*
    let open Arithmetic_expression in
    let a ~eta ~v_H_beta_1 ~v_H_beta_2 {Index.row; col; value} =
      sum [A; B; C] (fun m ->
          eta m
          * !v_H_beta_2 * !v_H_beta_1
          * ! (value m)
          * product
              (all_but m [A; B; C])
              (fun n -> (!beta_2 - !(row n) )
                        * (!beta_1 * !(col n)) ))
    in
    let b { Index.row; col; _ } =
      product [A; B; C] (fun m ->
          (!beta_2 - !(row m)) * (!beta_1 - ! (col m)))
    in  *)

(* Inside here we have F_q arithmetic, so we can incrementally check
   the polynomial commitments from the pairing-based Marlin *)
let dlog_main
    app_state (* F_p based (passed through) *)

    pairing_marlin_vk (* F_q based *)
    next_pairing_marlin_acc (* F_q based *)

    dlog_marlin_vk (* F_p based (passed through) *)
    g_old (* F_p based (passed through) *)

    x_old (* F_q based *)
    u_old (* F_q based *)
    b_u_x_old (* F_q based *)

    prev_dlog_marlin_acc (* F_p based *)
    prev_deferred_fp_arithmetic (* F_p based *)
  =
  let prev_pairing_marlin_acc = exists Pairing_marlin_acc
  and prev_deferred_fq_arithmetic = exists Deferred_fq_arithmetic
  in
  List.iter prev_deferred_fq_arithmetic ~f:(fun a ->
      perform a);
  (* This is kind of a special case of deferred fq arithmetic. *)
  assert (b u_old x_old = b_u_x_old);

  let updated_pairing_marlin_acc, deferred_fp_arithmetic =
    let prev_marlin_proof = exists Prev_pairing_marlin_proof in
    (* This performs the marlin verifier, does the incremental update of
       the polynomial commitment verification but does not perform all the
       F_p arithmetic equality checks. *)
    Pairing_marlin.incrementally_verify_openings
      pairing_marlin_vk
      prev_marlin_proof
      ~public_input:[
        pairing_marlin_vk; (* This may need to be passed in using the hashing trick. It could be hashed together with prev_pairing_marlin_acc since they're both just passed through anyway.  *)
        prev_pairing_marlin_acc;
        dlog_marlin_vk;
        g_old;

        prev_dlog_marlin_acc;

        prev_deferred_fq_arithmetic;
      ]
  in
  assert (updated_pairing_marlin_macc = next_pairing_marlin_acc);
  assert (prev_deferred_fp_arithmetic = deferred_fp_arithmetic);

end

(* Inside here we have F_p arithmetic so we can incrementally check the
   polynomial commitments from the DLog-based marlin *)
let pairing_main
    app_state
    pairing_marlin_vk
    prev_pairing_marlin_acc
    dlog_marlin_vk
    g_new
    u_new
    x_new
    next_dlog_marlin_acc
    next_deferred_fq_arithmetic
    =
    (* The actual computation *)
    let prev_app_state = exists Prev_app_state in
    let transition = exists Transition in
    assert (transition_function prev_app_state transition = app_state);

    let prev_dlog_marlin_acc = exists Dlog_marlin_acc
    and prev_deferred_fp_arithmetic = exists Deferred_fp_arithmetic in
    List.iter prev_deferred_fp_arithmetic ~f:perform;
    let (actual_g_new, actual_u_new), deferred_fq_arithmetic =
      let g_old, x_old, u_old, b_u_old = exists G_old in
      let updated_dlog_marlin_acc, deferred_fq_arithmetic, polynomial_evaluation_checks =
        let prev_dlog_marlin_proof = exists Prev_dlog_marlin_proof in
        Dlog_marlin.incrementally_execute_protocol
          dlog_marlin_vk
          prev_dlog_marlin_proof
          ~public_input:[
            prev_app_state;
            pairing_marlin_vk;
            prev_pairing_marlin_acc;
            dlog_marlin_vk;
            g_old;
            x_old;
            u_old;
            b_u_old_x;
            prev_dlog_marlin_acc;
            prev_deferred_fp_arithmetic;
          ]
      in
      let g_new_u_new =
        batched_inner_product_argument
          ((g_old, x_old, b_u_old_x) :: polynomial_evaluation_checks)
      in
      g_new_u_new, deferred_fq_arithmetic
    in
    (* This should be sampled using the hash state at the end of 
        "Dlog_marlin.incrementally_execute_protocol" *)
    let x_new = sample () in
    assert (actual_g_new = g_new);
    assert (actual_u_new = u_new);
    assert (actual_x_new = x_new)
