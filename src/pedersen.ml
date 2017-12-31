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

    val random : (unit -> bool) -> max_input_length:int -> t
  end

  module State : sig
    type t

    val create : Params.t ->  t

    val update : t -> Bigstring.t -> unit

    val digest : t -> Digest.t
  end
end

module Make
    (Field : Camlsnark.Field_intf.Extended)
    (Bigint : Camlsnark.Bigint_intf.Extended with type field := Field.t)
    (Field_size : sig val size : Bigint.t end)
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

    let max_input_length t = Array.length t

    module Random (R : sig val random_bool : unit -> bool end) = struct
      open R

      let rec random_field_element () =
        let n =
          Bigint.of_numeral ~base:2
            (String.init Field.size_in_bits ~f:(fun _ ->
              if random_bool () then '\001' else '\000'))
        in
        if Bigint.compare n Field_size.size = -1
        then Bigint.to_field n
        else random_field_element ()
      ;;

      let double_points =
        [ Field.one
        ; Field.(negate one)
        ]
      ;;

      let is_double_point x = List.mem double_points x ~equal:Field.equal

      (* x^2 + y^2 = 1 + dx^2 y^2
         (1 - dx^2) y^2 = 1 - x^2
         y^2 = (1 - x^2)/(1-dx^2)
      *)

      let sqrt x =
        let a = Field.sqrt x in
        let b = Field.negate a in
        if Bigint.(compare (of_field a) (of_field b)) = -1
        then (a, b)
        else (b, a)
      ;;

      let rec random_point () =
        let x = random_field_element () in
        if is_double_point x
        then
          (if random_bool () then (x, Field.zero) else random_point ())
        else
          let c = Field.(Infix.((one - x * x) / (one - Curve.Params.d * x * x))) in
          if Field.is_square c
          then
            let (a, b) = sqrt c in
            (if random_bool () then (x, a) else (x, b))
          else
            random_point ()
      ;;

      let params max_input_length =
        Array.init max_input_length ~f:(fun _ -> random_point ())
      ;;
    end

    let random random_bool ~max_input_length =
      let module M = Random(struct let random_bool = random_bool end) in
      M.params max_input_length
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
      for i = 0 to byte_length - 1 do
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

  (* Someday: There should be a more efficient way of doing
     this since bigints are backed by a char[] *)
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

  include Make
      (Snark_params.Main.Field)(Snark_params.Main_curve.Bigint.R)
      (struct let size = Snark_params.Main_curve.field_size end)
      (Curve)

  let params = Pedersen_params.t

  let hash x : Digest.t =
    let s = State.create params in
    State.update s x;
    State.digest s
  ;;

  let zero_hash = hash (Bigstring.create 0)
end
