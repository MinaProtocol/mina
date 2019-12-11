(* TODO:
   Start writing pairing_main so I can get a sense of how the x_hat
   commitment and challenge is going to work. *)
open Core_kernel
open Import

let rec absorb : type a g1 f scalar.
       absorb_field:(f -> unit)
    -> g1_to_field_elements:(g1 -> f list)
    -> pack_scalar:(scalar -> f)
    -> (a, < scalar: scalar ; g1: g1 >) Type.t
    -> a
    -> unit =
 fun ~absorb_field ~g1_to_field_elements ~pack_scalar ty t ->
  match ty with
  | PC ->
      List.iter ~f:absorb_field (g1_to_field_elements t)
  | Scalar ->
      absorb_field (pack_scalar t)
  | ty1 :: ty2 ->
      let absorb t =
        absorb t ~absorb_field ~g1_to_field_elements ~pack_scalar
      in
      let t1, t2 = t in
      absorb ty1 t1 ; absorb ty2 t2

module Dlog_main (Inputs : Intf.Dlog_main_inputs.S) = struct
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

      let assert_equal t1 t2 = Field.(Assert.equal (project t1) (project t2))
    end

    let pack : Unpacked.t -> Packed.t = Packed.project
  end

  let absorb sponge ty t =
    absorb ~absorb_field:(Sponge.absorb sponge)
      ~g1_to_field_elements:G1.to_field_elements ~pack_scalar:Fp.Packed.project
      ty t

  module Opening_proof = G1

  module Opening = struct
    type 'n t =
      ( Opening_proof.t
      , (Fp.Unpacked.t, 'n) Vector.t )
      Pairing_marlin_types.Opening.t
  end

  module Marlin_proof = struct
    type t =
      (Opening_proof.t, PC.t, Fp.Unpacked.t) Pairing_marlin_types.Proof.t
  end

  module Accumulator = Pairing_marlin_types.Accumulator
  module Proof = Pairing_marlin_types.Proof

  let combined_commitment ~xi (polys : _ Vector.t) =
    ksprintf with_label "combined_commitment %s" __LOC__ (fun () ->
        let (p0 :: ps) = polys in
        List.fold_left (Vector.to_list ps) ~init:p0 ~f:(fun acc p ->
            G1.(p + scale acc xi) ) )

  let accumuluate_pairing_state r_i zr_i pi_i f_i {Accumulator.r_f; r_pi; zr_pi}
      =
    ksprintf with_label "accumulate_pairing_state %s" __LOC__ (fun () ->
        let open G1 in
        let ( * ) s p = scale p s in
        { Accumulator.r_f= r_f + (r_i * f_i)
        ; r_pi= r_pi + (r_i * pi_i)
        ; zr_pi= zr_pi + (zr_i * pi_i) } )

  let pack_fp = Field.project

  let accumulate_and_defer
      ~(defer : [`Mul of Fp.Unpacked.t * Fp.Unpacked.t] -> Boolean.var list)
      r_i f_i z_i ({values; proof} : _ Opening.t) acc =
    let zr_i = defer (`Mul (z_i, r_i)) in
    let acc = accumuluate_pairing_state r_i zr_i proof f_i acc in
    (acc, {Accumulator.Input.zr= zr_i; z= z_i; v= values})

  type scalar = Boolean.var list

  module Requests = struct
    open Snarky.Request

    module Prev = struct
      type _ t +=
        | Pairing_marlin_accumulator : G1.Constant.t Accumulator.t t
        | Pairing_marlin_proof :
            ( Opening_proof.Constant.t
            , PC.Constant.t
            , Fp.Unpacked.constant )
            Proof.t
            t
        | Sponge_digest : Fp.Unpacked.constant t
    end

    type _ t +=
      | Fp_mul : bool list * bool list -> bool list t
      | Mul_scalars : bool list * bool list -> bool list t
  end

  module Challenge = struct
    let length = 128

    type t = Boolean.var list

    let typ = Typ.list ~length Boolean.typ
  end

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

  module L = Eval_lagrange.Eval_lagrange (Impl) (Sponge) (Fp_constant)

  let incrementally_verify_pairings
      ~verification_key:(m : _ Abc.t Matrix_evals.t) ~sponge ~public_input
      ~pairing_acc:pacc ~proof:({messages; openings= ops} : Marlin_proof.t) =
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
          (Proof.typ Opening_proof.typ PC.typ Fp.Unpacked.typ)
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
      Field.pack (Sponge.squeeze sponge ~length:128)
    in
    Field.Assert.equal sponge_digest actual_sponge_digest ;
    Accumulator.assert_equal
      (fun x y ->
        List.iter2_exn ~f:Field.Assert.equal (G1.to_field_elements x)
          (G1.to_field_elements y) )
      updated_pairing_marlin_acc pairing_marlin_acc ;
    Dlog_marlin_statement.Deferred_values.assert_equal Fp.Unpacked.assert_equal
      deferred_values deferred_fp_arithmetic
end

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
