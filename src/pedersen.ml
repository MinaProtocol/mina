open Core_kernel

module type S = sig
  type curve

  module Digest : sig
    type t [@@deriving bin_io]

    module Bits : Bits_intf.S with type t := t

    module Snarkable : functor (Impl : Snark_intf.S) ->
      Impl.Snarkable.Bits.S
      with type Packed.var = Impl.Cvar.t
       and type Packed.value = Impl.Field.t
       and type Unpacked.value = Impl.Field.t
  end

  module Params : sig
    type t = curve array

    val random : max_input_length:int -> t
  end

  module State : sig
    type t

    val create : Params.t ->  t

    val update_bigstring : t -> Bigstring.t -> unit

    val update_fold
      : t
      -> (init:(curve * int) -> f:((curve * int) -> bool -> (curve * int)) -> curve * int)
      -> unit

    val update_iter
      : t
      -> (f:(bool -> unit) -> unit)
      -> unit

    val digest : t -> Digest.t
  end
end

module Make
    (Field : Camlsnark.Field_intf.S)
    (Bigint : Camlsnark.Bigint_intf.Extended with type field := Field.t)
    (Curve : Camlsnark.Curves.Edwards.Basic.S with type field := Field.t) =
struct
  (* TODO: Unit tests for field_to_bigstring/bigstring_to_field *)

  module Digest = struct
    type t = Field.t

    include Field_bin.Make(Field)(Bigint)

    module Snarkable = Bits.Snarkable.Field

    module Bits = Bits.Make_field(Field)(Bigint)
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

    let update_fold (t : t) (fold : init:'acc -> f:('acc -> bool -> 'acc) -> 'acc) =
      let params = t.params in
      let (acc, i) =
        fold ~init:(t.acc, t.i) ~f:(fun (acc, i) b ->
          if b then (Curve.add acc params.(i), i + 1) else (acc, i + 1))
      in
      t.acc <- acc;
      t.i <- i
    ;;

    let update_iter (t : t) (iter : f:(bool -> unit) -> unit) =
      let i = ref t.i in
      let acc = ref t.acc in
      let params = t.params in
      iter ~f:(fun b ->
        (if b then acc := Curve.add !acc params.(!i));
        incr i);
      t.acc <- !acc;
      t.i <- !i
    ;;

    let update_bigstring (t : t) (s : Bigstring.t) =
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

    let digest t = let (x, _y) = t.acc in x
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

  include Make(Snark_params.Main.Field)(Snark_params.Main_curve.Bigint.R)(Curve)

  let params = Pedersen_params.t

  let hash_bigstring x : Digest.t =
    let s = State.create params in
    State.update_bigstring s x;
    State.digest s
  ;;

  let zero_hash = hash_bigstring (Bigstring.create 0)
end
