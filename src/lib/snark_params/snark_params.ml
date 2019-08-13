[%%import
"../../config.mlh"]

open Core
open Bitstring_lib
open Snark_bits
module Tick_backend = Crypto_params.Tick_backend
module Tock_backend = Crypto_params.Tock_backend
module Snarkette_tick = Crypto_params.Snarkette_tick
module Snarkette_tock = Crypto_params.Snarkette_tock

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

module Tock0_run = struct
  include Crypto_params.Tock0_run
  module Snarkable = Make_snarkable (Crypto_params.Tock0)
end

module Tick0 = struct
  include Crypto_params.Tick0
  module Snarkable = Make_snarkable (Crypto_params.Tick0)
end

module Tick0_run = struct
  include Crypto_params.Tick0_run
  module Snarkable = Make_snarkable (Crypto_params.Tick0)
end

let%test_unit "group-map test" =
  let params =
    Group_map.Params.create
      (module Tick0.Field)
      ~a:Tick_backend.Inner_curve.Coefficients.a
      ~b:Tick_backend.Inner_curve.Coefficients.b
  in
  let module M = Snarky.Snark.Run.Make (Tick_backend) (Unit) in
  Quickcheck.test ~trials:3 Tick0.Field.gen ~f:(fun t ->
      let (), checked_output =
        M.run_and_check
          (fun () ->
            let x, y =
              Snarky_group_map.Checked.to_group
                (module M)
                ~params (M.Field.constant t)
            in
            fun () -> M.As_prover.(read_var x, read_var y) )
          ()
        |> Or_error.ok_exn
      in
      [%test_eq: Tick0.Field.t * Tick0.Field.t] checked_output
        (Group_map.to_group (module Tick0.Field) ~params t) )

module Wrap_input = Crypto_params.Wrap_input

module Make_inner_curve_scalar
    (Impl : Snark_intf.S)
    (Other_impl : Snark_intf.S) =
struct
  module T = Other_impl.Field

  include (
    T :
      module type of T with module Var := T.Var and module Checked := T.Checked )

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

module Make_inner_curve_aux (Impl : Snark_intf.S) (Other_impl : Snark_intf.S) =
struct
  open Impl

  type var = Field.Var.t * Field.Var.t

  module Scalar = Make_inner_curve_scalar (Impl) (Other_impl)
end

module Tock = struct
  include (Tock0 : module type of Tock0 with module Proof := Tock0.Proof)

  module Fq = Snarky_field_extensions.Field_extensions.F (Tock0)

  module Inner_curve = struct
    include Tock_backend.Inner_curve

    include Sexpable.Of_sexpable (struct
                type t = Field.t * Field.t [@@deriving sexp]
              end)
              (struct
                type nonrec t = t

                let to_sexpable = to_affine_exn

                let of_sexpable = of_affine
              end)

    include Make_inner_curve_aux (Tock0) (Tick0)

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

      let scale_field = scale_field
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
            let x, y = Snarkette_tock.G2.(to_affine_exn one) in
            {x= Fqe.conv x; y= Fqe.conv y; z= Fqe.Unchecked.one}
        end

        let one : Unchecked.t = Unchecked.one

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

        let loop_count_is_neg = Snarkette_tock.Pairing_info.is_loop_count_neg
      end

      module G2_precomputation = struct
        include Snarky_pairing.G2_precomputation.Make (Fqe) (N)
                  (struct
                    include Params

                    let coeff_a = G2.Coefficients.a
                  end)

        let create_constant =
          Fn.compose create_constant G2.Unchecked.to_affine_exn
      end
    end

    include T
    include Snarky_pairing.Miller_loop.Make (T)
    module FE = Snarky_pairing.Final_exponentiation.Make (T)

    let final_exponentiation = FE.final_exponentiation4
  end

  module Tock_run = Snarky.Snark.Run.Make (Tock_backend) (Unit)

  module Pairing_run = struct
    include Tock_run

    module G1 = struct
      type t = Pairing.G1.t

      let add_unsafe a b = run_checked (Pairing.G1.add_unsafe a b)
      
      let add_exn a b =
        match run_checked (Pairing.G1.add_unsafe a b) with
        | `I_thought_about_this_very_carefully x -> x

      let typ = Pairing.G1.typ

      let one_checked = Pairing.G1.one_checked

      let scale_field = Pairing.G1.scale_field

      module Unchecked = Pairing.G1.Unchecked
      
      let scale a b ~init =
        run_checked begin
          let open Let_syntax in
          let%bind (module Shifted) = Pairing.G1.Shifted.create () in
          let%bind init = Shifted.(add zero init) in
          Pairing.G1.scale (module Shifted) a b ~init >>= Shifted.unshift_nonzero
        end
    end

    module G2 = struct
      type t = Pairing.G2.t

      let add_unsafe a b = run_checked (Pairing.G2.add_unsafe a b)

      let add_exn a b =
        match run_checked (Pairing.G2.add_unsafe a b) with
        | `I_thought_about_this_very_carefully x -> x

      let typ = Pairing.G2.typ

      let one_checked = Pairing.G2.one_checked

      module Unchecked = Pairing.G2.Unchecked

      let scale a b ~init =
        run_checked begin
          let open Let_syntax in
          let%bind (module Shifted) = Pairing.G2.Shifted.create () in
          let%bind init = Shifted.(add zero init) in
          Pairing.G2.scale (module Shifted) a b ~init >>= Shifted.unshift_nonzero
        end

      (* let scale a b c ~init = run_checked (Pairing.G2.scale a b c ~init) *)
    end

    module Fqe = struct
      type 'a t_ = 'a Pairing.Fqe.t_

      let real_part = Pairing.Fqe.real_part

      let to_list = Pairing.Fqe.to_list

      let if_ b ~then_ ~else_ = run_checked (Pairing.Fqe.if_ b ~then_ ~else_)
    end

    module Fqk = struct
      type t = Pairing.Fqk.t

      type base = Pairing.Fqk.Base.t

      let typ = Pairing.Fqk.typ

      module Unchecked = Pairing.Fqk.Unchecked

      let ( + ) = Pairing.Fqk.( + )

      let ( - ) = Pairing.Fqk.( - )

      let ( * ) a b = run_checked (Pairing.Fqk.( * ) a b)

      let inv a = run_checked (Pairing.Fqk.inv_exn a)

      let ( / ) a b = ( * ) a (inv b)

      let one = Pairing.Fqk.one

      let zero = Pairing.Fqk.zero
      
      let equal_bool a b =
        let res = run_checked Pairing.Fqk.(if_ (run_checked (equal a b)) ~then_:one ~else_:zero) in
        res = one

      let equal_var a b = Pairing.Fqk.Impl.Boolean.var_of_value (equal_bool a b)

      let equal = equal_bool

      let square x = run_checked (Pairing.Fqk.square x)

      let negate = Pairing.Fqk.negate

      let to_list x =
        let a, b = x in
        [a; b]

      let if_ b ~then_ ~else_ = run_checked (Pairing.Fqk.if_ b ~then_ ~else_)

      (* STUBS *)
      let project_to_base _ = Pairing.Fqk.Base.zero

      let of_base _ = zero

      let scale _ _ = zero

      let compare _ _ = 0

      let t_of_sexp _ = zero

      let sexp_of_t _ = [%message "blank"]

      let gen =
        Quickcheck.Generator.map (Bignum_bigint.gen_incl Bignum_bigint.zero
         Bignum_bigint.one) ~f:(fun _ -> zero)
      
      let to_yojson _ = [%to_yojson: int] 0

      let bin_size_t _ = 0

      let bin_write_t buf ~pos _ =
        let plen = Bin_prot.Nat0.unsafe_of_int 0 in
        let new_pos = Bin_prot.Write.bin_write_nat0 buf ~pos plen in
        new_pos

      let bin_writer_t = Bin_prot.Type_class.{size= bin_size_t; write= bin_write_t}

      let bin_shape_t = String.bin_shape_t

      let __bin_read_t__ _ ~pos_ref = let _pos_ref = pos_ref in (fun _ -> zero)

      let bin_read_t _ ~pos_ref = let _pos_ref = pos_ref in zero

      let bin_reader_t = Bin_prot.Type_class.{read= bin_read_t; vtag_read= __bin_read_t__}

      let bin_t =
        Bin_prot.Type_class.
          {shape= bin_shape_t; writer= bin_writer_t; reader= bin_reader_t}
    end

    module G1_precomputation = struct
      include Pairing.G1_precomputation

     (* include Pairing.G1

      let create x = x *)
    end

    module G2_precomputation = struct
      (* include Pairing.G2_precomputation *)
      
      type t = Pairing.G2_precomputation.t

      let create x = run_checked (Pairing.G2_precomputation.create x)

      let if_ b ~then_ ~else_ = run_checked (Pairing.G2_precomputation.if_ b ~then_ ~else_)

      let create_constant = Pairing.G2_precomputation.create_constant
    end

    module Impl = struct
      include Tock0_run
    end

    let miller_loop a b = run_checked (Pairing.miller_loop a b)

    let final_exponentiation a = run_checked (Pairing.final_exponentiation a)

    let unreduced_pairing a b = run_checked (Pairing.miller_loop (G1_precomputation.create a) (G2_precomputation.create b))

    let reduced_pairing a b = run_checked (Pairing.(final_exponentiation (unreduced_pairing a b)))

    let batch_miller_loop a = run_checked (Pairing.batch_miller_loop a)
  end

  module Proof = struct
    include Tock0.Proof

    let dummy = Dummy_values.Tock.Bowe_gabizon18.proof
  end

  module Sonic_verifier = struct
    include Snarky_verifier.Sonic_commitment_scheme.Make (Pairing_run) (Field)
  end
end

module Tick = struct
  include (Tick0 : module type of Tick0 with module Field := Tick0.Field)

  module Field = struct
    include Tick0.Field
    include Hashable.Make (Tick0.Field)
    module Bits = Bits.Make_field (Tick0.Field) (Tick0.Bigint)

    let size_in_triples = Int.((size_in_bits + 2) / 3)
  end

  module Fq = Snarky_field_extensions.Field_extensions.F (Tick0)

  module Inner_curve = struct
    include Crypto_params.Tick_backend.Inner_curve

    include Sexpable.Of_sexpable (struct
                type t = Field.t * Field.t [@@deriving sexp]
              end)
              (struct
                type nonrec t = t

                let to_sexpable = to_affine_exn

                let of_sexpable = of_affine
              end)

    include Make_inner_curve_aux (Tick0) (Tock0)

    let ctypes_typ = typ

    let scale = scale_field

    module Checked = struct
      include Snarky_curves.Make_weierstrass_checked (Fq) (Scalar)
                (struct
                  include Crypto_params.Tick_backend.Inner_curve

                  let scale = scale_field
                end)
                (Coefficients)
      
      let scale_field = scale_field

      let add_known_unsafe t x = add_unsafe t (constant x)
    end

    let typ = Checked.typ
  end

  module Pedersen = struct
    include Crypto_params.Pedersen_params
    include Crypto_params.Pedersen_chunk_table
    include Crypto_params.Tick_pedersen

    let zero_hash =
      digest_fold (State.create ())
        (Fold_lib.Fold.of_list [(false, false, false)])

    module Checked = struct
      include Snarky.Pedersen.Make (Tick0) (Inner_curve)
                (struct
                  let params = Crypto_params.Pedersen_params.affine
                end)

      let hash_prefix (p : State.t) =
        Section.create ~acc:(`Value p.acc)
          ~support:
            (Interval_union.of_interval (0, Hash_prefixes.length_in_triples))

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
          let c1_x, c1_y = Inner_curve.to_affine_exn c1 in
          let c2_x, c2_y = Inner_curve.to_affine_exn c2 in
          Field.equal c1_x c2_x && Field.equal c1_y c2_y

      let equal_states s1 s2 =
        equal_curves s1.State.acc s2.State.acc
        && Int.equal s1.triples_consumed s2.triples_consumed

      (* params, chunk_tables should never be modified *)

      let gen_fold n =
        let gen_triple =
          Quickcheck.Generator.map (Int.gen_incl 0 7) ~f:(function
            | 0 ->
                (false, false, false)
            | 1 ->
                (false, false, true)
            | 2 ->
                (false, true, false)
            | 3 ->
                (false, true, true)
            | 4 ->
                (true, false, false)
            | 5 ->
                (true, false, true)
            | 6 ->
                (true, true, false)
            | 7 ->
                (true, true, true)
            | _ ->
                failwith "gen_triple: got unexpected integer" )
        in
        let gen_triples n =
          Quickcheck.random_value
            (Quickcheck.Generator.list_with_length n gen_triple)
        in
        Fold.of_list (gen_triples n)

      let initial_state = State.create ()

      let run_updates fold =
        (* make sure chunk table deserialized before running test;
           actual deserialization happens just once
         *)
        ignore (Lazy.force chunk_table) ;
        let result = State.update_fold_chunked initial_state fold in
        let unchunked_result =
          State.update_fold_unchunked initial_state fold
        in
        (result, unchunked_result)

      let run_hash_test n =
        let fold = gen_fold n in
        let result, unchunked_result = run_updates fold in
        assert (equal_states result unchunked_result)

      let hash_unchunked n =
        let fold = gen_fold n in
        State.update_fold_unchunked initial_state fold

      let hash_chunked n =
        let fold = gen_fold n in
        State.update_fold_chunked initial_state fold
    end

    (* compare unchunked, chunked hashes *)

    let%test_unit "hash one triple" = For_tests.run_hash_test 1

    let%test_unit "hash small number of chunks" =
      For_tests.run_hash_test (Chunked_triples.Chunk.size * 25)

    let%test_unit "hash small number of chunks plus 1" =
      For_tests.run_hash_test ((Chunked_triples.Chunk.size * 25) + 1)

    let%test_unit "hash large number of chunks" =
      For_tests.run_hash_test (Chunked_triples.Chunk.size * 250)

    let%test_unit "hash large number of chunks plus 2" =
      For_tests.run_hash_test ((Chunked_triples.Chunk.size * 250) + 2)

    (* benchmark unchunked, chunked hashes *)

    let%bench "hash one triple unchunked" = For_tests.hash_unchunked 1

    let%bench_fun "hash one triple chunked" =
      (* make sure chunk table deserialized *)
      ignore (Lazy.force chunk_table) ;
      fun () -> For_tests.hash_chunked 1

    let%bench "hash small number of triples unchunked" =
      For_tests.hash_unchunked 25

    let%bench_fun "hash small number of triples chunked" =
      ignore (Lazy.force chunk_table) ;
      fun () -> For_tests.hash_chunked 25

    let%bench "hash large number of triples unchunked" =
      For_tests.hash_unchunked 250

    let%bench_fun "hash large number of triples chunked" =
      ignore (Lazy.force chunk_table) ;
      fun () -> For_tests.hash_chunked 250

    let%bench "hash huge number of triples unchunked" =
      For_tests.hash_unchunked 1000

    let%bench_fun "hash huge number of triples chunked" =
      ignore (Lazy.force chunk_table) ;
      fun () -> For_tests.hash_chunked 1000
  end

  module Util = Snark_util.Make (Tick0)

  module Pairing = struct
    module T = struct
      module Impl = Tick0
      open Snarky_field_extensions.Field_extensions
      module Fq = Fq

      module Fr = Snarkette.Mnt4_80.Fq

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
            let x, y = Snarkette_tick.G2.(to_affine_exn one) in
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
          Fn.compose create_constant G2.Unchecked.to_affine_exn
      end
    end

    include T
    include Snarky_pairing.Miller_loop.Make (T)
    module FE = Snarky_pairing.Final_exponentiation.Make (T)

    let final_exponentiation = FE.final_exponentiation6
  end

  module Run = Snarky.Snark.Run.Make (Tick_backend) (Unit)

  module Tick_run = Snarky.Snark.Run.Make (Tick_backend) (Unit)

  module Pairing_run = struct
    include Tick_run

    module G1 = struct
      type t = Pairing.G1.t

      let add_unsafe a b = run_checked (Pairing.G1.add_unsafe a b)
      
      let add_exn a b =
        match run_checked (Pairing.G1.add_unsafe a b) with
        | `I_thought_about_this_very_carefully x -> x

      let typ = Pairing.G1.typ

      let one_checked = Pairing.G1.one_checked

      module Unchecked = Pairing.G1.Unchecked
      
      let scale a b ~init =
        run_checked begin
          let open Let_syntax in
          let%bind (module Shifted) = Pairing.G1.Shifted.create () in
          let%bind init = Shifted.(add zero init) in
          Pairing.G1.scale (module Shifted) a b ~init >>= Shifted.unshift_nonzero
        end
    end

    module G2 = struct
      type t = Pairing.G2.t

      let add_unsafe a b = run_checked (Pairing.G2.add_unsafe a b)

      let add_exn a b =
        match run_checked (Pairing.G2.add_unsafe a b) with
        | `I_thought_about_this_very_carefully x -> x

      let typ = Pairing.G2.typ

      module Unchecked = Pairing.G2.Unchecked

      let scale a b c ~init = run_checked (Pairing.G2.scale a b c ~init)
    end

    module Fqe = struct
      type 'a t_ = 'a Pairing.Fqe.t_

      let real_part = Pairing.Fqe.real_part

      let to_list = Pairing.Fqe.to_list

      let if_ b ~then_ ~else_ = run_checked (Pairing.Fqe.if_ b ~then_ ~else_)
    end

    module Fqk = struct
      type t = Pairing.Fqk.t

      let typ = Pairing.Fqk.typ

      module Unchecked = Pairing.Fqk.Unchecked

      let ( * ) a b = run_checked (Pairing.Fqk.( * ) a b)

      let equal a b = run_checked (Pairing.Fqk.equal a b)

      let one = Pairing.Fqk.one

      let if_ b ~then_ ~else_ = run_checked (Pairing.Fqk.if_ b ~then_ ~else_)
    end

    module G1_precomputation = struct
      include Pairing.G1_precomputation

      (* type t = G1.t

      let create x = x *)
    end

    module G2_precomputation = struct
      include Pairing.G2_precomputation
      
      (* type t = G2.t

      let if_ b ~then_ ~else_ = then_

      let create_constant x = x

      let create x = x *)
    end

    module Impl = struct
      include Tock0_run
    end

    let final_exponentiation a = run_checked (Pairing.final_exponentiation a)

    let batch_miller_loop a = run_checked (Pairing.batch_miller_loop a)
  end

  module Verifier = struct
    include Snarky_verifier.Bowe_gabizon.Make (struct
      include Pairing

      module H =
        Snarky_bowe_gabizon_hash.Make (Run) (Tick0)
          (struct
            module Fqe = Pairing.Fqe

            let init =
              Pedersen.State.salt (Hash_prefixes.bowe_gabizon_hash :> string)

            let pedersen x =
              Pedersen.Checked.digest_triples ~init (Fold_lib.Fold.to_list x)

            let params = Tock_backend.bg_params
          end)

      let hash = H.hash
    end)

    let conv_fqe v =
      let v = Tock_backend.Full.Fqe.to_vector v in
      Field.Vector.(get v 0, get v 1, get v 2)

    let conv_g2 p =
      let x, y = Tick_backend.Inner_twisted_curve.to_affine_exn p in
      Pairing.G2.Unchecked.of_affine (conv_fqe x, conv_fqe y)

    let conv_fqk (p : Tock_backend.Full.Fqk.t) =
      let v = Tock_backend.Full.Fqk.to_elts p in
      let f i =
        let x j = Tick0.Field.Vector.get v ((3 * i) + j) in
        (x 0, x 1, x 2)
      in
      (f 0, f 1)

    let proof_of_backend_proof
        ({a; b; c; delta_prime; z} : Tock_backend.Proof.t) =
      {Proof.a; b= conv_g2 b; c; delta_prime= conv_g2 delta_prime; z}

    let vk_of_backend_vk (vk : Tock_backend.Verification_key.t) =
      let open Tock_backend.Verification_key in
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

module Sonic_backend = struct
  (* include Tock.Pairing_run *)

  (* module N = Snarkette.Mnt6_80.N *)

  module N = struct
    include Tock.Inner_curve.Scalar

    let num_bits _ = length_in_bits

    (* include Tock.Bigint
    let num_bits _ = Tock.Field.size_in_bits
    let of_int n = of_field (Tock.Field.of_int n) *)
  end

  module Fq = struct
    include Tick.Field

    let length_in_bits = size_in_bits

    let ( ** ) x n =
      let rec go acc i =
        if i < 0
        then acc 
        else
          let acc = square acc in 
          let acc = if N.test_bit n i then mul acc x else acc in
          go acc Int.(i - 1)
      in 
      go one (Int.(-) length_in_bits 1)

    let to_bits = unpack

    let of_bits x = Some (project x)

    (* major hack: Fq shouldn't require the to_bigint function *)
    let to_bigint x = x
  end
  
  module Fr = struct
    include Tock.Field

    let length_in_bits = size_in_bits

    let order = Tock.Field.size

    let ( ** ) x n =
      let rec go acc i =
        if i < 0
        then acc 
        else
          let acc = square acc in 
          let acc = if N.test_bit n i then mul acc x else acc in
          go acc Int.(i - 1)
      in 
      go one (Int.(-) length_in_bits 1)

    open Fold_lib

    let fold_bits = Fn.compose Fold.of_list unpack

    let to_bits = unpack

    let of_bits x = Some (project x)

    (* TODO Fix *)
    let to_bigint x = match (Fq.of_bits (to_bits x)) with
      | Some y -> y
      | None -> Fq.zero

    let to_yojson x = `String (to_string x)

    let fold x = Fold.group3 ~default:false (fold_bits x)
  end

  module Fq_target = struct
    include Tock.Pairing_run.Fqk
  end

  (* module Fq_target = struct
    type t = Fq.t * Fq.t [@@deriving eq, bin_io, sexp, compare]

    type base = Fq.t

    (* STUBS *)

    let square x = x

    let ( * ) x y = x

    let ( + ) x y = x  

    let equal x y = false

    let inv x = x

    let zero = (Fq.zero, Fq.zero)

    let one = (Fq.zero, Fq.zero)

    let project_to_base x = Fq.zero

    let unitary_inverse x = x

    let to_list x = []

    let scale x y = x

    let negate x = x
    
    let ( / ) x y = x

    let of_base x = zero

    let to_yojson x = `String "blah"

    let ( - ) x y = x

    let compare x y = 0

    let gen = Quickcheck.Generator.(tuple2 Tick.Field.gen Tick.Field.gen)
  end *)

  module G1 = struct
    type t = Tock.Pairing_run.G1.t

    (* let unchecked_to_checked u = Tock.Pairing_run.exists Tock.Pairing_run.G1.typ ~compute:(fun () -> u)

    let one = unchecked_to_checked Tock.Pairing_run.G1.one *)

    let one = Tock.Pairing_run.G1.one_checked

    let scale a b = Tock.Pairing_run.G1.scale a
                      (Bitstring_lib.Bitstring.Lsb_first.of_list (List.map ~f:Tock.Fq.Impl.Boolean.var_of_value (Fq.to_bits b)))
                      ~init:one

    let ( + ) = Tock.Pairing_run.G1.add_exn
  end

  module G2 = struct
    type t = Tock.Pairing_run.G2.t

    (* let unchecked_to_checked u = Tock.Pairing_run.exists Tock.Pairing_run.G2.typ ~compute:(fun () -> u)

    let one = unchecked_to_checked Tock.Pairing_run.G2.one *)

    let one = Tock.Pairing_run.G2.one_checked

    let scale a b = Tock.Pairing_run.G2.scale a
                      (Bitstring_lib.Bitstring.Lsb_first.of_list (List.map ~f:Tock.Fq.Impl.Boolean.var_of_value (Fq.to_bits b)))
                      ~init:one

    let ( + ) = Tock.Pairing_run.G2.add_exn
  end

  module Fqe = Crypto_params.Tock_full.Fqe

  module Pairing = struct
    include Tock.Pairing_run
  end

  module Fr_laurent = Sonic_prototype.Laurent.Make_laurent (N) (Fr)

  module Bivariate_fr_laurent = Sonic_prototype.Laurent.Make_laurent (N) (Fr_laurent)


end

module Srs = Sonic_prototype.Srs.Make (Sonic_backend)
module Commitment_scheme =
  Sonic_prototype.Commitment_scheme.Make 
    (Sonic_backend)

module Sonic_commitment_scheme = Snarky_verifier.Sonic_commitment_scheme.Make (Tock.Pairing_run) (Tock.Field)

let%test_unit "sonic test" =
  let module M = Snarky.Snark.Run.Make (Tock_backend) (Unit) in
  Quickcheck.test ~trials:3 Quickcheck.Generator.(tuple3 Tock.Field.gen Tock.Field.gen Tock.Field.gen) ~f:(fun (x, z, alpha) ->
      let (), checked_output =
        M.run_and_check
          (fun () ->
            let open Sonic_backend in
            let open Commitment_scheme in
            let open Sonic_commitment_scheme in
            let d = 15 in
            let srs = Srs.create d x alpha in
            let f = Fr_laurent.create 1 [Fr.of_int 10] in
            let commitment = commit_poly srs f in
            let opening = open_poly srs commitment z f in
            let g = List.hd_exn srs.gPositiveX in
            let h = List.hd_exn srs.hPositiveX in
            let h_alpha = List.hd_exn srs.hPositiveAlphaX in
            let h_alpha_x = List.nth_exn srs.hPositiveAlphaX 1 in
            let (vk : (G1.t, G2.t) Verification_key.t_) = {g; h; h_alpha; h_alpha_x} in
            let (vk_precomp : Verification_key.Precomputation.t) = Verification_key.Precomputation.create vk in
            fun () -> pc_v vk vk_precomp commitment z opening )
          ()
        |> Or_error.ok_exn
      in
      let res = Tock.Pairing_run.run_checked Tock.Pairing.Fqk.(if_ checked_output ~then_:one ~else_:zero) in
      assert (res = Tock.Pairing.Fqk.one)
  )

let tock_vk_to_bool_list vk =
  let vk = Tick.Verifier.vk_of_backend_vk vk in
  let g1 = Tick.Inner_curve.to_affine_exn in
  let g2 = Tick.Pairing.G2.Unchecked.to_affine_exn in
  let vk =
    { vk with
      query_base= g1 vk.query_base
    ; query= List.map vk.query ~f:g1
    ; delta= g2 vk.delta }
  in
  Tick.Verifier.Verification_key.(summary_unchecked (summary_input vk))

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

[%%inject
"scan_state_transaction_capacity_log_2", scan_state_transaction_capacity_log_2]

[%%inject
"scan_state_work_delay_factor", scan_state_work_delay_factor]

[%%inject
"scan_state_latency_factor", scan_state_latency_factor]

let pending_coinbase_depth =
  let working_levels =
    scan_state_transaction_capacity_log_2 + scan_state_work_delay_factor
    - scan_state_latency_factor + 1
  in
  let root_nodes = Int.pow 2 scan_state_latency_factor in
  let total_stacks = working_levels * root_nodes in
  Int.ceil_log2 total_stacks

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
