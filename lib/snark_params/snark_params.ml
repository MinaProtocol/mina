open Core_kernel
open Snark_bits
module Tick_curve = Crypto_params.Tick_curve
module Tock_curve = Crypto_params.Tock_curve

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

module Tock = struct
  module Tock0 = Extend (Snarky.Snark.Make (Tock_curve))

  include (Tock0 : module type of Tock0 with module Proof := Tock0.Proof)

  module Proof = struct
    include Tock0.Proof

    let dummy = Dummy_values.Tock.proof
  end
end

module Tick = struct
  module Tick0 = Extend (Crypto_params.Tick0)

  module Sha256 =
    Snarky.Sha256.Make (struct
        let prefix = Tick_curve.prefix
      end)
      (Tick0)
      (Tick_curve)

  include (Tick0 : module type of Tick0 with module Field := Tick0.Field)

  module Inner_curve = struct
    open Tick0

    type var = Field.Checked.t * Field.Checked.t

    include Crypto_params.Inner_curve

    module Scalar = struct
      module T = (Tock.Field : module type of Tock.Field with type var := Tock.Field.var and module Checked := Tock.Field.Checked)
      include T

      let of_bits = Tock.Field.project

      include Binable.Of_sexpable(T)

      let length_in_bits = size_in_bits

      type var = Boolean.var list

      let typ =
        Typ.transport (Typ.list ~length:size_in_bits Boolean.typ)
          ~there:unpack
          ~back:project

      let gen : t Quickcheck.Generator.t =
        Quickcheck.Generator.map
          (Bignum_bigint.gen_incl Bignum_bigint.one
             Bignum_bigint.(Tock.Field.size - one))
          ~f:(fun x ->
            Tock.Bigint.(to_field (of_bignum_bigint x)))

      module Checked = struct
        module Assert = struct
          let equal = Bitstring_checked.Assert.equal
        end
      end
    end

    module Checked = struct
      include
        Snarky.Curves.Make_weierstrass_checked
          (Tick0)
          (Scalar)
          (struct
            include Crypto_params.Inner_curve
            let scale = scale_field
          end)
          (Snarky.Libsnark.Curves.Mnt6.G1.Coefficients)

      let add_known v x = add v (constant x)
    end

    let typ = Checked.typ
  end

  module Field = struct
    module T = struct
      include Tick0.Field

      let compare t1 t2 = Bigint.(compare (of_field t1) (of_field t2))

      let hash_fold_t s x =
        Bignum_bigint.hash_fold_t s Bigint.(to_bignum_bigint (of_field x))

      let hash = Hash.of_fold hash_fold_t
    end

    include T
    include Hashable.Make (T)
    include Field_bin.Make (Tick0.Field) (Tick_curve.Bigint.R)
    module Bits = Bits.Make_field (Tick0.Field) (Tick0.Bigint)

    let gen =
      Quickcheck.Generator.map
        Bignum_bigint.(gen_incl zero (Tick0.Field.size - one))
        ~f:(fun x -> Bigint.(to_field (of_bignum_bigint x)))

    let rec compare_bitstring xs0 ys0 =
      match (xs0, ys0) with
      | true :: xs, true :: ys | false :: xs, false :: ys ->
          compare_bitstring xs ys
      | false :: _, true :: _ -> `LT
      | true :: _, false :: _ -> `GT
      | [], [] -> `EQ
      | _ :: _, [] | [], _ :: _ ->
          failwith "compare_bitstrings: Different lengths"

    let () =
      let main_size_proxy = List.rev (unpack (negate one)) in
      let other_size_proxy = List.rev Tock.Field.(unpack (negate one)) in
      assert (compare_bitstring main_size_proxy other_size_proxy = `LT)
  end

  module Pedersen = struct
    include Pedersen.Make(Field)(Bigint)(Inner_curve)
    module Checked = Snarky.Pedersen.Make(Tick0)(Inner_curve)(Crypto_params.Pedersen_params)
  end

  module Util = Snark_util.Make (Tick0)
end

let embed (x: Tick.Field.t) : Tock.Field.t =
  let n = Tick.Bigint.of_field x in
  let rec go pt acc i =
    if i = Tick.Field.size_in_bits then acc
    else
      go (Tock.Field.add pt pt)
        (if Tick.Bigint.test_bit n i then Tock.Field.add pt acc else acc)
        (i + 1)
  in
  go Tock.Field.one Tock.Field.zero 0

let ledger_depth = 3

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
