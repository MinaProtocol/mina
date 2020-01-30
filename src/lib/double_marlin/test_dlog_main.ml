open Core_kernel
open Tuple_lib
module Bn382 = Snarky_bn382_backend.Dlog_based
module Fp = Snarky_bn382_backend.Fp
module Fq = Snarky_bn382_backend.Fq

(* module G = Snarky_bn382_backend.G *)
module G1 = Snarky_bn382_backend.G1
open Common

(* TODO: Check a_hat! *)
let compute_challenges chals =
  let nonresidue = Fq.of_int 5 in
  Array.map chals
    ~f:(fun {Types.Bulletproof_challenge.prechallenge; is_square} ->
      let prechallenge =
        Fq.of_bits (Challenge.Constant.to_bits prechallenge)
      in
      assert (is_square = Fq.is_square prechallenge) ;
      let sq =
        if is_square then prechallenge else Fq.(nonresidue * prechallenge)
      in
      Fq.sqrt sq )

let group_map_fq =
  let params =
    Group_map.Params.create (module Fq) ~a:Fq.zero ~b:(Fq.of_int 14)
  in
  fun x -> Group_map.to_group (module Fq) ~params x

let bits_random_oracle =
  let h = Digestif.blake2s 32 in
  fun ?(length = 256) s ->
    Digestif.digest_string h s |> Digestif.to_raw_string h |> String.to_list
    |> List.concat_map ~f:(fun c ->
           let c = Char.to_int c in
           List.init 8 ~f:(fun i -> (c lsr i) land 1 = 1) )
    |> fun a -> List.take a length

let fq_random_oracle ?length s = Fq.of_bits (bits_random_oracle ?length s)

let unrelated_g g =
  let hash =
    let str a =
      List.map
        (List.groupi (Fq.to_bits a) ~break:(fun i _ _ -> i mod 8 = 0))
        ~f:(fun bs ->
          List.foldi bs ~init:0 ~f:(fun i acc b ->
              if b then acc lor (1 lsl i) else acc )
          |> Char.of_int_exn )
      |> String.of_char_list
    in
    let x, y = G1.to_affine_exn g in
    fq_random_oracle (str x ^ str y)
  in
  group_map_fq hash

module Inputs = struct
  let crs_max_degree = 1 lsl 22

  module Impl = Snarky.Snark.Run.Make (Bn382) (Unit)

  module Input_domain = struct
    let domain = Domain.Pow_2_roots_of_unity 6

    (* TODO: Make the real values *)
    let lagrange_commitments =
      let x = 64 in
      let u = Unsigned.Size_t.of_int in
      time "lagrange" (fun () ->
          Array.init (Domain.size domain) ~f:(fun i ->
              Snarky_bn382_backend.G1.Affine.of_backend
                (Snarky_bn382.Fp_urs.lagrange_commitment
                   (Lazy.force Snarky_bn382_backend.Pairing_based.Keypair.urs)
                   (u x) (u i)) ) )
  end

  module G1 = struct
    module Inputs = struct
      module Impl = Impl

      module Params = struct
        open Impl.Field.Constant

        let a = zero

        let b = of_int 14

        let one = G1.to_affine_exn G1.one

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

      module Constant = G1
    end

    module Params = Inputs.Params

    module Constant = struct
      type t = G1.Affine.t

      let to_affine_exn = Fn.id

      let of_affine = Fn.id
    end

    module T = Snarky_curve.For_native_base_field (Inputs)

    module Scaling_precomputation = struct
      include T.Scaling_precomputation

      let create (base : Constant.t) =
        let base = G1.of_affine base in
        create ~unrelated_base:(G1.of_affine (unrelated_g base)) base
    end

    open Impl

    type t = T.t

    let ( + ) = T.add_exn

    let constant (t : Constant.t) = T.constant (G1.of_affine t)

    let multiscale_known = T.multiscale_known

    (* TODO: Make real *)
    let scale t bs =
      let res =
        exists T.typ
          ~compute:
            As_prover.(
              fun () ->
                G1.scale (read T.typ t)
                  (Snarky_bn382_backend.Fp.of_bits
                     (List.map bs ~f:(read Boolean.typ))))
      in
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
          res )

    (*         T.scale t (Bitstring_lib.Bitstring.Lsb_first.of_list bs) *)
    let to_field_elements (x, y) = [x; y]

    let assert_equal (x1, y1) (x2, y2) =
      Field.Assert.equal x1 x2 ; Field.Assert.equal y1 y2

    let scale_inv t bs =
      let res =
        exists T.typ
          ~compute:
            As_prover.(
              fun () ->
                G1.scale (read T.typ t)
                  (Fp.inv (Fp.of_bits (List.map ~f:(read Boolean.typ) bs))))
      in
      (* TODO: assert_equal t (scale res bs) ; *)
      ignore (scale res bs) ;
      res

    let scale_by_quadratic_nonresidue t = T.double (T.double t) + t

    let one_fifth = Fp.(inv (of_int 5))

    let scale_by_quadratic_nonresidue_inv t =
      let res =
        exists T.typ
          ~compute:As_prover.(fun () -> G1.scale (read T.typ t) one_fifth)
      in
      (*TODO:assert_equal t (scale_by_quadratic_nonresidue res) ; *)
      ignore (scale_by_quadratic_nonresidue res) ;
      res

    let typ = Typ.transport T.typ ~there:G1.of_affine ~back:G1.to_affine_exn

    let negate = T.negate

    let one = T.one

    let if_ b ~then_:(tx, ty) ~else_:(ex, ey) =
      (Field.if_ b ~then_:tx ~else_:ex, Field.if_ b ~then_:ty ~else_:ey)
  end

  module Generators = struct
    let g = G1.one
  end

  let sponge_params_constant =
    Sponge.Params.(map bn382_q ~f:Impl.Field.Constant.of_string)

  module Fp = struct
    type t = Fp.t

    let order =
      Impl.Bigint.to_bignum_bigint
        Snarky_bn382_backend.Pairing_based.field_size

    let size_in_bits = Fp.size_in_bits

    let to_bigint = Fp.to_bigint

    let of_bigint = Fp.of_bigint
  end

  let domain_k = Domain.Pow_2_roots_of_unity 18

  let domain_h = Domain.Pow_2_roots_of_unity 18

  let sponge_params =
    Sponge.Params.(map sponge_params_constant ~f:Impl.Field.constant)

  module Sponge = struct
    open Impl

    module Poseidon_inputs = struct
      module Field = Impl.Field

      let rounds_full = 8

      module Alpha_17 = struct
        let rounds_partial = 25

        let to_the_alpha x =
          x |> Impl.Field.square |> Impl.Field.square |> Impl.Field.square
          |> Impl.Field.square
          |> Impl.Field.(( * ) x)
      end

      (* Rounds required = 37 *)
      module Alpha_13 = struct
        let rounds_partial = 37 - 8

        let to_the_alpha x =
          x |> Impl.Field.square
          |> Impl.Field.(( * ) x)
          |> Impl.Field.square |> Impl.Field.square
          |> Impl.Field.(( * ) x)
      end

      (* Rounds required = 39 *)
      module Alpha_11 = struct
        let rounds_partial = 39 - 8

        let to_the_alpha x =
          x |> Impl.Field.square |> Impl.Field.square
          |> Impl.Field.(( * ) x)
          |> Impl.Field.square
          |> Impl.Field.(( * ) x)
      end

      module Alpha_5 = struct
        let rounds_partial = 49

        let to_the_alpha x = Impl.Field.(square (square x) * x)
      end

      include Alpha_11

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
            Array.reduce_exn
              (Array.map2_exn row v ~f:Field.( * ))
              ~f:Field.( + )
          in
          Array.mapi matrix ~f:(fun i row ->
              seal Field.(constants.(i) + dotv row) )

        let copy = Array.copy
      end
    end

    module S = struct
      module S = Sponge.Make_sponge (Sponge.Poseidon (Poseidon_inputs))

      type t = S.t

      let copy = S.copy

      let create ?init params = S.create ?init params

      let state = S.state

      let absorb t input =
        (*
        as_prover As_prover.(fun () ->
            Core.printf "caml-absorb:%!"; Fq.print  (read_var input)
            ; Core.printf "\n%!";
          );
        as_prover As_prover.(fun () ->
            let state = Array.map ~f:read_var (S.state t) in
            Array.iteri state ~f:(fun i s ->
                Core.printf "state[%d] = %!" i; Fq.print s
            ; Core.printf "\n%!";
              )
          ); *)
        ksprintf Impl.with_label "absorb: %s" __LOC__ (fun () ->
            S.absorb t input )

      let squeeze t =
        (*
        as_prover As_prover.(fun () ->
            let state = Array.map ~f:read_var (S.state t) in
            Array.iteri state ~f:(fun i s ->
                Core.printf "caml-squeeze-state[%d] = %!" i; Fq.print s
            ; Core.printf "\n%!";
              )
          );
*)
        let x =
          ksprintf Impl.with_label "squeeze: %s" __LOC__ (fun () -> S.squeeze t)
        in
        (*
        as_prover As_prover.(fun () ->
            Core.printf "caml-squeeze:%!"; Fq.print  (read_var x)
            ; Core.printf "\n%!";
          );
*)
        x
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
end

(*
module M = Dlog_main.Dlog_main (Dlog_main_inputs)

let wrap_proof vk public_input
    ( (prev_statement :
        ( Challenge.Constant.t
        , Fq.t
        , bool
        , (Challenge.Constant.t, bool) Types.Bulletproof_challenge.t
        , _ Types.Pairing_based.Proof_state.Me_only.t
        , _ Types.Dlog_based.Proof_state.Me_only.t
        , _ )
        Types.Pairing_based.Statement.t)
    , (prev_x_hat_beta1 : Fq.t)
    , (prev_dlog_evals : Fq.t Pickles_types.Dlog_marlin_types.Evals.t Triple.t)
    ) (pi : Snarky_bn382_backend.Pairing_based.Proof.t) =
  let prev_me_only : _ Types.Dlog_based.Proof_state.Me_only.t =
    prev_statement.pass_through
  in
  let index = prev_me_only.pairing_marlin_index in
  let prev_bulletproof_challenges =
    prev_statement.proof_state.deferred_values.bulletproof_challenges
  in
  let fp_as_fq (x : Fp.t) = Fq.of_bigint (Fp.to_bigint x) in
  let input =
    let open Pickles_types.Vector in
    let fp =
      let open Inputs.Impl in
      Typ.transport M.Fq.typ ~there:fp_as_fq ~back:(fun (x : Fq.t) ->
          Fp.of_bigint (Fq.to_bigint x) )
    in
    Snarky.Typ.tuple3 (typ fp Nat.N3.n)
      (*       (typ M.Fq.typ Nat.N1.n) *)
      (typ M.Challenge.packed_typ Nat.N9.n)
      (*       (typ M.Fq.typ Nat.N1.n) *)
      (typ M.Digest.packed_typ Nat.N3.n)
  in
  let kp =
    Inputs.Impl.generate_keypair ~exposing:[input] (fun x () -> M.main x)
  in
  let module O = Snarky_bn382_backend.Pairing_based.Oracles in
  let o = O.create vk public_input pi in
  let chal x =
    M.Challenge.Constant.of_bits (List.take (Fp.to_bits x) M.Challenge.length)
  in
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
  (let module Impl =
     Snarky.Snark.Run.Make (Snarky_bn382_backend.Pairing_based) (Unit)
   in
  List.iter
    [ ("alpha", alpha)
    ; ("eta_a", eta_a)
    ; ("eta_b", eta_b)
    ; ("eta_c", eta_c)
    ; ("r_k", r_k)
    ; ("beta_1", beta_1)
    ; ("beta_2", beta_2)
    ; ("beta_3", beta_3)
    ; ("r", r)
    ; ("xi", xi)
    ; ("digest_before_evaluations", sponge_digest_before_evaluations) ]
    ~f:(fun (s, x) ->
      Core.printf "%s: %s\n%!" s (Impl.Field.Constant.to_string x) )) ;
  (* Redundant computation *)
  let r_xi_sum =
    let { Pickles_types.Pairing_marlin_types.Evals.w_hat
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
      pi.openings.evals
    in
    let x_hat = O.x_hat_beta1 o in
    let combine t (pt : Fp.t) =
      let open Fp in
      Pickles_types.Pcs_batch.combine_evaluations
        ~crs_max_degree:Inputs.crs_max_degree ~mul ~add ~one
        ~evaluation_point:pt ~xi t
    in
    let f_1 =
      combine Common.pairing_beta_1_pcs_batch beta_1
        [x_hat; w_hat; z_hat_a; z_hat_b; g_1; h_1]
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
  in
  let print_g1 lab (x, y) =
    Core.printf "cpu: %s (%s, %s)" lab
      (Inputs.Impl.Field.Constant.to_string x)
      (Inputs.Impl.Field.Constant.to_string y)
  in
  let f_1, f_2, f_3 =
    let combine t v =
      let open G1 in
      let module Impl =
        Snarky.Snark.Run.Make (Snarky_bn382_backend.Pairing_based) (Unit)
      in
      let scale acc xi =
        let x, y = to_affine_exn acc in
        Core.printf "cpu scale: acc=(%s, %s), xi=%s\n%!"
          (Inputs.Impl.Field.Constant.to_string x)
          (Inputs.Impl.Field.Constant.to_string y)
          (Impl.Field.Constant.to_string xi) ;
        scale acc xi
      in
      let add p scaled =
        let px, py = to_affine_exn p in
        let sx, sy = to_affine_exn scaled in
        Core.printf "cpu add: p=(%s, %s), scaled=(%s, %s)\n%!"
          (Inputs.Impl.Field.Constant.to_string px)
          (Inputs.Impl.Field.Constant.to_string py)
          (Inputs.Impl.Field.Constant.to_string sx)
          (Inputs.Impl.Field.Constant.to_string sy) ;
        add p scaled
      in
      Core.printf "cpu combine\n%!" ;
      Pickles_types.Pcs_batch.combine_commitments t ~scale ~add ~xi
        (Pickles_types.Vector.map v ~f:G1.of_affine)
    in
    let { Pickles_types.Pairing_marlin_types.Messages.w_hat
        ; z_hat_a
        ; z_hat_b
        ; gh_1= (g1, _), h1
        ; sigma_gh_2= _, ((g2, _), h2)
        ; sigma_gh_3= _, ((g3, _), h3) } =
      pi.messages
    in
    let x_hat =
      let v = Fp.Vector.create () in
      Core.printf "cpu xhat multiscale\n%!" ;
      (let module Impl =
         Snarky.Snark.Run.Make (Snarky_bn382_backend.Pairing_based) (Unit)
       in
      List.iteri public_input ~f:(fun _ x ->
          Core.printf "%s\n%!" (Impl.Field.Constant.to_string x) )) ;
      List.iter public_input ~f:(Fp.Vector.emplace_back v) ;
      time "x_hat" (fun () ->
          Snarky_bn382.Fp_urs.commit_subdomain
            (Lazy.force Snarky_bn382_backend.Pairing_based.Keypair.urs)
            (Unsigned.Size_t.of_int 64)
            (Unsigned.Size_t.of_int (131072 / 64))
            v
          |> Snarky_bn382_backend.G1.Affine.of_backend )
    in
    print_g1 "x_hat" x_hat ;
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
  in
  print_g1 "w" pi.messages.w_hat ;
  print_g1 "za" pi.messages.z_hat_a ;
  print_g1 "zb" pi.messages.z_hat_b ;
  print_g1 "f_1" (G1.to_affine_exn f_1) ;
  print_g1 "f_2" (G1.to_affine_exn f_2) ;
  print_g1 "f_3" (G1.to_affine_exn f_3) ;
  let proof1, proof2, proof3 = Triple.map pi.openings.proofs ~f:G1.of_affine in
  let next_bulletproof_challenges =
    compute_challenges
      prev_statement.proof_state.deferred_values.bulletproof_challenges
  in
  let next_statement : _ Types.Dlog_based.Statement.t =
    let me_only : _ Types.Dlog_based.Proof_state.Me_only.t =
      let open G1 in
      let conv = Double.map ~f:G1.of_affine in
      let g1 = conv (fst pi.messages.gh_1) in
      let g2 = conv (fst (snd pi.messages.sigma_gh_2)) in
      let g3 = conv (fst (snd pi.messages.sigma_gh_3)) in
      let prev_acc =
        Pickles_types.Pairing_marlin_types.Accumulator.map ~f:G1.of_affine
          prev_statement.pass_through.pairing_marlin_acc
      in
      { pairing_marlin_index= prev_me_only.pairing_marlin_index
      ; pairing_marlin_acc=
          Pickles_types.Pairing_marlin_types.Accumulator.map
            ~f:G1.to_affine_exn
            { degree_bound_checks=
                Dlog_main.accumulate_degree_bound_checks
                  prev_acc.degree_bound_checks ~add ~scale ~r_h:r ~r_k g1 g2 g3
            ; opening_check=
                Dlog_main.accumulate_opening_check ~add ~negate ~scale
                  ~generator:one ~r ~r_xi_sum prev_acc.opening_check
                  (f_1, beta_1, proof1) (f_2, beta_2, proof2)
                  (f_3, beta_3, proof3) }
      ; old_bulletproof_challenges= next_bulletproof_challenges }
    in
    { proof_state=
        { deferred_values=
            { xi= chal xi
            ; r= chal r
            ; r_xi_sum
            ; marlin=
                { sigma_2= fst pi.messages.sigma_gh_2
                ; sigma_3= fst pi.messages.sigma_gh_3
                ; alpha= chal alpha
                ; eta_a= chal eta_a
                ; eta_b= chal eta_b
                ; eta_c= chal eta_c
                ; beta_1= chal beta_1
                ; beta_2= chal beta_2
                ; beta_3= chal beta_3 } }
        ; sponge_digest_before_evaluations=
            M.Digest.Constant.of_bits
              (List.take
                 (Fp.to_bits sponge_digest_before_evaluations)
                 M.Digest.length)
        ; me_only }
    ; pass_through: _ Types.Pairing_based.Proof_state.Me_only.t =
        prev_statement.proof_state.me_only }
  in
  let handler (Snarky.Request.With {request; respond}) =
    let open M.Requests in
    let k x = respond (Provide x) in
    match request with
    | Prev_evals ->
        k prev_dlog_evals
    | Prev_x_hat_beta_1 ->
        k prev_x_hat_beta1
    | Prev_messages ->
        k pi.messages
    | Prev_openings_proof ->
        k pi.openings.proofs
    | Prev_proof_state ->
        k
          { prev_statement.proof_state with
            me_only=
              Common.hash_pairing_me_only prev_statement.proof_state.me_only
          ; deferred_values=
              { prev_statement.proof_state.deferred_values with
                bulletproof_challenges=
                  prev_statement.proof_state.deferred_values
                    .bulletproof_challenges } }
    | Prev_me_only ->
        k prev_statement.pass_through
    | _ ->
        Snarky.Request.unhandled
  in
  let module I = Inputs.Impl in
  I.prove (I.Keypair.pk kp) [input]
    (fun x () -> I.handle (fun () -> M.main x) handler)
    ()
    (Types.Dlog_based.Statement.to_data
       { proof_state=
           { next_statement.proof_state with
             sponge_digest_before_evaluations=
               next_statement.proof_state.sponge_digest_before_evaluations
           ; me_only=
               Common.hash_dlog_me_only next_statement.proof_state.me_only }
       ; pass_through= Common.hash_pairing_me_only next_statement.pass_through
       })

(*
  let n =
    Inputs.Impl.constraint_count (fun () -> M.main (Inputs.Impl.exists input))
  in
  Core.printf "dlog-main: %d / %d\n%!" n
    !Snarky_bn382_backend.R1cs_constraint_system.weight ;
  let wt = !Snarky_bn382_backend.R1cs_constraint_system.wt in
  Core.printf "weights %d %d %d\n%!" wt.a wt.b wt.c ;
  Core.printf "yo: %d\n%!" n *)
   *)
