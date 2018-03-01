open Core_kernel

module type S = sig
  type curve

  module Digest : sig
    type t [@@deriving bin_io, sexp]

    val (=) : t -> t -> bool

    module Bits : Bits_intf.S with type t := t

    module Snarkable : functor (Impl : Snark_intf.S) ->
      Impl.Snarkable.Bits.Lossy
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

    val update_bigstring : t -> Bigstring.t -> t

    val update_fold
      : t
      -> (init:(curve * int) -> f:((curve * int) -> bool -> (curve * int)) -> curve * int)
      -> t

    val update_iter
      : t
      -> (f:(bool -> unit) -> unit)
      -> t

    val digest : t -> Digest.t
  end
end

module Make
    (Field : sig include Snarky.Field_intf.S include Sexpable.S with type t := t end)
    (Bigint : Snarky.Bigint_intf.Extended with type field := Field.t)
    (Curve : Snarky.Curves.Edwards.Basic.S with type field := Field.t) =
struct
  module Digest = struct
    type t = Field.t [@@deriving sexp]

    let (=) = Field.equal

    include Field_bin.Make(Field)(Bigint)

    module Snarkable = Bits.Snarkable.Field

    module Bits = Bits.Make_field(Field)(Bigint)
  end

  module Params = struct
    type t = Curve.t array

    let random_elt () =
      let x = Field.random () in
      let n = Bigint.of_field x in
      let rec go two_to_the_i i acc =
        if i = Field.size_in_bits
        then acc
        else
          let acc =
            if Bigint.test_bit n i
            then Curve.add acc two_to_the_i
            else acc
          in
          go (Curve.double two_to_the_i) (i + 1) acc
      in
      go Curve.generator 0 Curve.identity
    ;;

    let random ~max_input_length =
      Array.init max_input_length ~f:(fun _ -> random_elt ())

    let max_input_length t = Array.length t
  end

  module State = struct
    type t =
      { acc    : Curve.t
      ; i      : int
      ; params : Params.t
      }

    let create params = { acc = Curve.identity; i = 0; params }

    let ith_bit_int n i =
      ((n lsr i) land 1) = 1

    let update_fold (t : t) (fold : init:'acc -> f:('acc -> bool -> 'acc) -> 'acc) =
      let params = t.params in
      let (acc, i) =
        fold ~init:(t.acc, t.i) ~f:(fun (acc, i) b ->
          if b
          then (Curve.add acc params.(i), i + 1)
          else (acc, i + 1))
      in
      { t with acc; i }
    ;;

    let update_iter (t : t) (iter : f:(bool -> unit) -> unit) =
      let i = ref t.i in
      let acc = ref t.acc in
      let params = t.params in
      iter ~f:(fun b ->
        (if b then acc := Curve.add !acc params.(!i));
        incr i);
      { t with acc = !acc; i = !i }
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
      { t with acc = !acc; i = t.i + bit_length }
    ;;

    let digest t = let (x, _y) = t.acc in x
  end
end
