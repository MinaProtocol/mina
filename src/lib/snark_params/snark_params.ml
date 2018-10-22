open Core_kernel
open Bitstring_lib
open Snark_bits
module Tick_backend = Crypto_params.Tick_backend
module Tock_backend = Crypto_params.Tock_backend

module Extend (Impl : Snarky.Snark_intf.S) = struct
  include Impl

  module Snarkable = struct
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
    end
  end
end

module Tock0 = Extend (Crypto_params.Tock0)
module Tick0 = Extend (Crypto_params.Tick0)
module Wrap_input = Crypto_params.Wrap_input

module Make_inner_curve_scalar
    (Impl : Snark_intf.S)
    (Other_impl : Snark_intf.S) =
struct
  module T = Other_impl.Field

  include (
    T : module type of T with type var := T.var and module Checked := T.Checked )

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

  type var = Field.Checked.t * Field.Checked.t

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

  module Inner_curve = struct
    include Tock_backend.Inner_curve

    include Sexpable.Of_sexpable (struct
                type t = Field.t * Field.t [@@deriving sexp]
              end)
              (struct
                type nonrec t = t

                let to_sexpable = to_coords

                let of_sexpable = of_coords
              end)

    include Make_inner_curve_aux (Tock0) (Tick0)
              (Tock_backend.Inner_curve.Coefficients)

    let ctypes_typ = typ

    let scale = scale_field

    module Checked = struct
      include Snarky.Curves.Make_weierstrass_checked (Tock0) (Scalar)
                (struct
                  include Tock_backend.Inner_curve

                  let scale = scale_field
                end)
                (Coefficients)

      let add_known_unsafe t x = add_unsafe t (constant x)
    end

    let typ = Checked.typ
  end

  module Proof = struct
    include Tock0.Proof

    let dummy = Dummy_values.Tock.proof
  end

  module Verifier_gadget =
    Snarky.Gm_verifier_gadget.Make (Tock0) (Tock_backend) (Tock_backend)
      (Tick_backend)
      (struct
        let input_size = 1

        let fqe_size_in_field_elements = 2
      end)
      (Inner_curve)
end

module Tick = struct
  include (Tick0 : module type of Tick0 with module Field := Tick0.Field)

  module Field = struct
    include Tick0.Field
    include Hashable.Make (Tick0.Field)
    module Bits = Bits.Make_field (Tick0.Field) (Tick0.Bigint)

    let size_in_triples = (size_in_bits + 2) / 3

    let gen =
      Quickcheck.Generator.map
        Bignum_bigint.(gen_incl zero (Tick0.Field.size - one))
        ~f:(fun x -> Bigint.(to_field (of_bignum_bigint x)))
  end

  module Inner_curve = struct
    include Crypto_params.Tick_backend.Inner_curve

    include Sexpable.Of_sexpable (struct
                type t = Field.t * Field.t [@@deriving sexp]
              end)
              (struct
                type nonrec t = t

                let to_sexpable = to_coords

                let of_sexpable = of_coords
              end)

    include Make_inner_curve_aux (Tick0) (Tock0)
              (Tick_backend.Inner_curve.Coefficients)

    let ctypes_typ = typ

    let scale = scale_field

    module Checked = struct
      include Snarky.Curves.Make_weierstrass_checked (Tick0) (Scalar)
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
    include Pedersen.Make (Field) (Bigint) (Inner_curve)

    let zero_hash =
      digest_fold (State.create params)
        (Fold_lib.Fold.of_list [(false, false, false)])

    module Checked = struct
      include Snarky.Pedersen.Make (Tick0) (Inner_curve)
                (Crypto_params.Pedersen_params)

      let hash_triples ts ~(init : State.t) =
        hash ts ~init:(init.triples_consumed, `Value init.acc)

      let digest_triples ts ~init =
        Checked.map (hash_triples ts ~init) ~f:digest
    end
  end

  module Util = Snark_util.Make (Tick0)

  module Verifier_gadget =
    Snarky.Gm_verifier_gadget.Make (Tick0) (Tick_backend) (Tick_backend)
      (Tock_backend)
      (struct
        let input_size = Tock0.Data_spec.(size [Wrap_input.typ])

        let fqe_size_in_field_elements = 3
      end)
      (Inner_curve)
end

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

let ledger_depth = 30

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
