[%%import
"../../config.mlh"]

open Core_kernel
open Bitstring_lib
open Snark_bits
module Tick_backend = Crypto_params.Tick_backend
module Tock_backend = Crypto_params.Tock_backend

module Make_snarkable (Impl : Snarky.Snark_intf.S) = struct
  open Impl

  module type S = sig
    type var

    type value

    val typ : (var, value) Typ.t
  end

  module Bits = struct
    module type Lossy =
      Bits_intf.Snarkable.Lossy
      with type ('a, 'b) typ := ('a, 'b) Typ.t
       and type ('a, 'b) checked := ('a, 'b) Checked.t
       and type boolean_var := Boolean.var

    module type Faithful =
      Bits_intf.Snarkable.Faithful
      with type ('a, 'b) typ := ('a, 'b) Typ.t
       and type ('a, 'b) checked := ('a, 'b) Checked.t
       and type boolean_var := Boolean.var

    module type Small =
      Bits_intf.Snarkable.Small
      with type ('a, 'b) typ := ('a, 'b) Typ.t
       and type ('a, 'b) checked := ('a, 'b) Checked.t
       and type boolean_var := Boolean.var
       and type comparison_result := Field.Checked.comparison_result
       and type field_var := Field.Var.t
  end
end

module Tock0 = struct
  include Crypto_params.Tock0
  module Snarkable = Make_snarkable (Crypto_params.Tock0)
end

module Tick0 = struct
  include Crypto_params.Tick0
  module Snarkable = Make_snarkable (Crypto_params.Tick0)
end

module Wrap_input = Crypto_params.Wrap_input

module Make_inner_curve_scalar
    (Impl : Snark_intf.S)
    (Other_impl : Snark_intf.S) =
struct
  module T = Other_impl.Field

  include (
    T :
      module type of T with module Var := T.Var and module Checked := T.Checked )

  include Infix

  let of_bits = Other_impl.Field.project

  let length_in_bits = size_in_bits

  open Impl

  type var = Boolean.var Bitstring.Lsb_first.t

  let typ : (var, t) Typ.t =
    Typ.transport_var
      (Typ.transport
         (Typ.list ~length:size_in_bits Boolean.typ)
         ~there:unpack ~back:project)
      ~there:Bitstring.Lsb_first.to_list ~back:Bitstring.Lsb_first.of_list

  let gen : t Quickcheck.Generator.t =
    Quickcheck.Generator.map
      (Bignum_bigint.gen_incl Bignum_bigint.one
         Bignum_bigint.(Other_impl.Field.size - one))
      ~f:(fun x -> Other_impl.Bigint.(to_field (of_bignum_bigint x)))

  let test_bit x i = Other_impl.Bigint.(test_bit (of_field x) i)

  module Checked = struct
    let equal a b =
      Bitstring_checked.equal
        (Bitstring.Lsb_first.to_list a)
        (Bitstring.Lsb_first.to_list b)

    let to_bits = Fn.id

    module Assert = struct
      let equal : var -> var -> (unit, _) Checked.t =
       fun a b ->
        Bitstring_checked.Assert.equal
          (Bitstring.Lsb_first.to_list a)
          (Bitstring.Lsb_first.to_list b)
    end
  end
end

module Make_inner_curve_aux
    (Impl : Snark_intf.S)
    (Other_impl : Snark_intf.S) (Coefficients : sig
        val a : Impl.Field.t

        val b : Impl.Field.t
    end) =
struct
  open Impl

  type var = Field.Var.t * Field.Var.t

  module Scalar = Make_inner_curve_scalar (Impl) (Other_impl)

  let find_y x =
    let y2 =
      Field.Infix.(
        (x * Field.square x) + (Coefficients.a * x) + Coefficients.b)
    in
    if Field.is_square y2 then Some (Field.sqrt y2) else None
end

module Tock = struct
  include (Tock0 : module type of Tock0 with module Proof := Tock0.Proof)

  module Groth16 = Snarky.Snark.Make (Tock_backend.Full.Default)
  module Fq = Snarky_field_extensions.Field_extensions.F (Tock0)
  module Snarkette_tock = Snarkette.Mnt4_80

  module Inner_curve = struct
    include Tock_backend.Inner_curve

    include Sexpable.Of_sexpable (struct
                type t = Field.t * Field.t [@@deriving sexp]
              end)
              (struct
                type nonrec t = t

                let to_sexpable = to_affine_coordinates

                let of_sexpable = of_affine_coordinates
              end)

    include Make_inner_curve_aux (Tock0) (Tick0)
              (Tock_backend.Inner_curve.Coefficients)

    let ctypes_typ = typ

    let scale = scale_field

    module Checked = struct
      include Snarky_curves.Make_weierstrass_checked (Fq) (Scalar)
                (struct
                  include Tock_backend.Inner_curve

                  let scale = scale_field
                end)
                (Coefficients)

      let add_known_unsafe t x = add_unsafe t (constant x)
    end

    let typ = Checked.typ
  end

  module Pairing = struct
    module T = struct
      let conv_field =
        Fn.compose Tock0.Field.of_string Snarkette_tock.Fq.to_string

      module Impl = Tock0
      open Snarky_field_extensions.Field_extensions
      module Fq = Fq

      let non_residue = conv_field Snarkette_tock.non_residue

      module Fqe = struct
        module Params = struct
          let non_residue = non_residue

          let mul_by_non_residue x = Fq.scale x non_residue
        end

        include E2 (Fq) (Params)

        let conv = A.map ~f:conv_field

        let real_part (x, _) = x
      end

      module G1 = struct
        module Unchecked = Inner_curve

        let one : Unchecked.t = Inner_curve.one

        include Inner_curve.Checked
      end

      module G2 = struct
        module Coefficients = struct
          let a = Fq.Unchecked.(Inner_curve.Coefficients.a * non_residue, zero)

          let b = Fq.Unchecked.(zero, Inner_curve.Coefficients.b * non_residue)
        end

        module Unchecked = struct
          include Snarkette.Elliptic_curve.Make (struct
                      include Inner_curve.Scalar

                      let num_bits _ = Field.size_in_bits
                    end)
                    (Fqe.Unchecked)
                    (Coefficients)

          let one =
            let x, y = Snarkette_tock.G2.(to_affine_coordinates one) in
            { x=
                Fqe.conv x
            ; y=Fqe.conv y
            ; z= Fqe.Unchecked.one }
        end

        include Snarky_curves.Make_weierstrass_checked
                  (Fqe)
                  (Inner_curve.Scalar)
                  (struct
                    include Unchecked

                    let double x = x + x

                    let random () = scale one (Tick0.Field.random ())
                  end)
                  (Unchecked.Coefficients)
      end

      module Fqk = struct
        module Params = struct
          let non_residue = Fq.Unchecked.(zero, one)

          let mul_by_non_residue = Fqe.mul_by_primitive_element

          let frobenius_coeffs_c1 =
            Array.map ~f:conv_field
              Snarkette_tock.Fq4.Params.frobenius_coeffs_c1
        end

        include F4 (Fqe) (Params)
      end

      module G1_precomputation =
        Snarky_pairing.G1_precomputation.Make (Tock0) (Fqe)
          (struct
            let twist = Fq.Unchecked.(zero, one)
          end)

      module N = Snarkette.Mnt6_80.N

      module Params = struct
        include Snarkette_tock.Pairing_info

        let loop_count_is_neg =
          Snarkette_tock.Pairing_info.is_loop_count_neg
      end

      module G2_precomputation = struct
        include Snarky_pairing.G2_precomputation.Make (Fqe) (N)
                  (struct
                    include Params

                    let coeff_a = G2.Coefficients.a
                  end)

        let create_constant =
          Fn.compose create_constant G2.Unchecked.to_affine_coordinates
      end
    end

    include T
    include Snarky_pairing.Miller_loop.Make (T)
    module FE = Snarky_pairing.Final_exponentiation.Make (T)

    let final_exponentiation = FE.final_exponentiation4
  end

  module Proof = struct
    include Tock0.Proof

    let dummy = Dummy_values.Tock.GrothMaller17.proof
  end

  module Groth_maller_verifier = Snarky_verifier.Groth_maller.Make (Pairing)

  module Groth_verifier = struct
    include Snarky_verifier.Groth.Make (Pairing)

    let conv_fqe v = Field.Vector.(get v 0, get v 1)

    let conv_g2 p =
      let x, y = Tock_backend.Inner_twisted_curve.to_coords p in
      Pairing.G2.Unchecked.of_affine_coordinates (conv_fqe x, conv_fqe y)

    let conv_fqk p =
      let v = Tick_backend.Full.Fqk.to_elts p in
      let f i =
        let x j = Tock0.Field.Vector.get v ((2 * i) + j) in
        (x 0, x 1)
      in
      (f 0, f 1)

    let proof_of_backend_proof p =
      let open Tick_backend.Full.Groth16_proof_accessors in
      {Proof.a= a p; b= conv_g2 (b p); c= c p}

    let vk_of_backend_vk vk =
      let open Tick_backend.Full.Groth16_verification_key_accessors in
      let open Inner_curve.Vector in
      let q = query vk in
      { Verification_key.query_base= get q 0
      ; query= List.init (length q - 1) ~f:(fun i -> get q (i + 1))
      ; delta= conv_g2 (delta vk)
      ; alpha_beta= conv_fqk (alpha_beta vk) }

    let constant_vk vk =
      let open Verification_key in
      { query_base= Inner_curve.Checked.constant vk.query_base
      ; query= List.map ~f:Inner_curve.Checked.constant vk.query
      ; delta= Pairing.G2.constant vk.delta
      ; alpha_beta= Pairing.Fqk.constant vk.alpha_beta }
  end
end

module Tick = struct
  include (Tick0 : module type of Tick0 with module Field := Tick0.Field)

  module Groth16 = Snarky.Snark.Make (Tick_backend.Full.Default)

  module Field = struct
    include Tick0.Field
    include Hashable.Make (Tick0.Field)
    module Bits = Bits.Make_field (Tick0.Field) (Tick0.Bigint)

    let size_in_triples = (size_in_bits + 2) / 3
  end

  module Fq = Snarky_field_extensions.Field_extensions.F (Tick0)

  module Inner_curve = struct
    include Crypto_params.Tick_backend.Inner_curve

    include Sexpable.Of_sexpable (struct
                type t = Field.t * Field.t [@@deriving sexp]
              end)
              (struct
                type nonrec t = t

                let to_sexpable = to_affine_coordinates

                let of_sexpable = of_affine_coordinates
              end)

    include Make_inner_curve_aux (Tick0) (Tock0)
              (Tick_backend.Inner_curve.Coefficients)

    let ctypes_typ = typ

    let scale = scale_field

    let point_near_x x =
      let rec go x = function
        | Some y -> of_affine_coordinates (x, y)
        | None ->
            let x' = Field.(add one x) in
            go x' (find_y x')
      in
      go x (find_y x)

    module Checked = struct
      include Snarky_curves.Make_weierstrass_checked (Fq) (Scalar)
                (struct
                  include Crypto_params.Tick_backend.Inner_curve

                  let scale = scale_field
                end)
                (Coefficients)

      let add_known_unsafe t x = add_unsafe t (constant x)
    end

    let typ = Checked.typ
  end

  module Pedersen = struct
    include Crypto_params.Pedersen_params
    include Crypto_params.Pedersen_chunk_table
    include Pedersen.Make (Field) (Bigint) (Inner_curve)

    let zero_hash =
      digest_fold
        (State.create params ~get_chunk_table)
        (Fold_lib.Fold.of_list [(false, false, false)])

    module Checked = struct
      include Snarky.Pedersen.Make (Tick0) (Inner_curve)
                (Crypto_params.Pedersen_params)

      let hash_triples ts ~(init : State.t) =
        hash ts ~init:(init.triples_consumed, `Value init.acc)

      let digest_triples ts ~init =
        Checked.map (hash_triples ts ~init) ~f:digest
    end

    (* easier to put these hashing tests here, where Pedersen.Make has been applied, than
      inside the Pedersen functor
    *)
    module For_tests = struct
      open Fold_lib

      let equal_curves c1 c2 =
        if phys_equal c1 Inner_curve.zero || phys_equal c2 Inner_curve.zero
        then phys_equal c1 c2
        else
          let c1_x, c1_y = Inner_curve.to_affine_coordinates c1 in
          let c2_x, c2_y = Inner_curve.to_affine_coordinates c2 in
          Field.equal c1_x c2_x && Field.equal c1_y c2_y

      let equal_states s1 s2 =
        equal_curves s1.State.acc s2.State.acc
        && Int.equal s1.triples_consumed s2.triples_consumed
        (* params, chunk_tables should never be modified *)
        && phys_equal s1.params s2.params
        && phys_equal (s1.get_chunk_table ()) (s2.get_chunk_table ())

      let gen_fold n =
        let gen_triple =
          Quickcheck.Generator.map (Int.gen_incl 0 7) ~f:(function
            | 0 -> (false, false, false)
            | 1 -> (false, false, true)
            | 2 -> (false, true, false)
            | 3 -> (false, true, true)
            | 4 -> (true, false, false)
            | 5 -> (true, false, true)
            | 6 -> (true, true, false)
            | 7 -> (true, true, true)
            | _ -> failwith "gen_triple: got unexpected integer" )
        in
        let gen_triples n =
          Quickcheck.random_value
            (Quickcheck.Generator.list_with_length n gen_triple)
        in
        Fold.of_list (gen_triples n)

      let initial_state = State.create params ~get_chunk_table

      let run_updates fold =
        (* make sure chunk table deserialized before running test;
           actual deserialization happens just once
         *)
        ignore (Crypto_params.Pedersen_chunk_table.deserialize ()) ;
        let result = State.update_fold_chunked initial_state fold in
        let unchunked_result =
          State.update_fold_unchunked initial_state fold
        in
        (result, unchunked_result)

      let run_hash_test n =
        let fold = gen_fold n in
        let result, unchunked_result = run_updates fold in
        assert (equal_states result unchunked_result)
    end

    let%test_unit "hash one triple" = For_tests.run_hash_test 1

    let%test_unit "hash small number of chunks" =
      For_tests.run_hash_test (Chunked_triples.Chunk.size * 25)

    let%test_unit "hash small number of chunks plus 1" =
      For_tests.run_hash_test ((Chunked_triples.Chunk.size * 25) + 1)

    let%test_unit "hash large number of chunks" =
      For_tests.run_hash_test (Chunked_triples.Chunk.size * 250)

    let%test_unit "hash large number of chunks plus 2" =
      For_tests.run_hash_test ((Chunked_triples.Chunk.size * 250) + 2)
  end

  module Util = Snark_util.Make (Tick0)
  module Snarkette_tick = Snarkette.Mnt6_80

  module Pairing = struct
    module T = struct
      module Impl = Tick0
      open Snarky_field_extensions.Field_extensions
      module Fq = Fq

      let conv_field =
        Fn.compose Tick0.Field.of_string Snarkette_tick.Fq.to_string

      let non_residue = conv_field Snarkette_tick.non_residue

      module Fqe = struct
        module Params = struct
          let non_residue = non_residue

          let mul_by_non_residue x = Fq.scale x non_residue

          let frobenius_coeffs_c1 =
            Array.map ~f:conv_field
              Snarkette_tick.Fq3.Params.frobenius_coeffs_c1

          let frobenius_coeffs_c2 =
            Array.map ~f:conv_field
              Snarkette_tick.Fq3.Params.frobenius_coeffs_c2
        end

        include F3 (Fq) (Params)

        let conv = A.map ~f:conv_field

        let real_part (x, _, _) = x
      end

      module G1 = struct
        module Unchecked = Inner_curve

        let one : Unchecked.t = Inner_curve.one

        include Inner_curve.Checked
      end

      module G2 = struct
        module Unchecked = struct
          include Snarkette.Elliptic_curve.Make (struct
                      include Inner_curve.Scalar

                      let num_bits _ = Field.size_in_bits
                    end)
                    (Fqe.Unchecked)
                    (struct
                      let a =
                        Tick0.Field.(zero, zero, Inner_curve.Coefficients.a)

                      let b =
                        Fq.Unchecked.
                          ( Inner_curve.Coefficients.b * Fqe.Params.non_residue
                          , zero
                          , zero )
                    end)

          let one =
            let x, y = Snarkette_tick.G2.(to_affine_coordinates one) in
            {z= Fqe.Unchecked.one; x= Fqe.conv x; y= Fqe.conv y}
        end

        include Snarky_curves.Make_weierstrass_checked
                  (Fqe)
                  (Inner_curve.Scalar)
                  (struct
                    include Unchecked

                    let double x = x + x

                    let random () = scale one (Tock.Field.random ())
                  end)
                  (Unchecked.Coefficients)
      end

      module Fqk = struct
        module Params = struct
          let frobenius_coeffs_c1 =
            Array.map ~f:conv_field
              Snarkette_tick.Fq6.Params.frobenius_coeffs_c1
        end

        module Fq2 =
          E2
            (Fq)
            (struct
              let non_residue = non_residue

              let mul_by_non_residue x = Fq.scale x non_residue
            end)

        include F6 (Fq) (Fq2) (Fqe) (Params)
      end

      module G1_precomputation =
        Snarky_pairing.G1_precomputation.Make (Tick0) (Fqe)
          (struct
            let twist = Fq.Unchecked.(zero, one, zero)
          end)

      module N = Snarkette_tick.N

      module Params = struct
        include Snarkette_tick.Pairing_info

        let loop_count_is_neg = Snarkette_tick.Pairing_info.is_loop_count_neg
      end

      module G2_precomputation = struct
        include Snarky_pairing.G2_precomputation.Make (Fqe) (N)
                  (struct
                    include Params

                    let coeff_a =
                      Tick0.Field.(zero, zero, G1.Unchecked.Coefficients.a)
                  end)

        let create_constant =
          Fn.compose create_constant G2.Unchecked.to_affine_coordinates
      end
    end

    include T
    include Snarky_pairing.Miller_loop.Make (T)
    module FE = Snarky_pairing.Final_exponentiation.Make (T)

    let final_exponentiation = FE.final_exponentiation6
  end

  module Groth_maller_verifier = struct
    include Snarky_verifier.Groth_maller.Make (Pairing)

    let conv_fqe v = Field.Vector.(get v 0, get v 1, get v 2)

    let conv_g2 p =
      let x, y = Tick_backend.Inner_twisted_curve.to_coords p in
      Pairing.G2.Unchecked.of_affine_coordinates (conv_fqe x, conv_fqe y)

    let conv_fqk (p : Tock_backend.Full.Fqk.t) =
      let v = Tock_backend.Full.Fqk.to_elts p in
      let f i =
        let x j = Tick0.Field.Vector.get v ((3 * i) + j) in
        (x 0, x 1, x 2)
      in
      (f 0, f 1)

    let proof_of_backend_proof p =
      let open Tock_backend.Full.GM_proof_accessors in
      {Proof.a= a p; b= conv_g2 (b p); c= c p}

    let vk_of_backend_vk (vk : Tock_backend.Full.GM.Verification_key.t) =
      let open Tock_backend.Full.GM_verification_key_accessors in
      let open Inner_curve.Vector in
      let q = query vk in
      let g_alpha = g_alpha vk in
      let h_beta = conv_g2 (h_beta vk) in
      { Verification_key.query_base= get q 0
      ; query= List.init (length q - 1) ~f:(fun i -> get q (i + 1))
      ; h= conv_g2 (h vk)
      ; g_alpha
      ; h_beta
      ; g_gamma= g_gamma vk
      ; h_gamma= conv_g2 (h_gamma vk)
      ; g_alpha_h_beta= conv_fqk (g_alpha_h_beta vk) }

    let constant_vk vk =
      let open Verification_key in
      { query_base= Inner_curve.Checked.constant vk.query_base
      ; query= List.map ~f:Inner_curve.Checked.constant vk.query
      ; h= Pairing.G2.constant vk.h
      ; g_alpha= Pairing.G1.constant vk.g_alpha
      ; h_beta= Pairing.G2.constant vk.h_beta
      ; g_gamma= Pairing.G1.constant vk.g_gamma
      ; h_gamma= Pairing.G2.constant vk.h_gamma
      ; g_alpha_h_beta= Pairing.Fqk.constant vk.g_alpha_h_beta }
  end

  module Groth_verifier = Snarky_verifier.Groth.Make (Pairing)
end

let tock_vk_to_bool_list vk =
  let vk = Tick.Groth_maller_verifier.vk_of_backend_vk vk in
  let g1 = Tick.Inner_curve.to_affine_coordinates in
  let g2 = Tick.Pairing.G2.Unchecked.to_affine_coordinates in
  let vk =
    { vk with
      query_base= g1 vk.query_base
    ; query= List.map vk.query ~f:g1
    ; g_alpha= g1 vk.g_alpha
    ; g_gamma= g1 vk.g_gamma
    ; h= g2 vk.h
    ; h_beta= g2 vk.h_beta
    ; h_gamma= g2 vk.h_gamma }
  in
  Tick.Groth_maller_verifier.Verification_key.(
    summary_unchecked (summary_input vk))

let embed (x : Tick.Field.t) : Tock.Field.t =
  let n = Tick.Bigint.of_field x in
  let rec go pt acc i =
    if i = Tick.Field.size_in_bits then acc
    else
      go (Tock.Field.add pt pt)
        (if Tick.Bigint.test_bit n i then Tock.Field.add pt acc else acc)
        (i + 1)
  in
  go Tock.Field.one Tock.Field.zero 0

(** enable/disable use of chunk table in Pedersen hashing *)
let set_chunked_hashing b = Tick.Pedersen.State.set_chunked_fold b

[%%inject
"ledger_depth", ledger_depth]

(* Let n = Tick.Field.size_in_bits.
   Let k = n - 3.
   The reason k = n - 3 is as follows. Inside [meets_target], we compare
   a value against 2^k. 2^k requires k + 1 bits. The comparison then unpacks
   a (k + 1) + 1 bit number. This number cannot overflow so it is important that
   k + 1 + 1 < n. Thus k < n - 2.

   However, instead of using `Field.size_in_bits - 3` we choose `Field.size_in_bits - 8`
   to clamp the easiness. To something not-to-quick on a personal laptop from mid 2010s.
*)
let target_bit_length = Tick.Field.size_in_bits - 8

module type Snark_intf = Snark_intf.S
