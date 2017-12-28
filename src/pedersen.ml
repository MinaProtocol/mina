open Core_kernel

module type S = sig
  type curve

  module Digest : sig
    type t [@@deriving bin_io]

    module Snarkable : functor (Impl : Snark_intf.S) ->
      Impl.Snarkable.Bits.S
  end

  module Params : sig
    type t = curve array

    val random : max_input_length:int -> t
  end

  module State : sig
    type t

    val create : Params.t ->  t

    val update : t -> Bigstring.t -> unit

    val digest : t -> Digest.t
  end
end

module Make
    (Field : Camlsnark.Field_intf.S)
    (Bigint : Camlsnark.Bigint_intf.S with type field := Field.t)
    (Curve : Camlsnark.Curves.Edwards.Basic.S with type field := Field.t) =
struct
  module Digest = struct
    type t = Bigstring.t [@@deriving bin_io]

    let () = assert (Snark_params.Main.Field.size_in_bits = Snark_params.Other.Field.size_in_bits)
    module Snarkable = Bits.Field_element
  end

  module Params = struct
    type t = Curve.t array

    let random_elt () =
      let x = Field.random () in
      let n = Bigint.of_field x in
      let rec go pt i acc =
        if i = Field.size_in_bits
        then acc
        else
          let acc =
            if Bigint.test_bit n i
            then Curve.add acc pt
            else acc
          in
          go (Curve.double pt) (i + 1) acc
      in
      go Curve.generator 0 Curve.identity
    ;;

    let random ~max_input_length =
      Array.init max_input_length ~f:(fun _ -> random_elt ())

    let max_input_length t = Array.length t
  end

  module State = struct
    type t =
      { mutable acc : Curve.t
      ; mutable i   : int
      ; params      : Params.t
      }

    let create params = { acc = Curve.identity; i = 0; params }

    let ith_bit_int n i =
      ((n lsr i) land 1) = 1

    let update (t : t) s =
      let byte_length = Bigstring.length s in
      let bit_length = 8 * byte_length in
      assert (bit_length <= Params.max_input_length t.params - t.i);
      let acc = ref t.acc in
      for i = 0 to byte_length do
        let c = Char.to_int (Bigstring.get s i) in
        let cond_add j acc =
          if ith_bit_int c j
          then Curve.add acc t.params.(i)
          else acc
        in
        acc :=
          !acc
          |> cond_add 0
          |> cond_add 1
          |> cond_add 2
          |> cond_add 3
          |> cond_add 4
          |> cond_add 5
          |> cond_add 6
          |> cond_add 7
      done;
      t.acc <- !acc;
      t.i   <- t.i + bit_length
    ;;

    let (/^) x y = Float.(to_int (round_up (x // y)))

    let digest t =
      let (x, _y) = t.acc in
      let n = Bigint.of_field x in
      let b i j =
        if Bigint.test_bit n (i + j) then 1 lsl i else 0
      in
      Bigstring.init (Field.size_in_bits /^ 8) ~f:(fun i ->
        Char.of_int_exn (
          b i 0
          lor b i 1
          lor b i 2
          lor b i 3
          lor b i 4
          lor b i 5
          lor b i 6
          lor b i 7))
  end
end

module Main = struct
  module Curve = struct
    include Snark_params.Main.Hash_curve

    module Scalar (Impl : Camlsnark.Snark_intf.S) = struct
      (* Someday: Make more efficient *)
      open Impl
      type var = Boolean.var list
      type value = bool list

      let length = bit_length
      let spec : (var, value) Var_spec.t = Var_spec.list ~length Boolean.spec
      let assert_equal = Checked.Assert.equal_bitstrings
    end
  end

  include Make(Snark_params.Main.Field)(Snark_params.Main.Bigint)(Curve)

  let params =
    let max_input_length = 8 * Snark_params.Main.Field.size_in_bits in
    Params.random ~max_input_length
end

