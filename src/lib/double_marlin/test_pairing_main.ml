open Core_kernel

let weight = ref 0

module Bn382 = Snarky_bn382_backend.Pairing_based
module Fq = Snarky_bn382_backend.Fq
module Fp = Snarky_bn382_backend.Fp
module G = Snarky_bn382_backend.G
module G1 = Snarky_bn382_backend.G1

let group_map_fp =
  let params =
    Group_map.Params.create (module Fp) ~a:Fp.zero ~b:(Fp.of_int 7)
  in
  fun x -> Group_map.to_group (module Fp) ~params x |> G.of_affine

let bits_random_oracle =
  let h = Digestif.blake2s 32 in
  fun ?(length = 256) s ->
    Digestif.digest_string h s |> Digestif.to_raw_string h |> String.to_list
    |> List.concat_map ~f:(fun c ->
           let c = Char.to_int c in
           List.init 8 ~f:(fun i -> (c lsr i) land 1 = 1) )
    |> fun a -> List.take a length

let fp_random_oracle ?length s = Fp.of_bits (bits_random_oracle ?length s)

(* We get an element with unrelated discrete log by hashing g. *)
let unrelated_g g =
  let hash =
    let str a =
      List.map
        (List.groupi (Fp.to_bits a) ~break:(fun i _ _ -> i mod 8 = 0))
        ~f:(fun bs ->
          List.foldi bs ~init:0 ~f:(fun i acc b ->
              if b then acc lor (1 lsl i) else acc )
          |> Char.of_int_exn )
      |> String.of_char_list
    in
    let x, y = G.to_affine_exn g in
    fp_random_oracle (str x ^ str y)
  in
  group_map_fp hash

module Inputs = struct
  module Impl = Snarky.Snark.Run.Make (Bn382) (Unit)

  let sponge_params_constant =
    Sponge.Params.(map bn382_p ~f:Impl.Field.Constant.of_string)

  let%test_unit "one-identity" =
    let module F = Impl.Field.Constant in
    let x = F.random () in
    assert (F.equal x F.(one * x))

  module Fq_constant = struct
    type t = unit

    let size_in_bits = 382
  end

  open Impl

  module App_state = struct
    type t = Field.t

    module Constant = Field.Constant

    let to_field_elements x = [|x|]

    let typ = Typ.field

    let check_update x0 x1 = Field.(equal x1 (x0 + one))

    let is_base_case x = Field.(equal x zero)
  end

  module Poseidon_inputs = struct
    module Field = Impl.Field

    let rounds_full = 8

    let rounds_partial = 55

    let to_the_alpha x = Impl.Field.(square (square x) * x)

    module Operations = struct
      (* TODO: experiment with sealing version of this *)
      let add_assign ~state i x = state.(i) <- Field.( + ) state.(i) x

      let apply_affine_map (matrix, constants) v =
        let seal x =
          let x' =
            exists Field.typ ~compute:As_prover.(fun () -> read_var x)
          in
          Field.Assert.equal x x' ; x'
        in
        let dotv row =
          Array.reduce_exn (Array.map2_exn row v ~f:Field.( * )) ~f:Field.( + )
        in
        Array.mapi matrix ~f:(fun i row ->
            seal Field.(constants.(i) + dotv row) )

      let copy = Array.copy
    end
  end

  module S = Sponge.Make_sponge (Sponge.Poseidon (Poseidon_inputs))

  let sponge_params =
    Sponge.Params.(map sponge_params_constant ~f:Impl.Field.constant)

  module Sponge = struct
    module S = struct
      type t = S.t

      let create ?init params = S.create ?init params

      let absorb t input =
        ksprintf Impl.with_label "absorb: %s" __LOC__ (fun () ->
            S.absorb t input )

      let squeeze t =
        ksprintf Impl.with_label "squeeze: %s" __LOC__ (fun () -> S.squeeze t)
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

    let absorb t input =
      match input with
      | `Field x ->
          absorb t x
      | `Bits bs ->
          absorb t (Field.pack bs)
  end

  module Input_domain = struct
    let domain = Domain.Pow_2_roots_of_unity 5

    (* TODO: Make the real values *)
    let lagrange_commitments =
      Array.init (Domain.size domain) ~f:(fun i ->
          unrelated_g (G.scale G.one (Fq.of_int i)) )
  end

  module G = struct
    module Inputs = struct
      module Impl = Impl

      module Params = struct
        open Impl.Field.Constant

        let a = zero

        let b = of_int 7

        let one = G.to_affine_exn G.one

        let group_size_in_bits = 382
      end

      module F = struct
        include struct
          open Impl.Field

          type nonrec t = t

          let ( * ), ( + ), ( - ), inv_exn, square, scale, if_, typ, constant =
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

      module Constant = Snarky_bn382_backend.G
    end

    module Params = Inputs.Params
    module Constant = Inputs.Constant
    module T = Snarky_curve.For_native_base_field (Inputs)

    module Scaling_precomputation = struct
      include T.Scaling_precomputation

      let create base = create ~unrelated_base:(unrelated_g base) base
    end

    type t = T.t

    let typ = T.typ

    let ( + ) = T.add_exn

    let multiscale_known = T.multiscale_known

    (* TODO: Make real *)
    let scale t bs =
      let x, y = t in
      let constraints_per_bit =
        if Option.is_some (Field.to_constant x) then 2 else 6
      in
      let x = exists Field.typ ~compute:(fun () -> As_prover.read_var x)
      and x2 =
        exists Field.typ ~compute:(fun () ->
            Field.Constant.square (As_prover.read_var x) )
      in
      ksprintf Impl.with_label "scale %s" __LOC__ (fun () ->
          (* Dummy constraints *)
          let num_bits = List.length bs in
          for _ = 1 to constraints_per_bit * num_bits do
            assert_r1cs x x x2
          done ;
          (x, y) )

    (*         T.scale t (Bitstring_lib.Bitstring.Lsb_first.of_list bs) *)
    let to_field_elements (x, y) = [x; y]

    let assert_equal (x1, y1) (x2, y2) =
      Field.Assert.equal x1 x2 ; Field.Assert.equal y1 y2

    let scale_inv t bs =
      let res =
        exists typ
          ~compute:
            As_prover.(
              fun () ->
                G.scale (read typ t)
                  (Fq.inv (Fq.of_bits (List.map ~f:(read Boolean.typ) bs))))
      in
      (* TODO: assert_equal t (scale res bs) ; *)
      ignore (scale res bs) ;
      res

    let scale_by_quadratic_nonresidue t = T.double (T.double t) + t

    let one_fifth = Fq.(inv (of_int 5))

    let scale_by_quadratic_nonresidue_inv t =
      let res =
        exists typ
          ~compute:As_prover.(fun () -> G.scale (read typ t) one_fifth)
      in
      (*TODO:assert_equal t (scale_by_quadratic_nonresidue res) ; *)
      ignore (scale_by_quadratic_nonresidue res) ;
      res

    let negate = T.negate

    let one = T.one

    let if_ b ~then_:(tx, ty) ~else_:(ex, ey) =
      (Field.if_ b ~then_:tx ~else_:ex, Field.if_ b ~then_:ty ~else_:ey)
  end

  let domain_k = Domain.Pow_2_roots_of_unity 18

  let domain_h = Domain.Pow_2_roots_of_unity 18

  module Generators = struct
    let g = G.one

    let h = G.T.constant (unrelated_g Snarky_bn382_backend.G.one)
  end
end

let pairing_marlin_acc_init =
  let open Snarky_bn382_backend in
  let x = Fp.random () in
  let commitment_to_id_poly = G1.scale G1.one x in
  let eval_pt = Fp.random () in
  let evaluation = eval_pt in
  let pi =
    (* (f(x) - evaluation) / (x - eval_pt)
       = (x - eval_pt) / (x - eval_pt)
       = 1
    *)
    G1.one
  in
  Pickles_types.Pairing_marlin_types.Accumulator.map ~f:G1.to_affine_exn
    { r_f_plus_r_v= G1.add commitment_to_id_poly (G1.scale G1.one evaluation)
    ; r_pi= pi
    ; zr_pi= G1.scale pi eval_pt }

let bulletproof_log2 = 15

open Pickles_types
module M = Pairing_main.Main (Inputs)

let hash_me_only t =
  let elts =
    Types.Pairing_based.Proof_state.Me_only.to_field_elements t
      ~g:(fun g ->
        let x, y = Snarky_bn382_backend.G.to_affine_exn g in
        [x; y] )
      ~app_state:(fun x -> [|x|])
  in
  let sponge = Fp_sponge.Bits.create Inputs.sponge_params_constant in
  Array.iter elts ~f:(fun x -> Fp_sponge.Bits.absorb sponge x) ;
  Fp_sponge.Bits.squeeze sponge ~length:M.Digest.length

let%test_unit "pairing-main" =
  let module Stmt = Types.Pairing_based.Statement in
  let input =
    let open Pickles_types.Vector in
    Snarky.Typ.tuple5
      (typ Inputs.Impl.Boolean.typ Nat.N1.n)
      (typ M.Fq.typ Nat.N4.n)
      (typ Inputs.Impl.Field.typ Nat.N3.n)
      (typ Inputs.Impl.Field.typ Nat.N9.n)
      (Snarky.Typ.array ~length:bulletproof_log2 Inputs.Impl.Field.typ)
  in
  let n =
    Inputs.Impl.constraint_count (fun () -> M.main (Inputs.Impl.exists input))
  in
  Core.printf "pairing-main: %d / %d\n%!" n
    !Snarky_bn382_backend.R1cs_constraint_system.weight ;
  let main x () = M.main x in
  let kp = Inputs.Impl.generate_keypair ~exposing:[input] main in
  let pk = Inputs.Impl.Keypair.pk kp in
  Core.printf "pairing-main: %d / %d\n%!" n
    !Snarky_bn382_backend.R1cs_constraint_system.weight ;
  let wt = !Snarky_bn382_backend.R1cs_constraint_system.wt in
  Core.printf "weights %d %d %d\n%!" wt.a wt.b wt.c ;
  let pi =
    let pass_through =
      { Types.Pairing_based.Proof_state.Pass_through.pairing_marlin_index=
          Snarky_bn382_backend.Keypair.vk_commitments pk
      ; pairing_marlin_acc= pairing_marlin_acc_init }
    in
    let module I = Inputs.Impl in
    let me_only =
      { Types.Pairing_based.Proof_state.Me_only.app_state= I.Field.Constant.zero
      ; dlog_marlin_index=
          (let g = Snarky_bn382_backend.G.one in
           let t = {Pickles_types.Abc.a= g; b= g; c= g} in
           {row= t; col= t; value= t})
      ; sg= group_map_fp (fp_random_oracle "sg") }
    in
    let fq : M.Fq.Constant.t = (fp_random_oracle ~length:20 "fq", true) in
    let fp = I.Field.Constant.zero in
    let challenge = fp_random_oracle ~length:128 in
    let digest = fp_random_oracle ~length:256 "digest" in
    let g = Snarky_bn382_backend.G.one in
    let bulletproof_challenges =
      Array.init bulletproof_log2 ~f:(fun i ->
          Fp.zero
          (*
          bits_random_oracle (sprintf "bp_%d" i)
            ~length:129
          |> Fp.of_bits
*)
      )
    in
    let prev_evals =
      let open Pairing_marlin_types.Evals in
      let mk n = Vector.init n ~f:(fun _ -> I.Field.Constant.zero) in
      (mk Beta1.n, mk Beta2.n, mk Beta3.n)
    in
    let prev_messages : _ Pairing_marlin_types.Messages.t =
      { w_hat= g
      ; s= g
      ; z_hat_a= g
      ; z_hat_b= g
      ; gh_1= ((g, g), g)
      ; sigma_gh_2= (fq, ((g, g), g))
      ; sigma_gh_3= (fq, ((g, g), g)) }
    in
    let prev_openings_proof : _ Types.Pairing_based.Openings.Bulletproof.t =
      { gammas= Array.init bulletproof_log2 ~f:(fun _ -> (g, g))
      ; z_1= fq
      ; z_2= fq
      ; beta= g
      ; delta= g }
    in
    let prev_sg = group_map_fp (fp_random_oracle "prev_sg") in
    let prev_proof_state : _ Types.Dlog_based.Proof_state.t =
      let challenge = bits_random_oracle ~length:M.Challenge.length in
      let digest = List.init M.Digest.length ~f:(fun _ -> false) in
      { deferred_values=
          { xi= challenge "xi"
          ; r= challenge "r"
          ; r_xi_sum= fp
          ; marlin=
              { sigma_2= fp
              ; sigma_3= fp
              ; alpha= challenge __LOC__
              ; eta_a= challenge __LOC__
              ; eta_b= challenge __LOC__
              ; eta_c= challenge __LOC__
              ; beta_1= challenge __LOC__
              ; beta_2= challenge __LOC__
              ; beta_3= challenge __LOC__ }
          ; sg_challenge_point= challenge __LOC__
          ; sg_evaluation= fq }
      ; sponge_digest_before_evaluations= digest
      ; me_only= digest }
    in
    let handler (Snarky.Request.With {request; respond}) =
      let open M.Requests in
      let k x = respond (Provide x) in
      match request with
      | Compute.Fq_is_square bits ->
          k Fq.(is_square (of_bits bits))
      | Me_only ->
          k me_only
      | Prev_app_state ->
          k Bn382.Field.zero
      | Prev_evals ->
          k prev_evals
      | Prev_messages ->
          k prev_messages
      | Prev_openings_proof ->
          k prev_openings_proof
      | Prev_sg ->
          k prev_sg
      | Prev_proof_state ->
          k prev_proof_state
      | _ ->
          Snarky.Request.unhandled
    in
    I.prove pk [input]
      (fun x () -> I.handle (main x) handler)
      ()
      (Stmt.to_data
         { proof_state=
             { deferred_values=
                 { xi= challenge "xi"
                 ; r= challenge "r"
                 ; bulletproof_challenges
                 ; a_hat= fq
                 ; combined_inner_product= fq
                 ; marlin=
                     { sigma_2= fq
                     ; sigma_3= fq
                     ; alpha= challenge "alpha"
                     ; eta_a= challenge "eta_a"
                     ; eta_b= challenge "eta_b"
                     ; eta_c= challenge "eta_c"
                     ; beta_1= challenge "beta_1"
                     ; beta_2= challenge "beta_2"
                     ; beta_3= challenge "beta_3" } }
             ; was_base_case= true
             ; sponge_digest_before_evaluations= digest
             ; me_only= I.Field.Constant.project (hash_me_only me_only) }
         ; pass_through= I.Field.Constant.project prev_proof_state.me_only })
  in
  ()

(*
module Dlog_inputs : Intf.Dlog_main_inputs.S = struct
  open Inputs
  module Impl = Impl
  module G1 = G1
  module Input_domain = Input_domain

  let domain_k = domain_k

  let domain_h = domain_h

  module Generators = Generators

  let sponge_params = sponge_params

  module Fp_params = struct
    let size_in_bits = 382

    let p =
      Bigint.of_string
        "5543634365110765627805495722742127385843376434033820803590214255538854698464778703795540858859767700241957783601153"
  end

  module Sponge = struct
    include Sponge

    let absorb t x = absorb t (`Field x)
  end
end *)

(*

let%test_unit "dlog-main" =
  let module Inputs = Dlog_inputs in
  let module M = Dlog_main.Dlog_main (Inputs) in
  let n =
    let open Vector in
    Inputs.Impl.constraint_count (fun () ->
        M.main
          (Inputs.Impl.exists
             (Snarky.Typ.tuple5
                (typ M.Fp.Unpacked.typ Nat.N3.n)
                (typ M.Challenge.typ Nat.N9.n)
                (typ Inputs.Impl.Field.typ Nat.N3.n))) )
  in
  Core.printf "dlog-main: %d\n%!" n
*)
(*
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
    end *)
