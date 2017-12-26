open Core_kernel

module Digest = struct
  type t = Bigstring.t [@@deriving bin_io]

  module Snarkable (Impl : Snark_intf.S) =
    Bits.Make0(Impl)(struct
      let bit_length = 2 * Impl.Field.size_in_bits
      let bits_per_element = Impl.Field.size_in_bits
    end)
end

module Field = Snark_params.Main.Field

module Curve = Make_edwards_basic(Field)(struct
    let d = failwith "TODO"
    let cofactor = failwith "TODO"
    let generator = failwith "TODO"
  end)

module Params = struct
  type t = Curve.t array

  let random_elt () =
    let open Snark_params.Main in
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
        go (Field.double pt) (i + 1) acc
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

  let create () = ref { acc = Curve.identity; i = 0 }

  let ith_bit_int n i =
    ((n lsr i) land 1) = 1

  let update (t : t) s =
    let byte_length = Bigstring.length s
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
      acc <-
        t.acc
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
    t.i   <- t.i + n
  ;;

  let digest t = t.acc
end
